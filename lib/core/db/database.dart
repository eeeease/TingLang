import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import 'tables.dart';

export 'tables.dart';

part 'database.g.dart';

/// Tinglang's local SQLite database (`tinglang.sqlite` in the library root).
@DriftDatabase(
  tables: [
    Media,
    Sessions,
    TimeAnchors,
    Segments,
    Translations,
    Courses,
    Clips,
    Items,
    Exercises,
    Progress,
    Attempts,
    Cards,
    ReviewLogs,
    ProviderConfigs,
    FeatureRoutes,
    LlmCache,
    PodcastFeeds,
    Episodes,
    Drafts,
    AppMeta,
    DictationAttempts,
    SyncRecords,
  ],
)
class TinglangDatabase extends _$TinglangDatabase {
  TinglangDatabase(super.executor);

  /// Opens (creating if needed) the database file on a background isolate.
  factory TinglangDatabase.open(File file) =>
      TinglangDatabase(NativeDatabase.createInBackground(file));

  factory TinglangDatabase.memory() => TinglangDatabase(NativeDatabase.memory());

  @override
  int get schemaVersion => 4;

  /// Full-text search over finalised segments. The trigram tokenizer indexes
  /// every 3-character window, so Chinese/Japanese/Korean work without a
  /// word segmenter; queries shorter than 3 characters fall back to LIKE.
  static const _ftsStatements = [
    "CREATE VIRTUAL TABLE segment_fts USING fts5(body, content='segment', "
        "content_rowid='rowid', tokenize='trigram')",
    'CREATE TRIGGER segment_fts_ai AFTER INSERT ON segment BEGIN '
        'INSERT INTO segment_fts(rowid, body) VALUES (new.rowid, new.body); END',
    'CREATE TRIGGER segment_fts_ad AFTER DELETE ON segment BEGIN '
        "INSERT INTO segment_fts(segment_fts, rowid, body) VALUES('delete', old.rowid, old.body); END",
    'CREATE TRIGGER segment_fts_au AFTER UPDATE OF body ON segment BEGIN '
        "INSERT INTO segment_fts(segment_fts, rowid, body) VALUES('delete', old.rowid, old.body); "
        'INSERT INTO segment_fts(rowid, body) VALUES (new.rowid, new.body); END',
  ];

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      for (final statement in _ftsStatements) {
        await customStatement(statement);
      }
    },
    onUpgrade: (m, from, to) async {
      // Add one `if (from < N)` step per schema version; never drop learner
      // tables. Each step is covered by test/db/migration_test.dart.
      if (from > to) {
        throw StateError(
          'Database schema $from is newer than this app ($to). '
          'Update Tinglang instead of opening it with an older build.',
        );
      }
      if (from < 2) await m.createTable(dictationAttempts);
      if (from < 3) await m.addColumn(sessions, sessions.sourceRef);
      if (from < 4) await m.createTable(syncRecords);
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// Segment ids whose text contains [query], newest first.
  Future<List<SegmentRow>> searchSegments(String query, {int limit = 50}) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return Future.value(const []);
    if (trimmed.runes.length < 3) {
      final pattern =
          '%${trimmed.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_')}%';
      return customSelect(
        r"SELECT * FROM segment WHERE body LIKE ? ESCAPE '\' "
        'ORDER BY created_at DESC LIMIT ?',
        variables: [Variable.withString(pattern), Variable.withInt(limit)],
        readsFrom: {segments},
      ).asyncMap(segments.mapFromRow).get();
    }
    // Quote as an FTS5 string so user punctuation is not query syntax.
    final phrase = '"${trimmed.replaceAll('"', '""')}"';
    return customSelect(
      'SELECT segment.* FROM segment_fts JOIN segment '
      'ON segment.rowid = segment_fts.rowid '
      'WHERE segment_fts MATCH ? ORDER BY segment.created_at DESC LIMIT ?',
      variables: [Variable.withString(phrase), Variable.withInt(limit)],
      readsFrom: {segments},
    ).asyncMap(segments.mapFromRow).get();
  }

  Future<String?> meta(String key) async =>
      (await (select(appMeta)..where((t) => t.key.equals(key))).getSingleOrNull())?.value;

  Future<void> setMeta(String key, String? value) async {
    if (value == null) {
      await (delete(appMeta)..where((t) => t.key.equals(key))).go();
    } else {
      await into(appMeta).insertOnConflictUpdate(AppMetaCompanion.insert(key: key, value: value));
    }
  }
}

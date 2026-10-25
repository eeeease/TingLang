import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;

import '../course_codec.dart';
import '../json_helpers.dart';
import '../library_store.dart';
import '../models.dart';
import '../review.dart';
import 'database.dart';

const _legacyImportKey = 'legacy_library_json_imported_at';
const _lastCourseKey = 'last_course_id';
const _lastClipKey = 'last_clip_id';
const _settingPrefix = 'setting.';

/// [LibraryStore] whose learner state lives in SQLite instead of
/// `library.json`. Media, recordings and path rules are inherited unchanged.
///
/// [save] commits one transaction per [AppController.change], writing only
/// entities that differ from the last committed state (immutable entities
/// are compared by identity, which `LibraryState.clone` preserves). A failed
/// transaction rolls back and leaves the comparison base untouched, so the
/// next save rewrites everything that is still pending.
class SqliteLibraryStore extends LibraryStore {
  SqliteLibraryStore(super.root, this.db);

  /// Opens `tinglang.sqlite` inside [root].
  factory SqliteLibraryStore.open(Directory root) =>
      SqliteLibraryStore(root, TinglangDatabase.open(File(p.join(root.path, 'tinglang.sqlite'))));

  final TinglangDatabase db;
  LibraryState _committed = LibraryState();

  /// On first launch after the JSON era, imports `library.json` once. The
  /// JSON file (and its .bak) is left untouched as a pre-migration backup.
  /// A corrupt JSON file aborts startup without writing anything.
  @override
  Future<LibraryState> load() async {
    await root.create(recursive: true);
    if (await db.meta(_legacyImportKey) == null && await stateFile.exists()) {
      final legacy = await super.load();
      await db.transaction(() async {
        await _write(LibraryState(), legacy);
        await db.setMeta(_legacyImportKey, DateTime.now().toUtc().toIso8601String());
      });
    }
    try {
      final loaded = await _read();
      for (final course in loaded.courses) {
        final media = course.mediaPath;
        if (media != null) resolve(media);
      }
      for (final attempt in loaded.attempts) {
        final recording = attempt.recordingPath;
        if (recording != null) resolve(recording);
      }
      _committed = loaded;
      return loaded.clone();
    } catch (error) {
      throw LibraryReadException(p.join(root.path, 'tinglang.sqlite'), error);
    }
  }

  @override
  Future<void> save(LibraryState state) async {
    await db.transaction(() => _write(_committed, state));
    _committed = state;
  }

  /// True once a `library.json` has been migrated into this database.
  Future<bool> get importedLegacyJson async => await db.meta(_legacyImportKey) != null;

  /// Closes SQLite (and its background isolate) cleanly. Without this the
  /// isolate is torn down mid-close at process exit (SIGSEGV in sqlite3Close).
  @override
  Future<void> close() => db.close();

  Future<LibraryState> _read() async {
    const codec = CourseCodec();
    final courses = <Course>[];
    for (final row in await (db.select(
      db.courses,
    )..orderBy([(t) => OrderingTerm(expression: const CustomExpression<int>('rowid'))])).get()) {
      courses.add(
        codec.fromMap(
          jsonObject(jsonDecode(row.rawJson), 'course.raw_json'),
          area: Area.parse(row.area),
          importedAt: row.importedAt.toUtc(),
          mediaPath: row.mediaPath,
          sourceLabel: row.sourceLabel,
        ),
      );
    }
    final attempts = [
      for (final row in await (db.select(
        db.attempts,
      )..orderBy([(t) => OrderingTerm(expression: const CustomExpression<int>('rowid'))])).get())
        PracticeAttempt(
          id: row.id,
          createdAt: row.createdAt.toUtc(),
          kind: row.kind,
          note: row.note,
          durationMs: row.durationMs,
          courseId: row.courseId,
          clipId: row.clipId,
          recordingPath: row.recordingPath,
        ),
    ];
    final completed = <String, Set<String>>{};
    for (final row in await db.select(db.progress).get()) {
      completed.putIfAbsent(entityKey(row.courseId, row.clipId), () => {}).add(row.step);
    }
    final logs = <String, List<Map<String, Object?>>>{};
    for (final row
        in await (db.select(db.reviewLogs)..orderBy([
              (t) => OrderingTerm(expression: t.cardId),
              (t) => OrderingTerm(expression: t.seq),
            ]))
            .get()) {
      logs
          .putIfAbsent(row.cardId, () => [])
          .add(jsonObject(jsonDecode(row.dataJson), 'review_log.data_json'));
    }
    final reviews = [
      for (final row in await (db.select(
        db.cards,
      )..orderBy([(t) => OrderingTerm(expression: const CustomExpression<int>('rowid'))])).get())
        ReviewCard(
          id: row.id,
          courseId: row.courseId,
          clipId: row.clipId,
          text: row.body,
          meaning: row.meaning,
          dueAt: row.dueAt.toUtc(),
          repetitions: row.repetitions,
          history: logs[row.id] ?? const [],
          stability: row.scheduler == 'fsrs6' ? row.stability : null,
          difficulty: row.scheduler == 'fsrs6' ? row.difficulty : null,
        ),
    ];
    final drafts = {for (final row in await db.select(db.drafts).get()) row.key: row.body};
    final meta = {for (final row in await db.select(db.appMeta).get()) row.key: row.value};
    return LibraryState(
      courses: courses,
      attempts: attempts,
      completed: completed,
      drafts: drafts,
      reviews: reviews,
      settings: {
        for (final e in meta.entries)
          if (e.key.startsWith(_settingPrefix)) e.key.substring(_settingPrefix.length): e.value,
      },
      lastCourseId: meta[_lastCourseKey],
      lastClipId: meta[_lastClipKey],
    );
  }

  Future<void> _write(LibraryState before, LibraryState after) async {
    // Courses and their clip/item projection.
    final oldCourses = {for (final c in before.courses) c.id: c};
    final newIds = {for (final c in after.courses) c.id};
    for (final id in oldCourses.keys.where((id) => !newIds.contains(id))) {
      await (db.delete(db.courses)..where((t) => t.id.equals(id))).go();
    }
    for (final course in after.courses) {
      if (identical(oldCourses[course.id], course)) continue;
      await _writeCourse(course);
    }

    final oldAttempts = {for (final a in before.attempts) a.id: a};
    final newAttemptIds = {for (final a in after.attempts) a.id};
    for (final id in oldAttempts.keys.where((id) => !newAttemptIds.contains(id))) {
      await (db.delete(db.attempts)..where((t) => t.id.equals(id))).go();
    }
    for (final a in after.attempts) {
      if (identical(oldAttempts[a.id], a)) continue;
      await db
          .into(db.attempts)
          .insertOnConflictUpdate(
            AttemptsCompanion.insert(
              id: a.id,
              createdAt: a.createdAt.toUtc(),
              kind: a.kind,
              note: a.note,
              durationMs: a.durationMs,
              courseId: Value(a.courseId),
              clipId: Value(a.clipId),
              recordingPath: Value(a.recordingPath),
            ),
          );
    }

    final oldSteps = _steps(before.completed), newSteps = _steps(after.completed);
    for (final (course, clip, step) in oldSteps.difference(newSteps)) {
      await (db.delete(db.progress)
            ..where((t) => t.courseId.equals(course) & t.clipId.equals(clip) & t.step.equals(step)))
          .go();
    }
    for (final (course, clip, step) in newSteps.difference(oldSteps)) {
      await db
          .into(db.progress)
          .insertOnConflictUpdate(
            ProgressCompanion.insert(courseId: course, clipId: clip, step: step),
          );
    }

    for (final key in before.drafts.keys.where((k) => !after.drafts.containsKey(k))) {
      await (db.delete(db.drafts)..where((t) => t.key.equals(key))).go();
    }
    for (final e in after.drafts.entries) {
      if (before.drafts[e.key] == e.value) continue;
      await db
          .into(db.drafts)
          .insertOnConflictUpdate(DraftsCompanion.insert(key: e.key, body: e.value));
    }

    final oldCards = {for (final r in before.reviews) r.id: r};
    final newCardIds = {for (final r in after.reviews) r.id};
    for (final id in oldCards.keys.where((id) => !newCardIds.contains(id))) {
      await (db.delete(db.cards)..where((t) => t.id.equals(id))).go();
    }
    for (final card in after.reviews) {
      if (identical(oldCards[card.id], card)) continue;
      await db
          .into(db.cards)
          .insertOnConflictUpdate(
            CardsCompanion.insert(
              id: card.id,
              courseId: card.courseId,
              clipId: card.clipId,
              body: card.text,
              meaning: card.meaning,
              dueAt: card.dueAt.toUtc(),
              repetitions: Value(card.repetitions),
              scheduler: const Value('fsrs6'),
              stability: Value(card.stability),
              difficulty: Value(card.difficulty),
            ),
          );
      await (db.delete(db.reviewLogs)..where((t) => t.cardId.equals(card.id))).go();
      for (var i = 0; i < card.history.length; i++) {
        final entry = card.history[i];
        final at = entry['at'];
        await db
            .into(db.reviewLogs)
            .insert(
              ReviewLogsCompanion.insert(
                cardId: card.id,
                seq: i,
                reviewedAt: Value(at is String ? DateTime.tryParse(at)?.toUtc() : null),
                rating: '${entry['rating']}',
                dataJson: jsonEncode(entry),
              ),
            );
      }
    }

    if (before.lastCourseId != after.lastCourseId) {
      await db.setMeta(_lastCourseKey, after.lastCourseId);
    }
    if (before.lastClipId != after.lastClipId) await db.setMeta(_lastClipKey, after.lastClipId);
    for (final key in {...before.settings.keys, ...after.settings.keys}) {
      if (before.settings[key] != after.settings[key]) {
        await db.setMeta('$_settingPrefix$key', after.settings[key]);
      }
    }
  }

  Future<void> _writeCourse(Course course) async {
    await db
        .into(db.courses)
        .insertOnConflictUpdate(
          CoursesCompanion.insert(
            id: course.id,
            title: course.title,
            area: course.area.name,
            rawJson: jsonEncode(course.raw),
            mediaPath: Value(course.mediaPath),
            sourceLabel: Value(course.sourceLabel),
            importedAt: course.importedAt.toUtc(),
          ),
        );
    await (db.delete(db.clips)..where((t) => t.courseId.equals(course.id))).go();
    await (db.delete(db.items)..where((t) => t.courseId.equals(course.id))).go();
    for (var i = 0; i < course.clips.length; i++) {
      final clip = course.clips[i];
      await db
          .into(db.clips)
          .insert(
            ClipsCompanion.insert(
              courseId: course.id,
              id: clip.id,
              ord: i,
              title: clip.title,
              startMs: clip.startMs,
              endMs: Value(clip.endMs),
              transcript: clip.transcript,
            ),
          );
      for (final item in clip.items) {
        await db
            .into(db.items)
            .insert(
              ItemsCompanion.insert(
                courseId: course.id,
                clipId: clip.id,
                id: item.id,
                kind: item.kind,
                body: item.text,
                meaning: Value(item.meaning),
              ),
            );
      }
    }
  }

  static Set<(String, String, String)> _steps(Map<String, Set<String>> completed) {
    final steps = <(String, String, String)>{};
    for (final e in completed.entries) {
      final (course, clip) =
          splitEntityKey(e.key) ?? (throw FormatException('Unrecognised completion key: ${e.key}'));
      for (final step in e.value) {
        steps.add((course, clip, step));
      }
    }
    return steps;
  }
}

import 'package:drift/drift.dart';

import 'db/database.dart';

/// One saved line of a live session (final text plus its translation).
class SavedLine {
  const SavedLine({
    required this.segmentId,
    required this.startMs,
    required this.endMs,
    required this.text,
    this.translation,
    this.wordsJson,
  });
  final String segmentId;
  final int startMs, endMs;
  final String text;
  final String? translation;

  /// `[{"w":…,"s":ms,"e":ms}]` when the recogniser produced word timings.
  final String? wordsJson;
}

/// A finalised segment ready to be stored.
typedef NewSegment = ({
  String id,
  int startMs,
  int endMs,
  String text,
  String? language,
  String? wordsJson,
});

/// Live caption sessions in SQLite. Only finals and translations are stored;
/// partials never touch the database. Writes are batched by the caller.
class LiveRepository {
  LiveRepository(this.db);
  final TinglangDatabase db;

  /// Sessions left `active` by a crash or force-quit become `interrupted`.
  Future<int> markInterrupted() => (db.update(db.sessions)..where((s) => s.status.equals('active')))
      .write(const SessionsCompanion(status: Value('interrupted')));

  Future<void> createSession({
    required String id,
    required String origin,
    required String language,
    required String title,
    required DateTime startedAt,
    String timeBase = 'wallclock',
    String? mediaId,
    String? sourceRef,
  }) => db
      .into(db.sessions)
      .insert(
        SessionsCompanion.insert(
          id: id,
          origin: origin,
          timeBase: timeBase,
          mediaId: Value(mediaId),
          language: Value(language),
          title: Value(title),
          startedAt: startedAt,
          sourceRef: Value(sourceRef),
        ),
      );

  /// Source references (see `Sessions.sourceRef`) starting with [prefix]
  /// whose import finished or is running, e.g. Voice Memos already imported.
  /// Failed or cancelled imports can be tried again.
  Future<Set<String>> importedSources(String prefix) async {
    final rows = await (db.select(
      db.sessions,
    )..where((s) => s.sourceRef.isNotNull() & s.status.isNotIn(['failed', 'interrupted']))).get();
    return {
      for (final row in rows)
        if (row.sourceRef!.startsWith(prefix)) row.sourceRef!,
    };
  }

  /// Registers an app-owned media file (idempotent by id).
  Future<void> addMedia({
    required String id,
    required String kind,
    required String relPath,
    String? sha256,
    int? durationMs,
    String title = '',
  }) => db
      .into(db.media)
      .insert(
        MediaCompanion.insert(
          id: id,
          kind: kind,
          relPath: Value(relPath),
          sha256: Value(sha256),
          durationMs: Value(durationMs),
          title: Value(title),
          createdAt: DateTime.now().toUtc(),
        ),
        mode: InsertMode.insertOrIgnore,
      );

  /// Caption times of [sessionId] are offsets into [mediaId] from now on.
  Future<void> attachMedia(String sessionId, String mediaId) =>
      (db.update(db.sessions)..where((s) => s.id.equals(sessionId))).write(
        SessionsCompanion(mediaId: Value(mediaId), timeBase: const Value('media')),
      );

  Future<SessionRow?> session(String id) =>
      (db.select(db.sessions)..where((s) => s.id.equals(id))).getSingleOrNull();

  Future<MediaRow?> media(String id) =>
      (db.select(db.media)..where((m) => m.id.equals(id))).getSingleOrNull();

  Future<void> addDictationAttempt({
    required String id,
    required String sessionId,
    required String segmentId,
    required String answer,
    required String result,
    required double similarity,
  }) => db
      .into(db.dictationAttempts)
      .insert(
        DictationAttemptsCompanion.insert(
          id: id,
          sessionId: sessionId,
          segmentId: segmentId,
          answer: answer,
          result: result,
          similarity: similarity,
          createdAt: DateTime.now().toUtc(),
        ),
      );

  /// Latest result per segment of a session.
  Future<Map<String, String>> dictationResults(String sessionId) async {
    final rows =
        await (db.select(db.dictationAttempts)
              ..where((a) => a.sessionId.equals(sessionId))
              ..orderBy([(a) => OrderingTerm.asc(a.createdAt)]))
            .get();
    return {for (final r in rows) r.segmentId: r.result};
  }

  Future<void> endSession(String id, {required String status, required DateTime endedAt}) =>
      (db.update(db.sessions)..where((s) => s.id.equals(id))).write(
        SessionsCompanion(status: Value(status), endedAt: Value(endedAt)),
      );

  /// Appends finals in one transaction; `seq` continues from the session's
  /// current maximum so later batches never collide.
  Future<void> addSegments(String sessionId, List<NewSegment> segments) async {
    if (segments.isEmpty) return;
    await db.transaction(() async {
      final max = db.segments.seq.max();
      final row =
          await (db.selectOnly(db.segments)
                ..addColumns([max])
                ..where(db.segments.sessionId.equals(sessionId)))
              .getSingle();
      var seq = (row.read(max) ?? -1) + 1;
      final now = DateTime.now().toUtc();
      for (final s in segments) {
        await db
            .into(db.segments)
            .insert(
              SegmentsCompanion.insert(
                id: s.id,
                sessionId: sessionId,
                seq: seq++,
                startMs: s.startMs,
                endMs: s.endMs,
                body: s.text,
                language: Value(s.language),
                wordsJson: Value(s.wordsJson),
                createdAt: now,
              ),
              mode: InsertMode.insertOrIgnore,
            );
      }
    });
  }

  /// Translations reference saved segments, so callers flush segments first.
  Future<void> addTranslations(
    List<({String segmentId, String target, String text, String provider})> translations,
  ) async {
    if (translations.isEmpty) return;
    final now = DateTime.now().toUtc();
    await db.batch((b) {
      for (final t in translations) {
        b.insert(
          db.translations,
          TranslationsCompanion.insert(
            segmentId: t.segmentId,
            targetLang: t.target,
            body: t.text,
            provider: t.provider,
            quality: 'final',
            createdAt: now,
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
  }

  Future<List<SessionRow>> recentSessions({int limit = 50}) =>
      (db.select(db.sessions)
            ..where(
              (s) => s.origin.isIn(['live_system', 'live_mic', 'file', 'shared', 'voice_memo']),
            )
            ..orderBy([(s) => OrderingTerm.desc(s.startedAt)])
            ..limit(limit))
          .get();

  /// The first saved line of each session, for list previews.
  Future<Map<String, String>> firstLines(List<String> sessionIds) async {
    if (sessionIds.isEmpty) return const {};
    final placeholders = List.filled(sessionIds.length, '?').join(', ');
    final rows = await db
        .customSelect(
          'SELECT s.session_id AS session_id, s.body AS body FROM segment s '
          'JOIN (SELECT session_id, MIN(seq) AS seq FROM segment '
          'WHERE session_id IN ($placeholders) GROUP BY session_id) f '
          'ON s.session_id = f.session_id AND s.seq = f.seq',
          variables: [for (final id in sessionIds) Variable.withString(id)],
          readsFrom: {db.segments},
        )
        .get();
    return {for (final row in rows) row.read<String>('session_id'): row.read<String>('body')};
  }

  Future<List<SavedLine>> lines(String sessionId) async {
    final segments =
        await (db.select(db.segments)
              ..where((s) => s.sessionId.equals(sessionId))
              ..orderBy([(s) => OrderingTerm.asc(s.seq)]))
            .get();
    if (segments.isEmpty) return const [];
    final translations = await (db.select(
      db.translations,
    )..where((t) => t.segmentId.isIn(segments.map((s) => s.id)))).get();
    final byId = {for (final t in translations) t.segmentId: t.body};
    return [
      for (final s in segments)
        SavedLine(
          segmentId: s.id,
          startMs: s.startMs,
          endMs: s.endMs,
          text: s.body,
          translation: byId[s.id],
          wordsJson: s.wordsJson,
        ),
    ];
  }

  /// Every saved translation of [sessionId]'s lines: segment id → target
  /// language → text (a final translation wins over a preview).
  Future<Map<String, Map<String, String>>> translationsOf(String sessionId) async {
    final rows = await db
        .customSelect(
          'SELECT t.segment_id AS segment_id, t.target_lang AS target, t.body AS body, '
          't.quality AS quality FROM "translation" t JOIN segment s ON s.id = t.segment_id '
          'WHERE s.session_id = ?',
          variables: [Variable.withString(sessionId)],
          readsFrom: {db.translations, db.segments},
        )
        .get();
    final out = <String, Map<String, String>>{};
    for (final quality in const ['preview', 'final']) {
      for (final row in rows) {
        if (row.read<String>('quality') != quality) continue;
        out.putIfAbsent(row.read<String>('segment_id'), () => {})[row.read<String>('target')] = row
            .read<String>('body');
      }
    }
    return out;
  }

  /// Writes a copy of a session that came from another Mac (sync): the
  /// session row is created or updated in place (its dictation answers stay),
  /// its lines are replaced by [segments] with their ids, and translations
  /// are written for them. One transaction.
  Future<void> importSessionCopy({
    required String id,
    required String origin,
    required String? language,
    required String title,
    required DateTime startedAt,
    required DateTime? endedAt,
    required String status,
    required String timeBase,
    required String? mediaId,
    required String? sourceRef,
    required List<NewSegment> segments,
    required List<({String segmentId, String target, String text, String provider})> translations,
  }) => db.transaction(() async {
    await db
        .into(db.sessions)
        .insertOnConflictUpdate(
          SessionsCompanion.insert(
            id: id,
            origin: origin,
            timeBase: timeBase,
            mediaId: Value(mediaId),
            language: Value(language),
            title: Value(title),
            startedAt: startedAt,
            endedAt: Value(endedAt),
            status: Value(status),
            sourceRef: Value(sourceRef),
          ),
        );
    final keep = {for (final s in segments) s.id};
    await (db.delete(db.segments)..where((s) => s.sessionId.equals(id) & s.id.isNotIn(keep))).go();
    final now = DateTime.now().toUtc();
    for (final (seq, s) in segments.indexed) {
      await db
          .into(db.segments)
          .insertOnConflictUpdate(
            SegmentsCompanion.insert(
              id: s.id,
              sessionId: id,
              seq: seq,
              startMs: s.startMs,
              endMs: s.endMs,
              body: s.text,
              language: Value(s.language),
              wordsJson: Value(s.wordsJson),
              createdAt: now,
            ),
          );
    }
    await addTranslations(translations);
  });

  /// Dictation answers of every session, oldest first (sync).
  Future<List<DictationAttemptRow>> allDictationAttempts() =>
      (db.select(db.dictationAttempts)..orderBy([(a) => OrderingTerm.asc(a.createdAt)])).get();

  /// Writes a dictation answer that came from another Mac, keeping its id.
  Future<void> putDictationAttempt(DictationAttemptRow row) =>
      db.into(db.dictationAttempts).insertOnConflictUpdate(row);

  Future<void> deleteDictationAttempt(String id) =>
      (db.delete(db.dictationAttempts)..where((a) => a.id.equals(id))).go();

  Future<void> renameSession(String id, String title) => (db.update(
    db.sessions,
  )..where((s) => s.id.equals(id))).write(SessionsCompanion(title: Value(title)));

  /// Deletes the session; segments and translations cascade.
  Future<void> deleteSession(String id) =>
      (db.delete(db.sessions)..where((s) => s.id.equals(id))).go();
}

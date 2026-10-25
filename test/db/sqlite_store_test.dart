import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:tinglang/core/course_codec.dart';
import 'package:tinglang/core/db/database.dart';
import 'package:tinglang/core/db/sqlite_library_store.dart';
import 'package:tinglang/core/json_helpers.dart';
import 'package:tinglang/core/library_store.dart';
import 'package:tinglang/core/models.dart';
import 'package:tinglang/core/review.dart';
import 'package:tinglang/services/app_controller.dart';

Course demoCourse() => const CourseCodec()
    .decode(
      File('assets/demo/course.json').readAsStringSync(),
      area: Area.nba,
      importedAt: DateTime.utc(2026, 9, 22, 8),
    )
    .copyWith(mediaPath: 'media/demo.wav');

/// A state touching every persisted field.
LibraryState richState() {
  final course = demoCourse();
  final clip = course.clips.first;
  final card =
      ReviewCard(
            id: 'card-1',
            courseId: course.id,
            clipId: clip.id,
            text: 'show up',
            meaning: '坚持参与',
            dueAt: DateTime.utc(2026, 9, 22, 12),
          )
          .rate(Recall.good, DateTime.utc(2026, 9, 22, 12))
          .rate(Recall.again, DateTime.utc(2026, 9, 23, 12));
  return LibraryState(
    courses: [course],
    attempts: [
      PracticeAttempt(
        id: 'a1',
        createdAt: DateTime.utc(2026, 9, 22, 9, 30, 1, 250),
        kind: 'retelling',
        note: '我的复述 · my words',
        durationMs: 4200,
        courseId: course.id,
        clipId: clip.id,
        recordingPath: 'recordings/a1.wav',
      ),
      PracticeAttempt(
        id: 'a2',
        createdAt: DateTime.utc(2026, 9, 22, 10),
        kind: 'free-speaking',
        note: '',
        durationMs: 0,
      ),
    ],
    completed: {
      entityKey(course.id, clip.id): {'words', 'shadowing'},
      entityKey('a:b', 'c:d'): {'blind'},
    },
    drafts: {'k1': 'draft one', 'k2': ''},
    reviews: [card],
    settings: {'ui_locale': 'zh', 'theme': 'dark'},
    lastCourseId: course.id,
    lastClipId: clip.id,
  );
}

/// toJson with set-derived lists sorted, so equal states compare equal.
Object? canonical(LibraryState state) {
  final json = jsonDecode(jsonEncode(state.toJson())) as Map<String, Object?>;
  final completed = json['completed']! as Map<String, Object?>;
  for (final key in completed.keys) {
    completed[key] = [...(completed[key]! as List<Object?>).cast<String>()]..sort();
  }
  return json;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  setUp(() async => directory = await Directory.systemTemp.createTemp('tinglang-db-'));
  tearDown(() async => directory.delete(recursive: true));

  group('schema', () {
    test('creates every planned table plus the FTS index', () async {
      final db = TinglangDatabase.memory();
      addTearDown(db.close);
      final rows = await db
          .customSelect("SELECT name FROM sqlite_master WHERE type IN ('table')")
          .get();
      final names = rows.map((r) => r.read<String>('name')).toSet();
      expect(
        names,
        containsAll([
          'media',
          'session',
          'time_anchor',
          'segment',
          'translation',
          'course',
          'clip',
          'item',
          'exercise',
          'progress',
          'attempt',
          'card',
          'review_log',
          'provider_config',
          'feature_route',
          'llm_cache',
          'podcast_feed',
          'episode',
          'draft',
          'app_meta',
          'segment_fts',
        ]),
      );
      final fk = await db.customSelect('PRAGMA foreign_keys').getSingle();
      expect(fk.read<int>('foreign_keys'), 1);
    });

    Future<TinglangDatabase> withSegments() async {
      final db = TinglangDatabase.memory();
      final now = DateTime.utc(2026, 10, 21);
      await db
          .into(db.sessions)
          .insert(
            SessionsCompanion.insert(
              id: 's1',
              origin: 'live_system',
              timeBase: 'wallclock',
              startedAt: now,
            ),
          );
      var seq = 0;
      for (final text in [
        '今天我们讨论实时字幕的延迟',
        'Live captions should stay local.',
        '用中文和 English 混合说话',
        '50% "quoted" text',
      ]) {
        await db
            .into(db.segments)
            .insert(
              SegmentsCompanion.insert(
                id: 'g$seq',
                sessionId: 's1',
                seq: seq,
                startMs: seq * 1000,
                endMs: seq * 1000 + 900,
                body: text,
                createdAt: now.add(Duration(seconds: seq)),
              ),
            );
        seq++;
      }
      return db;
    }

    test('trigram FTS finds Chinese and English substrings', () async {
      final db = await withSegments();
      addTearDown(db.close);
      expect((await db.searchSegments('实时字幕')).map((s) => s.id), ['g0']);
      expect((await db.searchSegments('caption')).map((s) => s.id), ['g1']);
      expect((await db.searchSegments('English 混合')).map((s) => s.id), ['g2']);
    });
    test('short queries fall back to LIKE; punctuation is not query syntax', () async {
      final db = await withSegments();
      addTearDown(db.close);
      expect((await db.searchSegments('中文')).map((s) => s.id), ['g2']);
      expect((await db.searchSegments('"quoted"')).map((s) => s.id), ['g3']);
      expect((await db.searchSegments('%')).map((s) => s.id), ['g3']);
      expect(await db.searchSegments('  '), isEmpty);
    });
    test('FTS index follows updates and deletes', () async {
      final db = await withSegments();
      addTearDown(db.close);
      await (db.update(db.segments)..where((t) => t.id.equals('g1'))).write(
        const SegmentsCompanion(body: Value('Subtitles moved here')),
      );
      expect(await db.searchSegments('caption'), isEmpty);
      expect((await db.searchSegments('Subtitles')).map((s) => s.id), ['g1']);
      await (db.delete(db.sessions)..where((t) => t.id.equals('s1'))).go();
      expect(await db.searchSegments('Subtitles'), isEmpty, reason: 'cascade');
    });
  });

  group('library.json import', () {
    test('imports every field once and leaves the JSON untouched', () async {
      final original = richState();
      await LibraryStore(directory).save(original);
      final json = File('${directory.path}/library.json');
      final bytes = await json.readAsBytes();

      final store = SqliteLibraryStore(directory, TinglangDatabase.memory());
      addTearDown(store.close);
      final loaded = await store.load();
      expect(canonical(loaded), canonical(original));
      expect(await store.importedLegacyJson, isTrue);
      expect(await json.readAsBytes(), bytes);
      expect(loaded.reviews.single.history, hasLength(2));

      // A later edit to the old file must not be imported again.
      await LibraryStore(directory).save(LibraryState());
      expect(canonical(await store.load()), canonical(original));
    });
    test('corrupt JSON aborts without writing anything', () async {
      await File('${directory.path}/library.json').writeAsString('{broken');
      final db = TinglangDatabase.memory();
      final store = SqliteLibraryStore(directory, db);
      addTearDown(store.close);
      await expectLater(store.load(), throwsA(isA<LibraryReadException>()));
      expect(await store.importedLegacyJson, isFalse);
      expect(await db.select(db.courses).get(), isEmpty);
      expect(await File('${directory.path}/library.json').readAsString(), '{broken');
    });
    test('no JSON: starts empty and does not mark an import', () async {
      final store = SqliteLibraryStore(directory, TinglangDatabase.memory());
      addTearDown(store.close);
      expect((await store.load()).courses, isEmpty);
      expect(await store.importedLegacyJson, isFalse);
    });
  });

  group('AppController on SQLite', () {
    test('changes survive reopening the database file', () async {
      final file = File('${directory.path}/tinglang.sqlite');
      var store = SqliteLibraryStore(directory, TinglangDatabase.open(file));
      final app = AppController(store, await store.load());
      final course = demoCourse();
      await app.upsertCourse(course);
      await app.setDone(course, course.clips.first, 'shadowing', true);
      await app.saveExpression(course, course.clips[1], 'keep going', '继续');
      await app.rateCard(app.state.reviews.single, Recall.good);
      await app.saveDraft(null, null, 'free', 'unsent');
      await app.setDone(course, course.clips.first, 'shadowing', false);
      await app.setDone(course, course.clips.first, 'blind', true);
      final expected = canonical(app.state);
      app.dispose();
      await store.close();

      store = SqliteLibraryStore(directory, TinglangDatabase.open(file));
      addTearDown(store.close);
      expect(canonical(await store.load()), expected);
    });
    test('reimport preserves completion, drafts, attempts and media', () async {
      final store = SqliteLibraryStore(directory, TinglangDatabase.memory());
      addTearDown(store.close);
      final app = AppController(store, await store.load());
      addTearDown(app.dispose);
      final course = demoCourse();
      await app.upsertCourse(course);
      await app.setDone(course, course.clips.first, 'shadowing', true);
      await app.saveAttempt(
        PracticeAttempt(
          id: 'attempt-1',
          createdAt: DateTime.utc(2026, 9, 22),
          kind: 'retelling',
          note: 'Keep this',
          durationMs: 1000,
          courseId: course.id,
          clipId: course.clips.first.id,
          recordingPath: 'recordings/keep.wav',
        ),
      );
      await app.upsertCourse(
        const CourseCodec().decode(File('assets/demo/course.json').readAsStringSync()),
      );
      final reloaded = await store.load();
      expect(reloaded.courses.single.mediaPath, 'media/demo.wav');
      expect(reloaded.completed[entityKey(course.id, course.clips.first.id)], {'shadowing'});
      expect(reloaded.attempts.single.recordingPath, 'recordings/keep.wav');
      expect(reloaded.courses.single.raw, course.raw);
    });
    test('rapid writes commit in order', () async {
      final store = SqliteLibraryStore(directory, TinglangDatabase.memory());
      addTearDown(store.close);
      final app = AppController(store, await store.load());
      addTearDown(app.dispose);
      await Future.wait([
        for (var i = 0; i < 20; i++) app.saveDraft(null, null, 'free', 'draft $i'),
      ]);
      expect(app.draft(null, null, 'free'), 'draft 19');
      expect((await store.load()).drafts.values, ['draft 19']);
    });
    test('a failed transaction rolls back the whole change and can be retried', () async {
      final db = TinglangDatabase.memory();
      final store = SqliteLibraryStore(directory, db);
      addTearDown(store.close);
      final app = AppController(store, await store.load());
      addTearDown(app.dispose);
      await db.customStatement(
        "CREATE TRIGGER fail_attempt BEFORE INSERT ON attempt "
        "BEGIN SELECT RAISE(ABORT, 'simulated disk failure'); END",
      );
      final attempt = PracticeAttempt(
        id: 'pending',
        createdAt: DateTime.utc(2026, 10, 21),
        kind: 'free',
        note: 'Do not lose me',
        durationMs: 0,
      );
      // One change that writes a draft *and* an attempt: neither may persist.
      final failed = app.change((next) {
        next.drafts['together'] = 'with the attempt';
        next.attempts.add(attempt);
      });
      await expectLater(failed, throwsA(anything));
      await app.flush();
      expect(app.persistenceError, contains('simulated disk failure'));
      expect(app.state.attempts, isEmpty);
      expect(await db.select(db.drafts).get(), isEmpty);

      await db.customStatement('DROP TRIGGER fail_attempt');
      await app.saveAttempt(attempt);
      expect(app.persistenceError, isNull);
      final reloaded = await store.load();
      expect(reloaded.attempts.single.id, 'pending');
      expect(reloaded.drafts, isEmpty, reason: 'the failed edit was never published');
    });
  });

  test('splitEntityKey inverts entityKey, including delimiter-heavy ids', () {
    for (final (course, clip) in [
      ('a', 'b'),
      ('a:b', 'c'),
      ('12:x', '3:'),
      ('', ''),
      ('课程', '片段'),
    ]) {
      expect(splitEntityKey(entityKey(course, clip)), (course, clip));
    }
    expect(splitEntityKey('nonsense'), isNull);
    expect(splitEntityKey('3:ab'), isNull);
  });
}

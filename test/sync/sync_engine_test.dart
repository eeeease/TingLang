// iCloud Drive sync between two simulated Macs that share one folder (as
// macOS would keep it in step). Each Mac has its own library and database.
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:tinglang/core/course_codec.dart';
import 'package:tinglang/core/db/database.dart';
import 'package:tinglang/core/db/sqlite_library_store.dart';
import 'package:tinglang/core/json_helpers.dart';
import 'package:tinglang/core/live_repository.dart';
import 'package:tinglang/core/models.dart';
import 'package:tinglang/core/review.dart';
import 'package:tinglang/services/app_controller.dart';
import 'package:tinglang/services/sync_engine.dart';
import 'package:tinglang_platform_interface/testing.dart';
import 'package:tinglang_platform_interface/tinglang_platform_interface.dart' show CloudItemState;

import '../cloud/cloud_fakes.dart';

/// One Mac: its own library folder and database, the shared sync folder,
/// its own clock and what iCloud has downloaded on it.
final class _Mac {
  _Mac._(this.id, this.root, this.store, this.app, this.shared);
  final String id;
  final Directory root, shared;
  final SqliteLibraryStore store;
  final AppController app;
  final drive = FakeCloudDrive();
  DateTime now = DateTime.utc(2026, 10, 25, 9);
  SyncEngine? _engine;

  static Future<_Mac> open(String id, Directory temp, Directory shared, {File? database}) async {
    final root = Directory(p.join(temp.path, id));
    await root.create(recursive: true);
    final db = database == null ? TinglangDatabase.memory() : TinglangDatabase.open(database);
    final store = SqliteLibraryStore(root, db);
    final app = AppController(store, await store.load());
    return _Mac._(id, root, store, app, shared);
  }

  LiveRepository get repository => LiveRepository(store.db);
  TinglangDatabase get db => store.db;

  SyncEngine get engine => _engine ??= SyncEngine(
    folder: shared,
    app: app,
    repository: repository,
    deviceId: id,
    deviceName: 'Mac $id',
    drive: drive,
    appVersion: 'test',
    clock: () => now,
  );

  Future<SyncReport> sync() async {
    final report = await engine.run();
    now = now.add(const Duration(minutes: 1));
    return report;
  }

  Directory get folder => Directory(p.join(shared.path, 'devices', id));
  File get stateFile => File(p.join(folder.path, 'state.json'));
  List<Map<String, Object?>> get stateRecords =>
      ((jsonDecode(stateFile.readAsStringSync()) as Map<String, Object?>)['records']! as List)
          .cast<Map<String, Object?>>();
  List<File> get packages => [
    for (final f in Directory(p.join(folder.path, 'items')).listSync())
      if (f is File && f.path.endsWith('.tinglang')) f,
  ];
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late Directory temp, shared;
  late _Mac a, b;
  late File audio;
  late Course demo;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('tinglang-sync-');
    // The Tinglang folder inside "iCloud Drive".
    shared = Directory(p.join(temp.path, 'iCloud Drive', 'Tinglang'));
    await shared.parent.create(recursive: true);
    a = await _Mac.open('mac-a', temp, shared);
    b = await _Mac.open('mac-b', temp, shared);
    // Mac B's clock runs a little behind: order comes from the versions.
    b.now = a.now.add(const Duration(seconds: 30));
    audio = File(p.join(temp.path, 'talk.m4a'))
      ..writeAsBytesSync([for (var i = 0; i < 8192; i++) (i * 7) % 251]);
    demo = const CourseCodec().fromMap(
      jsonObject(jsonDecode(File('assets/demo/course.json').readAsStringSync()), 'demo'),
      area: Area.nba,
      importedAt: DateTime.utc(2026, 10, 20),
    );
  });
  tearDown(() async {
    await a.db.close();
    await b.db.close();
    await temp.delete(recursive: true);
  });

  /// A finished recording with audio, two lines, a translation and a
  /// dictation answer.
  Future<void> record(_Mac mac, {String id = 's1', String title = 'Morning memo'}) async {
    final repo = mac.repository;
    final relative = await mac.store.importMedia(audio);
    final mediaId = p.basenameWithoutExtension(relative);
    await repo.addMedia(id: mediaId, kind: 'audio', relPath: relative, sha256: mediaId);
    await repo.createSession(
      id: id,
      origin: 'voice_memo',
      language: 'en',
      title: title,
      startedAt: DateTime.utc(2026, 10, 24, 8),
      timeBase: 'media',
      mediaId: mediaId,
      sourceRef: 'voicememo:memo-1',
    );
    await repo.addSegments(id, [
      (
        id: '$id-a',
        startMs: 0,
        endMs: 1500,
        text: 'Good morning.',
        language: 'en',
        wordsJson: null,
      ),
      (id: '$id-b', startMs: 1600, endMs: 4000, text: 'Ready?', language: 'en', wordsJson: null),
    ]);
    await repo.addTranslations([
      (segmentId: '$id-a', target: 'zh-Hans', text: '早上好。', provider: 'apple_translation'),
    ]);
    await repo.endSession(id, status: 'completed', endedAt: DateTime.utc(2026, 10, 24, 8, 1));
    await repo.addDictationAttempt(
      id: '$id-dict',
      sessionId: id,
      segmentId: '$id-a',
      answer: 'good morning',
      result: 'correct',
      similarity: 1,
    );
  }

  /// The demo course with media, one done step, a draft, a review card and
  /// a speaking attempt with its recording.
  Future<void> study(_Mac mac) async {
    final course = demo.copyWith(mediaPath: await mac.store.importMedia(audio));
    await mac.app.upsertCourse(course);
    final clip = course.clips.first;
    await mac.app.setDone(course, clip, 'words', true);
    await mac.app.saveDraft(course.id, clip.id, 'retelling', 'He kept showing up.');
    await mac.app.saveExpression(course, clip, 'show up', '出现');
    final card = mac.app.state.reviews.single;
    await mac.app.rateCard(card, Recall.good);
    final recording = await mac.store.recordingDestination();
    File(mac.store.resolve(recording)).writeAsBytesSync(List.filled(2048, 9));
    await mac.app.saveAttempt(
      PracticeAttempt(
        id: 'attempt-1',
        createdAt: DateTime.utc(2026, 10, 24, 9),
        kind: 'shadowing',
        note: 'Smoother this time',
        durationMs: 5000,
        courseId: course.id,
        clipId: clip.id,
        recordingPath: recording,
      ),
    );
  }

  test('a course with its media, a recording and the progress reach the other Mac', () async {
    await study(a);
    await record(a);
    final first = await a.sync();
    expect(first.problems, isEmpty);
    expect(first.courses, 1);
    expect(first.sessions, 1);
    expect(a.packages, hasLength(2));
    // The database never goes to iCloud Drive.
    expect(shared.listSync(recursive: true).where((f) => f.path.endsWith('.sqlite')), isEmpty);

    final report = await b.sync();
    expect(report.problems, isEmpty);
    expect(report.otherDevices, 1);
    final course = b.app.state.courses.single;
    expect(course.id, demo.id);
    expect(course.area, Area.nba);
    expect(File(b.store.resolve(course.mediaPath!)).readAsBytesSync(), audio.readAsBytesSync());
    final clip = course.clips.first;
    expect(b.app.done(course, clip), {'words'});
    expect(b.app.draft(course.id, clip.id, 'retelling'), 'He kept showing up.');
    final card = b.app.state.reviews.single;
    expect(card.text, 'show up');
    expect(card.repetitions, 1);
    expect(card.stability, a.app.state.reviews.single.stability);
    final attempt = b.app.state.attempts.single;
    expect(attempt.note, 'Smoother this time');
    expect(File(b.store.resolve(attempt.recordingPath!)).readAsBytesSync(), List.filled(2048, 9));

    // The same session, same line ids: the dictation answer still fits.
    final session = (await b.repository.session('s1'))!;
    expect(session.title, 'Morning memo');
    expect(session.origin, 'voice_memo');
    expect(session.sourceRef, 'voicememo:memo-1');
    expect(session.status, 'completed');
    final lines = await b.repository.lines('s1');
    expect(lines.map((l) => (l.segmentId, l.text, l.translation)), [
      ('s1-a', 'Good morning.', '早上好。'),
      ('s1-b', 'Ready?', null),
    ]);
    expect(await b.repository.dictationResults('s1'), {'s1-a': 'correct'});
    // The Voice Memo counts as imported on this Mac too.
    expect(await b.repository.importedSources('voicememo:'), {'voicememo:memo-1'});
  });

  test('running again writes and applies nothing', () async {
    await study(a);
    await record(a);
    await a.sync();
    await b.sync();
    final state = a.stateFile.readAsStringSync();
    final packages = a.packages.map((f) => f.path).toSet();
    final again = await a.sync();
    expect(again.published, 0);
    expect(again.applied, 0);
    final other = await b.sync();
    expect(other.published, 0);
    expect(other.applied, 0);
    expect(a.stateFile.readAsStringSync(), state);
    expect(a.packages.map((f) => f.path).toSet(), packages);
    // Mac B republished nothing of what it received.
    expect(b.stateRecords, isEmpty);
    expect(b.app.state.courses, hasLength(1));
    expect(await b.repository.lines('s1'), hasLength(2));
  });

  test('a change on either Mac travels; answers given meanwhile stay', () async {
    await record(a);
    await a.sync();
    await b.sync();
    await b.repository.addDictationAttempt(
      id: 'b-dict',
      sessionId: 's1',
      segmentId: 's1-b',
      answer: 'ready',
      result: 'correct',
      similarity: 1,
    );
    await a.repository.renameSession('s1', 'Monday memo');
    await a.sync();
    await b.sync();
    expect((await b.repository.session('s1'))!.title, 'Monday memo');
    expect(await b.repository.dictationResults('s1'), {'s1-a': 'correct', 's1-b': 'correct'});
    // Mac B's own answer goes the other way.
    await b.sync();
    await a.sync();
    expect(await a.repository.dictationResults('s1'), {'s1-a': 'correct', 's1-b': 'correct'});
    // The renamed package replaced the old one in Mac A's folder.
    expect(a.packages, hasLength(1));
  });

  test('the newer change wins on both Macs (last writer wins per record)', () async {
    await study(a);
    await a.sync();
    await b.sync();
    final course = a.app.state.courses.single, clip = course.clips.first;
    // Both edit the same draft before either syncs; Mac B's edit is later.
    await a.app.saveDraft(course.id, clip.id, 'retelling', 'Version from A');
    await b.app.saveDraft(course.id, clip.id, 'retelling', 'Version from B');
    a.now = DateTime.utc(2026, 10, 25, 12);
    b.now = DateTime.utc(2026, 10, 25, 12, 5);
    await a.sync();
    await b.sync();
    await a.sync();
    expect(a.app.draft(course.id, clip.id, 'retelling'), 'Version from B');
    expect(b.app.draft(course.id, clip.id, 'retelling'), 'Version from B');
    // A step unchecked on B and a card reviewed on A both arrive.
    await b.app.setDone(course, clip, 'words', false);
    await a.app.rateCard(a.app.state.reviews.single, Recall.easy);
    await b.sync();
    await a.sync();
    await b.sync();
    expect(a.app.done(course, clip), isEmpty);
    expect(b.app.state.reviews.single.repetitions, 2);
  });

  test('deletions travel as tombstones; a missing file deletes nothing', () async {
    await record(a);
    await record(a, id: 's2', title: 'Evening memo');
    await a.sync();
    await b.sync();
    expect(await b.repository.session('s2'), isNotNull);

    // A package that vanished (or was never downloaded) is not a deletion.
    for (final file in a.packages) {
      file.deleteSync();
    }
    await b.sync();
    expect(await b.repository.session('s1'), isNotNull);
    expect(await b.repository.session('s2'), isNotNull);

    await a.repository.deleteSession('s2');
    await a.sync();
    final tombstones = a.stateRecords.where((r) => r['deleted'] == true).map((r) => r['key']);
    expect(tombstones, contains('s2'));
    await b.sync();
    expect(await b.repository.session('s2'), isNull);
    expect(await b.repository.session('s1'), isNotNull);
    // Mac A wrote its missing package again.
    expect(a.packages, hasLength(1));
  });

  test('files iCloud has not downloaded are requested and applied later', () async {
    await record(a);
    await a.sync();
    // As iCloud leaves it on a Mac that has not downloaded it yet.
    final package = a.packages.single;
    final placeholder = File(p.join(package.parent.path, '.${p.basename(package.path)}.icloud'));
    package.renameSync(placeholder.path);
    final waiting = await b.sync();
    // The recording, and its dictation answer that needs it.
    expect(waiting.waiting, 2);
    expect(waiting.problems, isEmpty);
    expect(b.drive.requested, contains(package.path));
    expect(await b.repository.session('s1'), isNull);

    placeholder.renameSync(package.path);
    // A file macOS reports as not downloaded (dataless) waits the same way.
    b.drive.states[package.path] = CloudItemState.notDownloaded;
    expect((await b.sync()).waiting, 2);
    expect(await b.repository.session('s1'), isNull);

    b.drive.states.remove(package.path);
    final done = await b.sync();
    expect(done.waiting, 0);
    expect(await b.repository.session('s1'), isNotNull);

    // The other Mac's state file itself can also be in the cloud only.
    await a.repository.renameSession('s1', 'Renamed');
    await a.sync();
    b.drive.states[a.stateFile.path] = CloudItemState.notDownloaded;
    expect((await b.sync()).waiting, 1);
    expect(b.drive.requested, contains(a.stateFile.path));
    expect((await b.repository.session('s1'))!.title, 'Morning memo');
  });

  test('a corrupt package or one from a newer Tinglang is skipped and reported', () async {
    await study(a);
    await record(a);
    await a.sync();
    final course = a.packages.firstWhere((f) => p.basename(f.path).startsWith('course-'));
    final session = a.packages.firstWhere((f) => p.basename(f.path).startsWith('session-'));
    course.writeAsStringSync('not a zip');
    // Same entries, but a format from the future.
    final archive = ZipDecoder().decodeBytes(session.readAsBytesSync());
    final manifest = jsonDecode(
      utf8.decode(archive.findFile('manifest.json')!.readBytes()!),
    ) as Map<String, Object?>;
    final newer = Archive()
      ..addFile(ArchiveFile.string('manifest.json', jsonEncode({...manifest, 'version': 99})));
    session.writeAsBytesSync(ZipEncoder().encode(newer));

    final report = await b.sync();
    expect(report.problems.map((p) => p.kind).toSet(), {
      SyncProblemKind.unreadablePackage,
      SyncProblemKind.newerPackage,
    });
    expect(b.app.state.courses, isEmpty);
    expect(await b.repository.session('s1'), isNull);
    // Everything else still arrived.
    expect(b.app.state.reviews, hasLength(1));
    expect(b.app.state.drafts, hasLength(1));
    // Reported again on the next pass, still without crashing.
    expect((await b.sync()).problems, hasLength(2));
  });

  test('a state file or folder from a newer Tinglang is not used or written', () async {
    await study(a);
    await a.sync();
    final state = jsonDecode(a.stateFile.readAsStringSync()) as Map<String, Object?>;
    a.stateFile.writeAsStringSync(jsonEncode({...state, 'version': 2}));
    final report = await b.sync();
    expect(report.problems.single.kind, SyncProblemKind.newerState);
    expect(report.problems.single.name, 'Mac mac-a');
    expect(b.app.state.courses, isEmpty);

    File(p.join(shared.path, 'sync.json'))
        .writeAsStringSync(jsonEncode({'format': SyncEngine.folderFormat, 'version': 2}));
    final c = await _Mac.open('mac-c', temp, shared);
    addTearDown(c.db.close);
    await study(c);
    final blocked = await c.sync();
    expect(blocked.problems.single.kind, SyncProblemKind.newerFolder);
    expect(c.folder.existsSync(), isFalse);
  });

  test('reopening the library does not count as a change', () async {
    final file = File(p.join(temp.path, 'b.sqlite'));
    await b.db.close();
    b = await _Mac.open('mac-b', temp, shared, database: file);
    await study(a);
    await record(a);
    await a.sync();
    await b.sync();
    await b.db.close();
    b = await _Mac.open('mac-b', temp, shared, database: file);
    final report = await b.sync();
    expect(report.published, 0);
    expect(report.applied, 0);
    expect(b.stateRecords, isEmpty);
    expect(b.app.state.reviews.single.text, 'show up');
  });

  test('a library synced for the first time gives way to what is already there', () async {
    await study(a);
    await a.sync();
    // Mac B has its own, older copy of the same course and a draft.
    await b.app.upsertCourse(
      const CourseCodec().fromMap(demo.raw, area: Area.nba, importedAt: DateTime.utc(2026, 10, 1)),
    );
    final clip = demo.clips.first;
    await b.app.saveDraft(demo.id, clip.id, 'retelling', 'Older draft on B');
    await b.app.saveDraft(demo.id, clip.id, 'shadowing', 'Only on B');
    await b.sync();
    expect(b.app.draft(demo.id, clip.id, 'retelling'), 'He kept showing up.');
    // A's course (imported later, with media) replaced B's copy.
    expect(b.app.state.courses.single.mediaPath, isNotNull);
    await a.sync();
    expect(a.app.draft(demo.id, clip.id, 'shadowing'), 'Only on B');
    expect(a.app.draft(demo.id, clip.id, 'retelling'), 'He kept showing up.');
  });

  test('a pass opens no network connection', () async {
    final network = NoNetwork();
    final before = HttpOverrides.current;
    HttpOverrides.global = network;
    addTearDown(() => HttpOverrides.global = before);
    await study(a);
    await record(a);
    await a.sync();
    await b.sync();
    expect(network.created, isEmpty);
  });
}

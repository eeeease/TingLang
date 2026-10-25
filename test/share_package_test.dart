import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:tinglang/core/course_codec.dart';
import 'package:tinglang/core/db/database.dart';
import 'package:tinglang/core/json_helpers.dart';
import 'package:tinglang/core/library_store.dart';
import 'package:tinglang/core/live_repository.dart';
import 'package:tinglang/core/models.dart';
import 'package:tinglang/core/share_package.dart';

void main() {
  late Directory temp;
  late TinglangDatabase db, otherDb;
  late LiveRepository repository, other;
  late LibraryStore store, otherStore;
  late File audio;

  // Two libraries on purpose: the sender's and the receiver's.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('tinglang-share-test-');
    db = TinglangDatabase.memory();
    otherDb = TinglangDatabase.memory();
    repository = LiveRepository(db);
    // The receiving side: another library, as on a friend's Mac.
    other = LiveRepository(otherDb);
    store = LibraryStore(Directory(p.join(temp.path, 'mine')));
    otherStore = LibraryStore(Directory(p.join(temp.path, 'theirs')));
    audio = File(p.join(temp.path, 'memo.m4a'))
      ..writeAsBytesSync([for (var i = 0; i < 4096; i++) i % 251]);
  });
  tearDown(() async {
    await db.close();
    await otherDb.close();
    await temp.delete(recursive: true);
  });

  Future<SharedItem> import(File package) =>
      importSharePackage(package, repository: other, store: otherStore, fallbackLanguage: 'ja');

  Matcher fails(ShareProblem problem) =>
      throwsA(isA<ShareFailure>().having((f) => f.problem, 'problem', problem));

  /// A hand-made package, for inputs the exporter never writes.
  File zip(
    String name,
    Map<String, Object?> manifest, [
    Map<String, List<int>> entries = const {},
  ]) {
    final archive = Archive()..addFile(ArchiveFile.string('manifest.json', jsonEncode(manifest)));
    for (final entry in entries.entries) {
      archive.addFile(ArchiveFile.bytes(entry.key, entry.value));
    }
    return File(p.join(temp.path, name))..writeAsBytesSync(ZipEncoder().encode(archive));
  }

  final emptyTranscript = utf8.encode(jsonEncode({'lines': <Object?>[]}));

  test('a recording keeps its lines, word timings, translations and audio', () async {
    final relative = await store.importMedia(audio);
    final mediaId = p.basenameWithoutExtension(relative);
    await repository.addMedia(
      id: mediaId,
      kind: 'audio',
      relPath: relative,
      sha256: mediaId,
      durationMs: 4000,
    );
    await repository.createSession(
      id: 's1',
      origin: 'file',
      language: 'en',
      title: 'Morning memo',
      startedAt: DateTime.utc(2026, 10, 21, 9),
      timeBase: 'media',
      mediaId: mediaId,
    );
    final words = [
      {'text': 'Good', 'startMs': 0, 'endMs': 600},
      {'text': 'morning.', 'startMs': 600, 'endMs': 1500},
    ];
    await repository.addSegments('s1', [
      (
        id: 's1-0',
        startMs: 0,
        endMs: 1500,
        text: 'Good morning.',
        language: 'en',
        wordsJson: jsonEncode(words),
      ),
      (
        id: 's1-1',
        startMs: 1600,
        endMs: 4000,
        text: 'Ready to listen?',
        language: 'en',
        wordsJson: null,
      ),
    ]);
    await repository.addTranslations([
      (segmentId: 's1-0', target: 'zh-Hans', text: '早上好。', provider: 'apple_translation'),
    ]);
    await repository.endSession(
      's1',
      status: 'completed',
      endedAt: DateTime.utc(2026, 10, 21, 9, 0, 4),
    );

    final package = p.join(temp.path, 'Morning memo.${SharePackage.extension}');
    await exportSessionPackage(
      repository: repository,
      store: store,
      sessionId: 's1',
      title: 'Morning memo',
      destination: package,
    );
    final item = await import(File(package));

    final sessionId = (item as SharedSession).sessionId;
    final session = (await other.session(sessionId))!;
    expect(session.origin, 'shared');
    expect(session.title, 'Morning memo');
    expect(session.language, 'en');
    expect(session.status, 'completed');
    expect(session.startedAt, DateTime.utc(2026, 10, 21, 9));
    final lines = await other.lines(sessionId);
    expect(lines.map((l) => (l.startMs, l.endMs, l.text)), [
      (0, 1500, 'Good morning.'),
      (1600, 4000, 'Ready to listen?'),
    ]);
    expect(lines.map((l) => l.translation), ['早上好。', null]);
    expect(jsonDecode(lines.first.wordsJson!), words);
    final media = (await other.media(session.mediaId!))!;
    expect(media.durationMs, 4000);
    expect(File(otherStore.resolve(media.relPath!)).readAsBytesSync(), audio.readAsBytesSync());
  });

  test('a course keeps its area, scenes and media', () async {
    final raw = jsonObject(jsonDecode(File('assets/demo/course.json').readAsStringSync()), 'demo');
    final course = const CourseCodec().fromMap(
      raw,
      area: Area.nba,
      mediaPath: await store.importMedia(audio),
    );
    final package = p.join(temp.path, 'course.${SharePackage.extension}');
    await exportCoursePackage(course: course, store: store, destination: package);
    // Audio and video are stored as they are (streamed, not deflated in
    // memory), and nothing half-written is left next to the file.
    final entries = ZipDecoder().decodeBytes(File(package).readAsBytesSync()).files;
    expect(
      entries.singleWhere((f) => f.name.startsWith('media/')).compression,
      CompressionType.none,
    );
    expect(temp.listSync().where((f) => f.path.endsWith('.partial')), isEmpty);

    final shared = ((await import(File(package))) as SharedCourse).course;
    expect(shared.id, course.id);
    expect(shared.title, course.title);
    expect(shared.area, Area.nba);
    expect(shared.clips.map((c) => c.id), course.clips.map((c) => c.id));
    expect(File(otherStore.resolve(shared.mediaPath!)).readAsBytesSync(), audio.readAsBytesSync());
  });

  test('refuses files that are not packages or come from a newer version', () async {
    final text = File(p.join(temp.path, 'notes.${SharePackage.extension}'))
      ..writeAsStringSync('just text');
    await expectLater(import(text), fails(ShareProblem.notAPackage));
    await expectLater(
      import(zip('other.zip', {'format': 'something.else', 'version': 1, 'kind': 'session'})),
      fails(ShareProblem.notAPackage),
    );
    await expectLater(
      import(
        zip('newer.zip', {
          'format': SharePackage.format,
          'version': SharePackage.version + 1,
          'kind': 'session',
        }),
      ),
      fails(ShareProblem.newerVersion),
    );
    await expectLater(
      import(zip('empty.zip', {'format': SharePackage.format, 'version': 1, 'kind': 'session'})),
      fails(ShareProblem.missingContent),
    );
  });

  test('only reads media the manifest names under media/, with a known extension', () async {
    final manifest = {'format': SharePackage.format, 'version': 1, 'kind': 'session'};
    // A name that climbs out of media/ is ignored; the lines still import.
    final escape = await import(
      zip(
        'escape.zip',
        {...manifest, 'media': 'media/../../evil.m4a'},
        {
          'media/../../evil.m4a': [1, 2, 3],
          'transcript.json': emptyTranscript,
        },
      ),
    );
    expect((await other.session((escape as SharedSession).sessionId))!.mediaId, isNull);
    expect(Directory(p.join(temp.path, 'theirs', 'media')).existsSync(), isFalse);

    await expectLater(
      import(
        zip(
          'program.zip',
          {...manifest, 'media': 'media/media.command'},
          {'media/media.command': utf8.encode('#!/bin/sh'), 'transcript.json': emptyTranscript},
        ),
      ),
      fails(ShareProblem.unsupportedMedia),
    );
  });
}

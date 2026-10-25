import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tinglang/core/library_store.dart';
import 'package:tinglang/core/course_codec.dart';
import 'package:tinglang/core/models.dart';
import 'package:tinglang/services/app_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late LibraryStore store;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('tinglang-test-');
    store = LibraryStore(directory);
  });
  tearDown(() async {
    await directory.delete(recursive: true);
  });

  test('round-trips library and keeps previous valid snapshot as backup', () async {
    final state = LibraryState();
    state.drafts['a'] = 'Original words';
    await store.save(state);
    state.drafts['a'] = 'New words';
    await store.save(state);
    expect((await store.load()).drafts['a'], 'New words');
    expect(await File('${store.stateFile.path}.bak').readAsString(), contains('Original words'));
  });
  test('corrupt storage is not silently overwritten', () async {
    await store.stateFile.writeAsString('{broken');
    await expectLater(store.load(), throwsA(isA<LibraryReadException>()));
    expect(await store.stateFile.readAsString(), '{broken');
  });
  test('rejects absolute paths and directory traversal', () {
    expect(() => store.resolve('/tmp/outside'), throwsFormatException);
    expect(() => store.resolve('../outside'), throwsFormatException);
    expect(store.resolve('recordings/local.wav'), startsWith(directory.path));
  });
  test('media imports deduplicate and do not depend on source file afterward', () async {
    final source = File('${directory.path}/source.wav');
    await source.writeAsBytes([82, 73, 70, 70, 1, 2, 3]);
    final first = await store.importMedia(source);
    final second = await store.importMedia(source);
    expect(first, second);
    await source.delete();
    expect(await File(store.resolve(first)).exists(), isTrue);
  });
  test('reimport preserves completion, drafts, attempts and media', () async {
    final app = AppController(store, LibraryState());
    addTearDown(app.dispose);
    final course = const CourseCodec()
        .decode(File('assets/demo/course.json').readAsStringSync())
        .copyWith(mediaPath: 'media/demo.wav');
    await app.upsertCourse(course);
    await app.setDone(course, course.clips.first, 'shadowing', true);
    await app.saveDraft(course.id, course.clips.first.id, 'retelling', 'My real words');
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
    final imported = const CourseCodec().decode(File('assets/demo/course.json').readAsStringSync());
    await app.upsertCourse(imported);
    expect(app.state.courses, hasLength(1));
    expect(app.state.courses.single.mediaPath, 'media/demo.wav');
    expect(app.done(course, course.clips.first), contains('shadowing'));
    expect(app.draft(course.id, course.clips.first.id, 'retelling'), 'My real words');
    expect(app.state.attempts.single.recordingPath, 'recordings/keep.wav');
  });
  test('rapid draft writes commit in order', () async {
    final app = AppController(store, LibraryState());
    addTearDown(app.dispose);
    await Future.wait([for (var i = 0; i < 12; i++) app.saveDraft(null, null, 'free', 'draft $i')]);
    expect(app.draft(null, null, 'free'), 'draft 11');
    expect((await store.load()).drafts.values, contains('draft 11'));
  });
  test('failed persistence does not publish a successful attempt and can retry', () async {
    final failing = FailingStore(directory);
    final app = AppController(failing, LibraryState());
    addTearDown(app.dispose);
    final attempt = PracticeAttempt(
      id: 'pending',
      createdAt: DateTime.now(),
      kind: 'free',
      note: 'Do not lose me',
      durationMs: 0,
    );
    await expectLater(app.saveAttempt(attempt), throwsA(isA<FileSystemException>()));
    await app.flush();
    expect(app.state.attempts, isEmpty);
    expect(app.pendingAttempt?.id, 'pending');
    failing.fail = false;
    await app.retryPending();
    expect(app.state.attempts.single.id, 'pending');
    expect(app.pendingAttempt, isNull);
  });
}

class FailingStore extends LibraryStore {
  FailingStore(super.root);
  bool fail = true;
  @override
  Future<void> save(LibraryState state) {
    if (fail) return Future.error(const FileSystemException('Simulated disk failure'));
    return super.save(state);
  }
}

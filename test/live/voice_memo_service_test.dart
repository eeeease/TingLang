import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tinglang/core/db/database.dart';
import 'package:tinglang/core/library_store.dart';
import 'package:tinglang/core/live_repository.dart';
import 'package:tinglang/services/app_controller.dart';
import 'package:tinglang/services/transcription_controller.dart';
import 'package:tinglang/services/voice_memos.dart';
import 'package:tinglang_native/tinglang_native.dart';
import 'package:tinglang_platform_interface/testing.dart';

void main() {
  late Directory dir;
  late TinglangDatabase db;
  late AppController app;
  late TranscriptionController transcription;
  late FakeVoiceMemoLibrary library;
  late TinglangPlatform platform;
  late FakeDesktopShell shell;
  // Evening of the day the memos were recorded (local time).
  final now = DateTime(2026, 10, 22, 21, 30);

  VoiceMemo memo(String id, DateTime local, {String title = ''}) => VoiceMemo(
    id: id,
    title: title,
    recordedAt: local.toUtc(),
    duration: const Duration(minutes: 3),
    path: (File('${dir.path}/$id.m4a')..writeAsBytesSync(List.filled(32, id.length))).path,
  );

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('tinglang-voice-memos-');
    db = TinglangDatabase.memory();
    final store = LibraryStore(Directory('${dir.path}/library'));
    app = AppController(store, LibraryState());
    library = FakeVoiceMemoLibrary([
      memo('morning', DateTime(2026, 10, 22, 8, 15), title: 'Standup'),
      memo('lunch', DateTime(2026, 10, 22, 12, 40)),
      memo('yesterday', DateTime(2026, 10, 21, 19)),
    ]);
    platform = TinglangPlatform(probeSource: FakeProbeSource(FakeProbes.macos(const OsVersion(26))))
      ..voiceMemos.register(BackendFactory(BackendCatalog.appleVoiceMemos, () => library))
      ..fileAsr.register(
        BackendFactory(
          BackendCatalog.speechAnalyzerFile,
          () => FakeFileTranscriber(
            BackendCatalog.speechAnalyzerFile.id,
            output: const [TranscriptSegment(startMs: 0, endMs: 900, text: 'Good morning.')],
          ),
        ),
      );
    transcription = TranscriptionController(
      repository: LiveRepository(db),
      store: store,
      platform: platform,
    );
    shell = FakeDesktopShell();
  });
  tearDown(() async {
    app.dispose();
    await db.close();
    await dir.delete(recursive: true);
  });

  VoiceMemoService service() => VoiceMemoService(
    app: app,
    transcription: transcription,
    platform: platform,
    shell: shell,
    now: () => now,
  );

  Future<void> settle() async {
    while (transcription.jobs.any(
      (j) => j.status == ImportStatus.copying || j.status == ImportStatus.transcribing,
    )) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  test('nothing is read until the list has been opened once', () async {
    final memos = service();
    await memos.init();
    expect(memos.available, isTrue);
    await memos.checkInBackground();
    expect(library.listed, 0);

    await memos.refresh();
    expect(library.listed, 1);
    expect(app.setting(VoiceMemoService.enabledKey, ''), 'true');
    await service().checkInBackground();
    expect(library.listed, 2);
  });

  test("today's recordings are new until imported, and stay imported", () async {
    final memos = service();
    await memos.refresh();
    expect(memos.memos.map((m) => m.id), ['lunch', 'morning', 'yesterday']);
    expect(memos.fresh.map((m) => m.id), ['lunch', 'morning']);

    await memos.import(memos.fresh, (m) => 'Voice memo ${m.id}');
    await settle();
    expect(memos.fresh, isEmpty);
    final sessions = await transcription.repository.recentSessions();
    expect(sessions.map((s) => (s.origin, s.title, s.sourceRef)), [
      ('voice_memo', 'Voice memo lunch', 'voicememo:lunch'),
      ('voice_memo', 'Standup', 'voicememo:morning'),
    ]);
    // Grouped by when it was recorded, not when it was imported.
    expect(sessions.last.startedAt, DateTime(2026, 10, 22, 8, 15).toUtc());

    // A later listing (e.g. after a relaunch) still knows.
    final again = service();
    await again.refresh();
    expect(again.fresh, isEmpty);
    expect(again.isImported(again.memos.last), isFalse);
  });

  test('a protected library asks for Full Disk Access and opens its settings', () async {
    library.problem = VoiceMemoProblem.needsFullDiskAccess;
    final memos = service();
    await memos.refresh();
    expect(memos.problem, VoiceMemoProblem.needsFullDiskAccess);
    expect(memos.memos, isEmpty);
    expect(app.setting(VoiceMemoService.enabledKey, 'false'), 'false');
    await memos.openPrivacySettings();
    expect(shell.openedSettings, [SystemSettingsPane.fullDiskAccess]);
  });

  test('platforms without Voice Memos say so', () async {
    final memos = VoiceMemoService(
      app: app,
      transcription: transcription,
      platform: TinglangPlatform(probeSource: FakeProbeSource(FakeProbes.windows(26100))),
    );
    await memos.init();
    expect(memos.available, isFalse);
    await memos.refresh();
    expect(memos.memos, isEmpty);
  });
}

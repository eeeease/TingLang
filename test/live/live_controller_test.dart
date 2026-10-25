import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tinglang/core/db/database.dart';
import 'package:tinglang/core/live_repository.dart';
import 'package:tinglang/services/live_controller.dart';
import 'package:tinglang_native/tinglang_native.dart';
import 'package:tinglang_platform_interface/testing.dart';

void main() {
  late TinglangDatabase db;
  late FakeLivePipelineHost host;
  late FakeGlobalHotkeys hotkeys;
  late LiveController live;

  TinglangPlatform platform(PlatformProbe probe) {
    final p = TinglangPlatform(probeSource: FakeProbeSource(probe));
    host = FakeLivePipelineHost(PipelineTopology.nativeMacos);
    hotkeys = FakeGlobalHotkeys();
    p.pipelines.register(BackendFactory(BackendCatalog.nativeMacosPipeline, () => host));
    p.hotkeys.register(BackendFactory(BackendCatalog.carbonHotkeys, () => hotkeys));
    p.overlays.register(BackendFactory(BackendCatalog.nsPanel, FakeCaptionOverlay.new));
    return p;
  }

  setUp(() async {
    db = TinglangDatabase.memory();
    live =
        LiveController(
            repository: LiveRepository(db),
            platform: platform(FakeProbes.macos(const OsVersion(26))),
            flushInterval: const Duration(milliseconds: 20),
          )
          ..requestBuilder = () => const LiveRequest(
            source: AudioSourceKind.systemAudio,
            language: 'en',
            translateTo: 'zh-Hans',
          );
    await live.init();
  });
  tearDown(() async {
    live.dispose();
    await db.close();
  });

  test('init registers ⌘⇧T and picks the native pipeline', () {
    expect(live.unavailableReason, isNull);
    expect(hotkeys.bindings[LiveController.toggleHotkeyId]?.key, 'T');
  });

  test('partials update one line in place; finals and translations are saved', () async {
    await live.toggle();
    expect(live.status, LiveStatus.running);
    final session = host.sessions.single;
    expect(session.config.translateTo, 'zh-Hans');

    session.emitCaption(const AsrPartial('s-0', text: 'Hel', startMs: 0));
    session.emitCaption(const AsrPartial('s-0', text: 'Hello wor', startMs: 0));
    session.emitCaption(const AsrFinal('s-0', text: 'Hello world.', startMs: 0, endMs: 1200));
    session.emitCaption(const AsrPartial('s-1', text: 'Next', startMs: 1300));
    session.emitTranslation(
      SegmentTranslation('s-0', const LanguagePair('en', 'zh-Hans'), '你好，世界。'),
    );
    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(live.lines.map((l) => l.text), ['Hello world.', 'Next']);
    expect(live.lines.first.isFinal, isTrue);
    expect(live.lines.first.translation, '你好，世界。');

    await live.toggle(); // stop
    expect(live.status, LiveStatus.idle);
    expect(session.stopped, isTrue);
    final saved = await live.repository.lines(session.sessionId);
    expect(saved.map((l) => (l.text, l.translation)), [('Hello world.', '你好，世界。')]);
    final row = (await live.repository.recentSessions()).single;
    expect(row.status, 'completed');
    expect(row.origin, 'live_system');
  });

  test('a translation that arrives before its final is flushed waits for the segment', () async {
    await live.toggle();
    final session = host.sessions.single;
    session.emitCaption(const AsrFinal('s-0', text: 'One.', startMs: 0, endMs: 500));
    session.emitTranslation(SegmentTranslation('s-0', const LanguagePair('en', 'zh-Hans'), '一。'));
    await live.stop();
    final saved = await live.repository.lines(session.sessionId);
    expect(saved.single.translation, '一。');
  });

  test('missing translation pack becomes a setup need; captions keep running', () async {
    await live.toggle();
    host.sessions.single.emitIssue(const TranslationPackMissing('en→zh-Hans'));
    await Future<void>.delayed(Duration.zero);
    expect(live.setupNeed, isA<TranslationPackNeeded>());
    expect(live.status, LiveStatus.running);
    await live.stop();
  });

  test('captions from the microphone ask macOS first; a refusal says where to allow it', () async {
    var allowed = false, asked = 0;
    live
      ..requestMicrophone = () async {
        asked++;
        return allowed;
      }
      ..requestBuilder = () =>
          const LiveRequest(source: AudioSourceKind.microphone, language: 'en');
    await live.toggle();
    expect(asked, 1);
    expect(live.status, LiveStatus.idle);
    expect(live.error, isNull);
    expect(
      live.setupNeed,
      isA<CapturePermissionNeeded>().having(
        (n) => n.permission,
        'permission',
        PermissionKind.microphone,
      ),
    );
    expect(host.sessions, isEmpty, reason: 'nothing is captured without the microphone');

    allowed = true;
    await live.toggle();
    expect(asked, 2);
    expect(live.setupNeed, isNull);
    expect(live.status, LiveStatus.running);
    expect(host.sessions.single.config.source, AudioSourceKind.microphone);
    await live.stop();
  });

  test('system audio never asks the microphone; a capture refusal becomes a setup need', () async {
    var asked = 0;
    live.requestMicrophone = () async {
      asked++;
      return false;
    };
    final refusing =
        LiveController(
            repository: LiveRepository(db),
            platform:
                TinglangPlatform(
                    probeSource: FakeProbeSource(FakeProbes.macos(const OsVersion(26))),
                  )
                  ..pipelines.register(
                    BackendFactory(BackendCatalog.nativeMacosPipeline, () => _RefusingHost()),
                  )
                  ..overlays.register(
                    BackendFactory(BackendCatalog.nsPanel, FakeCaptionOverlay.new),
                  ),
          )
          ..requestBuilder = () =>
              const LiveRequest(source: AudioSourceKind.systemAudio, language: 'en');
    addTearDown(refusing.dispose);
    await refusing.init();
    await refusing.toggle();
    expect(refusing.status, LiveStatus.idle);
    expect(refusing.error, isNull, reason: 'not a "Bad state" error');
    expect(
      refusing.setupNeed,
      isA<CapturePermissionNeeded>().having(
        (n) => n.permission,
        'permission',
        PermissionKind.systemAudio,
      ),
    );

    await live.toggle();
    expect(asked, 0);
    expect(live.status, LiveStatus.running);
    await live.stop();
  });

  test('the global shortcut toggles capture', () async {
    hotkeys.press(LiveController.toggleHotkeyId);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(live.status, LiveStatus.running);
    hotkeys.press(LiveController.toggleHotkeyId);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(live.status, LiveStatus.idle);
  });

  test('a kept recording becomes the session media; caption times stay offsets into it', () async {
    final root = await Directory.systemTemp.createTemp('tinglang-rec-');
    addTearDown(() => root.delete(recursive: true));
    final recording = LiveController(
      repository: LiveRepository(db),
      platform: platform(FakeProbes.macos(const OsVersion(26))),
      libraryRoot: root,
    );
    await recording.init();
    await recording.start(
      const LiveRequest(source: AudioSourceKind.microphone, language: 'en', recordAudio: true),
    );
    final session = host.sessions.single;
    final path = session.config.recordPath!;
    expect(path, startsWith('${root.path}/media/live-'));
    File(path).writeAsBytesSync(List.filled(32, 1)); // what Swift would write
    session.emitCaption(const AsrFinal('m-0', text: 'My own words.', startMs: 0, endMs: 2400));
    await Future<void>.delayed(Duration.zero);
    await recording.stop();
    final row = (await recording.repository.session(session.sessionId))!;
    expect(row.origin, 'live_mic');
    expect(row.timeBase, 'media');
    final media = (await recording.repository.media(row.mediaId!))!;
    expect(media.relPath, startsWith('media/live-'));
    expect(media.durationMs, 2400);
    recording.dispose();
  });

  test('no recording is attached when nothing was written', () async {
    final root = await Directory.systemTemp.createTemp('tinglang-rec-');
    addTearDown(() => root.delete(recursive: true));
    final recording = LiveController(
      repository: LiveRepository(db),
      platform: platform(FakeProbes.macos(const OsVersion(26))),
      libraryRoot: root,
    );
    await recording.init();
    await recording.start(
      const LiveRequest(source: AudioSourceKind.systemAudio, language: 'en', recordAudio: true),
    );
    await recording.stop();
    final row = (await recording.repository.recentSessions()).first;
    expect(row.mediaId, isNull);
    expect(row.timeBase, 'wallclock');
    recording.dispose();
  });

  test('no pipeline on old macOS: start is disabled with a reason', () async {
    final old = LiveController(
      repository: LiveRepository(db),
      platform:
          TinglangPlatform(probeSource: FakeProbeSource(FakeProbes.macos(const OsVersion(14, 2))))
            ..pipelines.register(
              BackendFactory(
                BackendCatalog.nativeMacosPipeline,
                () => FakeLivePipelineHost(PipelineTopology.nativeMacos),
              ),
            ),
    );
    await old.init();
    expect(old.unavailableReason, contains('26'));
    await old.toggle();
    expect(old.status, LiveStatus.idle);
    old.dispose();
  });
}

/// A pipeline whose capture macOS refused.
final class _RefusingHost implements LivePipelineHost {
  @override
  PipelineTopology get topology => PipelineTopology.nativeMacos;

  @override
  Future<LiveSession> start(LivePipelineConfig config) async =>
      throw const CapturePermissionDenied(PermissionKind.systemAudio);
}

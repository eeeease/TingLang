import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tinglang_native/src/shared/portable_pipeline.dart';
import 'package:tinglang_native/src/shared/shared_backends.dart';
import 'package:tinglang_native/src/shared/sherpa_file_transcriber.dart';
import 'package:tinglang_native/src/shared/sherpa_streaming_asr.dart';
import 'package:tinglang_platform_interface/testing.dart';
import 'package:tinglang_platform_interface/tinglang_platform_interface.dart';

/// A session the test drives: records pushed samples, emits what it is told.
final class ScriptedAsrSession implements AsrSession {
  final _events = StreamController<AsrEvent>.broadcast();
  final _stats = StreamController<AsrStats>.broadcast();
  int samples = 0;
  bool stopped = false;
  @override
  Stream<AsrEvent> get events => _events.stream;
  @override
  Stream<AsrStats> get stats => _stats.stream;
  void emit(AsrEvent event) => _events.add(event);
  void emitStats(AsrStats stats) => _stats.add(stats);
  @override
  void acceptWaveform(Float32List samples, int sampleRate) => this.samples += samples.length;
  @override
  Future<void> stop() async {
    stopped = true;
    _events.add(const AsrFinal('s-9', text: 'flushed', startMs: 0, endMs: 10));
    await _events.close();
    await _stats.close();
  }
}

final class ScriptedAsr implements StreamingAsrBackend {
  final sessions = <ScriptedAsrSession>[];
  final configs = <AsrSessionConfig>[];
  @override
  Set<String> get languages => const {'en'};
  @override
  Future<AsrSession> start(AsrSessionConfig config) async {
    configs.add(config);
    final session = ScriptedAsrSession();
    sessions.add(session);
    return session;
  }
}

/// Records when each tail push happened.
final class TimedOverlay implements CaptionOverlay {
  final fake = FakeCaptionOverlay();
  final times = <DateTime>[];
  List<List<CaptionLine>> get pushes => fake.pushes;
  @override
  Future<void> pushTail(List<CaptionLine> lines) {
    times.add(DateTime.now());
    return fake.pushTail(lines);
  }

  @override
  Stream<OverlayEvent> get events => fake.events;
  @override
  Future<void> hide() => fake.hide();
  @override
  Future<void> resetPosition() => fake.resetPosition();
  @override
  Future<void> setState(OverlayState state) => fake.setState(state);
  @override
  Future<void> show(CaptionStyle style, {required Map<String, String> strings}) =>
      fake.show(style, strings: strings);
}

/// Lists no pairs (like Apple Translation) and fails like a missing pack.
final class PacklessTranslator implements TranslatorBackend {
  int calls = 0;
  @override
  Set<LanguagePair> get pairs => const {};
  @override
  Future<List<String>> translate(List<String> texts, LanguagePair pair) async {
    calls++;
    throw StateError('pack not installed');
  }
}

final class RecordingCapture implements AudioCaptureBackend {
  final inner = FakeAudioCaptureBackend(AudioSourceKind.systemAudio);
  final requests = <AudioCaptureRequest>[];
  @override
  AudioSourceKind get kind => inner.kind;
  @override
  Future<NativeAudioSource> open(AudioCaptureRequest request) {
    requests.add(request);
    return inner.open(request);
  }
}

void main() {
  const asrId = 'sherpa.xasr_zh_en_480';
  late TinglangPlatform platform;
  late ScriptedAsr asr;
  late FakeAudioCaptureBackend capture;
  late TimedOverlay overlay;
  late FakeTranslator translator;

  setUp(() {
    platform = fakeTinglangPlatform(
      FakeProbes.macos(
        const OsVersion(15),
        permissions: FakeProbes.allGranted,
        installedAssets: {'xasr-zh-en-480ms-int8', 'silero-vad'},
      ),
    );
    asr = ScriptedAsr();
    capture = FakeAudioCaptureBackend(AudioSourceKind.systemAudio);
    overlay = TimedOverlay();
    translator = FakeTranslator();
    platform.liveAsr.register(BackendFactory(BackendCatalog.sherpaXasrZhEn, () => asr));
    platform.systemAudio.register(BackendFactory(BackendCatalog.coreAudioTap, () => capture));
    platform.overlays.register(BackendFactory(BackendCatalog.nsPanel, () => overlay));
    platform.translators.register(
      BackendFactory(BackendCatalog.appleTranslation, () => translator),
    );
  });

  LivePipelineConfig config({String? translateTo = 'zh-Hans', bool overlay = true}) =>
      LivePipelineConfig(
        source: AudioSourceKind.systemAudio,
        asrBackendId: asrId,
        language: 'en',
        translateTo: translateTo,
        showOverlay: overlay,
        speech: const SpeechOptions(latency: LatencyTier.fastest),
      );

  test('wires capture, recogniser, translation of finals and the panel', () async {
    final host = PortablePipelineHost(platform);
    expect(host.topology, PipelineTopology.portable);
    final session = await host.start(config());
    final captions = <AsrEvent>[];
    final translations = <SegmentTranslation>[];
    final stats = <AsrStats>[];
    session.captions.listen(captions.add);
    session.translations.listen(translations.add);
    session.stats.listen(stats.add);

    // Fake capture has no ring: blocks are pushed; the tier reaches the ASR.
    expect(asr.configs.single.source, isNull);
    expect(asr.configs.single.latency, LatencyTier.fastest);
    expect(asr.configs.single.numThreads, 1);
    expect(asr.configs.single.endpointSilenceMs, 500);
    final source = capture.opened.single;
    expect(source.isRunning, isTrue);
    source.emit(Float32List(1600));
    source.emit(Float32List(1600));
    await pumpEventQueue();
    final recognizer = asr.sessions.single;
    expect(recognizer.samples, 3200);

    // 40 partials within a few ms are coalesced to the newest one.
    for (var i = 0; i < 40; i++) {
      recognizer.emit(AsrPartial('s-0', text: 'hello $i', startMs: 0));
    }
    await Future<void>.delayed(const Duration(milliseconds: 150));
    final partials = captions.whereType<AsrPartial>().toList();
    expect(partials.length, 1);
    expect(partials.single.text, 'hello 39');

    recognizer.emit(const AsrFinal('s-0', text: 'hello world', startMs: 0, endMs: 900));
    recognizer.emit(AsrPartial('s-1', text: 'next', startMs: 1000));
    recognizer.emitStats(const AsrStats(realTimeFactor: .1, queuedMs: 0, cpuMsPerSecond: 60));
    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(captions.whereType<AsrFinal>().single.text, 'hello world');
    expect(translations.single.segmentId, 's-0');
    expect(translations.single.text, '[zh-Hans] hello world');
    expect(translations.single.pair, const LanguagePair('en', 'zh-Hans'));
    expect(stats.single.cpuMsPerSecond, 60);

    final tail = overlay.pushes.last;
    expect(tail.first.segmentId, 's-0');
    expect(tail.first.isFinal, isTrue);
    expect(tail.first.translation, '[zh-Hans] hello world');
    expect(tail.last.text, 'next');

    await session.stop();
    expect(recognizer.stopped, isTrue);
    expect(source.isRunning, isFalse);
    expect(captions.last, isA<AsrFinal>().having((f) => f.text, 'text', 'flushed'));
    // Partials are never translated.
    expect(translations.map((t) => t.segmentId), ['s-0', 's-9']);
  });

  test('the panel gets at most 30 lines at no more than 10 Hz', () async {
    final session = await PortablePipelineHost(platform).start(config(translateTo: null));
    final recognizer = asr.sessions.single;
    for (var i = 0; i < 80; i++) {
      recognizer.emit(AsrFinal('s-$i', text: 'line $i', startMs: i * 10, endMs: i * 10 + 5));
      if (i % 10 == 0) await Future<void>.delayed(const Duration(milliseconds: 30));
    }
    await Future<void>.delayed(const Duration(milliseconds: 250));
    await session.stop();
    expect(overlay.pushes, isNotEmpty);
    for (final push in overlay.pushes) {
      expect(push.length, lessThanOrEqualTo(CaptionOverlay.maxTailLines));
    }
    expect(overlay.pushes.last.last.text, 'flushed');
    expect(overlay.pushes.last.first.text, 'line 51');
    for (var i = 1; i < overlay.times.length; i++) {
      final gap = overlay.times[i].difference(overlay.times[i - 1]);
      expect(gap.inMilliseconds, greaterThanOrEqualTo(90));
    }
  });

  test('without the overlay nothing is pushed; levels and issues pass through', () async {
    final session = await PortablePipelineHost(platform).start(config(overlay: false));
    final levels = <double>[];
    final issues = <AudioCaptureIssue>[];
    session.levels.listen(levels.add);
    session.issues.listen(issues.add);
    final source = capture.opened.single;
    source.emitIssue(const SilentTapDetected(Duration(seconds: 4)));
    await pumpEventQueue();
    expect(issues.single, isA<SilentTapDetected>());
    asr.sessions.single.emit(const AsrFinal('s-0', text: 'hi', startMs: 0, endMs: 1));
    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(overlay.pushes, isEmpty);
    await session.stop();
  });

  test('a missing translation pack is reported and captions continue', () async {
    platform.translators.register(
      BackendFactory(
        BackendCatalog.appleTranslation,
        () => FakeTranslator(pairs: {const LanguagePair('en', 'ja')}),
      ),
    );
    final session = await PortablePipelineHost(platform).start(config());
    final issues = <AudioCaptureIssue>[];
    final translations = <SegmentTranslation>[];
    session.issues.listen(issues.add);
    session.translations.listen(translations.add);
    await Future<void>.delayed(Duration.zero);
    expect(
      issues.single,
      isA<TranslationPackMissing>().having((i) => i.pair, 'pair', 'en→zh-Hans'),
    );
    asr.sessions.single.emit(const AsrFinal('s-0', text: 'hi', startMs: 0, endMs: 1));
    await pumpEventQueue();
    expect(translations, isEmpty);
    await session.stop();
  });

  test('a translator without a pair list that fails reports the pack once', () async {
    final packless = PacklessTranslator();
    platform.translators.register(BackendFactory(BackendCatalog.appleTranslation, () => packless));
    final recording = RecordingCapture();
    platform.systemAudio.register(BackendFactory(BackendCatalog.coreAudioTap, () => recording));
    final session = await PortablePipelineHost(platform).start(
      const LivePipelineConfig(
        source: AudioSourceKind.systemAudio,
        asrBackendId: asrId,
        language: 'en',
        translateTo: 'zh-Hans',
        recordPath: '/tmp/x.m4a',
      ),
    );
    expect(recording.requests.single.recordPath, '/tmp/x.m4a');
    final issues = <AudioCaptureIssue>[];
    final captions = <AsrEvent>[];
    session.issues.listen(issues.add);
    session.captions.listen(captions.add);
    final recognizer = asr.sessions.single;
    recognizer.emit(const AsrFinal('s-0', text: 'one', startMs: 0, endMs: 1));
    await pumpEventQueue();
    recognizer.emit(const AsrFinal('s-1', text: 'two', startMs: 2, endMs: 3));
    await pumpEventQueue();
    expect(issues.whereType<TranslationPackMissing>().single.pair, 'en→zh-Hans');
    expect(packless.calls, 1);
    expect(captions.whereType<AsrFinal>().map((f) => f.text), ['one', 'two']);
    await session.stop();
  });

  test('captions start although macOS has not been asked yet; only a refusal stops them', () async {
    // As the real macOS probe: it reports the microphone and screen
    // recording, never system audio recording (macOS has no way to ask).
    PlatformProbe probe(PermissionState microphone) => FakeProbes.macos(
      const OsVersion(15, 6),
      permissions: {
        PermissionKind.microphone: microphone,
        PermissionKind.screenCapture: PermissionState.notDetermined,
      },
      installedAssets: {'xasr-zh-en-480ms-int8', 'silero-vad'},
    );
    TinglangPlatform macos(PermissionState microphone, FakeAudioCaptureBackend mic) =>
        fakeTinglangPlatform(probe(microphone))
          ..liveAsr.register(BackendFactory(BackendCatalog.sherpaXasrZhEn, () => asr))
          ..systemAudio.register(BackendFactory(BackendCatalog.coreAudioTap, () => capture))
          ..microphone.register(BackendFactory(BackendCatalog.avAudioEngineMic, () => mic));

    final mic = FakeAudioCaptureBackend(AudioSourceKind.microphone);
    final system = await PortablePipelineHost(macos(PermissionState.notDetermined, mic))
        .start(config(translateTo: null, overlay: false));
    expect(capture.opened, hasLength(1), reason: 'macOS asks for system audio when the tap opens');
    await system.stop();

    final asked = await PortablePipelineHost(macos(PermissionState.notDetermined, mic)).start(
      const LivePipelineConfig(
        source: AudioSourceKind.microphone,
        asrBackendId: asrId,
        language: 'en',
      ),
    );
    expect(mic.opened, hasLength(1), reason: 'macOS asks for the microphone when capture opens');
    await asked.stop();

    await expectLater(
      PortablePipelineHost(macos(PermissionState.denied, mic)).start(
        const LivePipelineConfig(
          source: AudioSourceKind.microphone,
          asrBackendId: asrId,
          language: 'en',
        ),
      ),
      throwsA(
        isA<CapturePermissionDenied>().having(
          (e) => e.permission,
          'permission',
          PermissionKind.microphone,
        ),
      ),
    );
    expect(mic.opened, hasLength(1));
  });

  test('refuses unknown or not yet installed recognisers', () async {
    final host = PortablePipelineHost(platform);
    await expectLater(
      host.start(
        const LivePipelineConfig(
          source: AudioSourceKind.microphone,
          asrBackendId: 'sherpa.nope',
          language: 'en',
        ),
      ),
      throwsStateError,
    );
    await expectLater(
      host.start(
        const LivePipelineConfig(
          source: AudioSourceKind.microphone,
          asrBackendId: 'sherpa.zipformer_en_small',
          language: 'en',
        ),
      ),
      throwsA(isA<StateError>().having((e) => e.message, 'message', contains('zipformer'))),
    );
    expect(capture.opened, isEmpty);
  });

  group('registerSharedBackends', () {
    test('registers every sherpa model, the cloud services and the portable pipeline', () async {
      final platform = TinglangPlatform(
        probeSource: FakeProbeSource(FakeProbes.macos(const OsVersion(15))),
      );
      registerSharedBackends(platform);
      const cloud = [
        'cloud.tencent',
        'cloud.dashscope',
        'cloud.xfyun',
        'cloud.soniox',
        'cloud.assemblyai',
        'cloud.azure',
      ];
      expect(platform.liveAsr.all.map((f) => f.id), [
        'sherpa.xasr_zh_en_480',
        'sherpa.zipformer_en_small',
        'sherpa.zipformer_en_medium',
        ...cloud,
      ]);
      expect(platform.fileAsr.all.map((f) => f.id), [
        'sherpa.xasr_zh_en_offline',
        'sherpa.parakeet_tdt_v2',
        ...cloud,
      ]);
      expect(platform.pipelines.byId('pipeline.portable')!.create(), isA<PortablePipelineHost>());
      final small = platform.liveAsr.byId('sherpa.zipformer_en_small')!.create();
      expect((small as SherpaStreamingAsr).sentenceCase, isTrue);
      expect((platform.liveAsr.byId(asrId)!.create() as SherpaStreamingAsr).sentenceCase, isFalse);
      expect(
        platform.fileAsr.byId('sherpa.parakeet_tdt_v2')!.create(),
        isA<SherpaFileTranscriber>(),
      );
      // Not installed: nothing is picked.
      final choice = platform.liveAsr.pick(await platform.probe());
      expect(choice.hasSelection, isFalse);
      expect(choice.blocker, isA<NeedsDownload>());
      // Without the app's model inventory, starting fails clearly.
      await expectLater(
        small.start(const AsrSessionConfig(language: 'en')),
        throwsA(isA<StateError>().having((e) => e.message, 'message', contains('models'))),
      );
    });
  });
}

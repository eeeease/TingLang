import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinglang_native_macos/src/host_api.g.dart';
import 'package:tinglang_native_macos/src/live.dart';
import 'package:tinglang_native_macos/tinglang_native_macos.dart';
import 'package:tinglang_platform_interface/tinglang_platform_interface.dart';

/// Records calls; events are pushed through [events].
final class _FakeApi extends TinglangHostApi {
  final calls = <String, List<Object?>>{};
  Completer<void> install = Completer<void>();
  final shown = <List<CaptionLineMessage>>[];

  @override
  Future<String> startLiveWith(LiveStartRequest request, SpeechConfig speech) async {
    calls['startLiveWith'] = [request, speech];
    return 's-1';
  }

  @override
  Future<void> transcribeFileWith(FileTranscribeRequest request, SpeechConfig speech) async {
    calls['transcribeFileWith'] = [request, speech];
  }

  @override
  Future<AssetStatus> speechAssetStatusFor(String locale, String engine) async {
    calls['speechAssetStatusFor'] = [locale, engine];
    return AssetStatus.supported;
  }

  @override
  Future<void> installSpeechAssetsFor(String requestId, String locale, String engine) {
    calls['installSpeechAssetsFor'] = [requestId, locale, engine];
    return install.future;
  }

  @override
  Future<void> cancelSpeechAssets(String requestId) async {
    calls['cancelSpeechAssets'] = [requestId];
    install.completeError(PlatformException(code: 'canceled', message: 'Cancelled'));
  }

  @override
  Future<CaptureHandle> openCapture(CaptureRequest request) async {
    calls['openCapture'] = [request];
    return CaptureHandle(captureId: 'c-1', ringAddress: 0x1000, capacity: 480000);
  }

  @override
  Future<void> closeCapture(String captureId) async {
    calls['closeCapture'] = [captureId];
  }

  @override
  Future<void> showCaptionLines(List<CaptionLineMessage> lines, bool awaitingTranslation) async {
    shown.add(lines);
    calls['showCaptionLines'] = [awaitingTranslation];
  }

  @override
  Future<String> decodeToPcmFile(String path) async => '/tmp/x.f32';

  @override
  Future<List<String>> translateTexts(String source, String target, List<String> texts) async => [
    for (final t in texts) '$target:$t',
  ];
}

void main() {
  late _FakeApi api;
  late StreamController<LiveEvent> events;
  late MacEvents macEvents;

  setUp(() {
    api = _FakeApi();
    events = StreamController<LiveEvent>.broadcast();
    macEvents = MacEvents(() => events.stream);
  });
  tearDown(() => events.close());

  group('speech config', () {
    test('each latency tier and the dictation hints go to Swift by name', () async {
      final host = MacNativePipelineHost(api, macEvents);
      for (final tier in LatencyTier.values) {
        await host.start(
          LivePipelineConfig(
            source: AudioSourceKind.systemAudio,
            asrBackendId: 'dictation_transcriber',
            language: 'en',
            speech: SpeechOptions(
              latency: tier,
              locale: 'en-GB',
              dictation: const DictationHints(farField: true),
            ),
          ),
        );
        final [request as LiveStartRequest, speech as SpeechConfig] = api.calls['startLiveWith']!;
        expect(speech.engine, 'appleDictation');
        expect(speech.latency, tier.name);
        expect(speech.locale, 'en-GB');
        expect(request.locale, 'en-GB');
        expect(speech.farField, isTrue);
        expect(speech.shortForm, isFalse);
      }
    });

    test('speech_transcriber is appleSpeech; without an accent the language decides', () async {
      await MacNativePipelineHost(api, macEvents).start(
        const LivePipelineConfig(
          source: AudioSourceKind.microphone,
          asrBackendId: 'speech_transcriber',
          language: 'zh-Hans',
        ),
      );
      final [request as LiveStartRequest, speech as SpeechConfig] = api.calls['startLiveWith']!;
      expect(speech.engine, 'appleSpeech');
      expect(speech.latency, 'balanced');
      expect(speech.locale, 'zh-CN');
      expect(request.locale, 'zh-CN');
      expect(request.source, 'microphone');
    });

    test('file backends pick their engine and report their own id', () async {
      final dictation = MacFileTranscriber(api, macEvents, engine: SpeechEngine.appleDictation);
      expect(dictation.backendId, 'dictation_file');
      final job = dictation.transcribe(
        '/a.m4a',
        const FileTranscriptionOptions(
          language: 'en',
          speech: SpeechOptions(locale: 'en-AU', dictation: DictationHints(shortForm: true)),
        ),
      );
      final transcript = await job.result;
      expect(transcript.backendId, 'dictation_file');
      final [request as FileTranscribeRequest, speech as SpeechConfig] =
          api.calls['transcribeFileWith']!;
      expect(request.locale, 'en-AU');
      expect(speech.engine, 'appleDictation');
      expect(speech.shortForm, isTrue);

      final speechFile = MacFileTranscriber(api, macEvents);
      expect(speechFile.backendId, 'speech_analyzer_file');
      expect(
        (await speechFile
                .transcribe('/a.m4a', const FileTranscriptionOptions(language: 'en'))
                .result)
            .backendId,
        'speech_analyzer_file',
      );
      expect((api.calls['transcribeFileWith']![1]! as SpeechConfig).engine, 'appleSpeech');
    });
  });

  group('speech assets', () {
    test('status asks per engine; sherpa engines are refused', () async {
      final assets = MacSpeechAssetSupport(api, macEvents);
      expect(await assets.status('en', SpeechEngine.appleDictation), AssetState.downloadable);
      expect(api.calls['speechAssetStatusFor'], ['en-US', 'appleDictation']);
      expect(() => assets.status('en', SpeechEngine.sherpaStreaming), throwsArgumentError);
    });

    test('progress events for the request reach the install; others do not', () async {
      final install = MacSpeechAssetSupport(
        api,
        macEvents,
      ).install('en-GB', SpeechEngine.appleSpeech);
      final [requestId as String, locale, engine] = api.calls['installSpeechAssetsFor']!;
      expect([locale, engine], ['en-GB', 'appleSpeech']);
      final seen = <double>[];
      install.progress.listen(seen.add);
      events
        ..add(LiveEvent(kind: 'assetProgress', sessionId: requestId, level: .25))
        ..add(LiveEvent(kind: 'assetProgress', sessionId: 'other', level: .9))
        ..add(LiveEvent(kind: 'progress', sessionId: requestId, level: .5))
        ..add(LiveEvent(kind: 'assetProgress', sessionId: requestId, level: .75));
      await pumpEventQueue();
      api.install.complete();
      await install.done;
      expect(seen, [.25, .75]);
    });

    test('cancel fails done with a cancellation', () async {
      final install = MacSpeechAssetSupport(api, macEvents).install('en', SpeechEngine.appleSpeech);
      await install.cancel();
      await expectLater(
        install.done,
        throwsA(
          isA<SpeechAssetInstallCanceled>().having((e) => '$e', 'message', contains('Cancel')),
        ),
      );
      expect(api.calls['cancelSpeechAssets'], [api.calls['installSpeechAssetsFor']![0]]);
    });
  });

  group('capture', () {
    test('opens on start; levels, issues and the end follow its id', () async {
      final backend = MacAudioCaptureBackend(api, macEvents, AudioSourceKind.systemAudio);
      final source = await backend.open(const AudioCaptureRequest(), recordPath: '/r.m4a');
      expect(api.calls['openCapture'], isNull);
      final levels = <AudioLevel>[];
      final issues = <AudioCaptureIssue>[];
      source.levels.listen(levels.add);
      source.issues.listen(issues.add);
      await source.start();
      final request = api.calls['openCapture']![0]! as CaptureRequest;
      expect(request.source, 'system');
      expect(request.recordPath, '/r.m4a');
      expect(source.ring!.address, 0x1000);
      expect(source.ring!.capacitySamples, 480000);
      expect(source.debugBlocks, isNull);
      expect(source.isRunning, isTrue);

      events
        ..add(LiveEvent(kind: 'level', sessionId: 'c-1', level: .4))
        ..add(LiveEvent(kind: 'level', sessionId: 's-other', level: .9))
        ..add(LiveEvent(kind: 'issue', sessionId: 'c-1', code: 'silent_tap'))
        ..add(LiveEvent(kind: 'issue', sessionId: 'c-1', code: 'frames_dropped', message: '1600'))
        ..add(
          LiveEvent(kind: 'issue', sessionId: 'c-1', code: 'recording_failed', message: 'disk'),
        );
      await pumpEventQueue();
      expect(levels.map((l) => l.rms), [.4]);
      expect(issues[0], isA<SilentTapDetected>());
      expect(issues[1], isA<FramesDropped>().having((i) => i.samples, 'samples', 1600));
      expect(issues[2], isA<CaptureFailed>());

      final stopping = source.stop();
      await pumpEventQueue();
      expect(api.calls['closeCapture'], ['c-1']);
      events.add(LiveEvent(kind: 'stopped', sessionId: 'c-1'));
      await stopping;
      expect(source.isRunning, isFalse);
      await source.ended;
    });

    test('the microphone backend asks for the microphone', () async {
      final source = await MacAudioCaptureBackend(
        api,
        macEvents,
        AudioSourceKind.microphone,
      ).open(const AudioCaptureRequest());
      await source.start();
      expect((api.calls['openCapture']![0]! as CaptureRequest).source, 'microphone');
      expect((api.calls['openCapture']![0]! as CaptureRequest).recordPath, isNull);
    });
  });

  test('pushTail sends the lines to the panel and keeps the 30-line limit', () async {
    final overlay = MacCaptionOverlay(api, macEvents);
    await overlay.pushTail(const [
      CaptionLine(segmentId: 'a', text: 'Hello', isFinal: true),
      CaptionLine(segmentId: 'b', text: 'wor'),
    ], awaitingTranslation: true);
    expect(api.shown.single.map((l) => l.segmentId), ['a', 'b']);
    expect(api.shown.single.first.isFinal, isTrue);
    expect(api.calls['showCaptionLines'], [true]);
    expect(
      () => overlay.pushTail([for (var i = 0; i < 31; i++) CaptionLine(segmentId: '$i', text: '')]),
      throwsArgumentError,
    );
  });

  test('decoder and translator go through Pigeon', () async {
    expect(await MacMediaDecoder(api).decodeToFile('/a.mp4'), '/tmp/x.f32');
    expect(
      () => MacMediaDecoder(api).decodeToFile('/a.mp4', sampleRate: 8000),
      throwsArgumentError,
    );
    expect(await MacTranslator(api).translate(['hi', 'yo'], const LanguagePair('en', 'zh-Hans')), [
      'zh-Hans:hi',
      'zh-Hans:yo',
    ]);
  });

  group('registration', () {
    PlatformProbe mac({
      OsVersion version = const OsVersion(26),
      Set<String> locales = const {'en-US'},
    }) => PlatformProbe(
      os: HostOs.macos,
      version: version,
      arch: CpuArch.arm64,
      speechLocales: locales,
      permissions: const {
        PermissionKind.microphone: PermissionState.granted,
        PermissionKind.systemAudio: PermissionState.granted,
        PermissionKind.screenCapture: PermissionState.granted,
      },
    );
    final macos26 = mac();

    TinglangPlatform registered() {
      final platform = TinglangPlatform(
        probeSource: TinglangNativeMacos(api: api, events: macEvents),
      );
      TinglangNativeMacos(api: api, events: macEvents).registerBackends(platform);
      return platform;
    }

    test('every macOS backend id is present', () {
      final platform = registered();
      expect(platform.liveAsr.byId('speech_transcriber'), isNotNull);
      expect(platform.liveAsr.byId('dictation_transcriber'), isNotNull);
      expect(platform.fileAsr.byId('speech_analyzer_file'), isNotNull);
      expect(platform.fileAsr.byId('dictation_file'), isNotNull);
      expect(platform.systemAudio.byId('coreaudio_tap'), isNotNull);
      expect(platform.microphone.byId('avaudioengine_mic'), isNotNull);
      expect(platform.decoders.byId('avassetreader'), isNotNull);
      expect(platform.translators.byId('apple_translation'), isNotNull);
      expect(platform.speechAssets, isA<MacSpeechAssetSupport>());
    });

    test('Apple recognisers need speech locales; translation needs macOS 26', () {
      final platform = registered();
      final dictation = platform.liveAsr.byId('dictation_transcriber')!;
      expect(dictation.availability(macos26), isA<Available>());
      expect(dictation.availability(mac(locales: const {})), isA<Unsupported>());
      expect(
        () => (dictation.create()).start(const AsrSessionConfig(language: 'en')),
        throwsUnsupportedError,
      );
      final translator = platform.translators.byId('apple_translation')!;
      expect(translator.availability(macos26), isA<Available>());
      expect(translator.availability(mac(version: const OsVersion(15, 4))), isA<Unsupported>());
      final tap = platform.systemAudio.byId('coreaudio_tap')!;
      expect(tap.availability(mac(version: const OsVersion(14, 2))), isA<Available>());
    });
  });
}

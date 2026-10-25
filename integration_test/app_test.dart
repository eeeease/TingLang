// Runs on a real macOS host: fvm flutter test integration_test -d macos
// Uses a temporary library directory, never the user's data folder.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:tinglang/app.dart';
import 'package:tinglang/core/db/sqlite_library_store.dart';
import 'package:tinglang/core/live_repository.dart';
import 'package:tinglang/services/app_controller.dart';
import 'package:tinglang/services/live_controller.dart';
import 'package:tinglang/services/transcription_controller.dart';
import 'package:tinglang/services/playback_hub.dart';
import 'package:tinglang/services/recording_service.dart';
import 'package:tinglang_native/tinglang_native.dart';

/// Pack folders as extracted by the benchmark (not Tinglang's own layout).
final class _LocalModels implements ModelInventory {
  _LocalModels(this.root);
  final String root;

  @override
  Set<String> get installed => {
    SpeechModels.vad.id,
    SpeechModels.parakeet.pack!.id,
    SpeechModels.xasrStreaming.pack!.id,
  };

  @override
  String directoryOf(String packId) => switch (packId) {
    'silero-vad' => root,
    'xasr-zh-en-480ms-int8' => p.join(
      root,
      'sherpa-onnx-x-asr-480ms-streaming-zipformer-transducer-zh-en-punct-int8-2026-06-05',
    ),
    _ => p.join(root, 'sherpa-onnx-nemo-parakeet-tdt-0.6b-v2-int8'),
  };
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('native probe over Pigeon and the shell render on macOS', (tester) async {
    final platform = TinglangNative.install();
    final probe = await platform.probe();
    expect(NativeBackendProvider.current?.name, 'macos-swift');
    expect(probe.os, HostOs.macos);
    expect(probe.isAtLeast(const OsVersion(14, 2)), isTrue);
    expect(probe.arch, isNot(CpuArch.other));
    // GitHub's macOS runners are virtual machines, where the system speech
    // recogniser reports no locales. A real Mac on 26+ must have it.
    final sysctl = await Process.run('sysctl', ['-n', 'kern.hv_vmm_present']);
    final virtualMachine = '${sysctl.stdout}'.trim() == '1';
    final appleSpeech = probe.isAtLeast(const OsVersion(26)) && !virtualMachine;
    if (appleSpeech) {
      // macOS 26+: the native pipeline (SpeechTranscriber) is the default.
      expect(probe.speechLocales, isNotEmpty);
      expect(platform.pipelines.pick(probe).id, 'pipeline.native_macos');
    } else if (probe.speechLocales.isEmpty) {
      // Without the system recogniser the native pipeline is never chosen.
      expect(platform.pipelines.pick(probe).id, isNot('pipeline.native_macos'));
    }

    final dir = await Directory.systemTemp.createTemp('tinglang-it-');
    final store = SqliteLibraryStore.open(dir);
    final app = AppController(store, await store.load());
    final live = LiveController(repository: LiveRepository(store.db), platform: platform);
    await live.init();
    await tester.pumpWidget(
      TinglangApp(
        controller: app,
        playback: PlaybackHub(),
        recorder: RecordingService(store),
        live: live,
        transcription: TranscriptionController(repository: live.repository, store: store),
        navigation: ValueNotifier(null),
        exitNotice: ValueNotifier(null),
      ),
    );
    await tester.pumpAndSettle();
    await app.setSetting(AppController.uiLocaleKey, 'en');
    await tester.pumpAndSettle();
    expect(find.text('TingLang'), findsOneWidget);
    // History is the home section; nothing is started here (no permission
    // prompts in CI). Captions themselves appear in the floating panel.
    expect(find.text('Nothing captured yet'), findsOneWidget);
    if (appleSpeech) {
      expect(live.unavailableReason, isNull);
      expect(find.text('Start live captions'), findsOneWidget);
    }

    await tester.tap(find.byKey(const ValueKey('nav-library')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Load the sample course'));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.text('Small reps. Real progress.'), findsWidgets);
    expect((await store.load()).courses, hasLength(1));
    await store.close();
    await dir.delete(recursive: true);
  });

  // With local model copies (nothing is downloaded):
  //   TINGLANG_SHERPA_MODELS=<folder with the extracted packs> fvm flutter test integration_test -d macos
  // Inside the real app process: Swift decodes the file to PCM (Pigeon carries
  // only paths), a worker isolate binds the sherpa-onnx library bundled with
  // the app and transcribes with Parakeet over Silero VAD segments. (One file:
  // macOS cannot relaunch the app for a second integration test file.)
  final models = Platform.environment['TINGLANG_SHERPA_MODELS'];
  final wav = p.join(
    models ?? '',
    'sherpa-onnx-nemo-parakeet-tdt-0.6b-v2-int8',
    'test_wavs',
    '0.wav',
  );

  testWidgets('a downloaded model transcribes a file in the app process', (tester) async {
    final platform = TinglangNative.install()..models = _LocalModels(models!);
    final probe = await platform.probe();
    final choice = platform.fileAsr.pick(probe, SpeechModels.parakeet.id);
    expect(choice.id, SpeechModels.parakeet.id);
    final job = choice.create().transcribe(wav, const FileTranscriptionOptions(language: 'en'));
    final transcript = await tester.runAsync(() => job.result);
    final text = transcript!.segments.map((s) => s.text).join(' ');
    expect(text, isNotEmpty);
    expect(transcript.backendId, SpeechModels.parakeet.id);
    final times = transcript.segments.expand((s) => [s.startMs, s.endMs]).toList();
    expect(times, orderedEquals([...times]..sort()), reason: 'segments in media order');
    // ignore: avoid_print
    print('Parakeet in-app: $text');
  }, skip: models == null || !File(wav).existsSync());

  // Swift plays the WAV into the native PCM ring as if it were a capture
  // device (only with TINGLANG_TEST_CAPTURE_FILES=1), the worker isolate reads
  // the ring through FFI and X-ASR captions it; the AAC copy is written on
  // the ring's clock.
  testWidgets(
    'live captions from the native ring: capture → worker isolate → X-ASR',
    (tester) async {
      final platform = TinglangNative.install()..models = _LocalModels(models!);
      final dir = await Directory.systemTemp.createTemp('tinglang-ring-');
      final record = p.join(dir.path, 'live.m4a');
      // By id: a file source needs no microphone permission.
      final capture = platform.microphone.byId(BackendCatalog.avAudioEngineMic.id)!.create();
      final source = await capture.open(
        AudioCaptureRequest(deviceId: 'file:$wav', recordPath: record),
      );
      await source.start();
      expect(source.ring?.address, isNot(0));
      final asr = platform.liveAsr.byId(SpeechModels.xasrStreaming.id)!.create();
      final session = await asr.start(AsrSessionConfig(language: 'en', source: source));
      final events = <AsrEvent>[];
      final sub = session.events.listen(events.add);
      // The clip is about 6.6 s; give it time in real time plus the endpoint.
      await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 10)));
      await tester.runAsync(session.stop);
      await tester.runAsync(source.stop);
      await sub.cancel();
      final finals = events.whereType<AsrFinal>().map((e) => e.text).join(' ');
      expect(events.whereType<AsrPartial>(), isNotEmpty, reason: 'partials while speaking');
      expect(finals.toLowerCase(), contains('phoebe'));
      expect(File(record).lengthSync(), greaterThan(0));
      // ignore: avoid_print
      print('X-ASR from the ring: $finals');
      await dir.delete(recursive: true);
    },
    skip:
        models == null ||
        !File(wav).existsSync() ||
        Platform.environment['TINGLANG_TEST_CAPTURE_FILES'] != '1',
  );
}

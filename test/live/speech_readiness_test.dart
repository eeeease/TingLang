import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tinglang/core/db/database.dart';
import 'package:tinglang/core/live_repository.dart';
import 'package:tinglang/services/live_controller.dart';
import 'package:tinglang/services/speech_model_service.dart';
import 'package:tinglang_native/tinglang_native.dart';
import 'package:tinglang_platform_interface/testing.dart';

/// Model choices and downloads in memory. A download adds the packs to the
/// probe and finishes when [finish] is called (or at once with [instant]).
final class _Models implements SpeechModelSource {
  _Models(this.probes, {this.instant = false});
  final FakeProbeSource probes;
  final bool instant;
  final chosen = <SpeechUse, String?>{};
  SpeechOptions options = const SpeechOptions();
  final downloads = <String>[];
  final cancels = <String>[];
  Completer<void>? _pending;
  void Function(double)? _progress;

  void finish() => _pending?.complete();

  void progress(double value) => _progress?.call(value);

  /// Whether the user has chosen how to recognise speech (first-start card).
  bool chosenSetup = true;
  bool cloudMissing = false;

  @override
  String? modelFor(SpeechUse use) => chosen[use];
  @override
  bool get setupChosen => chosenSetup;
  @override
  bool get cloudNeedsSetup => cloudMissing;
  @override
  SpeechOptions optionsFor(String language) => options;
  @override
  int missingBytes(SpeechModel model) => model.downloadBytes;

  @override
  Future<void> download(SpeechModel model, {void Function(double fraction)? onProgress}) async {
    downloads.add(model.id);
    _progress = onProgress;
    if (!instant) {
      _pending = Completer<void>();
      await _pending!.future;
    }
    probes.current = probes.current.copyWith(
      installedAssets: {...probes.current.installedAssets, ...model.requiredAssets},
    );
  }

  @override
  Future<void> cancelDownload(SpeechModel model) async {
    cancels.add(model.id);
    _pending?.completeError(const DownloadCancelled());
  }
}

final class _Text implements LivePanelText {
  @override
  String get preparing => 'Preparing';
  @override
  String get downloading => 'Downloading';
  @override
  String speechModelNeeded(String language) => 'Apple model for $language';
  @override
  String translationPackNeeded(String source, String target) => 'Pack $source→$target';
  @override
  String get silentSystemAudio => 'Silent';
  @override
  String get screenRecordingCapture => 'Screen';
  @override
  String get download => 'Download';
  @override
  String get retry => 'Retry';
  @override
  String get saved => 'Saved';
  @override
  String summary(Duration length, int words) => '$words words';
  @override
  String failed(String detail) => 'Failed: $detail';
  @override
  String unavailable(String reason) => 'Unavailable: $reason';
  @override
  String importing(int count) => 'Importing $count';
}

final class _ModelText implements LiveModelText {
  @override
  String modelName(SpeechModel model) => model.id;
  @override
  String modelNeeded(String name, String size) => '$name needs $size';
  @override
  String downloadSize(String size) => 'Download $size';
  @override
  String downloading(String name, int percent) => '$name $percent%';
  @override
  String languageUnsupported(String name, String language) => '$name cannot do $language';
  @override
  String get cancel => 'Cancel';
  @override
  String get openSettings => 'Settings';
  @override
  String size(int bytes) => '${(bytes / 1e6).round()} MB';
  @override
  String get chooseRecognizer => 'Choose a recogniser';
  @override
  String cloudNotSetUp(String? service) => 'No key for ${service ?? 'a service'}';
  @override
  String cloudLanguageUnsupported(String service, String language) =>
      '$service cannot do $language';
  @override
  String recognizerFailed(AsrFailure failure) => 'Failed: ${failure.reason.name}';
  @override
  String cloudServiceName(String backendId) => backendId;
  @override
  String cloudLabel(String backendId) => 'Cloud · $backendId';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late TinglangDatabase db;
  late FakeCaptionOverlay overlay;
  late FakeProbeSource probes;
  late FakeSpeechAssetSupport assets;
  late Map<String, FakeLivePipelineHost> hosts;

  /// Every catalog backend as a fake (so selection follows the real gates),
  /// with the overlay and pipelines kept for inspection.
  late TinglangPlatform current;
  TinglangPlatform platform(OsVersion version) {
    final p = current = fakeTinglangPlatform(
      FakeProbes.macos(version, permissions: FakeProbes.allGranted),
    );
    probes = p.probeSource as FakeProbeSource;
    overlay = FakeCaptionOverlay();
    p.overlays.register(BackendFactory<CaptionOverlay>(BackendCatalog.nsPanel, () => overlay));
    hosts = {};
    for (final spec in [BackendCatalog.nativeMacosPipeline, BackendCatalog.portablePipeline]) {
      p.pipelines.register(
        BackendFactory<LivePipelineHost>(
          spec,
          () => hosts[spec.id] = FakeLivePipelineHost(
            spec == BackendCatalog.portablePipeline
                ? PipelineTopology.portable
                : PipelineTopology.nativeMacos,
          ),
        ),
      );
    }
    assets = FakeSpeechAssetSupport();
    p.speechAssets = assets;
    return p;
  }

  Future<(LiveController, _Models)> controller(
    OsVersion version, {
    String language = 'en',
    bool instant = false,
  }) async {
    final p = platform(version);
    final models = _Models(probes, instant: instant);
    final live =
        LiveController(
            repository: LiveRepository(db),
            platform: p,
            flushInterval: const Duration(milliseconds: 20),
          )
          ..panelText = _Text()
          ..modelText = _ModelText()
          ..models = models
          ..requestBuilder = () =>
              LiveRequest(source: AudioSourceKind.systemAudio, language: language);
    await live.init();
    await live.showPanel(const CaptionStyle(), const {'start': 'Start'});
    return (live, models);
  }

  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));
  List<FakeLiveSession> sessions() => [for (final h in hosts.values) ...h.sessions];

  setUp(() => db = TinglangDatabase.memory());
  tearDown(() => db.close());

  group('macOS 14.2 (sherpa-onnx only)', () {
    test('without a model, pressing start asks for the download and records nothing', () async {
      final (live, models) = await controller(const OsVersion(14, 2));
      addTearDown(live.dispose);
      expect(overlay.states.last.canStart, isTrue, reason: 'start leads to the download');

      overlay.emit(const OverlayActionRequested(OverlayAction.toggle));
      await settle();
      expect(live.status, LiveStatus.idle);
      expect(sessions(), isEmpty, reason: 'no capture before the model is here');
      expect(models.downloads, isEmpty, reason: 'nothing is downloaded without consent');
      final need = live.setupNeed as ModelDownloadNeeded;
      expect(need.model.id, 'sherpa.xasr_zh_en_480');
      final state = overlay.states.last;
      expect(state.phase, OverlayPhase.needsSetup);
      expect(state.message, 'sherpa.xasr_zh_en_480 needs 135 MB');
      expect(state.action, OverlayAction.install);
      expect(state.actionLabel, 'Download 135 MB');

      // A direct start (⌘⇧T racing the panel) must not record either.
      await live.start(live.requestBuilder!());
      expect(sessions(), isEmpty);
    });

    test('download shows progress, then captions start on the portable pipeline', () async {
      final (live, models) = await controller(const OsVersion(14, 2));
      addTearDown(live.dispose);
      models.options = const SpeechOptions(latency: LatencyTier.fastest);
      overlay.emit(const OverlayActionRequested(OverlayAction.toggle));
      await settle();
      overlay.emit(const OverlayActionRequested(OverlayAction.install));
      await settle();
      expect(models.downloads, ['sherpa.xasr_zh_en_480']);
      models.progress(.42);
      await settle();
      final downloading = overlay.states.last;
      expect(downloading.phase, OverlayPhase.preparing);
      expect(downloading.progress, .42);
      expect(downloading.message, 'sherpa.xasr_zh_en_480 42%');
      expect(downloading.action, OverlayAction.cancel);

      models.finish();
      await settle();
      expect(live.status, LiveStatus.running);
      final session = sessions().single;
      expect(session.topology, PipelineTopology.portable);
      expect(session.config.asrBackendId, 'sherpa.xasr_zh_en_480');
      expect(session.config.speech.latency, LatencyTier.fastest);
      await live.stop();
    });

    test('cancel stops the download and keeps asking; nothing starts', () async {
      final (live, models) = await controller(const OsVersion(14, 2));
      addTearDown(live.dispose);
      overlay.emit(const OverlayActionRequested(OverlayAction.toggle));
      await settle();
      overlay.emit(const OverlayActionRequested(OverlayAction.install));
      await settle();
      overlay.emit(const OverlayActionRequested(OverlayAction.cancel));
      await settle();
      expect(models.cancels, ['sherpa.xasr_zh_en_480']);
      expect(live.error, isNull, reason: 'a cancel is not a failure');
      expect(live.setupNeed, isA<ModelDownloadNeeded>());
      expect(overlay.states.last.phase, OverlayPhase.needsSetup);
      expect(sessions(), isEmpty);
    });

    test('a chosen model is downloaded rather than replaced by another', () async {
      final (live, models) = await controller(const OsVersion(14, 2), instant: true);
      addTearDown(live.dispose);
      probes.current = probes.current.copyWith(
        installedAssets: SpeechModels.xasrStreaming.requiredAssets,
      );
      models.chosen[SpeechUse.live] = SpeechModels.smallEnglishStreaming.id;
      await live.toggle();
      expect((live.setupNeed as ModelDownloadNeeded).model.id, 'sherpa.zipformer_en_small');
      expect(sessions(), isEmpty);
    });

    test('an English-only model refuses Chinese before recording', () async {
      final (live, models) = await controller(const OsVersion(14, 2), language: 'zh-Hans');
      addTearDown(live.dispose);
      probes.current = probes.current.copyWith(
        installedAssets: SpeechModels.mediumEnglishStreaming.requiredAssets,
      );
      models.chosen[SpeechUse.live] = SpeechModels.mediumEnglishStreaming.id;
      await live.toggle();
      expect(live.setupNeed, isA<ModelLanguageUnsupported>());
      expect(overlay.states.last.action, OverlayAction.openSettings);
      expect(sessions(), isEmpty);
    });
  });

  group('macOS 26 (Apple engines)', () {
    test('a missing accent asset is asked for, then Apple Speech starts with it', () async {
      final (live, models) = await controller(const OsVersion(26));
      addTearDown(live.dispose);
      models.options = const SpeechOptions(locale: 'en-GB', latency: LatencyTier.powerSaver);
      await live.toggle();
      final need = live.setupNeed as SpeechModelNeeded;
      expect(need.locale, 'en-GB');
      expect(need.engine, SpeechEngine.appleSpeech);
      expect(sessions(), isEmpty);
      expect(assets.installs, isEmpty, reason: 'no OS download without the button');

      overlay.emit(const OverlayActionRequested(OverlayAction.install));
      await settle();
      assets.installs.single.emitProgress(.5);
      await settle();
      expect(overlay.states.last.progress, .5);
      assets.installs.single.finish();
      await settle();
      final session = sessions().single;
      expect(session.topology, PipelineTopology.nativeMacos);
      expect(session.config.asrBackendId, 'speech_transcriber');
      expect(session.config.speech.locale, 'en-GB');
      expect(session.config.speech.latency, LatencyTier.powerSaver);
      await live.stop();
    });

    test('Dictation with hints runs in the native pipeline once its asset is there', () async {
      final (live, models) = await controller(const OsVersion(26));
      addTearDown(live.dispose);
      models.chosen[SpeechUse.live] = SpeechModels.appleDictation.id;
      models.options = const SpeechOptions(
        locale: 'en-US',
        dictation: DictationHints(farField: true),
      );
      assets.installed.add(FakeSpeechAssetSupport.key('en-US', SpeechEngine.appleDictation));
      await live.toggle();
      final session = sessions().single;
      expect(session.config.asrBackendId, 'dictation_transcriber');
      expect(session.config.speech.dictation.farField, isTrue);
      await live.stop();
    });

    test('a downloaded sherpa model can be chosen on 26 too', () async {
      final (live, models) = await controller(const OsVersion(26));
      addTearDown(live.dispose);
      probes.current = probes.current.copyWith(
        installedAssets: SpeechModels.xasrStreaming.requiredAssets,
      );
      models.chosen[SpeechUse.live] = SpeechModels.xasrStreaming.id;
      await live.toggle();
      expect(sessions().single.topology, PipelineTopology.portable);
      await live.stop();
    });

    test('cancelling the OS download keeps the request and starts nothing', () async {
      final (live, _) = await controller(const OsVersion(26));
      addTearDown(live.dispose);
      await live.toggle();
      overlay.emit(const OverlayActionRequested(OverlayAction.install));
      await settle();
      overlay.emit(const OverlayActionRequested(OverlayAction.cancel));
      await settle();
      expect(assets.installs.single.cancelled, isTrue);
      expect(live.error, isNull);
      expect(live.setupNeed, isA<SpeechModelNeeded>());
      expect(sessions(), isEmpty);
    });
  });

  group('choosing how to recognise speech', () {
    test('first start with nothing ready asks for a choice instead of a download', () async {
      final (live, models) = await controller(const OsVersion(14, 2));
      addTearDown(live.dispose);
      models.chosenSetup = false;
      overlay.emit(const OverlayActionRequested(OverlayAction.toggle));
      await settle();
      expect(live.setupNeed, const RecognizerChoiceNeeded());
      expect(isSpeechSettingsNeed(live.setupNeed), isTrue);
      final state = overlay.states.last;
      expect(state.phase, OverlayPhase.needsSetup);
      expect(state.message, 'Choose a recogniser');
      expect(state.action, OverlayAction.openSettings);
      expect(models.downloads, isEmpty);
      expect(sessions(), isEmpty);

      // Once chosen, the model download is offered as before.
      models.chosenSetup = true;
      overlay.emit(const OverlayActionRequested(OverlayAction.toggle));
      await settle();
      expect(live.setupNeed, isA<ModelDownloadNeeded>());
    });

    test('macOS 26: Apple speech that is installed starts at once, even at first start', () async {
      final (live, models) = await controller(const OsVersion(26));
      addTearDown(live.dispose);
      models.chosenSetup = false;
      assets.installed.add(FakeSpeechAssetSupport.key('en-US', SpeechEngine.appleSpeech));
      overlay.emit(const OverlayActionRequested(OverlayAction.toggle));
      await settle();
      expect(live.setupNeed, isNull);
      expect(live.status, LiveStatus.running);
      await live.stop();
    });

    test('macOS 26: a missing Apple model at first start asks for a choice', () async {
      final (live, models) = await controller(const OsVersion(26));
      addTearDown(live.dispose);
      models.chosenSetup = false;
      overlay.emit(const OverlayActionRequested(OverlayAction.toggle));
      await settle();
      expect(live.setupNeed, const RecognizerChoiceNeeded());
      expect(assets.installs, isEmpty);
    });

    test('cloud chosen without a key never falls back to a model on this Mac', () async {
      final (live, models) = await controller(const OsVersion(26));
      addTearDown(live.dispose);
      assets.installed.add(FakeSpeechAssetSupport.key('en-US', SpeechEngine.appleSpeech));
      models.chosen[SpeechUse.live] = 'cloud.soniox';
      models.cloudMissing = true;
      overlay.emit(const OverlayActionRequested(OverlayAction.toggle));
      await settle();
      expect(live.setupNeed, const CloudSetupNeeded('cloud.soniox'));
      expect(overlay.states.last.message, 'No key for cloud.soniox');
      expect(overlay.states.last.action, OverlayAction.openSettings);
      expect(sessions(), isEmpty);

      // Saved key but not enabled by the app: still refused.
      models.cloudMissing = false;
      overlay.emit(const OverlayActionRequested(OverlayAction.toggle));
      await settle();
      expect(live.setupNeed, isA<CloudSetupNeeded>());
      expect(sessions(), isEmpty);
    });

    test('an enabled cloud service runs in the portable pipeline and is labelled', () async {
      final (live, models) = await controller(const OsVersion(26));
      addTearDown(live.dispose);
      models.chosen[SpeechUse.live] = 'cloud.soniox';
      current.enabledCloudBackends = {'cloud.soniox'};
      overlay.emit(const OverlayActionRequested(OverlayAction.toggle));
      await settle();
      expect(live.status, LiveStatus.running);
      final session = sessions().single;
      expect(session.topology, PipelineTopology.portable);
      expect(session.config.asrBackendId, 'cloud.soniox');
      expect(overlay.states.last.message, 'Cloud · cloud.soniox');

      // The service refuses the key: captions stop and say why.
      session.emitIssue(
        const RecognizerFailed(
          AsrFailure(AsrFailureReason.unauthorized, 'bad key', backendId: 'cloud.soniox'),
        ),
      );
      await settle();
      expect(live.status, LiveStatus.idle);
      expect(live.error, 'Failed: unauthorized');
      expect(overlay.states.last.phase, OverlayPhase.error);
    });

    test('a cloud service that cannot recognise the language says so', () async {
      final (live, models) = await controller(const OsVersion(26), language: 'ko');
      addTearDown(live.dispose);
      models.chosen[SpeechUse.live] = 'cloud.soniox';
      current.enabledCloudBackends = {'cloud.soniox'};
      overlay.emit(const OverlayActionRequested(OverlayAction.toggle));
      await settle();
      expect(live.setupNeed, isA<CloudLanguageUnsupported>());
      expect(overlay.states.last.message, 'cloud.soniox cannot do ko');
      expect(sessions(), isEmpty);
    });
  });
}

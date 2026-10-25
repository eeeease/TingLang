import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:tinglang_native/tinglang_native.dart';

import '../core/dictation.dart';
import '../core/live_repository.dart';
import 'speech_model_service.dart';

enum LiveStatus { idle, starting, running, stopping }

/// One caption row. Rows notify individually so a partial update repaints
/// one line, not the whole list.
class LiveLine extends ChangeNotifier {
  LiveLine(this.segmentId, this.text, this.startMs);
  final String segmentId;
  String text;
  final int startMs;
  String? translation;
  bool isFinal = false;

  void _update({String? text, String? translation, bool? isFinal}) {
    if (text != null) this.text = text;
    if (translation != null) this.translation = translation;
    if (isFinal != null) this.isFinal = isFinal;
    notifyListeners();
  }
}

/// What the user picked for the next live session.
@immutable
class LiveRequest {
  const LiveRequest({
    required this.source,
    required this.language,
    this.translateTo,
    this.showOverlay = true,
    this.overlayStyle = const CaptionStyle(),
    this.overlayStrings = const {},
    this.recordAudio = false,
  });
  final AudioSourceKind source;

  /// Learning language code (`en`, `zh-Hans`, …).
  final String language;

  /// Native language code; null or equal to [language] means no translation.
  final String? translateTo;
  final bool showOverlay;
  final CaptionStyle overlayStyle;
  final Map<String, String> overlayStrings;

  /// Keep an .m4a of the captured audio so the session can be replayed and
  /// practised (always on for the microphone; opt-in for system audio).
  final bool recordAudio;
}

/// Something the user must confirm before live captions can start or
/// translate (both are OS downloads, so Tinglang asks first).
sealed class LiveSetupNeed {
  const LiveSetupNeed();
}

/// macOS must download its speech model for [locale] first.
final class SpeechModelNeeded extends LiveSetupNeed {
  const SpeechModelNeeded(this.language, {this.locale, this.engine = SpeechEngine.appleSpeech});
  final String language;

  /// The recognition locale (an accent such as `en-GB`); null derives it
  /// from [language].
  final String? locale;
  final SpeechEngine engine;

  @override
  bool operator ==(Object other) =>
      other is SpeechModelNeeded &&
      other.language == language &&
      other.locale == locale &&
      other.engine == engine;

  @override
  int get hashCode => Object.hash(language, locale, engine);
}

/// A model Tinglang downloads (sherpa-onnx) must be on disk first. Captions
/// never start without it; the panel names the size and asks.
final class ModelDownloadNeeded extends LiveSetupNeed {
  const ModelDownloadNeeded(this.model, this.bytes);
  final SpeechModel model;
  final int bytes;

  @override
  bool operator ==(Object other) =>
      other is ModelDownloadNeeded && other.model.id == model.id && other.bytes == bytes;

  @override
  int get hashCode => Object.hash(model.id, bytes);
}

/// The chosen model does not recognise the learning language.
final class ModelLanguageUnsupported extends LiveSetupNeed {
  const ModelLanguageUnsupported(this.model, this.language);
  final SpeechModel model;
  final String language;
}

/// First start: no recogniser is ready and the user has not said how
/// speech should be recognised yet (a model on this Mac, which needs a
/// download, or a cloud service). Settings → Speech asks.
final class RecognizerChoiceNeeded extends LiveSetupNeed {
  const RecognizerChoiceNeeded();
  @override
  bool operator ==(Object other) => other is RecognizerChoiceNeeded;
  @override
  int get hashCode => (RecognizerChoiceNeeded).hashCode;
}

/// Cloud recognition is chosen, but the service [backendId] has no saved
/// credentials (or no service is chosen yet: null).
final class CloudSetupNeeded extends LiveSetupNeed {
  const CloudSetupNeeded(this.backendId);
  final String? backendId;
  @override
  bool operator ==(Object other) => other is CloudSetupNeeded && other.backendId == backendId;
  @override
  int get hashCode => Object.hash(CloudSetupNeeded, backendId);
}

/// The chosen cloud service does not recognise the learning language.
final class CloudLanguageUnsupported extends LiveSetupNeed {
  const CloudLanguageUnsupported(this.backendId, this.language);
  final String backendId;
  final String language;
}

/// Needs that are settled in Settings → Speech, not by a download.
bool isSpeechSettingsNeed(LiveSetupNeed? need) =>
    need is RecognizerChoiceNeeded ||
    need is CloudSetupNeeded ||
    need is CloudLanguageUnsupported ||
    need is ModelLanguageUnsupported;

/// Messages about speech models, localised by the app (kept apart from
/// [LivePanelText], which the panel's own code implements).
abstract interface class LiveModelText {
  String modelName(SpeechModel model);

  /// "[name] needs a one-time download of [size] before captions can start."
  String modelNeeded(String name, String size);

  /// Button label naming the size.
  String downloadSize(String size);
  String downloading(String name, int percent);
  String languageUnsupported(String name, String language);
  String get cancel;
  String get openSettings;
  String size(int bytes);

  /// "Choose how to recognise speech first" (first start, nothing ready).
  String get chooseRecognizer;

  /// Cloud recognition is on but [service] (null: none chosen) has no key.
  String cloudNotSetUp(String? service);
  String cloudLanguageUnsupported(String service, String language);

  /// A recogniser stopped for good: why, in the user's words.
  String recognizerFailed(AsrFailure failure);

  /// The name of the cloud service behind backend [backendId].
  String cloudServiceName(String backendId);

  /// "Cloud · [service]", shown while a cloud service recognises.
  String cloudLabel(String backendId);
}

final class TranslationPackNeeded extends LiveSetupNeed {
  const TranslationPackNeeded(this.pair);
  final LanguagePair pair;
}

/// Sentences the floating panel shows, localised by the app.
abstract interface class LivePanelText {
  String get preparing;
  String get downloading;
  String speechModelNeeded(String language);

  /// Captions run untranslated until the pack is installed.
  String translationPackNeeded(String source, String target);

  /// System audio arrived silent, so capture moved to screen recording.
  String get silentSystemAudio;
  String get screenRecordingCapture;
  String get download;
  String get retry;
  String get saved;
  String summary(Duration length, int words);
  String failed(String detail);
  String unavailable(String reason);
  String importing(int count);
}

/// Han characters count one each; other scripts count runs of letters.
final _wordPattern = RegExp(
  r"\p{Script=Han}|[A-Za-z0-9\u00C0-\u024F][A-Za-z0-9\u00C0-\u024F'’-]*",
  unicode: true,
);
int countWords(String text) => _wordPattern.allMatches(text).length;

/// Runs one live caption session at a time through the platform's preferred
/// pipeline, keeps the visible lines, and saves finals and translations.
class LiveController extends ChangeNotifier {
  LiveController({
    required this.repository,
    TinglangPlatform? platform,
    this.libraryRoot,
    this.flushInterval = const Duration(seconds: 2),
  }) : _platform = platform ?? (TinglangPlatform.isInstalled ? TinglangPlatform.instance : null);

  static const toggleHotkeyId = 'live.toggle';
  static const maxLines = 500;

  final LiveRepository repository;
  final TinglangPlatform? _platform;

  /// Library folder; recordings go to `media/live-<id>.m4a` inside it.
  final Directory? libraryRoot;
  String? _recordingRelPath;
  int _lastFinalEndMs = 0;
  final Duration flushInterval;

  LiveStatus status = LiveStatus.idle;
  String? error;
  String? unavailableReason;
  LiveSetupNeed? setupNeed;
  final issues = <AudioCaptureIssue>[];
  final lines = <LiveLine>[];
  final level = ValueNotifier<double>(0);

  /// CPU of the app process (ms per second; 1000 = one core).
  final cpuMsPerSecond = ValueNotifier<double?>(null);
  String? currentSessionId;

  /// The recogniser of the running session (a `cloud.<id>` backend sends
  /// audio off this Mac; the panel says so).
  String? currentBackendId;

  /// Builds the request for [toggle] (and the ⌘⇧T shortcut) from the
  /// user's saved choices; set by the app shell.
  LiveRequest Function()? requestBuilder;

  /// The chosen speech model, latency tier and accent, and model downloads.
  SpeechModelSource? models;
  LiveModelText? modelText;

  /// 0…1 while a model or speech asset downloads for [setupNeed].
  double? installProgress;
  SpeechAssetInstall? _assetInstall;
  final _hosts = <String, LivePipelineHost>{};
  bool _canStart = false;

  LivePipelineHost? _host;
  LiveSession? _session;
  final _subs = <StreamSubscription<Object?>>[];
  final _index = <String, LiveLine>{};
  final _savedSegments = <String>{};
  final _pendingFinals = <NewSegment>[];
  final _pendingTranslations =
      <({String segmentId, String target, String text, String provider})>[];
  Timer? _flushTimer;
  Future<void> _flushTail = Future.value();
  StreamSubscription<String>? _hotkeySub;
  String? _language;

  CaptionOverlay? _overlay;

  // The floating panel: the app's front door. It shows the captions and
  // this controller's state; what its other buttons do is up to the app.
  CaptionStyle panelStyle = const CaptionStyle();
  Map<String, String> _panelStrings = const {};
  bool panelVisible = false;
  LivePanelText? panelText;
  int dueCount = 0, newRecordings = 0;

  /// Panel requests that are not about captions (windows, imports, saving
  /// the look); set by the app.
  Future<void> Function(OverlayEvent event)? onPanelEvent;
  StreamSubscription<OverlayEvent>? _panelSub;
  OverlayState? _lastPanelState;
  DateTime? _startedAt;
  ({String sessionId, Duration length, int words})? _saved;
  String? _notice;
  Timer? _transientTimer;
  bool _installing = false;

  /// Shows the panel with [style] and [strings] (labels by key).
  Future<void> showPanel(CaptionStyle style, Map<String, String> strings) async {
    panelStyle = style;
    _panelStrings = strings;
    final overlay = await _overlayBackend();
    if (overlay == null) return;
    _panelSub ??= overlay.events.listen(
      (event) => unawaited(_onPanelEvent(event)),
      onError: (Object e) => debugPrint('Panel event failed: $e'),
    );
    await overlay.show(style, strings: strings);
    panelVisible = true;
    _lastPanelState = null;
    _syncPanel();
  }

  Future<void> hidePanel() async {
    panelVisible = false;
    await (await _overlayBackend())?.hide();
  }

  /// Keeps the look and labels while the panel stays hidden, so starting
  /// captions can still bring it up.
  void preparePanel(CaptionStyle style, Map<String, String> strings) {
    panelStyle = style;
    _panelStrings = strings;
  }

  /// A new look from settings or from the panel's own controls.
  Future<void> applyPanelStyle(CaptionStyle style) =>
      panelVisible ? showPanel(style, _panelStrings) : Future(() => panelStyle = style);

  Future<void> resetOverlay() async => (await _overlayBackend())?.resetPosition();

  void setPanelCounts({int? due, int? recordings}) {
    if (due != null) dueCount = due;
    if (recordings != null) newRecordings = recordings;
    _syncPanel();
  }

  /// A short message on the panel (for example after files were dropped).
  void showNotice(String message) {
    _clearTransient();
    _notice = message;
    _transientTimer = Timer(const Duration(seconds: 6), () {
      _notice = null;
      notifyListeners();
    });
    notifyListeners();
  }

  void _clearTransient() {
    _transientTimer?.cancel();
    _saved = null;
    _notice = null;
  }

  @override
  void notifyListeners() {
    super.notifyListeners();
    _syncPanel();
  }

  /// Pushes the panel state when it changed (lines alone never change it).
  void _syncPanel() {
    final overlay = _overlay;
    if (overlay == null || !panelVisible) return;
    final state = _panelState();
    if (state == _lastPanelState) return;
    _lastPanelState = state;
    unawaited(
      overlay.setState(state).catchError((Object e) => debugPrint('Panel update failed: $e')),
    );
  }

  OverlayState _panelState() {
    final text = panelText;
    final source = requestBuilder?.call().source ?? AudioSourceKind.systemAudio;
    final canStart = _canStart;
    OverlayState state(
      OverlayPhase phase, {
      String? message,
      OverlayAction? action,
      String? actionLabel,
      double? progress,
      String? sessionId,
      String? summary,
    }) => OverlayState(
      phase: phase,
      source: source,
      startedAt: phase == OverlayPhase.listening || phase == OverlayPhase.stopping
          ? _startedAt
          : null,
      message: message,
      action: action,
      actionLabel: actionLabel,
      progress: progress,
      dueCount: dueCount,
      newRecordings: newRecordings,
      sessionId: sessionId,
      summary: summary,
      canStart: canStart,
    );
    final need = setupNeed, saved = _saved;
    return switch (status) {
      LiveStatus.starting => state(OverlayPhase.preparing, message: text?.preparing),
      LiveStatus.running => state(OverlayPhase.listening, message: _listeningNotice(text)),
      LiveStatus.stopping => state(OverlayPhase.stopping),
      LiveStatus.idle when _installing => state(
        OverlayPhase.preparing,
        message: _downloadingMessage(text),
        progress: installProgress,
        action: modelText == null ? null : OverlayAction.cancel,
        actionLabel: modelText?.cancel,
      ),
      LiveStatus.idle when need is SpeechModelNeeded => state(
        OverlayPhase.needsSetup,
        message: text?.speechModelNeeded(need.locale ?? need.language),
        action: OverlayAction.install,
        actionLabel: text?.download,
      ),
      LiveStatus.idle when need is ModelDownloadNeeded => state(
        OverlayPhase.needsSetup,
        message: modelText?.modelNeeded(
          modelText!.modelName(need.model),
          modelText!.size(need.bytes),
        ),
        action: OverlayAction.install,
        actionLabel: modelText?.downloadSize(modelText!.size(need.bytes)) ?? text?.download,
      ),
      LiveStatus.idle when need is ModelLanguageUnsupported => state(
        OverlayPhase.needsSetup,
        message: modelText?.languageUnsupported(modelText!.modelName(need.model), need.language),
        action: OverlayAction.openSettings,
        actionLabel: modelText?.openSettings,
      ),
      LiveStatus.idle when need is RecognizerChoiceNeeded => state(
        OverlayPhase.needsSetup,
        message: modelText?.chooseRecognizer,
        action: OverlayAction.openSettings,
        actionLabel: modelText?.openSettings,
      ),
      LiveStatus.idle when need is CloudSetupNeeded => state(
        OverlayPhase.needsSetup,
        message: modelText?.cloudNotSetUp(
          need.backendId == null ? null : modelText!.cloudServiceName(need.backendId!),
        ),
        action: OverlayAction.openSettings,
        actionLabel: modelText?.openSettings,
      ),
      LiveStatus.idle when need is CloudLanguageUnsupported => state(
        OverlayPhase.needsSetup,
        message: modelText?.cloudLanguageUnsupported(
          modelText!.cloudServiceName(need.backendId),
          need.language,
        ),
        action: OverlayAction.openSettings,
        actionLabel: modelText?.openSettings,
      ),
      LiveStatus.idle when error != null => state(
        OverlayPhase.error,
        message: text?.failed(error!) ?? error,
        action: OverlayAction.retry,
        actionLabel: text?.retry,
      ),
      LiveStatus.idle when saved != null => state(
        OverlayPhase.saved,
        message: text?.saved,
        sessionId: saved.sessionId,
        summary: text?.summary(saved.length, saved.words),
      ),
      LiveStatus.idle when _notice != null => state(OverlayPhase.notice, message: _notice),
      // Not blocking: captions can start again without translation.
      LiveStatus.idle when need is TranslationPackNeeded => state(
        OverlayPhase.needsSetup,
        message: text?.translationPackNeeded(need.pair.source, need.pair.target),
        action: OverlayAction.install,
        actionLabel: text?.download,
      ),
      LiveStatus.idle => state(OverlayPhase.idle),
    };
  }

  String? _downloadingMessage(LivePanelText? text) {
    final names = modelText, need = setupNeed, progress = installProgress;
    if (names == null || need is! ModelDownloadNeeded) return text?.downloading;
    return names.downloading(names.modelName(need.model), ((progress ?? 0) * 100).round());
  }

  /// One line under the listening header: why capture moved to screen
  /// recording (macOS may ask for that permission), or why there is no
  /// translation yet.
  String? _listeningNotice(LivePanelText? text) {
    if (text == null) return null;
    final need = setupNeed;
    if (issues.any((i) => i is SilentTapDetected)) return text.silentSystemAudio;
    if (need is TranslationPackNeeded) {
      return text.translationPackNeeded(need.pair.source, need.pair.target);
    }
    if (issues.any((i) => i is CaptureDeviceChanged)) return text.screenRecordingCapture;
    // Audio leaves this Mac: say where, for as long as it does.
    final backend = currentBackendId, names = modelText;
    if (backend != null && BackendCatalog.isCloudAsr(backend) && names != null) {
      return names.cloudLabel(backend);
    }
    return null;
  }

  Future<void> _onPanelEvent(OverlayEvent event) async {
    switch (event) {
      case OverlayActionRequested(action: OverlayAction.toggle):
        _clearTransient();
        error = null;
        await toggle();
      case OverlayActionRequested(action: OverlayAction.retry):
        _clearTransient();
        error = null;
        notifyListeners();
        await toggle();
      case OverlayActionRequested(action: OverlayAction.install):
        // The button named the download (and its size): pressing it is the
        // user's consent.
        final need = setupNeed;
        if (need == null || _installing) return;
        _installing = true;
        installProgress = null;
        notifyListeners();
        var cancelled = false;
        try {
          await install(need);
        } catch (e) {
          cancelled = e is DownloadCancelled || '$e'.contains('Cancel');
          if (!cancelled) error = '$e';
        } finally {
          _installing = false;
          installProgress = null;
        }
        notifyListeners();
        // The model was blocking a start the user asked for; a translation
        // pack is fetched on its own.
        final blocking = need is SpeechModelNeeded || need is ModelDownloadNeeded;
        if (blocking && !cancelled && setupNeed == null && error == null) await toggle();
      case OverlayActionRequested(action: OverlayAction.cancel):
        await cancelInstall();
      default:
        await onPanelEvent?.call(event);
    }
  }

  Future<CaptionOverlay?> _overlayBackend() async {
    if (_overlay != null) return _overlay;
    final platform = _platform;
    if (platform == null) return null;
    final choice = platform.overlays.pick(await platform.probe());
    return _overlay = choice.hasSelection ? choice.create() : null;
  }

  bool get isActive => status == LiveStatus.running || status == LiveStatus.starting;

  /// Marks crashed sessions, picks the pipeline and registers ⌘⇧T.
  Future<void> init() async {
    await repository.markInterrupted();
    final platform = _platform;
    if (platform == null) {
      unavailableReason = 'Native platform is not installed';
      notifyListeners();
      return;
    }
    final probe = await platform.probe();
    final choice = platform.pipelines.pick(probe);
    if (choice.hasSelection) {
      _host = choice.create();
      _hosts[choice.id!] = _host!;
    }
    // A recogniser that only needs a download still lets the user press
    // start: the panel then asks for the download first.
    final asr = platform.liveAsr.pick(probe);
    final downloadable = asr.candidates.any(
      (c) => !c.factory.spec.cloud && c.availability is NeedsDownload,
    );
    _canStart = choice.hasSelection || downloadable;
    if (!_canStart) unavailableReason = '${choice.blocker}';
    final hotkeys = platform.hotkeys.pick(probe);
    if (hotkeys.hasSelection) {
      final keys = hotkeys.create();
      try {
        await keys.register(
          const HotkeyBinding(id: toggleHotkeyId, key: 'T', command: true, shift: true),
        );
        _hotkeySub = keys.pressed.where((id) => id == toggleHotkeyId).listen((_) => toggle());
      } catch (e) {
        debugPrint('Live shortcut unavailable: $e');
      }
    }
    notifyListeners();
  }

  /// Which recogniser and pipeline [request] runs on, or what must happen
  /// first. Never downloads anything.
  Future<({String asrId, LivePipelineHost? host, LiveSetupNeed? need})> _plan(
    LiveRequest request,
  ) async {
    final platform = _platform;
    const none = (asrId: '', host: null, need: null);
    if (platform == null) return none;
    final probe = await platform.probe();
    // Platforms without recogniser registrations run their only pipeline
    // with SpeechTranscriber.
    if (platform.liveAsr.all.isEmpty) {
      return (asrId: BackendCatalog.speechTranscriber.id, host: _host, need: null);
    }
    final preferred = models?.modelFor(SpeechUse.live);
    final choice = platform.liveAsr.pick(probe, preferred);
    // Cloud mode without saved credentials never falls back to a local
    // model (or the other way round) without the user knowing.
    if (models?.cloudNeedsSetup ?? false) {
      return (asrId: '', host: null, need: CloudSetupNeeded(preferred));
    }
    if (preferred != null && BackendCatalog.isCloudAsr(preferred) && !choice.usedPreference) {
      return (asrId: '', host: null, need: CloudSetupNeeded(preferred));
    }
    // An explicit choice that is only missing its files is downloaded, not
    // silently replaced by another model.
    final wanted = preferred == null ? null : SpeechModels.byId(preferred);
    if (wanted != null && !choice.usedPreference && choice.preferredAvailability is NeedsDownload) {
      return (asrId: '', host: null, need: _downloadNeed(wanted));
    }
    if (!choice.hasSelection) {
      for (final candidate in choice.candidates) {
        final model = SpeechModels.byId(candidate.factory.id);
        if (candidate.availability is NeedsDownload &&
            model != null &&
            !candidate.factory.spec.cloud) {
          return (asrId: '', host: null, need: _downloadNeed(model));
        }
      }
      return (asrId: '', host: null, need: null);
    }
    final asrId = choice.id!;
    final model = SpeechModels.byId(asrId);
    if (model != null && !model.languages.contains(_baseLanguage(request.language))) {
      return (asrId: asrId, host: null, need: ModelLanguageUnsupported(model, request.language));
    }
    if (BackendCatalog.isCloudAsr(asrId)) {
      final languages = platform.liveAsr.byId(asrId)!.create().languages;
      if (!languages.contains(baseLanguage(request.language))) {
        return (asrId: asrId, host: null, need: CloudLanguageUnsupported(asrId, request.language));
      }
    }
    final pipelineId = BackendCatalog.pipelineFor(asrId);
    var host = _hosts[pipelineId];
    if (host == null) {
      final factory = platform.pipelines.byId(pipelineId);
      if (factory != null && factory.availability(probe) is Available) {
        host = _hosts[pipelineId] = factory.create();
      }
    }
    return (asrId: asrId, host: host, need: null);
  }

  LiveSetupNeed _downloadNeed(SpeechModel model) =>
      ModelDownloadNeeded(model, models?.missingBytes(model) ?? model.downloadBytes);

  /// Checks downloads. Returns the first thing the user must approve, or
  /// null when captions can start (translation may still be missing;
  /// captions then run untranslated).
  Future<LiveSetupNeed?> checkSetup(LiveRequest request) async {
    final plan = await _plan(request);
    // The first time nothing is ready, ask how to recognise speech instead
    // of offering one particular download.
    final firstChoice = models != null && !models!.setupChosen;
    if (plan.need != null) {
      return firstChoice && plan.need is ModelDownloadNeeded
          ? const RecognizerChoiceNeeded()
          : plan.need;
    }
    if (plan.asrId.isEmpty && plan.host == null && firstChoice) {
      return const RecognizerChoiceNeeded();
    }
    final model = SpeechModels.byId(plan.asrId);
    final assets = _platform?.speechAssets;
    if (model != null && model.isApple && assets != null) {
      final locale = _speech(request).locale ?? defaultRecognitionLocale(request.language);
      if (await assets.status(locale, model.engine) == AssetState.downloadable) {
        return firstChoice
            ? const RecognizerChoiceNeeded()
            : SpeechModelNeeded(request.language, locale: locale, engine: model.engine);
      }
    }
    final host = plan.host;
    if (host is! LiveSetupSupport) return null;
    final setup = host as LiveSetupSupport;
    if (assets == null && plan.asrId == BackendCatalog.speechTranscriber.id) {
      final speech = await setup.speechAssets(request.language);
      if (speech == AssetState.downloadable) return SpeechModelNeeded(request.language);
    }
    final target = request.translateTo;
    if (target != null && target != request.language) {
      final pair = LanguagePair(_baseLanguage(request.language), target);
      if (await setup.translationPack(pair) == AssetState.downloadable) {
        return TranslationPackNeeded(pair);
      }
    }
    return null;
  }

  SpeechOptions _speech(LiveRequest request) =>
      models?.optionsFor(request.language) ?? const SpeechOptions();

  /// Stops a running session, or checks setup and starts a new one. A
  /// missing model is surfaced as [setupNeed] for the user to approve;
  /// recording never starts before the model is on this Mac.
  Future<void> toggle() async {
    if (isActive) return stop();
    _clearTransient();
    final build = requestBuilder;
    if (build == null || status != LiveStatus.idle || !_canStart || _installing) return;
    final request = build();
    final need = await checkSetup(request);
    if (need != null && need is! TranslationPackNeeded) {
      setupNeed = need;
      notifyListeners();
      return;
    }
    await start(request);
    if (need != null) {
      setupNeed = need;
      notifyListeners();
    }
  }

  /// Downloads what [need] names. Only called for a button the user pressed.
  Future<void> install(LiveSetupNeed need) async {
    final setup = _host;
    void progress(double value) {
      installProgress = value;
      notifyListeners();
    }

    switch (need) {
      case ModelDownloadNeeded(:final model):
        final source = models;
        if (source == null) return;
        await source.download(model, onProgress: progress);
      case SpeechModelNeeded(:final language, :final locale, :final engine):
        final assets = _platform?.speechAssets;
        if (assets != null) {
          final job = _assetInstall = assets.install(
            locale ?? defaultRecognitionLocale(language),
            engine,
          );
          final sub = job.progress.listen(progress);
          try {
            await job.done;
          } finally {
            await sub.cancel();
            _assetInstall = null;
          }
        } else if (setup is LiveSetupSupport) {
          await (setup as LiveSetupSupport).installSpeechAssets(language);
        }
      case TranslationPackNeeded(:final pair):
        if (setup is LiveSetupSupport) {
          await (setup as LiveSetupSupport).installTranslationPack(pair);
        }
      case ModelLanguageUnsupported() ||
          RecognizerChoiceNeeded() ||
          CloudSetupNeeded() ||
          CloudLanguageUnsupported():
        return;
    }
    if (setupNeed == need) setupNeed = null;
    notifyListeners();
  }

  /// Stops a download started from the panel; the need stays so the user
  /// can try again (partial files are kept and resumed).
  Future<void> cancelInstall() async {
    final need = setupNeed;
    if (need is ModelDownloadNeeded) await models?.cancelDownload(need.model);
    await _assetInstall?.cancel();
  }

  Future<void> start(LiveRequest request) async {
    if (status != LiveStatus.idle) return;
    final plan = await _plan(request);
    final host = plan.host;
    if (host == null || plan.need != null) {
      // [toggle] checks first; a direct call must not record without a model.
      if (plan.need != null) {
        setupNeed = plan.need;
        notifyListeners();
      }
      return;
    }
    status = LiveStatus.starting;
    error = null;
    issues.clear();
    setupNeed = null;
    notifyListeners();
    try {
      // Captions are drawn in the panel; bring it back if it was hidden.
      if (!panelVisible && _panelStrings.isNotEmpty) await showPanel(panelStyle, _panelStrings);
      final target = request.translateTo == request.language ? null : request.translateTo;
      String? recordPath;
      _recordingRelPath = null;
      _lastFinalEndMs = 0;
      final root = libraryRoot;
      if (request.recordAudio && root != null) {
        final relative = 'media/live-${DateTime.now().toUtc().microsecondsSinceEpoch}.m4a';
        recordPath = p.join(root.path, relative);
        await Directory(p.dirname(recordPath)).create(recursive: true);
        _recordingRelPath = relative;
      }
      final session = await host.start(
        LivePipelineConfig(
          source: request.source,
          asrBackendId: plan.asrId,
          language: request.language,
          translateTo: target,
          showOverlay: request.showOverlay,
          recordPath: recordPath,
          speech: _speech(request),
        ),
      );
      _session = session;
      currentSessionId = session.sessionId;
      currentBackendId = plan.asrId;
      _language = request.language;
      for (final line in lines) {
        line.dispose();
      }
      lines.clear();
      _index.clear();
      _savedSegments.clear();
      await repository.createSession(
        id: session.sessionId,
        origin: request.source == AudioSourceKind.microphone ? 'live_mic' : 'live_system',
        language: request.language,
        title: '',
        startedAt: DateTime.now().toUtc(),
      );
      _subs
        ..add(session.captions.listen(_onCaption))
        ..add(session.translations.listen(_onTranslation))
        ..add(session.issues.listen(_onIssue))
        ..add(session.stats.listen((s) => cpuMsPerSecond.value = s.cpuMsPerSecond));
      _subs.add(session.levels.listen((v) => level.value = v));
      _flushTimer = Timer.periodic(flushInterval, (_) => _flush());
      _startedAt = DateTime.now();
      status = LiveStatus.running;
    } catch (e) {
      error = e is AsrFailure ? modelText?.recognizerFailed(e) ?? e.message : '$e';
      status = LiveStatus.idle;
    }
    notifyListeners();
  }

  Future<void> stop() async {
    final session = _session;
    if (session == null || status != LiveStatus.running) return;
    status = LiveStatus.stopping;
    notifyListeners();
    try {
      await session.stop();
    } catch (e) {
      error = '$e';
    }
    for (final sub in _subs) {
      await sub.cancel();
    }
    _subs.clear();
    _flushTimer?.cancel();
    await _flush();
    await _flushTail;
    await _attachRecording(session.sessionId);
    await repository.endSession(
      session.sessionId,
      status: 'completed',
      endedAt: DateTime.now().toUtc(),
    );
    _session = null;
    currentBackendId = null;
    level.value = 0;
    final finals = lines.where((l) => l.isFinal).toList();
    if (finals.isNotEmpty) {
      _clearTransient();
      _saved = (
        sessionId: session.sessionId,
        length: DateTime.now().difference(_startedAt ?? DateTime.now()),
        words: finals.fold(0, (sum, line) => sum + countWords(line.text)),
      );
      _transientTimer = Timer(const Duration(seconds: 30), () {
        _saved = null;
        notifyListeners();
      });
    }
    _startedAt = null;
    status = LiveStatus.idle;
    notifyListeners();
  }

  /// Links the finished .m4a to the session; caption times are already
  /// offsets into it because Swift writes it on the recognizer's clock.
  Future<void> _attachRecording(String sessionId) async {
    final relative = _recordingRelPath, root = libraryRoot;
    _recordingRelPath = null;
    if (relative == null || root == null) return;
    final file = File(p.join(root.path, relative));
    if (!await file.exists() || await file.length() == 0) return;
    final mediaId = p.basenameWithoutExtension(relative);
    try {
      await repository.addMedia(
        id: mediaId,
        kind: 'audio',
        relPath: relative,
        durationMs: _lastFinalEndMs > 0 ? _lastFinalEndMs : null,
      );
      await repository.attachMedia(sessionId, mediaId);
    } catch (e) {
      error = 'Could not save the recording: $e';
    }
  }

  void _onCaption(AsrEvent event) {
    switch (event) {
      case AsrPartial(:final segmentId, :final text, :final startMs):
        final line = _index[segmentId];
        if (line == null) {
          _append(LiveLine(segmentId, text, startMs));
        } else if (!line.isFinal) {
          line._update(text: text);
        }
      case AsrFinal(:final segmentId, :final text, :final startMs, :final endMs, :final words):
        final line = _index[segmentId];
        if (line == null) {
          _append(LiveLine(segmentId, text, startMs)..isFinal = true);
        } else {
          line._update(text: text, isFinal: true);
        }
        _pendingFinals.add((
          id: segmentId,
          startMs: startMs,
          endMs: endMs,
          text: text,
          language: _language,
          wordsJson: wordsToJson(words),
        ));
        if (endMs > _lastFinalEndMs) _lastFinalEndMs = endMs;
      case AsrGap():
        break;
    }
  }

  void _onTranslation(SegmentTranslation t) {
    _index[t.segmentId]?._update(translation: t.text);
    _pendingTranslations.add((
      segmentId: t.segmentId,
      target: t.pair.target,
      text: t.text,
      provider: BackendCatalog.appleTranslation.id,
    ));
  }

  void _onIssue(AudioCaptureIssue issue) {
    if (issue is RecognizerFailed) {
      // A refused key or used-up quota: captions cannot go on.
      final failure = issue.failure;
      issues.add(issue);
      unawaited(
        stop().then((_) {
          error = modelText?.recognizerFailed(failure) ?? failure.message;
          notifyListeners();
        }),
      );
      return;
    }
    if (issue is TranslationPackMissing) {
      final parts = issue.pair.split('→');
      if (parts.length == 2) setupNeed = TranslationPackNeeded(LanguagePair(parts[0], parts[1]));
    }
    issues.add(issue);
    notifyListeners();
  }

  void _append(LiveLine line) {
    lines.add(line);
    _index[line.segmentId] = line;
    if (lines.length > maxLines) {
      final removed = lines.removeAt(0);
      _index.remove(removed.segmentId);
      removed.dispose();
    }
    notifyListeners();
  }

  /// Serialised so a slow write never overlaps the next batch.
  Future<void> _flush() {
    final sessionId = currentSessionId;
    if (sessionId == null || (_pendingFinals.isEmpty && _pendingTranslations.isEmpty)) {
      return _flushTail;
    }
    final finals = [..._pendingFinals];
    _pendingFinals.clear();
    _savedSegments.addAll(finals.map((f) => f.id));
    // A translation can only be written once its segment row exists.
    final ready = _pendingTranslations.where((t) => _savedSegments.contains(t.segmentId)).toList();
    _pendingTranslations.removeWhere(ready.contains);
    return _flushTail = _flushTail.then((_) async {
      try {
        await repository.addSegments(sessionId, finals);
        await repository.addTranslations(ready);
      } catch (e) {
        error = 'Could not save captions: $e';
        notifyListeners();
      }
    });
  }

  static String _baseLanguage(String code) =>
      code == 'zh-Hans' || code == 'zh-Hant' ? code : code.split('-').first;

  @override
  void dispose() {
    _hotkeySub?.cancel();
    _panelSub?.cancel();
    _transientTimer?.cancel();
    _flushTimer?.cancel();
    for (final sub in _subs) {
      sub.cancel();
    }
    for (final line in lines) {
      line.dispose();
    }
    level.dispose();
    cpuMsPerSecond.dispose();
    super.dispose();
  }
}

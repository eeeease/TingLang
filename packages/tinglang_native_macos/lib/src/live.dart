import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:tinglang_platform_interface/tinglang_platform_interface.dart';

import 'host_api.g.dart';

/// Shared broadcast view of the native event channel. The channel is opened
/// once and kept, so sessions, hotkeys and the overlay all read the same
/// stream.
final class MacEvents {
  MacEvents([Stream<LiveEvent> Function()? source]) : _source = source ?? liveEvents;
  final Stream<LiveEvent> Function() _source;
  Stream<LiveEvent>? _stream;
  Stream<LiveEvent> get stream => _stream ??= _source().asBroadcastStream();
}

/// Maps a learning-language code to a SpeechTranscriber locale (kept for
/// callers of this package; see [defaultRecognitionLocale]).
String recognitionLocale(String language) => defaultRecognitionLocale(language);

/// The accent chosen in Settings ([SpeechOptions.locale], e.g. `en-GB`) when
/// set, else the default locale for [language].
String speechLocale(String language, SpeechOptions speech) {
  final override = speech.locale;
  return override == null || override.isEmpty ? defaultRecognitionLocale(language) : override;
}

/// Pigeon name of an Apple [SpeechEngine]; other engines do not run in Swift.
String appleEngineName(SpeechEngine engine) => switch (engine) {
  SpeechEngine.appleSpeech => 'appleSpeech',
  SpeechEngine.appleDictation => 'appleDictation',
  _ => throw ArgumentError.value(engine, 'engine', 'not an Apple recogniser'),
};

/// The Apple engine behind a live or file backend id.
SpeechEngine appleEngineFor(String backendId) =>
    backendId == BackendCatalog.dictationTranscriber.id ||
        backendId == BackendCatalog.dictationFile.id
    ? SpeechEngine.appleDictation
    : SpeechEngine.appleSpeech;

/// What Swift needs to pick and tune the recogniser.
SpeechConfig speechConfig(SpeechEngine engine, String language, SpeechOptions speech) =>
    SpeechConfig(
      engine: appleEngineName(engine),
      latency: speech.latency.name,
      locale: speechLocale(language, speech),
      farField: speech.dictation.farField,
      shortForm: speech.dictation.shortForm,
    );

/// Topology A: capture, SpeechTranscriber or DictationTranscriber, Apple
/// Translation and the caption panel all run in Swift; Dart sends control
/// calls and receives events.
final class MacNativePipelineHost implements LivePipelineHost, LiveSetupSupport {
  MacNativePipelineHost(this._api, this._events);
  final TinglangHostApi _api;
  final MacEvents _events;

  @override
  PipelineTopology get topology => PipelineTopology.nativeMacos;

  @override
  Future<LiveSession> start(LivePipelineConfig config) async {
    final id = await _api.startLiveWith(
      LiveStartRequest(
        source: config.source == AudioSourceKind.microphone ? 'microphone' : 'system',
        locale: speechLocale(config.language, config.speech),
        targetLanguage: config.translateTo,
        showOverlay: config.showOverlay,
        recordPath: config.recordPath,
      ),
      speechConfig(appleEngineFor(config.asrBackendId), config.language, config.speech),
    );
    return MacLiveSession(id, _api, _events.stream, config);
  }

  @override
  Future<AssetState> speechAssets(String locale) async =>
      _asset(await _api.speechAssetStatus(recognitionLocale(locale)));

  @override
  Future<void> installSpeechAssets(String locale) =>
      _api.installSpeechAssets(recognitionLocale(locale));

  @override
  Future<AssetState> translationPack(LanguagePair pair) async =>
      _asset(await _api.translationStatus(pair.source, pair.target));

  @override
  Future<void> installTranslationPack(LanguagePair pair) =>
      _api.prepareTranslation(pair.source, pair.target);

  static AssetState _asset(AssetStatus status) => switch (status) {
    AssetStatus.installed => AssetState.installed,
    AssetStatus.supported => AssetState.downloadable,
    AssetStatus.unsupported => AssetState.unsupported,
  };
}

final class MacLiveSession implements LiveSession {
  MacLiveSession(this.sessionId, this._api, Stream<LiveEvent> events, LivePipelineConfig config)
    : _pair = config.translateTo == null
          ? null
          : LanguagePair(config.language, config.translateTo!) {
    _sub = events.where((e) => e.sessionId == sessionId).listen(_route);
  }

  @override
  final String sessionId;
  final TinglangHostApi _api;
  final LanguagePair? _pair;
  late final StreamSubscription<LiveEvent> _sub;
  final _captions = StreamController<AsrEvent>.broadcast();
  final _translations = StreamController<SegmentTranslation>.broadcast();
  final _stats = StreamController<AsrStats>.broadcast();
  final _issues = StreamController<AudioCaptureIssue>.broadcast();
  final _levels = StreamController<double>.broadcast();
  final _ended = Completer<void>();

  @override
  PipelineTopology get topology => PipelineTopology.nativeMacos;
  @override
  Stream<AsrEvent> get captions => _captions.stream;
  @override
  Stream<SegmentTranslation> get translations => _translations.stream;
  @override
  Stream<AsrStats> get stats => _stats.stream;
  @override
  Stream<AudioCaptureIssue> get issues => _issues.stream;

  @override
  Stream<double> get levels => _levels.stream;

  /// Completes when the native engine reports it has stopped.
  Future<void> get ended => _ended.future;

  void _route(LiveEvent e) {
    switch (e.kind) {
      case 'partial':
        _captions.add(AsrPartial(e.segmentId!, text: e.text ?? '', startMs: e.startMs ?? 0));
      case 'final':
        _captions.add(
          AsrFinal(
            e.segmentId!,
            text: e.text ?? '',
            startMs: e.startMs ?? 0,
            endMs: e.endMs ?? e.startMs ?? 0,
            words: parseWords(e.wordsJson),
          ),
        );
      case 'translation':
        final pair = _pair;
        if (pair != null) _translations.add(SegmentTranslation(e.segmentId!, pair, e.text ?? ''));
      case 'stats':
        _stats.add(
          AsrStats(
            realTimeFactor: 0,
            queuedMs: e.queuedMs ?? 0,
            cpuMsPerSecond: e.cpuMsPerSecond ?? 0,
          ),
        );
      case 'level':
        _levels.add(e.level ?? 0);
      case 'issue':
        _issues.add(issueFromCode(e.code ?? '', e.message));
      case 'stopped':
        if (e.message != null) _issues.add(CaptureFailed(e.message!));
        _close();
    }
  }

  @override
  Future<void> stop() async {
    await _api.stopLive();
    await ended.timeout(const Duration(seconds: 5), onTimeout: _close);
  }

  void _close() {
    if (_ended.isCompleted) return;
    _ended.complete();
    _sub.cancel();
    for (final c in [_captions, _translations, _stats, _issues, _levels]) {
      c.close();
    }
  }
}

/// Native issue codes → typed issues (unknown codes surface as failures).
AudioCaptureIssue issueFromCode(String code, String? message) => switch (code) {
  'silent_tap' => const SilentTapDetected(Duration(seconds: 4)),
  'fallback_screencapture' => const CaptureDeviceChanged('ScreenCaptureKit'),
  'translation_pack_missing' => TranslationPackMissing(message ?? ''),
  'frames_dropped' => FramesDropped(int.tryParse(message ?? '') ?? 0),
  _ => CaptureFailed(message == null ? code : '$code: $message'),
};

/// The floating capture panel drawn by Swift. In topology A captions are fed
/// natively; other topologies feed them through [pushTail].
final class MacCaptionOverlay implements CaptionOverlay {
  MacCaptionOverlay(this._api, this._events);
  final TinglangHostApi _api;
  final MacEvents _events;

  @override
  Future<void> show(CaptionStyle style, {required Map<String, String> strings}) async {
    await _api.configureOverlay(overlayConfig(style, strings));
    await _api.setOverlayVisible(true);
  }

  @override
  Future<void> hide() => _api.setOverlayVisible(false);

  @override
  Future<void> resetPosition() => _api.resetOverlayPosition();

  /// Replaces the panel's captions; an empty list clears them. With
  /// [awaitingTranslation] final lines without a translation show the
  /// "translating" placeholder.
  @override
  Future<void> pushTail(List<CaptionLine> lines, {bool awaitingTranslation = false}) async {
    if (lines.length > CaptionOverlay.maxTailLines) {
      throw ArgumentError.value(lines.length, 'lines', 'at most ${CaptionOverlay.maxTailLines}');
    }
    await _api.showCaptionLines([
      for (final line in lines)
        CaptionLineMessage(
          segmentId: line.segmentId,
          text: line.text,
          translation: line.translation,
          isFinal: line.isFinal,
        ),
    ], awaitingTranslation);
  }

  @override
  Future<void> setState(OverlayState state) => _api.updatePanel(panelState(state));

  @override
  Stream<OverlayEvent> get events =>
      _events.stream.map(overlayEvent).where((e) => e != null).cast();
}

OverlayConfig overlayConfig(CaptionStyle style, Map<String, String> strings) => OverlayConfig(
  fontSize: style.fontSize,
  backgroundOpacity: style.backgroundOpacity,
  showTranslation: style.showTranslation,
  clickThrough: style.clickThrough,
  translatingLabel: strings['translating'] ?? '…',
  mode: style.mode.name,
  background: style.background.name,
  backgroundColor: style.backgroundColor,
  textColor: style.textColor,
  translationColor: style.translationColor,
  accentColor: style.accentColor,
  fontWeight: style.fontWeight,
  outline: style.outline,
  maxLines: style.maxLines,
  alignment: style.alignment.name,
  strings: strings,
  layout: style.layout.name,
  scrollbackLines: style.scrollback,
);

PanelState panelState(OverlayState state) => PanelState(
  phase: state.phase.name,
  source: state.source == AudioSourceKind.microphone ? 'microphone' : 'system',
  startedAtMs: state.startedAt?.millisecondsSinceEpoch,
  message: state.message,
  action: state.action?.name,
  actionLabel: state.actionLabel,
  progress: state.progress,
  dueCount: state.dueCount,
  newRecordings: state.newRecordings,
  sessionId: state.sessionId,
  summary: state.summary,
  canStart: state.canStart,
);

/// Panel button presses, dropped files and looks chosen on the panel. Actions
/// the app does not know (from a newer native side) are ignored.
OverlayEvent? overlayEvent(LiveEvent event) => switch (event.kind) {
  'panel' => switch (OverlayAction.values.asNameMap()[event.code]) {
    final action? => OverlayActionRequested(action, event.message),
    null => null,
  },
  'drop' => OverlayFilesDropped([
    for (final path in (event.message ?? '').split('\n'))
      if (path.isNotEmpty) path,
  ], mainWindow: event.code == 'window'),
  'panelStyle' => _styleEvent(event.message),
  _ => null,
};

OverlayEvent? _styleEvent(String? json) {
  if (json == null) return null;
  try {
    final map = jsonDecode(json) as Map<String, Object?>;
    T? pick<T extends Enum>(List<T> values, Object? name) => values.asNameMap()[name];
    return OverlayStyleChanged(
      CaptionStyle(
        fontSize: (map['fontSize'] as num?)?.toDouble() ?? 22,
        backgroundOpacity: (map['backgroundOpacity'] as num?)?.toDouble() ?? .78,
        showTranslation: map['showTranslation'] as bool? ?? true,
        clickThrough: map['clickThrough'] as bool? ?? false,
        mode: pick(CaptionMode.values, map['mode']) ?? CaptionMode.card,
        background: pick(CaptionBackground.values, map['background']) ?? CaptionBackground.glass,
        backgroundColor: (map['backgroundColor'] as num?)?.toInt() ?? 0xFF1E1E1D,
        textColor: (map['textColor'] as num?)?.toInt() ?? 0xFFF7F7F6,
        translationColor: (map['translationColor'] as num?)?.toInt() ?? 0xFFB9B9B5,
        accentColor: (map['accentColor'] as num?)?.toInt() ?? 0xFFFF8A4C,
        fontWeight: (map['fontWeight'] as num?)?.toInt() ?? 500,
        outline: map['outline'] as bool? ?? true,
        maxLines: (map['maxLines'] as num?)?.toInt() ?? 2,
        alignment: pick(CaptionAlignment.values, map['alignment']) ?? CaptionAlignment.center,
        layout: pick(CaptionLayout.values, map['layout']) ?? CaptionLayout.stacked,
        scrollback: (map['scrollbackLines'] as num?)?.toInt() ?? CaptionStyle.defaultScrollback,
      ),
    );
  } on Object {
    return null;
  }
}

/// The Flutter main window, hidden at launch and opened from the panel.
final class MacDesktopShell implements DesktopShell {
  MacDesktopShell(this._api, [MacEvents? events]) : _events = events;
  final TinglangHostApi _api;
  final MacEvents? _events;

  @override
  Future<List<String>> takeOpenedFiles() => _api.takeOpenedFiles();

  @override
  Stream<void> get filesOpened =>
      _events?.stream.where((e) => e.kind == 'filesOpened') ?? const Stream.empty();

  @override
  Future<void> showMainWindow() => _api.showMainWindow();

  @override
  Future<void> ready() => _api.appReady();

  @override
  Future<void> setAppearance(ShellAppearance appearance) =>
      _api.setWindowAppearance(appearance.name);

  @override
  Future<void> openSystemSettings(SystemSettingsPane pane) => _api.openSystemSettings(pane.name);

  @override
  Future<void> openUrl(Uri url) => _api.openUrl(url.toString());
}

/// ASWebAuthenticationSession through the plugin.
final class MacWebAuthenticator implements WebAuthenticator {
  MacWebAuthenticator(this._api);
  final TinglangHostApi _api;

  @override
  Future<Uri> authenticate(Uri url, {required String callbackScheme}) async {
    try {
      return Uri.parse(await _api.authenticate(url.toString(), callbackScheme));
    } on PlatformException catch (e) {
      if (e.code == 'canceled') throw const WebAuthCanceled();
      rethrow;
    }
  }
}

final class MacGlobalHotkeys implements GlobalHotkeys {
  MacGlobalHotkeys(this._api, this._events);
  final TinglangHostApi _api;
  final MacEvents _events;

  @override
  Future<void> register(HotkeyBinding binding) async {
    final ok = await _api.registerHotkey(
      binding.id,
      binding.key,
      binding.command,
      binding.shift,
      binding.option,
      binding.control,
    );
    if (!ok) throw StateError('Shortcut ${binding.key} is unavailable or already taken');
  }

  @override
  Future<void> unregister(String id) => _api.unregisterHotkey(id);

  @override
  Stream<String> get pressed =>
      _events.stream.where((e) => e.kind == 'hotkey' && e.code != null).map((e) => e.code!);
}

/// Parses `[{"w":"word","s":ms,"e":ms}]`; malformed input yields null rather
/// than invented timings.
List<TimedWord>? parseWords(String? json) {
  if (json == null) return null;
  try {
    final list = jsonDecode(json) as List<Object?>;
    return [
      for (final item in list.cast<Map<String, Object?>>())
        TimedWord(item['w']! as String, (item['s']! as num).toInt(), (item['e']! as num).toInt()),
    ];
  } on Object {
    return null;
  }
}

/// File transcription through Apple SpeechAnalyzer (macOS 26+): decode with
/// AVAssetReader, recognise with word timings (SpeechTranscriber, or
/// DictationTranscriber for `dictation_file`), translate sentence by
/// sentence.
final class MacFileTranscriber implements FileTranscriber {
  MacFileTranscriber(this._api, this._events, {this.engine = SpeechEngine.appleSpeech})
    : assert(engine == SpeechEngine.appleSpeech || engine == SpeechEngine.appleDictation);
  final TinglangHostApi _api;
  final MacEvents _events;
  final SpeechEngine engine;

  /// `speech_analyzer_file` or `dictation_file`.
  String get backendId => engine == SpeechEngine.appleDictation
      ? BackendCatalog.dictationFile.id
      : BackendCatalog.speechAnalyzerFile.id;
  static var _counter = 0;

  @override
  Set<String> get languages => const {'en', 'zh-Hans', 'zh-Hant', 'ja', 'ko', 'es', 'fr', 'de'};

  @override
  Future<MediaInfo> inspect(String path) async {
    final facts = await _api.inspectMedia(path);
    return MediaInfo(
      durationMs: facts.durationMs,
      hasVideo: facts.hasVideo,
      hasAudio: facts.hasAudio,
    );
  }

  @override
  TranscriptionJob transcribe(String path, FileTranscriptionOptions options) {
    final jobId = 'file-${DateTime.now().microsecondsSinceEpoch}-${_counter++}';
    return _MacTranscriptionJob(jobId, _api, _events.stream, path, options, engine, backendId);
  }
}

final class _MacTranscriptionJob implements TranscriptionJob {
  _MacTranscriptionJob(
    this._jobId,
    this._api,
    Stream<LiveEvent> events,
    String path,
    FileTranscriptionOptions options,
    SpeechEngine engine,
    this._backendId,
  ) {
    _sub = events.where((e) => e.sessionId == _jobId).listen(_route);
    _api
        .transcribeFileWith(
          FileTranscribeRequest(
            jobId: _jobId,
            path: path,
            locale: speechLocale(options.language, options.speech),
            targetLanguage: options.translateTo,
          ),
          speechConfig(engine, options.language, options.speech),
        )
        .then(
          (_) => _finish(null, options.language),
          onError: (Object e) => _finish(e, options.language),
        );
  }

  final String _jobId;
  final TinglangHostApi _api;
  final String _backendId;
  late final StreamSubscription<LiveEvent> _sub;
  final _progress = StreamController<double>.broadcast();
  final _segments = StreamController<TranscriptSegment>.broadcast();
  final _translations = StreamController<(int, String)>.broadcast();
  final _result = Completer<FileTranscript>();
  final _collected = <TranscriptSegment>[];
  final _indexById = <String, int>{};
  final _translated = <int, String>{};

  @override
  Stream<double> get progress => _progress.stream;
  @override
  Stream<TranscriptSegment> get segments => _segments.stream;
  @override
  Stream<(int, String)> get translations => _translations.stream;
  @override
  Future<FileTranscript> get result => _result.future;

  void _route(LiveEvent e) {
    switch (e.kind) {
      case 'progress':
        _progress.add(e.level ?? 0);
      case 'final':
        final segment = TranscriptSegment(
          startMs: e.startMs ?? 0,
          endMs: e.endMs ?? e.startMs ?? 0,
          text: e.text ?? '',
          words: parseWords(e.wordsJson),
        );
        _indexById[e.segmentId!] = _collected.length;
        _collected.add(segment);
        _segments.add(segment);
      case 'translation':
        final index = _indexById[e.segmentId];
        if (index != null) {
          _translated[index] = e.text ?? '';
          _translations.add((index, e.text ?? ''));
        }
    }
  }

  Future<void> _finish(Object? error, String language) async {
    // Events are delivered on the platform thread before the reply; let the
    // last ones drain into the streams first.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await _sub.cancel();
    await Future.wait([_progress.close(), _segments.close(), _translations.close()]);
    if (_result.isCompleted) return;
    if (error != null) {
      _result.completeError(error);
    } else {
      _result.complete(
        FileTranscript(
          language: language,
          backendId: _backendId,
          segments: [
            for (var i = 0; i < _collected.length; i++)
              TranscriptSegment(
                startMs: _collected[i].startMs,
                endMs: _collected[i].endMs,
                text: _collected[i].text,
                words: _collected[i].words,
                translation: _translated[i],
              ),
          ],
        ),
      );
    }
  }

  @override
  Future<void> cancel() => _api.cancelTranscription(_jobId);
}

/// API keys in the macOS Keychain (never in SQLite, logs or exports).
final class MacKeychainSecretStore implements SecretStore {
  MacKeychainSecretStore(this._api);
  final TinglangHostApi _api;
  @override
  Future<String?> read(String key) => _api.secretRead(key);
  @override
  Future<void> write(String key, String value) => _api.secretWrite(key, value);
  @override
  Future<void> delete(String key) => _api.secretDelete(key);
}

/// iCloud Drive download states and requests (FileManager ubiquitous items).
final class MacCloudDrive implements CloudDriveSupport {
  MacCloudDrive(this._api);
  final TinglangHostApi _api;

  @override
  Future<Map<String, CloudItemState>> itemStates(List<String> paths) async {
    if (paths.isEmpty) return const {};
    final states = await _api.cloudItemStates(paths);
    return {
      for (final (index, path) in paths.indexed)
        path: index < states.length ? cloudItemState(states[index]) : CloudItemState.local,
    };
  }

  @override
  Future<void> download(List<String> paths) =>
      paths.isEmpty ? Future.value() : _api.cloudDownload(paths);

  @override
  Future<String?> machineId() => _api.machineIdentifier();
}

/// Swift's state names; anything unknown is read like a local file.
CloudItemState cloudItemState(String name) => switch (name) {
  'current' => CloudItemState.current,
  'outdated' => CloudItemState.outdated,
  'notDownloaded' => CloudItemState.notDownloaded,
  'missing' => CloudItemState.missing,
  _ => CloudItemState.local,
};

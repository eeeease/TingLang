import 'dart:async';
import 'dart:typed_data';

import 'backend_registry.dart';
import 'capabilities/audio_capture.dart';
import 'capabilities/cloud_drive.dart';
import 'capabilities/live_pipeline.dart';
import 'capabilities/media.dart';
import 'capabilities/services.dart';
import 'capabilities/streaming_asr.dart';
import 'capabilities/voice_memos.dart';
import 'catalog.dart';
import 'platform_probe.dart';
import 'speech_models.dart';
import 'tinglang_platform.dart';

/// Ready-made probes for common hosts.
abstract final class FakeProbes {
  static PlatformProbe macos(
    OsVersion version, {
    Map<PermissionKind, PermissionState> permissions = const {},
    Set<String> installedAssets = const {},
    Set<String> enabledCloudBackends = const {},
  }) => PlatformProbe(
    os: HostOs.macos,
    version: version,
    arch: CpuArch.arm64,
    hasNeuralEngine: true,
    permissions: permissions,
    installedAssets: installedAssets,
    enabledCloudBackends: enabledCloudBackends,
  );

  static PlatformProbe windows(
    int build, {
    Map<PermissionKind, PermissionState> permissions = const {},
    Set<String> installedAssets = const {},
    Set<String> enabledCloudBackends = const {},
  }) => PlatformProbe(
    os: HostOs.windows,
    version: OsVersion(10, 0, build),
    arch: CpuArch.x64,
    permissions: permissions,
    installedAssets: installedAssets,
    enabledCloudBackends: enabledCloudBackends,
  );

  static const allGranted = {
    PermissionKind.systemAudio: PermissionState.granted,
    PermissionKind.microphone: PermissionState.granted,
    PermissionKind.screenCapture: PermissionState.granted,
  };
}

final class FakeProbeSource implements PlatformProbeSource {
  FakeProbeSource(this.current);
  PlatformProbe current;
  @override
  Future<PlatformProbe> probe() async => current;
}

final class FakeNativeAudioSource implements NativeAudioSource {
  FakeNativeAudioSource(this.kind, this.format);
  @override
  final AudioSourceKind kind;
  @override
  final AudioFormat format;
  final _blocks = StreamController<Float32List>.broadcast();
  final _levels = StreamController<AudioLevel>.broadcast();
  final _issues = StreamController<AudioCaptureIssue>.broadcast();
  bool _running = false, _closed = false;

  @override
  NativePcmRing? get ring => null;
  @override
  Stream<Float32List> get debugBlocks => _blocks.stream;
  @override
  Stream<AudioLevel> get levels => _levels.stream;
  @override
  Stream<AudioCaptureIssue> get issues => _issues.stream;
  @override
  bool get isRunning => _running;

  /// Test hook: deliver one PCM block as if captured.
  void emit(Float32List block) {
    if (_running) _blocks.add(block);
  }

  void emitIssue(AudioCaptureIssue issue) => _issues.add(issue);

  @override
  Future<void> start() async {
    if (_closed) throw StateError('Source is closed.');
    _running = true;
  }

  @override
  Future<void> stop() async => _running = false;

  @override
  Future<void> close() async {
    _running = false;
    _closed = true;
    await Future.wait([_blocks.close(), _levels.close(), _issues.close()]);
  }
}

final class FakeAudioCaptureBackend implements AudioCaptureBackend {
  FakeAudioCaptureBackend(this.kind);
  @override
  final AudioSourceKind kind;
  final opened = <FakeNativeAudioSource>[];
  @override
  Future<NativeAudioSource> open(AudioCaptureRequest request) async {
    final source = FakeNativeAudioSource(kind, request.format);
    opened.add(source);
    return source;
  }
}

/// Emits one partial per accepted block and a final on [stop].
final class FakeAsrSession implements AsrSession {
  final _events = StreamController<AsrEvent>.broadcast();
  final _stats = StreamController<AsrStats>.broadcast();
  int _samples = 0, _sampleRate = 16000;

  @override
  Stream<AsrEvent> get events => _events.stream;
  @override
  Stream<AsrStats> get stats => _stats.stream;

  int get _elapsedMs => _samples * 1000 ~/ _sampleRate;

  @override
  void acceptWaveform(Float32List samples, int sampleRate) {
    _sampleRate = sampleRate;
    _samples += samples.length;
    _events.add(AsrPartial('seg-0', text: 'partial@$_elapsedMs', startMs: 0));
  }

  @override
  Future<void> stop() async {
    _events.add(AsrFinal('seg-0', text: 'final', startMs: 0, endMs: _elapsedMs));
    await Future.wait([_events.close(), _stats.close()]);
  }
}

final class FakeStreamingAsrBackend implements StreamingAsrBackend {
  FakeStreamingAsrBackend({this.languages = const {'en', 'zh'}});
  @override
  final Set<String> languages;
  @override
  Future<AsrSession> start(AsrSessionConfig config) async => FakeAsrSession();
}

final class FakeMediaDecoder implements MediaDecoder {
  @override
  Future<MediaInfo> inspect(String path) async =>
      const MediaInfo(durationMs: 1000, hasVideo: false, hasAudio: true);
  @override
  Stream<Float32List> decodePcm(String path, {int sampleRate = 16000}) =>
      Stream.value(Float32List(sampleRate));
  @override
  Future<String> decodeToFile(String path, {int sampleRate = 16000}) async => '$path.f32';
}

/// Emits its segments (and `[target] text` translations when asked) on the
/// next microtask, then completes.
final class FakeTranscriptionJob implements TranscriptionJob {
  FakeTranscriptionJob(this._result, {String? translateTo}) {
    scheduleMicrotask(() async {
      _progress.add(.5);
      for (final s in _result.segments) {
        _segments.add(s);
      }
      if (translateTo != null) {
        for (var i = 0; i < _result.segments.length; i++) {
          _translations.add((i, '[$translateTo] ${_result.segments[i].text}'));
        }
      }
      _progress.add(1);
      await Future.wait([_progress.close(), _segments.close(), _translations.close()]);
      if (!_done.isCompleted) _done.complete(_result);
    });
  }
  final FileTranscript _result;
  final _progress = StreamController<double>.broadcast();
  final _segments = StreamController<TranscriptSegment>.broadcast();
  final _translations = StreamController<(int, String)>.broadcast();
  final _done = Completer<FileTranscript>();
  bool cancelled = false;
  @override
  Stream<double> get progress => _progress.stream;
  @override
  Stream<TranscriptSegment> get segments => _segments.stream;
  @override
  Stream<(int, String)> get translations => _translations.stream;
  @override
  Future<FileTranscript> get result => _done.future;
  @override
  Future<void> cancel() async => cancelled = true;
}

final class FakeFileTranscriber implements FileTranscriber {
  FakeFileTranscriber(
    this.backendId, {
    this.output = const [TranscriptSegment(startMs: 0, endMs: 1000, text: 'fake')],
    this.info = const MediaInfo(durationMs: 1000, hasVideo: false, hasAudio: true),
  });
  final String backendId;
  final List<TranscriptSegment> output;
  final MediaInfo info;
  final jobs = <FakeTranscriptionJob>[];
  @override
  Set<String> get languages => const {'en', 'zh'};
  @override
  Future<MediaInfo> inspect(String path) async => info;
  @override
  TranscriptionJob transcribe(String path, FileTranscriptionOptions options) {
    final job = FakeTranscriptionJob(
      FileTranscript(language: options.language, backendId: backendId, segments: output),
      translateTo: options.translateTo,
    );
    jobs.add(job);
    return job;
  }
}

/// Returns `[target] text` so tests can see which pair was used.
final class FakeTranslator implements TranslatorBackend {
  FakeTranslator({Set<LanguagePair>? pairs})
    : pairs = pairs ?? {const LanguagePair('en', 'zh-Hans')};
  @override
  final Set<LanguagePair> pairs;
  @override
  Future<List<String>> translate(List<String> texts, LanguagePair pair) async => [
    for (final text in texts) '[${pair.target}] $text',
  ];
}

/// Records pushes and enforces the overlay contract; [emit] plays the user.
final class FakeCaptionOverlay implements CaptionOverlay {
  final pushes = <List<CaptionLine>>[];
  final states = <OverlayState>[];
  bool visible = false;
  CaptionStyle? style;
  Map<String, String> strings = const {};
  final _events = StreamController<OverlayEvent>.broadcast();
  @override
  Stream<OverlayEvent> get events => _events.stream;
  void emit(OverlayEvent event) => _events.add(event);
  @override
  Future<void> show(CaptionStyle style, {required Map<String, String> strings}) async {
    visible = true;
    this.style = style;
    this.strings = strings;
  }

  @override
  Future<void> setState(OverlayState state) async => states.add(state);
  @override
  Future<void> hide() async => visible = false;
  int resets = 0;
  @override
  Future<void> resetPosition() async => resets++;
  @override
  Future<void> pushTail(List<CaptionLine> lines) async {
    if (lines.length > CaptionOverlay.maxTailLines) {
      throw ArgumentError(
        'Overlay tail is limited to '
        '${CaptionOverlay.maxTailLines} lines.',
      );
    }
    pushes.add(List.unmodifiable(lines));
  }
}

/// Records what the app asked of its windows.
final class FakeDesktopShell implements DesktopShell {
  int mainWindowShown = 0;
  bool isReady = false;
  ShellAppearance? appearance;
  final openedSettings = <SystemSettingsPane>[];
  @override
  Future<void> showMainWindow() async => mainWindowShown++;
  @override
  Future<void> ready() async => isReady = true;
  @override
  Future<void> setAppearance(ShellAppearance appearance) async => this.appearance = appearance;
  @override
  Future<void> openSystemSettings(SystemSettingsPane pane) async => openedSettings.add(pane);
  final openedUrls = <Uri>[];
  @override
  Future<void> openUrl(Uri url) async => openedUrls.add(url);

  /// Files "opened in Finder" that the app has not taken yet.
  final pendingFiles = <String>[];
  final _filesOpened = StreamController<void>.broadcast();

  /// Simulates opening [paths] with the app (a double-click in Finder).
  void openFiles(List<String> paths) {
    pendingFiles.addAll(paths);
    _filesOpened.add(null);
  }

  @override
  Future<List<String>> takeOpenedFiles() async {
    final taken = [...pendingFiles];
    pendingFiles.clear();
    return taken;
  }

  @override
  Stream<void> get filesOpened => _filesOpened.stream;
}

/// iCloud Drive in memory: [states] says which paths are not downloaded yet
/// (anything missing from it is [CloudItemState.local]); [download] records
/// requests and, with [downloadAtOnce], marks them current.
final class FakeCloudDrive implements CloudDriveSupport {
  FakeCloudDrive({this.machine = 'fake-machine', this.downloadAtOnce = false});
  final String? machine;
  final bool downloadAtOnce;
  final states = <String, CloudItemState>{};
  final requested = <String>[];

  @override
  Future<Map<String, CloudItemState>> itemStates(List<String> paths) async => {
    for (final path in paths) path: states[path] ?? CloudItemState.local,
  };

  @override
  Future<void> download(List<String> paths) async {
    requested.addAll(paths);
    if (downloadAtOnce) {
      for (final path in paths) {
        states[path] = CloudItemState.current;
      }
    }
  }

  @override
  Future<String?> machineId() async => machine;
}

/// Answers sign-in requests with [respond]; by default the user cancels.
final class FakeWebAuthenticator implements WebAuthenticator {
  FakeWebAuthenticator([Uri Function(Uri url)? respond]) : respond = respond ?? _cancel;
  Uri Function(Uri url) respond;
  final opened = <Uri>[];
  final schemes = <String>[];
  static Uri _cancel(Uri _) => throw const WebAuthCanceled();
  @override
  Future<Uri> authenticate(Uri url, {required String callbackScheme}) async {
    opened.add(url);
    schemes.add(callbackScheme);
    return respond(url);
  }
}

/// A Voice Memos library held in memory; set [problem] to fail listing.
final class FakeVoiceMemoLibrary implements VoiceMemoLibrary {
  FakeVoiceMemoLibrary([List<VoiceMemo> memos = const []]) : memos = [...memos];
  final List<VoiceMemo> memos;
  VoiceMemoProblem? problem;
  int listed = 0;

  @override
  Future<List<VoiceMemo>> list() async {
    listed++;
    final failure = problem;
    if (failure != null) throw VoiceMemoFailure(failure);
    return [...memos]..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
  }
}

final class FakeGlobalHotkeys implements GlobalHotkeys {
  final bindings = <String, HotkeyBinding>{};
  final _pressed = StreamController<String>.broadcast();
  @override
  Stream<String> get pressed => _pressed.stream;
  @override
  Future<void> register(HotkeyBinding binding) async => bindings[binding.id] = binding;
  @override
  Future<void> unregister(String id) async => bindings.remove(id);
  void press(String id) => _pressed.add(id);
}

final class InMemorySecretStore implements SecretStore {
  final _values = <String, String>{};
  @override
  Future<String?> read(String key) async => _values[key];
  @override
  Future<void> write(String key, String value) async => _values[key] = value;
  @override
  Future<void> delete(String key) async => _values.remove(key);
}

final class FakeYouTubePlayer implements YouTubePlayer {
  final _events = StreamController<YouTubeEvent>.broadcast();
  String? videoId;
  int positionMs = 0;
  bool playing = false;
  @override
  Stream<YouTubeEvent> get events => _events.stream;
  @override
  Future<void> load(String videoId, {int startMs = 0}) async {
    this.videoId = videoId;
    positionMs = startMs;
  }

  @override
  Future<void> play() async => playing = true;
  @override
  Future<void> pause() async => playing = false;
  @override
  Future<void> seek(int ms) async => positionMs = ms;
  @override
  Future<void> dispose() => _events.close();
  void block(int code) => _events.add(YouTubeEmbedBlocked(code));
}

/// Scriptable live session: tests push captions, translations, issues and
/// levels through the `emit*` helpers.
final class FakeLiveSession implements LiveSession {
  FakeLiveSession(this.topology, this.config, {this.sessionId = 'fake-session'});
  @override
  final PipelineTopology topology;
  final LivePipelineConfig config;
  @override
  final String sessionId;
  final _captions = StreamController<AsrEvent>.broadcast();
  final _translations = StreamController<SegmentTranslation>.broadcast();
  final _stats = StreamController<AsrStats>.broadcast();
  final _issues = StreamController<AudioCaptureIssue>.broadcast();
  final _levels = StreamController<double>.broadcast();
  bool stopped = false;

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

  void emitCaption(AsrEvent event) => _captions.add(event);
  void emitTranslation(SegmentTranslation t) => _translations.add(t);
  void emitIssue(AudioCaptureIssue issue) => _issues.add(issue);
  void emitLevel(double level) => _levels.add(level);

  @override
  Future<void> stop() async {
    stopped = true;
    for (final c in [_captions, _translations, _stats, _issues, _levels]) {
      await c.close();
    }
  }
}

final class FakeLivePipelineHost implements LivePipelineHost {
  FakeLivePipelineHost(this.topology);
  @override
  final PipelineTopology topology;
  final sessions = <FakeLiveSession>[];
  @override
  Future<LiveSession> start(LivePipelineConfig config) async {
    final session = FakeLiveSession(topology, config, sessionId: 'fake-session-${sessions.length}');
    sessions.add(session);
    return session;
  }
}

/// A [TinglangPlatform] whose registries hold a fake for every
/// [BackendCatalog] spec, so `pick` follows the production gates.
TinglangPlatform fakeTinglangPlatform(PlatformProbe probe) {
  final platform = TinglangPlatform(probeSource: FakeProbeSource(probe));
  void each<T extends Object>(BackendRegistry<T> registry, T Function(BackendSpec spec) create) {
    for (final spec in BackendCatalog.byCapability[registry.capability]!) {
      registry.register(BackendFactory<T>(spec, () => create(spec)));
    }
  }

  each(platform.systemAudio, (_) => FakeAudioCaptureBackend(AudioSourceKind.systemAudio));
  each(platform.microphone, (_) => FakeAudioCaptureBackend(AudioSourceKind.microphone));
  each(platform.liveAsr, (_) => FakeStreamingAsrBackend());
  each(platform.fileAsr, (spec) => FakeFileTranscriber(spec.id));
  each(platform.decoders, (_) => FakeMediaDecoder());
  each(platform.translators, (_) => FakeTranslator());
  each(platform.overlays, (_) => FakeCaptionOverlay());
  each(platform.hotkeys, (_) => FakeGlobalHotkeys());
  each(platform.shells, (_) => FakeDesktopShell());
  each(platform.secrets, (_) => InMemorySecretStore());
  each(platform.youtube, (_) => FakeYouTubePlayer());
  each(platform.voiceMemos, (_) => FakeVoiceMemoLibrary());
  each(platform.webAuth, (_) => FakeWebAuthenticator());
  each(platform.cloudDrive, (_) => FakeCloudDrive());
  each(
    platform.pipelines,
    (spec) => FakeLivePipelineHost(switch (spec.id) {
      'pipeline.native_macos' => PipelineTopology.nativeMacos,
      'pipeline.cloud' => PipelineTopology.cloud,
      _ => PipelineTopology.portable,
    }),
  );
  return platform;
}

/// OS speech assets in memory: [installed] holds `engine/locale` keys;
/// installs finish when [finish] is called (or at once with [autoFinish]).
final class FakeSpeechAssetSupport implements SpeechAssetSupport {
  FakeSpeechAssetSupport({Set<String>? installed, this.autoFinish = false})
    : installed = installed ?? {};
  final Set<String> installed;
  final bool autoFinish;
  final installs = <FakeSpeechAssetInstall>[];

  static String key(String locale, SpeechEngine engine) => '${engine.name}/$locale';

  @override
  Future<AssetState> status(String locale, SpeechEngine engine) async =>
      installed.contains(key(locale, engine)) ? AssetState.installed : AssetState.downloadable;

  @override
  SpeechAssetInstall install(String locale, SpeechEngine engine) {
    final job = FakeSpeechAssetInstall(() => installed.add(key(locale, engine)));
    installs.add(job);
    if (autoFinish) scheduleMicrotask(job.finish);
    return job;
  }

  @override
  Future<bool> release(String locale, SpeechEngine engine) async =>
      installed.remove(key(locale, engine));

  @override
  Future<SpeechLocaleInventory> inventory() async => SpeechLocaleInventory(
    speechSupported: englishAccents.toSet(),
    dictationSupported: englishAccents.toSet(),
    speechInstalled: {
      for (final k in installed)
        if (k.startsWith('appleSpeech/')) k.split('/').last,
    },
    dictationInstalled: {
      for (final k in installed)
        if (k.startsWith('appleDictation/')) k.split('/').last,
    },
  );
}

final class FakeSpeechAssetInstall implements SpeechAssetInstall {
  FakeSpeechAssetInstall(this._onDone);
  final void Function() _onDone;
  final _progress = StreamController<double>.broadcast();
  final _done = Completer<void>();
  bool cancelled = false;

  void emitProgress(double value) => _progress.add(value);

  void finish() {
    if (_done.isCompleted) return;
    _onDone();
    _progress.close();
    _done.complete();
  }

  @override
  Stream<double> get progress => _progress.stream;
  @override
  Future<void> get done => _done.future;
  @override
  Future<void> cancel() async {
    cancelled = true;
    if (_done.isCompleted) return;
    _progress.close();
    _done.completeError(StateError('Cancelled'));
  }
}

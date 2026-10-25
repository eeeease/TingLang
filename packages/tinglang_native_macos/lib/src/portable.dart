import 'dart:async';
import 'dart:typed_data';

import 'package:tinglang_platform_interface/tinglang_platform_interface.dart';

import 'host_api.g.dart';
import 'live.dart';

/// `speech_transcriber` / `dictation_transcriber` in the `liveAsr` registry.
/// Apple recognisers run inside `pipeline.native_macos`; this entry only
/// lets selection and Settings see them.
final class MacAppleRecognizer implements StreamingAsrBackend {
  const MacAppleRecognizer(this.engine);
  final SpeechEngine engine;

  @override
  Set<String> get languages => switch (engine) {
    SpeechEngine.appleDictation => SpeechModels.appleDictation.languages,
    _ => SpeechModels.appleSpeech.languages,
  };

  @override
  Future<AsrSession> start(AsrSessionConfig config) =>
      throw UnsupportedError('runs inside ${BackendCatalog.nativeMacosPipeline.id}');
}

/// Core Audio tap (ScreenCaptureKit fallback) or AVAudioEngine microphone
/// into a native PCM ring for the portable pipeline (macOS 14.2+).
final class MacAudioCaptureBackend implements AudioCaptureBackend {
  MacAudioCaptureBackend(this._api, this._events, this.kind);
  final TinglangHostApi _api;
  final MacEvents _events;

  @override
  final AudioSourceKind kind;

  /// The source is opened (and capture starts) on [NativeAudioSource.start].
  /// [recordPath] also writes AAC (.m4a) on the ring's clock.
  @override
  Future<MacNativeAudioSource> open(AudioCaptureRequest request, {String? recordPath}) async {
    if (request.format.sampleRate != 16000 || request.format.channels != 1) {
      throw UnsupportedError('macOS capture delivers 16 kHz mono only');
    }
    return MacNativeAudioSource(
      _api,
      _events.stream,
      kind,
      request.format,
      recordPath: recordPath ?? request.recordPath,
      deviceId: request.deviceId,
    );
  }
}

/// One capture. PCM stays in Swift's ring ([ring]); Dart sees levels,
/// issues and the end of capture only. Cannot be restarted after [stop].
final class MacNativeAudioSource implements NativeAudioSource {
  MacNativeAudioSource(
    this._api,
    this._events,
    this.kind,
    this.format, {
    this.recordPath,
    this.deviceId,
  });
  final TinglangHostApi _api;
  final Stream<LiveEvent> _events;
  final String? recordPath;

  /// `file:<path>` plays a file instead of a device; Swift accepts it only
  /// when the process has `TINGLANG_TEST_CAPTURE_FILES=1` (tests).
  final String? deviceId;

  @override
  final AudioSourceKind kind;
  @override
  final AudioFormat format;

  String? _captureId;
  NativePcmRing? _ring;
  StreamSubscription<LiveEvent>? _sub;
  final _levels = StreamController<AudioLevel>.broadcast();
  final _issues = StreamController<AudioCaptureIssue>.broadcast();
  final _clock = Stopwatch();
  final _ended = Completer<void>();
  var _running = false;
  var _closed = false;

  /// Native id; also the `sessionId` of its events.
  String? get captureId => _captureId;

  @override
  NativePcmRing? get ring => _ring;

  @override
  Stream<Float32List>? get debugBlocks => null;

  @override
  Stream<AudioLevel> get levels => _levels.stream;

  @override
  Stream<AudioCaptureIssue> get issues => _issues.stream;

  @override
  bool get isRunning => _running;

  /// Completes when Swift reports the capture stopped.
  Future<void> get ended => _ended.future;

  @override
  Future<void> start() async {
    if (_closed || _captureId != null) throw StateError('capture already used');
    // Listen first: events for the new id may arrive before the reply.
    final early = <LiveEvent>[];
    _sub = _events.listen((e) {
      final id = _captureId;
      if (id == null) {
        early.add(e);
      } else if (e.sessionId == id) {
        _route(e);
      }
    });
    try {
      final handle = await _api.openCapture(
        CaptureRequest(
          source: deviceId != null && deviceId!.startsWith('file:')
              ? deviceId!
              : kind == AudioSourceKind.microphone
              ? 'microphone'
              : 'system',
          recordPath: recordPath,
        ),
      );
      _captureId = handle.captureId;
      _ring = NativePcmRing(address: handle.ringAddress, capacitySamples: handle.capacity);
      _running = true;
      _clock.start();
      for (final e in early) {
        if (e.sessionId == handle.captureId) _route(e);
      }
    } on Object {
      await _sub?.cancel();
      _closed = true;
      rethrow;
    }
  }

  void _route(LiveEvent e) {
    switch (e.kind) {
      case 'level':
        final level = e.level ?? 0;
        if (!_levels.isClosed) _levels.add(AudioLevel(rms: level, peak: level, at: _clock.elapsed));
      case 'issue':
        if (!_issues.isClosed) _issues.add(issueFromCode(e.code ?? '', e.message));
      case 'stopped':
        if (e.message != null && !_issues.isClosed) _issues.add(CaptureFailed(e.message!));
        _finish();
    }
  }

  void _finish() {
    _running = false;
    _clock.stop();
    if (!_ended.isCompleted) _ended.complete();
    _sub?.cancel();
    _levels.close();
    _issues.close();
  }

  /// Stops capture and closes the ring; the reader drains it and then calls
  /// its `release`.
  @override
  Future<void> stop() async {
    final id = _captureId;
    if (id == null || !_running) return;
    _running = false;
    await _api.closeCapture(id);
    await ended.timeout(const Duration(seconds: 5), onTimeout: _finish);
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await stop();
    if (!_ended.isCompleted) _finish();
  }
}

/// AVAssetReader decoding (any AVFoundation-readable audio or video).
final class MacMediaDecoder implements MediaDecoder {
  MacMediaDecoder(this._api);
  final TinglangHostApi _api;

  @override
  Future<MediaInfo> inspect(String path) async {
    final facts = await _api.inspectMedia(path);
    return MediaInfo(
      durationMs: facts.durationMs,
      hasVideo: facts.hasVideo,
      hasAudio: facts.hasAudio,
    );
  }

  /// PCM never crosses Pigeon; use [decodeToFile].
  @override
  Stream<Float32List> decodePcm(String path, {int sampleRate = 16000}) =>
      Stream.error(UnsupportedError('decodePcm is not available on macOS; use decodeToFile'));

  @override
  Future<String> decodeToFile(String path, {int sampleRate = 16000}) {
    if (sampleRate != 16000) {
      throw ArgumentError.value(sampleRate, 'sampleRate', 'only 16000 is supported');
    }
    return _api.decodeToPcmFile(path);
  }
}

/// Apple Translation over installed language packs (macOS 26+). [pairs] is
/// empty: ask [ready] at runtime.
final class MacTranslator implements TranslatorBackend {
  MacTranslator(this._api);
  final TinglangHostApi _api;

  @override
  Set<LanguagePair> get pairs => const {};

  /// Whether the pack for [pair] is installed, so [translate] can run now.
  Future<bool> ready(LanguagePair pair) => _api.translationReady(pair.source, pair.target);

  @override
  Future<List<String>> translate(List<String> texts, LanguagePair pair) async {
    if (texts.isEmpty) return const [];
    final result = await _api.translateTexts(pair.source, pair.target, texts);
    return result.cast<String>();
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;
// ignore: implementation_imports
import 'package:sherpa_onnx/src/sherpa_onnx_bindings.dart' show SherpaOnnxBindings;
import 'package:tinglang_platform_interface/tinglang_platform_interface.dart';

import 'pcm_ring.dart';
import 'sherpa_runtime.dart';

/// sherpa-onnx streaming transducer in a worker isolate (topology B).
///
/// PCM comes from the capture's native ring ([AsrSessionConfig.source]),
/// read through FFI inside the worker after a `NativeCallable.listener`
/// wake-up, so it never passes through the root isolate. Without a ring,
/// [AsrSession.acceptWaveform] sends samples to the worker (files and tests
/// only). The worker sends text events and stats back.
///
/// Silero VAD gates the recogniser (docs/perf/asr-bench-2026-10.md: feeding
/// silence costs CPU): audio is fed only while the VAD hears speech, starting
/// [preRollMs] before the VAD triggers, and stops [gateHangoverMs] after the
/// tier's endpoint pause once the VAD hears silence (Silero drops out for
/// up to ~0.75 s inside speech, so a shorter hold cuts words); the stream is
/// then closed with `inputFinished`, decoded to the end and dropped until
/// the next speech. Lines end at sherpa's rule-2 endpoint, never shorter
/// than [minEndpointMs] for the model: at 0.5 s the 480 ms X-ASR model
/// emits words after the endpoint fired and the reset drops them. Each new
/// stream starts with [warmupMs] of silence, and fed audio is boosted
/// towards [targetPeak]. Times are on the capture clock (sample index / 16).
final class SherpaStreamingAsr implements StreamingAsrBackend {
  SherpaStreamingAsr(
    this.model, {
    required this.directoryOf,
    this.sentenceCase = false,
    this.libraryDir,
  });

  final SpeechModel model;

  /// Folder of a model pack (`ModelInventory.directoryOf`), resolved at
  /// [start].
  final String Function(String packId) directoryOf;

  /// Display normalisation for models that emit upper case without
  /// punctuation (the LibriSpeech zipformers): lower case, then capitalise
  /// the first letter and a standalone "I".
  final bool sentenceCase;

  /// Overrides [sherpaLibraryDir] (null resolves it at start).
  final String? libraryDir;

  /// Audio fed from before the VAD's trigger. Silero needs up to ~0.65 s
  /// of speech to trigger at [vadThreshold] after silence (FLEURS, measured
  /// 2026-10-23; ~1 s at 0.5), and the first words are lost without it.
  static const preRollMs = 1000;

  /// How long the gate stays open after the endpoint pause.
  static const gateHangoverMs = 1000;

  /// Shortest rule-2 pause per model id (measured, see the class comment).
  static final minEndpointMs = {SpeechModels.xasrStreaming.id: 800};

  /// Silence before each new stream's audio (see `_LiveRecognizer._warmup`).
  static const warmupMs = 640;

  /// Audio fed to the recogniser is boosted (never cut) towards this peak,
  /// by at most [maxGain]: the LibriSpeech zipformers recognise little at
  /// -45 dBFS (quiet FLEURS clips), X-ASR is unaffected. The VAD sees the
  /// original samples.
  static const targetPeak = .3;
  static const maxGain = 30.0;

  /// Silero speech probability threshold for the gate.
  static const vadThreshold = .4;

  @override
  Set<String> get languages => model.languages;

  @override
  Future<SherpaAsrSession> start(AsrSessionConfig config) async {
    final files = model.sherpaFiles;
    final pack = model.pack;
    if (model.engine != SpeechEngine.sherpaStreaming || files == null || pack == null) {
      throw StateError('${model.id} is not a sherpa-onnx streaming model.');
    }
    final dir = directoryOf(pack.id);
    final vadDir = directoryOf(SpeechModels.vad.id);
    final tier = LatencyTiers.sherpa(config.latency);
    final ring = config.source?.ring;
    return SherpaAsrSession._spawn(
      _LiveJob(
        libraryDir: libraryDir ?? sherpaLibraryDir(),
        encoder: '$dir/${files.encoder}',
        decoder: '$dir/${files.decoder}',
        joiner: '$dir/${files.joiner}',
        tokens: '$dir/${files.tokens}',
        vad: '$vadDir/$vadFileName',
        numThreads: tier.numThreads,
        feedMs: tier.feedMs,
        endpointSilenceMs: math.max(tier.endpointSilenceMs, minEndpointMs[model.id] ?? 0),
        partialIntervalMs: tier.partialIntervalMs,
        ringAddress: ring?.address ?? 0,
        segmentPrefix: 's${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}',
        language: config.language == 'auto' ? null : config.language,
        sentenceCase: sentenceCase,
      ),
    );
  }
}

/// File name of the Silero model inside the `silero-vad` pack.
String get vadFileName =>
    SpeechModels.vad.files.isEmpty ? 'silero_vad.onnx' : SpeechModels.vad.files.first.name;

/// A running [SherpaStreamingAsr] session.
final class SherpaAsrSession implements AsrSession {
  SherpaAsrSession._(this._isolate, this._control, this._ringMode);

  static Future<SherpaAsrSession> _spawn(_LiveJob job) async {
    final port = ReceivePort('sherpa-live');
    final first = Completer<Object?>();
    late final SherpaAsrSession session;
    port.listen((Object? message) {
      if (!first.isCompleted) {
        first.complete(message);
      } else {
        session._onMessage(message);
      }
    });
    final isolate = await Isolate.spawn(
      _liveWorker,
      job.withReply(port.sendPort),
      onError: port.sendPort,
      onExit: port.sendPort,
      debugName: 'sherpa-live',
    );
    final reply = await first.future;
    if (reply is! SendPort) {
      port.close();
      isolate.kill();
      throw StateError('sherpa-onnx recogniser failed to start: ${_describe(reply)}');
    }
    session = SherpaAsrSession._(isolate, reply, job.ringAddress != 0).._port = port;
    return session;
  }

  final Isolate _isolate;
  final SendPort _control;
  final bool _ringMode;
  late final ReceivePort _port;
  final _events = StreamController<AsrEvent>.broadcast();
  final _stats = StreamController<AsrStats>.broadcast();
  final _done = Completer<void>();
  bool _stopping = false;
  int _fedSamples = 0;

  @override
  Stream<AsrEvent> get events => _events.stream;
  @override
  Stream<AsrStats> get stats => _stats.stream;

  /// Samples handed to the recogniser so far (the rest was gated out by the
  /// VAD); updated with each stats tick and at stop.
  int get fedSamples => _fedSamples;

  @override
  void acceptWaveform(Float32List samples, int sampleRate) {
    if (_ringMode) throw StateError('This session reads the capture ring; do not push samples.');
    if (sampleRate != 16000) throw ArgumentError.value(sampleRate, 'sampleRate', 'must be 16000');
    if (_stopping || _done.isCompleted) return;
    _control.send(samples);
  }

  @override
  Future<void> stop() async {
    if (!_stopping) {
      _stopping = true;
      if (!_done.isCompleted) _control.send('stop');
    }
    await _done.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        _isolate.kill(priority: Isolate.immediate);
        _finish();
      },
    );
  }

  void _onMessage(Object? message) {
    switch (message) {
      case AsrEvent event:
        _events.add(event);
      case AsrStats stats:
        _stats.add(stats);
      case int fed:
        _fedSamples = fed;
      case 'done':
        _finish();
      case null:
        // onExit without 'done': the worker died.
        if (!_done.isCompleted) {
          _events.addError(StateError('sherpa-onnx recogniser stopped unexpectedly.'));
          _finish();
        }
      case List<Object?> error:
        // onError: [message, stack].
        _events.addError(StateError('sherpa-onnx recogniser failed: ${error.first}'));
      case _WorkerError error:
        _events.addError(StateError('sherpa-onnx recogniser failed: ${error.message}'));
    }
  }

  void _finish() {
    if (_done.isCompleted) return;
    _done.complete();
    _port.close();
    _events.close();
    _stats.close();
  }
}

String _describe(Object? reply) => switch (reply) {
  _WorkerError(:final message) => message,
  List<Object?> error => '${error.first}',
  null => 'worker exited',
  _ => '$reply',
};

final class _WorkerError {
  const _WorkerError(this.message);
  final String message;
}

final class _LiveJob {
  const _LiveJob({
    required this.libraryDir,
    required this.encoder,
    required this.decoder,
    required this.joiner,
    required this.tokens,
    required this.vad,
    required this.numThreads,
    required this.feedMs,
    required this.endpointSilenceMs,
    required this.partialIntervalMs,
    required this.ringAddress,
    required this.segmentPrefix,
    required this.language,
    required this.sentenceCase,
    this.reply,
  });
  final String? libraryDir;
  final String encoder, decoder, joiner, tokens, vad;
  final int numThreads, feedMs, endpointSilenceMs, partialIntervalMs, ringAddress;
  final String segmentPrefix;
  final String? language;
  final bool sentenceCase;
  final SendPort? reply;

  _LiveJob withReply(SendPort port) => _LiveJob(
    libraryDir: libraryDir,
    encoder: encoder,
    decoder: decoder,
    joiner: joiner,
    tokens: tokens,
    vad: vad,
    numThreads: numThreads,
    feedMs: feedMs,
    endpointSilenceMs: endpointSilenceMs,
    partialIntervalMs: partialIntervalMs,
    ringAddress: ringAddress,
    segmentPrefix: segmentPrefix,
    language: language,
    sentenceCase: sentenceCase,
    reply: port,
  );
}

Future<void> _liveWorker(_LiveJob job) async {
  final reply = job.reply!;
  final control = ReceivePort();
  final _LiveRecognizer recognizer;
  try {
    bindSherpa(job.libraryDir);
    recognizer = _LiveRecognizer(job, reply.send);
  } on Object catch (e) {
    control.close();
    reply.send(_WorkerError('$e'));
    return;
  }
  PcmRingReader? reader;
  Timer? poll;
  var dropped = 0;
  final scratch = Float32List(16000);
  void pump() {
    final ring = reader;
    if (ring == null || ring.isClosed) return;
    final total = ring.dropped;
    if (total > dropped) {
      recognizer.gap(total - dropped);
      dropped = total;
    }
    while (true) {
      final n = ring.read(scratch);
      if (n <= 0) break;
      recognizer.accept(Float32List.sublistView(scratch, 0, n));
    }
  }

  try {
    if (job.ringAddress != 0) {
      reader = PcmRingReader.attach(job.ringAddress, onWake: (_) => pump());
      // Backstop for a producer that stops short of the wake threshold.
      poll = Timer.periodic(const Duration(milliseconds: 200), (_) => pump());
    }
  } on Object catch (e) {
    recognizer.free();
    control.close();
    reply.send(_WorkerError('$e'));
    return;
  }
  reply.send(control.sendPort);
  // Samples captured before the wake-up was registered.
  if (reader != null) Timer.run(pump);
  final stats = Timer.periodic(const Duration(seconds: 1), (_) {
    reply.send(recognizer.takeStats());
    reply.send(recognizer.fedSamples);
  });
  await for (final message in control) {
    if (message is Float32List) {
      recognizer.accept(message);
    } else if (message == 'stop') {
      pump();
      recognizer.finish();
      break;
    }
  }
  stats.cancel();
  poll?.cancel();
  reader?.close();
  reply.send(recognizer.fedSamples);
  recognizer.free();
  control.close();
  reply.send('done');
}

/// Result of one stream, read from the C API's JSON (the Dart wrapper drops
/// `start_time`, the stream time where the current segment began).
final class _Result {
  const _Result(this.text, this.tokens, this.timestamps, this.startTime);
  final String text;
  final List<String> tokens;
  final List<double> timestamps;
  final double startTime;
}

final class _LiveRecognizer {
  _LiveRecognizer(this.job, this.send)
    : _feed = Float32List(16 * job.feedMs),
      _preRoll = Float32List(16 * SherpaStreamingAsr.preRollMs),
      _hangover = 16 * (job.endpointSilenceMs + SherpaStreamingAsr.gateHangoverMs) {
    _vad = sherpa.VoiceActivityDetector(
      config: sherpa.VadModelConfig(
        sileroVad: sherpa.SileroVadModelConfig(
          model: job.vad,
          threshold: SherpaStreamingAsr.vadThreshold,
          minSilenceDuration: _minSilenceMs / 1000,
          minSpeechDuration: _minSpeechMs / 1000,
          windowSize: _window,
          maxSpeechDuration: 30,
        ),
        numThreads: 1,
        debug: false,
      ),
      bufferSizeInSeconds: 60,
    );
    try {
      _recognizer = sherpa.OnlineRecognizer(
        sherpa.OnlineRecognizerConfig(
          model: sherpa.OnlineModelConfig(
            transducer: sherpa.OnlineTransducerModelConfig(
              encoder: job.encoder,
              decoder: job.decoder,
              joiner: job.joiner,
            ),
            tokens: job.tokens,
            numThreads: job.numThreads,
            provider: 'cpu',
            debug: false,
          ),
          decodingMethod: 'greedy_search',
          enableEndpoint: true,
          // Rule 1 (no tokens for a while) is off: the VAD gate handles
          // silence, and a rule-1 reset that lands on the next onset drops
          // its first words. Rule 2: the line-ending pause after speech.
          // Rule 3: cut lines longer than 20 s.
          rule1MinTrailingSilence: 3600,
          rule2MinTrailingSilence: job.endpointSilenceMs / 1000,
          rule3MinUtteranceLength: 20,
        ),
      );
    } on Object {
      _vad.free();
      rethrow;
    }
  }

  static const _window = 512; // Silero window, 32 ms
  static const _minSpeechMs = 100;
  static const _minSilenceMs = 250;

  /// Silence fed to every new stream first: the LibriSpeech zipformers drop
  /// the first second of speech when a stream starts straight into it.
  static final _warmup = Float32List(16 * SherpaStreamingAsr.warmupMs);

  final _LiveJob job;
  final void Function(Object?) send;
  late final sherpa.VoiceActivityDetector _vad;
  late final sherpa.OnlineRecognizer _recognizer;
  sherpa.OnlineStream? _stream;

  final _windowBuf = Float32List(_window);
  int _windowFill = 0;
  final Float32List _preRoll;
  int _preHead = 0, _preFill = 0;
  final Float32List _feed;
  int _feedFill = 0;
  final int _hangover;
  int _hangoverLeft = 0;

  /// Peak envelope for the gain (instant attack, [_levelRelease] decay).
  double _level = 0;
  static final _levelRelease = math.pow(.5, _window / 16 / 2000).toDouble(); // halves in 2 s

  /// Capture index of the next sample, of the VAD's sample 0 offset, of
  /// the current stream's first sample, and samples fed to that stream.
  int _captured = 0, _vadOffset = 0, _origin = 0, _streamFed = 0;
  int? _speechEnd;
  int _segment = 0;
  String _lastPartial = '';
  final _clock = Stopwatch()..start();
  int _lastPartialAt = -1 << 30;

  int fedSamples = 0;
  int _statAudio = 0, _statProcUs = 0, _statCpuUs = 0, _droppedSamples = 0;
  final _statWall = Stopwatch()..start();

  void accept(Float32List samples) {
    final t0 = _clock.elapsedMicroseconds;
    final cpu0 = threadCpuMicros();
    var i = 0;
    while (i < samples.length) {
      final n = math.min(_window - _windowFill, samples.length - i);
      _windowBuf.setRange(_windowFill, _windowFill + n, samples, i);
      _windowFill += n;
      i += n;
      if (_windowFill == _window) {
        _windowFill = 0;
        _onWindow(_windowBuf);
      }
    }
    _statAudio += samples.length;
    _account(t0, cpu0);
  }

  /// [samples] were lost before reaching the worker (ring overflow).
  void gap(int samples) {
    if (_stream != null) _closeRun();
    final start = _captured;
    _captured += samples;
    _vadOffset += samples;
    _droppedSamples += samples;
    _preFill = 0;
    send(
      AsrGap(
        '${job.segmentPrefix}-${_segment++}',
        startMs: start ~/ 16,
        endMs: _captured ~/ 16,
        reason: 'dropped',
      ),
    );
  }

  /// Flushes the current line as a final (stop).
  void finish() {
    final t0 = _clock.elapsedMicroseconds;
    final cpu0 = threadCpuMicros();
    if (_stream != null) {
      if (_windowFill > 0) _push(Float32List.sublistView(_windowBuf, 0, _windowFill));
      _captured += _windowFill;
      _windowFill = 0;
      _closeRun(force: true);
    }
    _account(t0, cpu0);
  }

  AsrStats takeStats() {
    final wallUs = _statWall.elapsedMicroseconds;
    _statWall.reset();
    final audioUs = _statAudio * 1000000 ~/ 16000;
    final stats = AsrStats(
      realTimeFactor: audioUs == 0 ? 0 : _statProcUs / audioUs,
      queuedMs: (_windowFill + _feedFill) ~/ 16,
      cpuMsPerSecond: wallUs == 0 ? 0 : _statCpuUs / 1000 / (wallUs / 1e6),
      droppedMs: _droppedSamples ~/ 16,
    );
    _statAudio = _statProcUs = _statCpuUs = 0;
    return stats;
  }

  void free() {
    _stream?.free();
    _stream = null;
    _recognizer.free();
    _vad.free();
  }

  void _account(int t0, int? cpu0) {
    final wall = _clock.elapsedMicroseconds - t0;
    _statProcUs += wall;
    final cpu1 = threadCpuMicros();
    _statCpuUs += cpu0 == null || cpu1 == null ? wall : cpu1 - cpu0;
  }

  void _onWindow(Float32List window) {
    _captured += _window;
    _vad.acceptWaveform(window);
    final speech = _vad.isDetected();
    while (!_vad.isEmpty()) {
      final segment = _vad.front();
      _speechEnd = segment.start + segment.samples.length + _vadOffset;
      _vad.pop();
    }
    _level = math.max(_peak(window), _level * _levelRelease);
    if (_stream == null) {
      if (speech) {
        _stream = _recognizer.createStream();
        // Stream sample 0 is the start of the warm-up silence.
        _origin = _captured - _window - _preFill - _warmup.length;
        _streamFed = 0;
        _feedFill = 0;
        _lastPartial = '';
        _push(_warmup);
        if (_preFill > 0) {
          final preRoll = _takePreRoll();
          _level = math.max(_level, _peak(preRoll));
          _push(preRoll);
        }
        _hangoverLeft = _hangover;
        _push(window);
      }
    } else {
      _push(window);
      if (speech) {
        _hangoverLeft = _hangover;
      } else {
        _hangoverLeft -= _window;
        if (_hangoverLeft <= 0) _closeRun();
      }
    }
    // Always kept, so a line that starts right after a closed one still
    // gets its pre-roll.
    _remember(window);
  }

  static double _peak(Float32List samples) {
    var peak = 0.0;
    for (final sample in samples) {
      final magnitude = sample.abs();
      if (magnitude > peak) peak = magnitude;
    }
    return peak;
  }

  void _remember(Float32List window) {
    for (final sample in window) {
      _preRoll[(_preHead + _preFill) % _preRoll.length] = sample;
      if (_preFill < _preRoll.length) {
        _preFill++;
      } else {
        _preHead = (_preHead + 1) % _preRoll.length;
      }
    }
  }

  Float32List _takePreRoll() {
    final out = Float32List(_preFill);
    for (var i = 0; i < _preFill; i++) {
      out[i] = _preRoll[(_preHead + i) % _preRoll.length];
    }
    _preHead = 0;
    _preFill = 0;
    return out;
  }

  /// Buffers [samples] for the stream and decodes every full feed.
  void _push(Float32List samples) {
    final gain = (SherpaStreamingAsr.targetPeak / math.max(_level, 1e-6)).clamp(
      1.0,
      SherpaStreamingAsr.maxGain,
    );
    var i = 0;
    while (i < samples.length) {
      final n = math.min(_feed.length - _feedFill, samples.length - i);
      for (var k = 0; k < n; k++) {
        _feed[_feedFill + k] = samples[i + k] * gain;
      }
      _feedFill += n;
      i += n;
      if (_feedFill == _feed.length) _decodeFeed();
    }
  }

  void _decodeFeed() {
    final stream = _stream!;
    if (_feedFill == 0) return;
    stream.acceptWaveform(
      samples: _feedFill == _feed.length ? _feed : Float32List.sublistView(_feed, 0, _feedFill),
      sampleRate: 16000,
    );
    _streamFed += _feedFill;
    fedSamples += _feedFill;
    _feedFill = 0;
    while (_recognizer.isReady(stream)) {
      _recognizer.decode(stream);
    }
    final result = _result(stream);
    if (_recognizer.isEndpoint(stream)) {
      _final(result, endpoint: true);
      _recognizer.reset(stream);
      return;
    }
    final now = _clock.elapsedMilliseconds;
    if (result.text != _lastPartial &&
        _hasWords(result.text) &&
        now - _lastPartialAt >= job.partialIntervalMs) {
      _lastPartial = result.text;
      _lastPartialAt = now;
      send(
        AsrPartial(
          '${job.segmentPrefix}-$_segment',
          text: _display(result.text),
          startMs: _startMs(result),
        ),
      );
    }
  }

  /// Ends the fed run: decodes what is buffered with the input closed and
  /// emits it as a final, unless nothing was said since the last endpoint.
  void _closeRun({bool force = false}) {
    final stream = _stream!;
    _decodeFeed();
    if (force || _hasWords(_result(stream).text)) {
      stream.inputFinished();
      while (_recognizer.isReady(stream)) {
        _recognizer.decode(stream);
      }
      _final(_result(stream), endpoint: false);
    }
    stream.free();
    _stream = null;
    _feedFill = 0;
  }

  void _final(_Result result, {required bool endpoint}) {
    _lastPartial = '';
    if (!_hasWords(result.text)) return;
    final offsetMs = _origin ~/ 16 + (result.startTime * 1000).round();
    final startMs = _startMs(result);
    final lastToken = result.timestamps.isEmpty
        ? startMs
        : offsetMs + (result.timestamps.last * 1000).round();
    final fedEnd = (_origin + _streamFed) ~/ 16;
    final speechEnd = _speechEnd == null ? null : _speechEnd! ~/ 16;
    // The segment ends where the VAD heard speech stop, if that happened
    // after the last token; else before the pause sherpa's rule 2 measured
    // (endpoint) or at the last fed sample (flush).
    var endMs = speechEnd != null && speechEnd >= lastToken && speechEnd <= fedEnd
        ? speechEnd
        : endpoint
        ? fedEnd - job.endpointSilenceMs
        : fedEnd;
    endMs = math.max(endMs, math.max(startMs, lastToken));
    var words = wordsFromTokens(result.tokens, result.timestamps, offsetMs: offsetMs, endMs: endMs);
    if (job.sentenceCase && words != null) {
      words = [
        for (var i = 0; i < words.length; i++)
          TimedWord(sentenceCased(words[i].text, first: i == 0), words[i].startMs, words[i].endMs),
      ];
    }
    send(
      AsrFinal(
        '${job.segmentPrefix}-${_segment++}',
        text: _display(result.text),
        startMs: startMs,
        endMs: endMs,
        language: job.language,
        words: words,
      ),
    );
  }

  int _startMs(_Result result) {
    final offsetMs = _origin ~/ 16 + (result.startTime * 1000).round();
    return result.timestamps.isEmpty
        ? offsetMs
        : offsetMs + (result.timestamps.first * 1000).round();
  }

  String _display(String text) {
    // A line never starts with the previous sentence's full stop.
    final trimmed = text.trim().replaceFirst(_leadingPunctuation, '');
    return job.sentenceCase ? sentenceCased(trimmed) : trimmed;
  }

  _Result _result(sherpa.OnlineStream stream) {
    final json = SherpaOnnxBindings.getOnlineStreamResultAsJson!(_recognizer.ptr, stream.ptr);
    final map = jsonDecode(json.toDartString()) as Map<String, Object?>;
    SherpaOnnxBindings.destroyOnlineStreamResultJson!(json);
    return _Result(
      map['text'] as String? ?? '',
      [for (final t in map['tokens'] as List<Object?>? ?? const []) t! as String],
      [for (final t in map['timestamps'] as List<Object?>? ?? const []) (t! as num).toDouble()],
      (map['start_time'] as num?)?.toDouble() ?? 0,
    );
  }
}

final _wordChar = RegExp(r'[\p{L}\p{N}]', unicode: true);
final _leadingPunctuation = RegExp(r'^[\s.,!?;:。，！？；：、]+');
bool _hasWords(String text) => _wordChar.hasMatch(text);

/// Lower case with the first letter (when [first]) and a standalone "i"
/// capitalised: display text for models that emit upper case only.
String sentenceCased(String text, {bool first = true}) {
  var out = text.toLowerCase().replaceAllMapped(RegExp(r"\bi\b"), (_) => 'I');
  if (first) {
    final index = out.indexOf(RegExp(r'\p{L}', unicode: true));
    if (index >= 0) {
      out = out.substring(0, index) + out[index].toUpperCase() + out.substring(index + 1);
    }
  }
  return out;
}

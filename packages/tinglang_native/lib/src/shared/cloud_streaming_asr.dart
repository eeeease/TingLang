import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:tinglang_cloud_asr/tinglang_cloud_asr.dart';
import 'package:tinglang_platform_interface/tinglang_platform_interface.dart';

import 'pcm_ring.dart';

/// A cloud speech service as a live recogniser (topology B, like sherpa).
///
/// A worker isolate reads the capture's native ring (PCM never passes
/// through the root isolate), converts it to 16-bit PCM and streams it to
/// [provider]. Each connection keeps its own time base, so caption times
/// stay offsets into the capture after a reconnect: a service that ends a
/// stream at its time limit gets a new one at once, and network failures
/// are retried with backoff while up to [maxBufferMs] of audio waits. Audio
/// beyond that is reported as an [AsrGap]. A refused key, an exhausted
/// quota or repeated failures end the session with an [AsrFailure].
final class CloudStreamingAsr implements StreamingAsrBackend {
  CloudStreamingAsr(this.provider, {required this.credentials});

  final CloudAsrProvider provider;

  /// The user's credentials, read when a session starts.
  final Future<CloudCredentials?> Function() credentials;

  /// Audio kept while (re)connecting.
  static const maxBufferMs = 30000;

  /// Consecutive failed connections before giving up.
  static const maxAttempts = 6;

  @override
  Set<String> get languages => provider.info.languages;

  @override
  Future<AsrSession> start(AsrSessionConfig config) async {
    final backendId = 'cloud.${provider.info.id}';
    final values = await credentials();
    if (values == null || values.isEmpty) {
      throw AsrFailure(
        AsrFailureReason.unauthorized,
        'No credentials saved.',
        backendId: backendId,
      );
    }
    return CloudAsrSession._spawn(
      _LiveJob(
        provider: provider,
        credentials: Map.of(values),
        language: config.language,
        ringAddress: config.source?.ring?.address ?? 0,
        segmentPrefix: 'c${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}',
        backendId: backendId,
      ),
    );
  }
}

/// [CloudAsrErrorKind] → the reason the app explains.
AsrFailure asrFailureOf(CloudAsrError e, String backendId) => AsrFailure(
  switch (e.kind) {
    CloudAsrErrorKind.unauthorized => AsrFailureReason.unauthorized,
    CloudAsrErrorKind.quotaExceeded => AsrFailureReason.quotaExceeded,
    CloudAsrErrorKind.rateLimited => AsrFailureReason.rateLimited,
    CloudAsrErrorKind.network => AsrFailureReason.network,
    CloudAsrErrorKind.unsupportedLanguage => AsrFailureReason.unsupportedLanguage,
    CloudAsrErrorKind.audioTooLong => AsrFailureReason.audioTooLong,
    _ => AsrFailureReason.other,
  },
  e.message,
  backendId: backendId,
);

/// A running [CloudStreamingAsr] session.
final class CloudAsrSession implements AsrSession {
  CloudAsrSession._(this._isolate, this._control, this._ringMode);

  static Future<CloudAsrSession> _spawn(_LiveJob job) async {
    final port = ReceivePort('cloud-live');
    final first = Completer<Object?>();
    late final CloudAsrSession session;
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
      debugName: 'cloud-live',
    );
    final reply = await first.future;
    if (reply is! SendPort) {
      port.close();
      isolate.kill();
      throw switch (reply) {
        AsrFailure failure => failure,
        _ => StateError('Cloud recogniser failed to start: $reply'),
      };
    }
    session = CloudAsrSession._(isolate, reply, job.ringAddress != 0).._port = port;
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

  @override
  Stream<AsrEvent> get events => _events.stream;
  @override
  Stream<AsrStats> get stats => _stats.stream;

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
      const Duration(seconds: 20),
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
      case AsrFailure failure:
        _events.addError(failure);
      case 'done':
        _finish();
      case null:
        if (!_done.isCompleted) {
          _events.addError(StateError('Cloud recogniser stopped unexpectedly.'));
          _finish();
        }
      case List<Object?> error:
        _events.addError(StateError('Cloud recogniser failed: ${error.first}'));
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

final class _LiveJob {
  const _LiveJob({
    required this.provider,
    required this.credentials,
    required this.language,
    required this.ringAddress,
    required this.segmentPrefix,
    required this.backendId,
    this.reply,
  });
  final CloudAsrProvider provider;
  final Map<String, String> credentials;
  final String language, segmentPrefix, backendId;
  final int ringAddress;
  final SendPort? reply;

  _LiveJob withReply(SendPort port) => _LiveJob(
    provider: provider,
    credentials: credentials,
    language: language,
    ringAddress: ringAddress,
    segmentPrefix: segmentPrefix,
    backendId: backendId,
    reply: port,
  );
}

Future<void> _liveWorker(_LiveJob job) async {
  final reply = job.reply!;
  final control = ReceivePort();
  final live = CloudLiveRelay(
    open: () =>
        job.provider.openStream(job.credentials, CloudStreamOptions(language: job.language)),
    segmentPrefix: job.segmentPrefix,
    backendId: job.backendId,
    send: reply.send,
  );
  PcmRingReader? reader;
  Timer? poll;
  var dropped = 0;
  final scratch = Float32List(16000);
  void pump() {
    final ring = reader;
    if (ring == null || ring.isClosed) return;
    final total = ring.dropped;
    if (total > dropped) {
      live.lost(total - dropped);
      dropped = total;
    }
    while (true) {
      final n = ring.read(scratch);
      if (n <= 0) break;
      live.accept(Float32List.sublistView(scratch, 0, n));
    }
  }

  try {
    if (job.ringAddress != 0) {
      reader = PcmRingReader.attach(job.ringAddress, onWake: (_) => pump());
      poll = Timer.periodic(const Duration(milliseconds: 200), (_) => pump());
    }
    // The first connection must work, so a bad key fails the start.
    await live.connect();
  } on AsrFailure catch (failure) {
    poll?.cancel();
    reader?.close();
    control.close();
    reply.send(failure);
    return;
  }
  reply.send(control.sendPort);
  if (reader != null) Timer.run(pump);
  final stats = Timer.periodic(const Duration(seconds: 1), (_) => reply.send(live.takeStats()));
  final stop = Completer<void>();
  final sub = control.listen((Object? message) {
    if (message is Float32List) {
      live.accept(message);
    } else if (message == 'stop' && !stop.isCompleted) {
      stop.complete();
    }
  });
  final failed = await Future.any([stop.future.then((_) => false), live.failed.then((_) => true)]);
  if (!failed) {
    pump();
    await live.finish();
  }
  stats.cancel();
  poll?.cancel();
  reader?.close();
  await sub.cancel();
  control.close();
  reply.send('done');
}

/// The connection logic of [CloudStreamingAsr], apart from the isolate so
/// it can be tested directly. Times are on the capture clock: sample index
/// / 16 at 16 kHz.
final class CloudLiveRelay {
  CloudLiveRelay({
    required this.open,
    required this.segmentPrefix,
    required this.backendId,
    required this.send,
    this.maxBufferMs = CloudStreamingAsr.maxBufferMs,
    this.maxAttempts = CloudStreamingAsr.maxAttempts,
    this.backoff = _backoff,
    this.connectTimeout = const Duration(seconds: 15),
  });

  final Future<CloudAsrStream> Function() open;
  final String segmentPrefix, backendId;

  /// Receives [AsrEvent]s, [AsrStats] and a final [AsrFailure].
  final void Function(Object message) send;
  final int maxBufferMs, maxAttempts;
  final Duration Function(int attempt) backoff;
  final Duration connectTimeout;

  static Duration _backoff(int attempt) =>
      Duration(milliseconds: 500 * (1 << (attempt - 1).clamp(0, 4)));

  static const _rate = 16000;
  static const _sendSamples = 1600; // 100 ms

  /// Samples captured so far, lost ones included.
  int _captured = 0;

  /// Audio not sent yet and the capture index of its first sample.
  final _pending = <Uint8List>[];
  int _pendingSamples = 0;
  int _pendingStart = 0;
  int _droppedSamples = 0;

  _Connection? _current;
  final _retiring = <Future<void>>[];
  int _connections = 0;
  int _attempts = 0;
  bool _connecting = false;
  bool _finishing = false;
  int _gaps = 0;
  final _failed = Completer<void>();

  /// Completes when the session cannot go on (an [AsrFailure] was sent).
  Future<void> get failed => _failed.future;

  void accept(Float32List samples) {
    if (_failed.isCompleted) return;
    if (_pendingSamples == 0) _pendingStart = _captured;
    _captured += samples.length;
    _pending.add(pcm16FromFloat32(samples));
    _pendingSamples += samples.length;
    _trim();
    _flush();
  }

  /// [samples] were lost before reaching this relay (ring overflow): the
  /// current stream would drift, so it is finished and a new one starts at
  /// the new position.
  void lost(int samples) {
    if (samples <= 0 || _failed.isCompleted) return;
    _flush(force: true);
    if (_pendingSamples > 0) {
      // Not connected: what waits can no longer be placed in time.
      _gap(_pendingStart, _pendingStart + _pendingSamples, 'cloud reconnect');
      _droppedSamples += _pendingSamples;
      _pending.clear();
      _pendingSamples = 0;
    }
    final start = _captured;
    _captured += samples;
    _droppedSamples += samples;
    _gap(start, _captured, 'frames dropped');
    final current = _current;
    if (current != null) {
      _current = null;
      _retire(current, graceful: true);
      unawaited(_reconnect(immediately: true));
    }
  }

  /// Opens the first stream; throws [AsrFailure] if it cannot.
  Future<void> connect() async {
    _connecting = true;
    try {
      await _open();
    } on CloudAsrError catch (e) {
      throw asrFailureOf(e, backendId);
    } on Object catch (e) {
      // Not the adapter's own error type; its text may hold a signed URL.
      throw AsrFailure(
        AsrFailureReason.other,
        'Could not connect (${e.runtimeType}).',
        backendId: backendId,
      );
    } finally {
      _connecting = false;
    }
    _flush();
  }

  Future<void> _open() async {
    final stream = await open().timeout(
      connectTimeout,
      onTimeout: () =>
          throw const CloudAsrError(CloudAsrErrorKind.network, 'Connection timed out.'),
    );
    final connection = _Connection(
      ++_connections,
      _pendingSamples == 0 ? _captured : _pendingStart,
      stream,
    );
    connection.sub = stream.segments.listen(
      (segment) => _onSegment(connection, segment),
      onError: (Object e) => _onConnectionError(connection, e),
      onDone: () => _onConnectionDone(connection),
    );
    _current = connection;
  }

  void _onSegment(_Connection c, CloudSegment s) {
    final id = '$segmentPrefix-${c.index}-${s.id}';
    final base = c.startSample ~/ (_rate ~/ 1000);
    if (s.text.trim().isEmpty && !s.isFinal) return;
    if (s.isFinal) {
      c.partial = null;
      if (s.text.trim().isEmpty) return;
      send(
        AsrFinal(
          id,
          text: s.text.trim(),
          startMs: base + s.startMs,
          endMs: base + s.endMs,
          language: s.language,
          words: s.words == null
              ? null
              : [for (final w in s.words!) TimedWord(w.text, base + w.startMs, base + w.endMs)],
        ),
      );
      _attempts = 0;
    } else {
      c.partial = s;
      send(AsrPartial(id, text: s.text, startMs: base + s.startMs));
    }
  }

  void _onConnectionError(_Connection c, Object error) {
    if (c.closed) return;
    final e = error is CloudAsrError ? error : CloudAsrError(CloudAsrErrorKind.protocol, '$error');
    if (!e.retryable) {
      _fail(asrFailureOf(e, backendId));
      return;
    }
    // A stream that worked for a while does not count against the next one.
    if (DateTime.now().difference(c.openedAt) > const Duration(minutes: 1)) _attempts = 0;
    if (identical(_current, c)) _current = null;
    _retire(c, graceful: false);
    if (!_finishing) {
      unawaited(_reconnect(immediately: e.kind == CloudAsrErrorKind.sessionEnded));
    }
  }

  void _onConnectionDone(_Connection c) {
    if (c.closed) return;
    // The service closed a stream it was not asked to finish: treat it as
    // its time limit.
    if (identical(_current, c) && !_finishing) {
      _current = null;
      _retire(c, graceful: false);
      if (DateTime.now().difference(c.openedAt) > const Duration(minutes: 1)) _attempts = 0;
      unawaited(_reconnect(immediately: true));
    } else {
      _retire(c, graceful: false);
    }
  }

  /// Ends [c]. Its last partial becomes a final so no heard text is lost.
  void _retire(_Connection c, {required bool graceful}) {
    if (c.closed) return;
    c.closed = !graceful;
    if (graceful) {
      _retiring.add(
        c.stream.finish().catchError((Object _) {}).whenComplete(() {
          c.closed = true;
          _promotePartial(c);
          c.sub?.cancel();
        }),
      );
    } else {
      _promotePartial(c);
      unawaited(c.sub?.cancel());
      unawaited(c.stream.cancel().catchError((Object _) {}));
    }
  }

  void _promotePartial(_Connection c) {
    final p = c.partial;
    c.partial = null;
    if (p == null || p.text.trim().isEmpty) return;
    _onSegment(
      c,
      CloudSegment(id: p.id, text: p.text, startMs: p.startMs, endMs: p.endMs, isFinal: true),
    );
  }

  Future<void> _reconnect({bool immediately = false}) async {
    if (_connecting || _failed.isCompleted || _finishing) return;
    _connecting = true;
    try {
      while (!_failed.isCompleted && !_finishing) {
        _attempts++;
        if (_attempts > maxAttempts) {
          _fail(
            AsrFailure(
              AsrFailureReason.network,
              'The service could not be reached after $maxAttempts attempts.',
              backendId: backendId,
            ),
          );
          return;
        }
        if (!(immediately && _attempts == 1)) await Future<void>.delayed(backoff(_attempts));
        if (_finishing) return;
        try {
          await _open();
          return;
        } on CloudAsrError catch (e) {
          if (!e.retryable) {
            _fail(asrFailureOf(e, backendId));
            return;
          }
        } on Object {
          // Counted like a network failure.
        }
      }
    } finally {
      _connecting = false;
      _flush();
    }
  }

  /// Sends pending audio in 100 ms pieces once a stream is open.
  void _flush({bool force = false}) {
    final current = _current;
    if (current == null || _connecting || _pendingSamples == 0) return;
    if (_pendingSamples < _sendSamples && !force) return;
    final builder = BytesBuilder(copy: false);
    for (final piece in _pending) {
      builder.add(piece);
    }
    _pending.clear();
    _pendingSamples = 0;
    current.stream.addPcm(builder.takeBytes());
  }

  /// While no stream takes audio, keeps at most [maxBufferMs] waiting;
  /// older audio becomes a gap.
  void _trim() {
    final limit = maxBufferMs * (_rate ~/ 1000);
    if (_pendingSamples <= limit || (_current != null && !_connecting)) return;
    final start = _pendingStart;
    while (_pendingSamples > limit && _pending.isNotEmpty) {
      final first = _pending.first;
      final over = _pendingSamples - limit;
      final n = math.min(first.length ~/ 2, over);
      if (n == first.length ~/ 2) {
        _pending.removeAt(0);
      } else {
        _pending[0] = Uint8List.sublistView(first, n * 2);
      }
      _pendingSamples -= n;
      _pendingStart += n;
      _droppedSamples += n;
    }
    _gap(start, _pendingStart, 'cloud reconnect');
  }

  void _gap(int startSample, int endSample, String reason) {
    if (endSample <= startSample) return;
    final perMs = _rate ~/ 1000;
    send(
      AsrGap(
        '$segmentPrefix-gap-${++_gaps}',
        startMs: startSample ~/ perMs,
        endMs: endSample ~/ perMs,
        reason: reason,
      ),
    );
  }

  void _fail(AsrFailure failure) {
    if (_failed.isCompleted) return;
    final current = _current;
    _current = null;
    if (current != null) _retire(current, graceful: false);
    send(failure);
    _failed.complete();
  }

  /// Sends what is left, ends the stream and waits for its last results.
  Future<void> finish() async {
    if (_failed.isCompleted) return;
    _finishing = true;
    final current = _current;
    if (current != null) {
      _flush(force: true);
      _current = null;
      try {
        await current.stream.finish();
      } on Object {
        // The text so far stands.
      }
      current.closed = true;
      _promotePartial(current);
      await current.sub?.cancel();
    } else if (_pendingSamples > 0) {
      // Still disconnected: this audio was never recognised.
      _gap(_pendingStart, _pendingStart + _pendingSamples, 'cloud reconnect');
      _pending.clear();
      _pendingSamples = 0;
    }
    await Future.wait(_retiring);
  }

  AsrStats takeStats() => AsrStats(
    realTimeFactor: 0,
    queuedMs: _pendingSamples ~/ (_rate ~/ 1000),
    cpuMsPerSecond: 0,
    droppedMs: _droppedSamples ~/ (_rate ~/ 1000),
  );
}

final class _Connection {
  _Connection(this.index, this.startSample, this.stream);
  final int index;

  /// Capture index of this stream's first sample.
  final int startSample;
  final CloudAsrStream stream;
  final openedAt = DateTime.now();
  StreamSubscription<CloudSegment>? sub;
  CloudSegment? partial;
  bool closed = false;
}

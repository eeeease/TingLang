import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../speech_models.dart';
import 'audio_capture.dart';

/// A word with timing, offered only by backends that really produce it.
/// Tinglang never invents word timing.
@immutable
final class TimedWord {
  const TimedWord(this.text, this.startMs, this.endMs);
  final String text;
  final int startMs, endMs;
}

/// Events from a streaming recogniser. All times are milliseconds from the
/// session's time base (see the `session`/`time_anchor` tables).
sealed class AsrEvent {
  const AsrEvent(this.segmentId);

  /// Stable within a session; a partial and its final share the id so UI can
  /// update a line in place.
  final String segmentId;
}

/// Unstable hypothesis. Kept in memory only, never persisted.
final class AsrPartial extends AsrEvent {
  const AsrPartial(super.segmentId, {required this.text, required this.startMs});
  final String text;
  final int startMs;
}

/// Endpointed, stable text. Persisted in batches.
final class AsrFinal extends AsrEvent {
  const AsrFinal(
    super.segmentId, {
    required this.text,
    required this.startMs,
    required this.endMs,
    this.language,
    this.words,
  });
  final String text;
  final int startMs, endMs;
  final String? language;
  final List<TimedWord>? words;
}

/// Audio that was not recognised (dropped frames, reconnect, overload).
/// Recorded so transcripts never silently skip time.
final class AsrGap extends AsrEvent {
  const AsrGap(super.segmentId, {required this.startMs, required this.endMs, required this.reason});
  final int startMs, endMs;
  final String reason;
}

/// Why a recogniser stopped for good. Cloud services report these; the app
/// turns them into a message in the user's language.
enum AsrFailureReason {
  /// The key, secret or app id was refused.
  unauthorized,

  /// Out of balance or free quota, or the service is not activated.
  quotaExceeded,

  /// Too many requests or streams at once.
  rateLimited,

  /// The service could not be reached, also after retrying.
  network,

  /// The service does not recognise the learning language.
  unsupportedLanguage,

  /// The file is longer or larger than the service accepts.
  audioTooLong,
  other,
}

/// Thrown by recognisers (on [AsrSession.events] or from a
/// [TranscriptionJob]) when they cannot go on. [message] is the service's
/// own text, never a key.
final class AsrFailure implements Exception {
  const AsrFailure(this.reason, this.message, {this.backendId});
  final AsrFailureReason reason;
  final String message;
  final String? backendId;

  @override
  String toString() =>
      'AsrFailure(${reason.name}${backendId == null ? '' : ', $backendId'}): $message';
}

/// Once-per-second health numbers used for the CPU budget and auto-degrade.
@immutable
final class AsrStats {
  const AsrStats({
    required this.realTimeFactor,
    required this.queuedMs,
    required this.cpuMsPerSecond,
    this.droppedMs = 0,
  });

  /// Processing time / audio time; < 1 keeps up.
  final double realTimeFactor;
  final int queuedMs;

  /// CPU milliseconds consumed per wall-clock second (100 % of one core is
  /// 1000).
  final double cpuMsPerSecond;
  final int droppedMs;
}

@immutable
final class AsrSessionConfig {
  const AsrSessionConfig({
    required this.language,
    this.source,
    this.endpointSilenceMs = 800,
    this.numThreads = 1,
    this.latency = LatencyTier.balanced,
  });

  /// BCP-47 language, or `auto` for multilingual models.
  final String language;

  /// Live PCM source. Null when the caller pushes samples itself (files,
  /// cloud relays, tests) through [AsrSession.acceptWaveform].
  final NativeAudioSource? source;
  final int endpointSilenceMs;
  final int numThreads;

  /// Picks feed size, threads, endpoint pause and partial rate
  /// ([LatencyTiers.sherpa]); [endpointSilenceMs] and [numThreads] are the
  /// balanced defaults.
  final LatencyTier latency;
}

abstract interface class AsrSession {
  Stream<AsrEvent> get events;

  /// About 1 Hz.
  Stream<AsrStats> get stats;

  /// Pushes samples when no native [AsrSessionConfig.source] is attached.
  void acceptWaveform(Float32List samples, int sampleRate);

  /// Flushes the current segment as a final and stops.
  Future<void> stop();
}

/// Streaming speech recognition: sherpa-onnx in a worker isolate on both
/// platforms; SpeechTranscriber on macOS 26+; cloud WebSocket adapters.
abstract interface class StreamingAsrBackend {
  /// Languages this backend recognises (BCP-47 or `auto`).
  Set<String> get languages;
  Future<AsrSession> start(AsrSessionConfig config);
}

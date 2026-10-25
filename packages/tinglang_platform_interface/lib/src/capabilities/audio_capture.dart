import 'dart:typed_data';

import 'package:meta/meta.dart';

import 'streaming_asr.dart';

/// What a capture backend records.
enum AudioSourceKind { systemAudio, microphone }

/// PCM layout delivered to ASR. Pipeline B fixes this to 16 kHz mono f32 in
/// 100 ms blocks; native code resamples before the ring buffer.
@immutable
final class AudioFormat {
  const AudioFormat({this.sampleRate = 16000, this.channels = 1, this.blockMs = 100});
  final int sampleRate, channels, blockMs;

  int get samplesPerBlock => sampleRate * channels * blockMs ~/ 1000;
}

@immutable
final class AudioCaptureRequest {
  const AudioCaptureRequest({
    this.format = const AudioFormat(),
    this.excludeOwnProcess = true,
    this.deviceId,
    this.recordPath,
  });
  final AudioFormat format;

  /// System audio: leave Tinglang's own playback out of the tap.
  final bool excludeOwnProcess;

  /// Microphone/input device; null is the system default.
  final String? deviceId;

  /// Also write the captured audio here as AAC (.m4a), on the same clock as
  /// the ring, so caption times are offsets into the file.
  final String? recordPath;
}

/// Native single-producer/single-consumer ring buffer that holds PCM on the
/// native side. The ASR worker isolate reads it through FFI after a
/// `NativeCallable.listener` wake-up; PCM never crosses the root isolate.
@immutable
final class NativePcmRing {
  const NativePcmRing({required this.address, required this.capacitySamples});

  /// Address of the native ring struct (0 for in-memory fakes).
  final int address;
  final int capacitySamples;
}

/// Low-rate (≤10 Hz) level meter sample for UI.
@immutable
final class AudioLevel {
  const AudioLevel({required this.rms, required this.peak, required this.at});
  final double rms, peak;
  final Duration at;
}

/// Something went wrong or changed in capture. Surfaced as a banner.
sealed class AudioCaptureIssue {
  const AudioCaptureIssue();
}

/// The tap delivers only zeros (missing `NSAudioCaptureUsageDescription`,
/// revoked permission…). The pipeline may fall back to another backend.
final class SilentTapDetected extends AudioCaptureIssue {
  const SilentTapDetected(this.duration);
  final Duration duration;
}

final class CaptureDeviceChanged extends AudioCaptureIssue {
  const CaptureDeviceChanged(this.deviceName);
  final String deviceName;
}

/// Ring buffer overflowed because the consumer fell behind.
final class FramesDropped extends AudioCaptureIssue {
  const FramesDropped(this.samples);
  final int samples;
}

final class CaptureFailed extends AudioCaptureIssue {
  const CaptureFailed(this.message);
  final String message;
}

/// The recogniser stopped for good ([AsrFailure]); captions cannot go on.
final class RecognizerFailed extends AudioCaptureIssue {
  const RecognizerFailed(this.failure);
  final AsrFailure failure;
}

/// An open capture stream. PCM stays native ([ring]); Dart sees levels and
/// issues only.
abstract interface class NativeAudioSource {
  AudioSourceKind get kind;
  AudioFormat get format;

  /// Where PCM is written; null for fakes that deliver [debugBlocks].
  NativePcmRing? get ring;

  /// In-memory PCM for fakes and tests only. Real sources return null.
  Stream<Float32List>? get debugBlocks;

  Stream<AudioLevel> get levels;
  Stream<AudioCaptureIssue> get issues;
  bool get isRunning;

  Future<void> start();
  Future<void> stop();

  /// Releases native resources; the source cannot be restarted.
  Future<void> close();
}

/// Factory for capture streams: Core Audio tap / ScreenCaptureKit /
/// AVAudioEngine on macOS, WASAPI loopback / capture on Windows.
abstract interface class AudioCaptureBackend {
  AudioSourceKind get kind;
  Future<NativeAudioSource> open(AudioCaptureRequest request);
}

/// Captions keep running untranslated until the OS translation pack for
/// [pair] (e.g. `en→zh-Hans`) is installed.
final class TranslationPackMissing extends AudioCaptureIssue {
  const TranslationPackMissing(this.pair);
  final String pair;
}

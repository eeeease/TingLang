import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../speech_models.dart';
import 'streaming_asr.dart';

/// Basic facts about a local media file.
@immutable
final class MediaInfo {
  const MediaInfo({
    required this.durationMs,
    required this.hasVideo,
    required this.hasAudio,
    this.sampleRate,
    this.channels,
  });
  final int durationMs;
  final bool hasVideo, hasAudio;
  final int? sampleRate, channels;
}

/// Decodes local audio/video into PCM for offline recognition
/// (AVAssetReader on macOS, Media Foundation on Windows).
abstract interface class MediaDecoder {
  Future<MediaInfo> inspect(String path);

  /// Mono f32 blocks at [sampleRate]. Cancel by cancelling the subscription.
  Stream<Float32List> decodePcm(String path, {int sampleRate = 16000});

  /// Decodes the first audio track to a temporary headerless file of mono
  /// little-endian f32 samples at [sampleRate] and returns its path. A worker
  /// isolate reads it, so PCM never passes through the root isolate. The
  /// caller deletes the file.
  Future<String> decodeToFile(String path, {int sampleRate = 16000});
}

/// One recognised sentence of a file transcript.
@immutable
final class TranscriptSegment {
  const TranscriptSegment({
    required this.startMs,
    required this.endMs,
    required this.text,
    this.words,
    this.translation,
  });
  final int startMs, endMs;
  final String text;
  final List<TimedWord>? words;
  final String? translation;
}

@immutable
final class FileTranscript {
  const FileTranscript({required this.language, required this.segments, required this.backendId});
  final String language;
  final List<TranscriptSegment> segments;
  final String backendId;
}

@immutable
final class FileTranscriptionOptions {
  const FileTranscriptionOptions({
    required this.language,
    this.wordTimestamps = true,
    this.numThreads = 4,
    this.translateTo,
    this.speech = const SpeechOptions(),
  });
  final String language;
  final bool wordTimestamps;
  final int numThreads;

  /// Translate every sentence into this language when the pack is installed.
  final String? translateTo;

  /// Accent and dictation hints (the latency tier does not apply to files).
  final SpeechOptions speech;
}

/// A running offline transcription.
abstract interface class TranscriptionJob {
  /// 0.0–1.0 of media duration processed.
  Stream<double> get progress;

  /// Sentences as they are recognised (translation filled in later through
  /// [translations]), so long files can be saved incrementally.
  Stream<TranscriptSegment> get segments;

  /// `(segment index, translated text)` once a sentence is translated.
  Stream<(int, String)> get translations;
  Future<FileTranscript> get result;
  Future<void> cancel();
}

/// Offline batch recognition: Apple SpeechAnalyzer on macOS 26+, sherpa-onnx
/// (Parakeet / X-ASR offline) in a background isolate elsewhere.
abstract interface class FileTranscriber {
  Set<String> get languages;
  Future<MediaInfo> inspect(String path);
  TranscriptionJob transcribe(String path, FileTranscriptionOptions options);
}

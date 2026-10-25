import 'package:meta/meta.dart';

import '../platform_probe.dart';
import '../speech_models.dart';
import 'audio_capture.dart';
import 'streaming_asr.dart';

/// How audio, recognition and translation are wired for a live session.
enum PipelineTopology {
  /// B: native capture → worker isolate (sherpa) → UI + overlay. Default on
  /// both platforms.
  portable,

  /// A: tap + SpeechTranscriber + Apple Translation + NSPanel, all in Swift.
  /// Only enabled if it wins the M0 benchmark.
  nativeMacos,

  /// C: native capture → isolate → provider WebSocket. Opt-in only.
  cloud,
}

@immutable
final class LivePipelineConfig {
  const LivePipelineConfig({
    required this.source,
    required this.asrBackendId,
    required this.language,
    this.translateTo,
    this.translatorBackendId,
    this.showOverlay = true,
    this.recordPath,
    this.speech = const SpeechOptions(),
  });
  final AudioSourceKind source;
  final String asrBackendId;
  final String language;
  final String? translateTo;
  final String? translatorBackendId;
  final bool showOverlay;

  /// Absolute path for an AAC copy of the captured audio, written on the
  /// recognizer's clock so caption times are offsets into this file.
  final String? recordPath;

  /// Latency tier, accent and dictation hints chosen in Settings.
  final SpeechOptions speech;
}

/// A finalised translation for a segment.
@immutable
final class SegmentTranslation {
  const SegmentTranslation(this.segmentId, this.pair, this.text);
  final String segmentId;
  final LanguagePair pair;
  final String text;
}

abstract interface class LiveSession {
  String get sessionId;
  PipelineTopology get topology;

  /// Coalesced to ≤ 10 Hz for UI.
  Stream<AsrEvent> get captions;
  Stream<SegmentTranslation> get translations;
  Stream<AsrStats> get stats;
  Stream<AudioCaptureIssue> get issues;

  /// Input level 0…1 at ≤ 10 Hz.
  Stream<double> get levels;
  Future<void> stop();
}

/// Owns one live session at a time and the wiring for its topology.
abstract interface class LivePipelineHost {
  PipelineTopology get topology;
  Future<LiveSession> start(LivePipelineConfig config);
}

/// Install state of an on-device model or language pack.
enum AssetState { installed, downloadable, unsupported }

/// Optional setup surface a [LivePipelineHost] may implement when its
/// recogniser/translator needs OS-managed assets (macOS speech models and
/// translation packs). The UI asks before triggering any download.
abstract interface class LiveSetupSupport {
  Future<AssetState> speechAssets(String locale);
  Future<void> installSpeechAssets(String locale);
  Future<AssetState> translationPack(LanguagePair pair);

  /// Shows the OS download prompt for [pair]; completes when installed.
  Future<void> installTranslationPack(LanguagePair pair);
}

/// An OS speech-asset download in progress (macOS `AssetInventory`).
abstract interface class SpeechAssetInstall {
  /// 0…1, at most 10 Hz.
  Stream<double> get progress;

  /// Completes when installed; fails with the OS error, or a cancellation.
  Future<void> get done;
  Future<void> cancel();
}

/// Locales the OS recognisers support and have installed (BCP-47, `en-GB`).
@immutable
final class SpeechLocaleInventory {
  const SpeechLocaleInventory({
    this.speechSupported = const {},
    this.speechInstalled = const {},
    this.dictationSupported = const {},
    this.dictationInstalled = const {},
  });
  final Set<String> speechSupported, speechInstalled, dictationSupported, dictationInstalled;
}

/// OS-managed speech models per engine and locale (Apple SpeechTranscriber and
/// DictationTranscriber). Installing is a download the user must approve.
abstract interface class SpeechAssetSupport {
  Future<AssetState> status(String locale, SpeechEngine engine);
  SpeechAssetInstall install(String locale, SpeechEngine engine);

  /// Gives the asset back to the OS (it may be deleted later). Returns
  /// whether anything was released.
  Future<bool> release(String locale, SpeechEngine engine);
  Future<SpeechLocaleInventory> inventory();
}

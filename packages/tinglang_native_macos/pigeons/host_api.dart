// Pigeon definition of the macOS control-plane API.
// Regenerate with: fvm dart run pigeon --input pigeons/host_api.dart
// (run inside packages/tinglang_native_macos). PCM never uses this channel.
import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/host_api.g.dart',
    swiftOut: 'macos/tinglang_native_macos/Sources/tinglang_native_macos/HostApi.g.swift',
    dartPackageName: 'tinglang_native_macos',
  ),
)
enum PermissionStatus { granted, denied, notDetermined, restricted }

class HostProbe {
  HostProbe({
    required this.osMajor,
    required this.osMinor,
    required this.osPatch,
    required this.osVersionString,
    required this.arch,
    required this.microphone,
    required this.screenCapture,
    required this.speechLocales,
  });
  int osMajor;
  int osMinor;
  int osPatch;

  /// ProcessInfo.operatingSystemVersionString, for diagnostics only.
  String osVersionString;

  /// `arm64` or `x86_64` (the running process, not the machine).
  String arch;
  PermissionStatus microphone;

  /// CGPreflightScreenCaptureAccess; never prompts.
  PermissionStatus screenCapture;

  /// SpeechTranscriber.supportedLocales as BCP-47 (empty before macOS 26).
  List<String> speechLocales;
}

/// `installed`, `supported` (needs a download) or `unsupported`.
enum AssetStatus { installed, supported, unsupported }

class LiveStartRequest {
  LiveStartRequest({
    required this.source,
    required this.locale,
    this.targetLanguage,
    required this.showOverlay,
    this.recordPath,
  });

  /// `system` (Core Audio tap, ScreenCaptureKit fallback) or `microphone`.
  String source;

  /// Recognition locale, e.g. `en-US`, `zh-CN`.
  String locale;

  /// Translation target (e.g. `zh-Hans`); null for captions only.
  String? targetLanguage;
  bool showOverlay;

  /// When set, the captured audio is also written here as AAC (.m4a) on the
  /// recognizer's clock, so transcript times are offsets into this file.
  String? recordPath;
}

class MediaFacts {
  MediaFacts({required this.durationMs, required this.hasVideo, required this.hasAudio});
  int durationMs;
  bool hasVideo;
  bool hasAudio;
}

class FileTranscribeRequest {
  FileTranscribeRequest({
    required this.jobId,
    required this.path,
    required this.locale,
    this.targetLanguage,
  });

  /// Used as `sessionId` on every event of this job.
  String jobId;
  String path;
  String locale;
  String? targetLanguage;
}

/// Look of the floating panel plus its localised strings. Colours are
/// 0xAARRGGBB.
class OverlayConfig {
  OverlayConfig({
    required this.fontSize,
    required this.backgroundOpacity,
    required this.showTranslation,
    required this.clickThrough,
    required this.translatingLabel,
    required this.mode,
    required this.background,
    required this.backgroundColor,
    required this.textColor,
    required this.translationColor,
    required this.accentColor,
    required this.fontWeight,
    required this.outline,
    required this.maxLines,
    required this.alignment,
    required this.strings,
    required this.layout,
    required this.scrollbackLines,
  });
  double fontSize;
  double backgroundOpacity;
  bool showTranslation;
  bool clickThrough;

  /// Localised placeholder shown while a final line awaits translation.
  String translatingLabel;

  /// `card` or `text` (captions only, like desktop lyrics).
  String mode;

  /// `glass`, `solid` or `clear`.
  String background;
  int backgroundColor;
  int textColor;
  int translationColor;
  int accentColor;
  int fontWeight;
  bool outline;
  int maxLines;

  /// `leading` or `center`.
  String alignment;

  /// Panel labels by key (see the app's panel_strings.dart).
  Map<String, String> strings;

  /// `stacked` (translation under each line) or `sideBySide` (recognised text
  /// left, translation right).
  String layout;

  /// Lines of the current session the panel keeps for scrolling back.
  int scrollbackLines;
}

/// What the panel shows around the captions. Strings are localised.
class PanelState {
  PanelState({
    required this.phase,
    required this.source,
    this.startedAtMs,
    this.message,
    this.action,
    this.actionLabel,
    this.progress,
    required this.dueCount,
    required this.newRecordings,
    this.sessionId,
    this.summary,
    required this.canStart,
  });

  /// `idle`, `preparing`, `needsSetup`, `listening`, `stopping`, `saved`,
  /// `error`, `notice`.
  String phase;

  /// `system` or `microphone`.
  String source;

  /// Wall-clock start of listening (ms since epoch); the panel runs the timer.
  int? startedAtMs;
  String? message;

  /// The button offered with [message]: an action name as sent back in a
  /// `panel` event.
  String? action;
  String? actionLabel;
  double? progress;
  int dueCount;
  int newRecordings;
  String? sessionId;
  String? summary;
  bool canStart;
}

/// One event from the live engine. `kind` selects which fields are set:
/// - `partial`/`final`: segmentId, text, startMs, endMs (final only)
/// - `translation`: segmentId, text
/// - `level`: level (0…1, ≤10 Hz)
/// - `stats`: cpuMsPerSecond, queuedMs (1 Hz)
/// - `issue`: code (`silent_tap`, `tap_failed`, `fallback_screencapture`,
///   `translation_pack_missing`, `capture_ended`, `asr_failed`,
///   `recording_failed`, `frames_dropped` (message: samples dropped)), message
/// - `hotkey`: code (binding id)
/// - `panel`: code (action name, e.g. `toggle`, `openHistory`), message
///   (its value, e.g. a session id)
/// - `drop`: message (dropped file paths, one per line)
/// - `filesOpened`: files were opened with the app (see `takeOpenedFiles`)
/// - `panelStyle`: message (JSON of the look chosen on the panel)
/// - `stopped`: session ended (message holds a failure reason, if any)
/// - file jobs (sessionId = jobId): `progress` (level 0…1), `final` (with
///   wordsJson), `translation`, `done`, `issue`
/// - speech model downloads (sessionId = requestId): `assetProgress` (level)
/// - captures (sessionId = captureId): `level`, `stats`, `issue`, `stopped`
class LiveEvent {
  LiveEvent({required this.kind});
  String kind;
  String? sessionId;
  String? segmentId;
  String? text;
  int? startMs;
  int? endMs;
  double? level;
  double? cpuMsPerSecond;
  int? queuedMs;
  String? code;
  String? message;

  /// `[{"w":"word","s":ms,"e":ms}]` when the recognizer produced timings.
  String? wordsJson;
}

@HostApi()
abstract class TinglangHostApi {
  @async
  HostProbe probe();

  @async
  AssetStatus speechAssetStatus(String locale);

  /// Downloads the on-device speech model for [locale] (system asset).
  @async
  void installSpeechAssets(String locale);

  @async
  AssetStatus translationStatus(String source, String target);

  /// Shows a small window that lets macOS download the language pack.
  @async
  void prepareTranslation(String source, String target);

  /// Starts capture → SpeechTranscriber → Apple Translation → overlay.
  /// Returns the session id used on all events.
  @async
  String startLive(LiveStartRequest request);

  @async
  void stopLive();

  @async
  MediaFacts inspectMedia(String path);

  /// Transcribes (and optionally translates) a local media file; results
  /// arrive as events. Completes when the job has finished or failed.
  @async
  void transcribeFile(FileTranscribeRequest request);

  void cancelTranscription(String jobId);

  /// Keychain generic passwords (service `dev.eeeease.tinglang`) for
  /// user-supplied API keys. Values never touch the database or logs.
  String? secretRead(String account);
  void secretWrite(String account, String value);
  void secretDelete(String account);

  void configureOverlay(OverlayConfig config);
  void setOverlayVisible(bool visible);
  void resetOverlayPosition();
  void updatePanel(PanelState state);

  /// Shows and focuses the Flutter window (it is hidden at launch).
  void showMainWindow();

  /// Dart started; cancels the fallback that shows the main window.
  void appReady();

  /// `system`, `light` or `dark` for the main window chrome.
  void setWindowAppearance(String mode);

  /// `microphone`, `screenRecording` or `fullDiskAccess`.
  void openSystemSettings(String pane);

  /// Opens an http(s) page in the default browser.
  void openUrl(String url);

  /// Signs in through ASWebAuthenticationSession: opens [url] (https, or
  /// http on this machine) and returns the callback URL on [callbackScheme].
  /// Fails with code `canceled` when the user closes the window.
  @async
  String authenticate(String url, String callbackScheme);

  /// Carbon RegisterEventHotKey; no Accessibility permission needed.
  /// [key] is a single letter; modifiers use the command/shift/option/control
  /// flags.
  bool registerHotkey(String id, String key, bool command, bool shift, bool option, bool control);
  void unregisterHotkey(String id);

  // Speech models, portable capture and helpers for the portable pipeline
  // (feat/speech-models).

  /// Like [startLive] with the recogniser and latency tier chosen in
  /// Settings. Fails with code `assetsMissing` when the speech model for the
  /// locale is not installed (nothing is downloaded at start).
  @async
  String startLiveWith(LiveStartRequest request, SpeechConfig speech);

  /// Like [transcribeFile] with the chosen recogniser (the latency tier does
  /// not apply). Fails with `assetsMissing` like [startLiveWith].
  @async
  void transcribeFileWith(FileTranscribeRequest request, SpeechConfig speech);

  /// [engine] is `appleSpeech` or `appleDictation`.
  @async
  AssetStatus speechAssetStatusFor(String locale, String engine);

  /// Downloads the system speech model for [locale] and [engine]. Progress
  /// arrives as `assetProgress` events (sessionId = [requestId], level 0…1).
  /// Fails with code `canceled` after [cancelSpeechAssets].
  @async
  void installSpeechAssetsFor(String requestId, String locale, String engine);

  void cancelSpeechAssets(String requestId);

  /// Gives the locale's reservation back to macOS (it may then remove the
  /// model). Returns whether a reservation was released.
  @async
  bool releaseSpeechAssets(String locale, String engine);

  /// Supported and installed locales of both Apple recognisers.
  @async
  SpeechInventory speechInventory();

  /// Starts capture now (macOS 14.2+) into a native PCM ring (16 kHz mono
  /// f32, 30 s). Events use the capture id as `sessionId`: `level`, `stats`,
  /// `issue`, `stopped`.
  @async
  CaptureHandle openCapture(CaptureRequest request);

  /// Stops capture, finalises the recording and closes the ring (the reader
  /// drains it, then sees end of stream).
  @async
  void closeCapture(String captureId);

  /// Replaces the panel's caption tail (portable pipeline; ≤30 lines).
  void showCaptionLines(List<CaptionLineMessage> lines, bool awaitingTranslation);

  /// Decodes the first audio track to a temporary headerless file of mono
  /// little-endian f32 at 16 kHz and returns its path (caller deletes it).
  @async
  String decodeToPcmFile(String path);

  /// Apple Translation over installed packs (macOS 26+), order preserved.
  @async
  List<String> translateTexts(String source, String target, List<String> texts);

  /// Whether [translateTexts] can run for the pair now (false below macOS 26).
  @async
  bool translationReady(String source, String target);

  // Files opened with the app, and iCloud Drive for sync.

  /// Files opened with the app from Finder (a double-click, Open With, a
  /// drop on the Dock icon) since the last call, oldest first; each path is
  /// returned once. Files opened before Dart asks are kept. A `filesOpened`
  /// event says when there is something new.
  List<String> takeOpenedFiles();

  /// Download state of each path, in the same order: `local`, `current`,
  /// `outdated`, `notDownloaded` or `missing`.
  @async
  List<String> cloudItemStates(List<String> paths);

  /// Asks macOS to download these iCloud Drive items
  /// (FileManager.startDownloadingUbiquitousItem, `brctl download` as a
  /// fallback). Returns once requested, not when downloaded.
  @async
  void cloudDownload(List<String> paths);

  /// This Mac's IOPlatformUUID (stays on the Mac), or null.
  String? machineIdentifier();
}

@EventChannelApi()
abstract class TinglangEvents {
  LiveEvent liveEvents();
}

/// Which Apple recogniser runs and how (Settings → Speech models).
class SpeechConfig {
  SpeechConfig({
    required this.engine,
    required this.latency,
    this.locale,
    required this.farField,
    required this.shortForm,
  });

  /// `appleSpeech` (SpeechTranscriber) or `appleDictation`
  /// (DictationTranscriber).
  String engine;

  /// `powerSaver`, `balanced` or `fastest` (LatencyTier names).
  String latency;

  /// Overrides the request's locale when set (an English accent).
  String? locale;

  /// DictationTranscriber content hints.
  bool farField;
  bool shortForm;
}

/// BCP-47 locales of both Apple recognisers (empty before macOS 26).
class SpeechInventory {
  SpeechInventory({
    required this.speechSupported,
    required this.speechInstalled,
    required this.dictationSupported,
    required this.dictationInstalled,
  });
  List<String> speechSupported;
  List<String> speechInstalled;
  List<String> dictationSupported;
  List<String> dictationInstalled;
}

class CaptureRequest {
  CaptureRequest({required this.source, this.recordPath});

  /// `system` (Core Audio tap, ScreenCaptureKit fallback) or `microphone`.
  String source;

  /// AAC (.m4a) copy written on the ring's clock.
  String? recordPath;
}

/// An open capture: [ringAddress] is the `TLPR` ring header (see
/// PcmRing.swift); the reader calls its `release` once when done.
class CaptureHandle {
  CaptureHandle({required this.captureId, required this.ringAddress, required this.capacity});
  String captureId;
  int ringAddress;

  /// Ring capacity in samples.
  int capacity;
}

class CaptionLineMessage {
  CaptionLineMessage({
    required this.segmentId,
    required this.text,
    this.translation,
    required this.isFinal,
  });
  String segmentId;
  String text;
  String? translation;
  bool isFinal;
}

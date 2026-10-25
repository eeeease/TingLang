import 'package:meta/meta.dart';

import '../platform_probe.dart';
import 'audio_capture.dart';

/// Translation of finalised sentences only (never partials).
abstract interface class TranslatorBackend {
  /// Pairs that can be translated now (installed / configured).
  Set<LanguagePair> get pairs;

  /// Translates [texts] in one batch, preserving order.
  Future<List<String>> translate(List<String> texts, LanguagePair pair);
}

/// A line shown in the native caption overlay.
@immutable
final class CaptionLine {
  const CaptionLine({
    required this.segmentId,
    required this.text,
    this.translation,
    this.isFinal = false,
  });
  final String segmentId, text;
  final String? translation;
  final bool isFinal;
}

/// `card`: smoked panel with controls. `text`: captions only, like desktop
/// lyrics; controls appear while the pointer is over them.
enum CaptionMode { card, text }

/// Behind the captions: blurred smoked glass, a solid colour, or nothing.
enum CaptionBackground { glass, solid, clear }

enum CaptionAlignment { leading, center }

/// `stacked`: the translation under each line. `sideBySide`: recognised text
/// on the left, its translation on the right, row by row.
enum CaptionLayout { stacked, sideBySide }

/// Look of the floating panel. Colours are 0xAARRGGBB.
@immutable
final class CaptionStyle {
  const CaptionStyle({
    this.fontSize = 22,
    this.maxLines = 2,
    this.showTranslation = true,
    this.backgroundOpacity = .78,
    this.mode = CaptionMode.card,
    this.background = CaptionBackground.glass,
    this.backgroundColor = 0xFF1E1E1D,
    this.textColor = 0xFFF7F7F6,
    this.translationColor = 0xFFB9B9B5,
    this.accentColor = 0xFFFF8A4C,
    this.fontWeight = 500,
    this.outline = true,
    this.alignment = CaptionAlignment.center,
    this.clickThrough = false,
    this.layout = CaptionLayout.stacked,
    this.scrollback = defaultScrollback,
  });

  /// Lines the panel keeps for scrolling back, and the choices offered.
  static const defaultScrollback = 100;
  static const scrollbackChoices = [50, 100, 200, 500];

  final double fontSize;
  final int maxLines;
  final bool showTranslation;
  final double backgroundOpacity;
  final CaptionMode mode;
  final CaptionBackground background;
  final int backgroundColor, textColor, translationColor, accentColor;

  /// 400 regular … 700 bold.
  final int fontWeight;

  /// A dark rim and soft shadow around the text, for transparent backgrounds.
  final bool outline;
  final CaptionAlignment alignment;

  /// Clicks pass through to the window below ("locked").
  final bool clickThrough;

  final CaptionLayout layout;

  /// The panel keeps at most this many lines of the current session for
  /// scrolling back; older ones leave the panel (they stay in the database).
  /// [maxLines] is how many fit in the fixed caption area at once.
  final int scrollback;

  CaptionStyle copyWith({
    double? fontSize,
    int? maxLines,
    bool? showTranslation,
    double? backgroundOpacity,
    CaptionMode? mode,
    CaptionBackground? background,
    int? backgroundColor,
    int? textColor,
    int? translationColor,
    int? accentColor,
    int? fontWeight,
    bool? outline,
    CaptionAlignment? alignment,
    bool? clickThrough,
    CaptionLayout? layout,
    int? scrollback,
  }) => CaptionStyle(
    fontSize: fontSize ?? this.fontSize,
    maxLines: maxLines ?? this.maxLines,
    showTranslation: showTranslation ?? this.showTranslation,
    backgroundOpacity: backgroundOpacity ?? this.backgroundOpacity,
    mode: mode ?? this.mode,
    background: background ?? this.background,
    backgroundColor: backgroundColor ?? this.backgroundColor,
    textColor: textColor ?? this.textColor,
    translationColor: translationColor ?? this.translationColor,
    accentColor: accentColor ?? this.accentColor,
    fontWeight: fontWeight ?? this.fontWeight,
    outline: outline ?? this.outline,
    alignment: alignment ?? this.alignment,
    clickThrough: clickThrough ?? this.clickThrough,
    layout: layout ?? this.layout,
    scrollback: scrollback ?? this.scrollback,
  );

  @override
  bool operator ==(Object other) =>
      other is CaptionStyle &&
      other.fontSize == fontSize &&
      other.maxLines == maxLines &&
      other.showTranslation == showTranslation &&
      other.backgroundOpacity == backgroundOpacity &&
      other.mode == mode &&
      other.background == background &&
      other.backgroundColor == backgroundColor &&
      other.textColor == textColor &&
      other.translationColor == translationColor &&
      other.accentColor == accentColor &&
      other.fontWeight == fontWeight &&
      other.outline == outline &&
      other.alignment == alignment &&
      other.clickThrough == clickThrough &&
      other.layout == layout &&
      other.scrollback == scrollback;

  @override
  int get hashCode => Object.hash(
    fontSize,
    maxLines,
    showTranslation,
    backgroundOpacity,
    mode,
    background,
    backgroundColor,
    textColor,
    translationColor,
    accentColor,
    fontWeight,
    outline,
    alignment,
    clickThrough,
    layout,
    scrollback,
  );
}

/// What the panel is doing, besides drawing captions. `notice` is a short
/// informational message (for example after files were dropped).
enum OverlayPhase { idle, preparing, needsSetup, listening, stopping, saved, error, notice }

/// Buttons on the panel; the app decides what each one does.
enum OverlayAction {
  toggle,
  openHistory,
  openSession,
  makeCourse,
  install,
  retry,
  useSystemAudio,
  useMicrophone,
  openSettings,
  showRecordings,
  hide,

  /// The panel was shown again (Dock menu).
  show,

  /// Stop clicking through (Dock menu, or the unlock chip).
  unlock,
  quit,

  /// Stop a download shown on the panel (sent for `action: cancel`).
  cancel,
}

/// Panel state pushed by the app. Every string is already localised.
@immutable
final class OverlayState {
  const OverlayState({
    required this.phase,
    this.source = AudioSourceKind.systemAudio,
    this.startedAt,
    this.message,
    this.action,
    this.actionLabel,
    this.progress,
    this.dueCount = 0,
    this.newRecordings = 0,
    this.sessionId,
    this.summary,
    this.canStart = true,
  });
  final OverlayPhase phase;
  final AudioSourceKind source;

  /// When listening began; the panel runs its own clock from it.
  final DateTime? startedAt;

  /// One sentence for preparing / needsSetup / error / saved.
  final String? message;

  /// The single button offered with [message], if any.
  final OverlayAction? action;
  final String? actionLabel;

  /// 0…1 for downloads and imports; null when indeterminate.
  final double? progress;
  final int dueCount, newRecordings;

  /// The saved session ([OverlayPhase.saved]).
  final String? sessionId;

  /// For example "12:04 · 1,024 words".
  final String? summary;

  /// False when live captions cannot run on this Mac at all.
  final bool canStart;

  @override
  bool operator ==(Object other) =>
      other is OverlayState &&
      other.phase == phase &&
      other.source == source &&
      other.startedAt == startedAt &&
      other.message == message &&
      other.action == action &&
      other.actionLabel == actionLabel &&
      other.progress == progress &&
      other.dueCount == dueCount &&
      other.newRecordings == newRecordings &&
      other.sessionId == sessionId &&
      other.summary == summary &&
      other.canStart == canStart;

  @override
  int get hashCode => Object.hash(
    phase,
    source,
    startedAt,
    message,
    action,
    actionLabel,
    progress,
    dueCount,
    newRecordings,
    sessionId,
    summary,
    canStart,
  );
}

sealed class OverlayEvent {
  const OverlayEvent();
}

/// A panel button was pressed. [value] carries e.g. a session id.
final class OverlayActionRequested extends OverlayEvent {
  const OverlayActionRequested(this.action, [this.value]);
  final OverlayAction action;
  final String? value;
}

/// Audio/video files dropped on the panel (already copied out of any file
/// promise, so the paths are readable).
final class OverlayFilesDropped extends OverlayEvent {
  const OverlayFilesDropped(this.paths, {this.mainWindow = false});
  final List<String> paths;

  /// Dropped on the main window rather than the panel.
  final bool mainWindow;
}

/// The user changed the look from the panel's own controls.
final class OverlayStyleChanged extends OverlayEvent {
  const OverlayStyleChanged(this.style);
  final CaptionStyle style;
}

final class OverlayClosedByUser extends OverlayEvent {
  const OverlayClosedByUser();
}

final class OverlayMoved extends OverlayEvent {
  const OverlayMoved(this.x, this.y, this.width, this.height);
  final double x, y, width, height;
}

/// Always-on-top caption window drawn natively (NSPanel / layered DirectWrite
/// window). All user-visible strings come from Dart so they are localised.
abstract interface class CaptionOverlay {
  /// Hard limits callers must respect.
  static const maxTailLines = 30;
  static const maxPushHz = 10;

  Future<void> show(CaptionStyle style, {required Map<String, String> strings});
  Future<void> hide();

  /// Moves the panel back to the default place (bottom centre of the main
  /// screen).
  Future<void> resetPosition();

  /// Replaces the visible tail (≤ [maxTailLines] lines, ≤ [maxPushHz] Hz).
  Future<void> pushTail(List<CaptionLine> lines);

  /// Updates the controls and messages around the captions.
  Future<void> setState(OverlayState state);
  Stream<OverlayEvent> get events;
}

enum ShellAppearance { system, light, dark }

enum SystemSettingsPane { microphone, screenRecording, fullDiskAccess }

/// The app's own windows: the panel is the front door and the main window
/// (history, library, settings) opens on demand.
abstract interface class DesktopShell {
  /// Shows and focuses the main window.
  Future<void> showMainWindow();

  /// The app has started; until then the shell may show the main window by
  /// itself so a failed start is never invisible.
  Future<void> ready();
  Future<void> setAppearance(ShellAppearance appearance);
  Future<void> openSystemSettings(SystemSettingsPane pane);

  /// Opens an http(s) page in the default browser.
  Future<void> openUrl(Uri url);

  /// Files the user opened with the app from the system (a double-click in
  /// Finder, Open With, a drop on the Dock icon), oldest first, each returned
  /// once. Files opened before the app was ready are kept until asked for.
  Future<List<String>> takeOpenedFiles();

  /// Fires when [takeOpenedFiles] has something new.
  Stream<void> get filesOpened;
}

/// Signs in through the system's own browser session
/// (ASWebAuthenticationSession on macOS), so the app never sees passwords.
abstract interface class WebAuthenticator {
  /// Opens [url] and completes with the URL the sign-in page redirects to on
  /// [callbackScheme]. Throws [WebAuthCanceled] when the user closes it.
  Future<Uri> authenticate(Uri url, {required String callbackScheme});
}

/// The user closed the sign-in window.
final class WebAuthCanceled implements Exception {
  const WebAuthCanceled();
  @override
  String toString() => 'Sign-in canceled';
}

@immutable
final class HotkeyBinding {
  const HotkeyBinding({
    required this.id,
    required this.key,
    this.command = false,
    this.shift = false,
    this.option = false,
    this.control = false,
  });
  final String id;

  /// Key name such as `T`.
  final String key;
  final bool command, shift, option, control;
}

/// System-wide shortcuts (Carbon RegisterEventHotKey / RegisterHotKey); no
/// Accessibility permission required.
abstract interface class GlobalHotkeys {
  Future<void> register(HotkeyBinding binding);
  Future<void> unregister(String id);

  /// Emits the binding id when pressed.
  Stream<String> get pressed;
}

/// Credentials for user-supplied providers (Keychain / Credential Manager).
/// Values never go to the database, logs or exports.
abstract interface class SecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

sealed class YouTubeEvent {
  const YouTubeEvent();
}

final class YouTubePosition extends YouTubeEvent {
  const YouTubePosition(this.positionMs, {required this.playing});
  final int positionMs;
  final bool playing;
}

/// Embedding refused (IFrame errors 101 / 150 / 153). The app falls back to
/// "open in browser + floating captions"; it never downloads the video.
final class YouTubeEmbedBlocked extends YouTubeEvent {
  const YouTubeEmbedBlocked(this.errorCode);
  final int errorCode;
}

/// Embedded YouTube IFrame player (webview).
abstract interface class YouTubePlayer {
  Future<void> load(String videoId, {int startMs = 0});
  Future<void> play();
  Future<void> pause();
  Future<void> seek(int ms);
  Stream<YouTubeEvent> get events;
  Future<void> dispose();
}

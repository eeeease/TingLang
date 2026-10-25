import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:tinglang_native/tinglang_native.dart';

import '../l10n/app_localizations.dart';
import 'app_controller.dart';
import 'live_controller.dart';

/// Settings keys for the floating panel (stored in `app_meta` like every
/// other setting).
abstract final class PanelKeys {
  static const visible = 'overlay_visible';
  static const clickThrough = 'overlay_click_through';
  static const mode = 'overlay_mode';
  static const background = 'overlay_background';
  static const backgroundColor = 'overlay_background_color';
  static const backgroundOpacity = 'overlay_background_opacity';
  static const textColor = 'overlay_text_color';
  static const translationColor = 'overlay_translation_color';
  static const fontSize = 'overlay_font_size';
  static const fontWeight = 'overlay_font_weight';
  static const outline = 'overlay_outline';
  static const lines = 'overlay_lines';
  static const alignment = 'overlay_alignment';
  static const showTranslation = 'overlay_show_translation';
  static const layout = 'overlay_layout';
  static const scrollback = 'overlay_scrollback';
}

const liveSourceKey = 'live_source';
const keepSystemAudioKey = 'live_keep_system_audio';

/// The next live request from saved settings (source and languages).
LiveRequest liveRequestFrom(AppController app) {
  final language = app.setting(AppController.learningLanguageKey, 'en');
  final native = app.setting(AppController.nativeLanguageKey, 'zh-Hans');
  final mic = app.setting(liveSourceKey, 'system') == 'microphone';
  return LiveRequest(
    source: mic ? AudioSourceKind.microphone : AudioSourceKind.systemAudio,
    // Your own voice is always kept for practice; system audio only on request.
    recordAudio: mic || app.setting(keepSystemAudioKey, 'false') == 'true',
    language: language,
    translateTo: native == language ? null : native,
  );
}

/// The panel's saved look; anything missing or malformed falls back to the
/// default style.
CaptionStyle captionStyleFrom(AppController app) {
  const base = CaptionStyle();
  String? get(String key) => app.state.settings[key];
  int color(String key, int fallback) => int.tryParse(get(key) ?? '') ?? fallback;
  double number(String key, double fallback, double min, double max) =>
      (double.tryParse(get(key) ?? '') ?? fallback).clamp(min, max);
  T pick<T extends Enum>(List<T> values, String key, T fallback) =>
      values.asNameMap()[get(key)] ?? fallback;
  return CaptionStyle(
    mode: pick(CaptionMode.values, PanelKeys.mode, base.mode),
    background: pick(CaptionBackground.values, PanelKeys.background, base.background),
    backgroundColor: color(PanelKeys.backgroundColor, base.backgroundColor),
    backgroundOpacity: number(PanelKeys.backgroundOpacity, base.backgroundOpacity, .2, 1),
    textColor: color(PanelKeys.textColor, base.textColor),
    translationColor: color(PanelKeys.translationColor, base.translationColor),
    fontSize: number(PanelKeys.fontSize, base.fontSize, 14, 48),
    fontWeight: number(PanelKeys.fontWeight, base.fontWeight.toDouble(), 400, 700).round(),
    outline: (get(PanelKeys.outline) ?? '${base.outline}') == 'true',
    maxLines: number(PanelKeys.lines, base.maxLines.toDouble(), 1, 3).round(),
    alignment: pick(CaptionAlignment.values, PanelKeys.alignment, base.alignment),
    showTranslation: (get(PanelKeys.showTranslation) ?? '${base.showTranslation}') == 'true',
    clickThrough: get(PanelKeys.clickThrough) == 'true',
    layout: pick(CaptionLayout.values, PanelKeys.layout, base.layout),
    scrollback: number(
      PanelKeys.scrollback,
      base.scrollback.toDouble(),
      CaptionStyle.scrollbackChoices.first.toDouble(),
      CaptionStyle.scrollbackChoices.last.toDouble(),
    ).round(),
  );
}

/// [style] as settings entries, saved together in one change.
Map<String, String> captionStyleSettings(CaptionStyle style) => {
  PanelKeys.mode: style.mode.name,
  PanelKeys.background: style.background.name,
  PanelKeys.backgroundColor: '${style.backgroundColor}',
  PanelKeys.backgroundOpacity: style.backgroundOpacity.toStringAsFixed(2),
  PanelKeys.textColor: '${style.textColor}',
  PanelKeys.translationColor: '${style.translationColor}',
  PanelKeys.fontSize: style.fontSize.toStringAsFixed(0),
  PanelKeys.fontWeight: '${style.fontWeight}',
  PanelKeys.outline: '${style.outline}',
  PanelKeys.lines: '${style.maxLines}',
  PanelKeys.alignment: style.alignment.name,
  PanelKeys.showTranslation: '${style.showTranslation}',
  PanelKeys.clickThrough: '${style.clickThrough}',
  PanelKeys.layout: style.layout.name,
  PanelKeys.scrollback: '${style.scrollback}',
};

/// The interface language without a widget tree (the panel works before the
/// main window has ever been drawn).
AppLocalizations localizationsFor(AppController app) {
  final saved = app.setting(AppController.uiLocaleKey, 'system');
  final locale = switch (saved) {
    'en' || 'zh' => Locale(saved),
    _ => WidgetsBinding.instance.platformDispatcher.locale,
  };
  final supported = AppLocalizations.supportedLocales.any(
    (l) => l.languageCode == locale.languageCode,
  );
  return lookupAppLocalizations(supported ? Locale(locale.languageCode) : const Locale('en'));
}

/// Labels the native panel draws, by the keys CapturePanelView.swift reads.
Map<String, String> panelStrings(AppLocalizations l) => {
  'appName': l.appTitle,
  'start': l.panelStart,
  'stop': l.liveStop,
  'unavailable': l.panelUnavailable,
  'sourceSystem': l.liveSourceSystem,
  'sourceMic': l.liveSourceMic,
  'history': l.panelHistory,
  'more': l.panelMore,
  'appearance': l.panelAppearance,
  'openApp': l.panelOpenApp,
  'settings': l.panelSettings,
  'hidePanel': l.panelHide,
  'quit': l.panelQuit,
  'listening': l.panelListening,
  'waiting': l.panelWaiting,
  'saving': l.liveStopping,
  'view': l.panelView,
  'makeCourse': l.panelMakeCourse,
  'dropHint': l.panelDropHint,
  'newRecordings': l.panelNewRecordings('{n}'),
  'display': l.panelDisplay,
  'modeCard': l.panelModeCard,
  'modeText': l.panelModeText,
  'background': l.panelBackground,
  'bgGlass': l.panelBgGlass,
  'bgSolid': l.panelBgSolid,
  'bgClear': l.panelBgClear,
  'opacity': l.panelOpacity,
  'backgroundColor': l.panelBackgroundColor,
  'textColor': l.panelTextColor,
  'translationColor': l.panelTranslationColor,
  'fontSize': l.panelFontSize,
  'weightRegular': l.panelWeightRegular,
  'weightMedium': l.panelWeightMedium,
  'weightBold': l.panelWeightBold,
  'lines': l.panelLines,
  'showTranslation': l.panelShowTranslation,
  'outline': l.panelOutline,
  'center': l.panelCenter,
  'lock': l.panelLock,
  'unlock': l.panelUnlock,
  'resetPosition': l.panelResetPosition,
  'layout': l.panelLayout,
  'layoutStacked': l.panelLayoutStacked,
  'layoutSideBySide': l.panelLayoutSideBySide,
  'locked': l.panelLocked,
  'lockToggle': l.panelLockToggle,
  'jumpToLatest': l.panelJumpToLatest,
  'newLines': l.panelNewLines('{n}'),
  'translating': l.liveTranslating,
  'dock_toggle': l.panelDockToggle,
  'dock_showPanel': l.panelDockShow,
  'dock_unlock': l.panelDockUnlock,
  'hintRecord': l.panelHintRecord,
  'hintStop': l.panelHintStop,
  'hintMenu': l.panelHintMenu,
};

/// Messages the panel shows, in the interface language.
final class L10nPanelText implements LivePanelText {
  L10nPanelText(this.l, {this.languageName = _languageName});
  final AppLocalizations l;
  final String Function(String code) languageName;

  static String _languageName(String code) => code;

  @override
  String get preparing => l.panelPreparing;
  @override
  String get downloading => l.panelDownloading;
  @override
  String speechModelNeeded(String language) => l.liveNeedSpeechModel(languageName(language));
  @override
  String translationPackNeeded(String source, String target) =>
      l.liveNeedTranslationPack(l.liveLanguagePair(languageName(source), languageName(target)));
  @override
  String get silentSystemAudio => l.liveIssueSilentTap;
  @override
  String get screenRecordingCapture => l.liveIssueFallback;
  @override
  String get download => l.liveDownload;
  @override
  String get retry => l.panelRetry;
  @override
  String get saved => l.panelSaved;
  @override
  String summary(Duration length, int words) {
    final minutes = length.inMinutes, seconds = length.inSeconds % 60;
    final clock = length.inHours > 0
        ? '${length.inHours}:${(minutes % 60).toString().padLeft(2, '0')}:'
              '${seconds.toString().padLeft(2, '0')}'
        : '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    return l.panelSummary(clock, NumberFormat.decimalPattern(l.localeName).format(words));
  }

  @override
  String failed(String detail) => l.panelFailed(detail);
  @override
  String unavailable(String reason) => l.liveUnavailable(reason);
  @override
  String importing(int count) => l.panelImporting('$count');
}

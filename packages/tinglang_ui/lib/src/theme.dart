import 'package:flutter/material.dart';

import 'tokens.dart';

/// Semantic colours for one brightness: paper and ink neutrals with a single
/// orange accent (finesse "True Neutral + Orange"). Status colours are kept
/// apart from the accent.
@immutable
final class TinglangColors extends ThemeExtension<TinglangColors> {
  const TinglangColors({
    required this.canvas,
    required this.sidebar,
    required this.surface,
    required this.raised,
    required this.line,
    required this.text,
    required this.inkSoft,
    required this.muted,
    required this.accent,
    required this.onAccent,
    required this.accentInk,
    required this.accentSoft,
    required this.warning,
    required this.danger,
    required this.success,
    required this.shadow,
  });

  /// Window background (paper).
  final Color canvas;
  final Color sidebar;

  /// Cards and panels.
  final Color surface;

  /// Insets: inputs, track of a segmented control, code.
  final Color raised;

  /// Hairline borders (translucent ink).
  final Color line;

  /// Headings and primary text.
  final Color text;

  /// Body text that should step back a little.
  final Color inkSoft;

  /// Labels and captions; still AA on [surface] and [canvas].
  final Color muted;

  /// The accent as a fill (primary button, selection, record).
  final Color accent;
  final Color onAccent;

  /// The accent for text and icons on [surface] and [canvas] (AA).
  final Color accentInk;

  /// A faint accent tint for selected rows, chips and focus rings.
  final Color accentSoft;
  final Color warning;
  final Color danger;
  final Color success;

  /// Whisper shadow, tinted toward the ink.
  final Color shadow;

  static const light = TinglangColors(
    canvas: Color(0xFFF5F5F3),
    sidebar: Color(0xFFEEEEEC),
    surface: Color(0xFFFFFFFF),
    raised: Color(0xFFF0F0EE),
    line: Color(0x14171716),
    text: TinglangBrand.ink,
    inkSoft: Color(0xFF4A4A47),
    muted: Color(0xFF6B6B67),
    accent: Color(0xFFBD5520),
    onAccent: Color(0xFFFFFFFF),
    accentInk: Color(0xFFA8471A),
    accentSoft: Color(0x1ABD5520),
    warning: Color(0xFF8A5A00),
    danger: Color(0xFFB3261E),
    success: Color(0xFF2F7A55),
    shadow: Color(0x0F171716),
  );

  static const dark = TinglangColors(
    canvas: Color(0xFF161615),
    sidebar: Color(0xFF1B1B1A),
    surface: Color(0xFF222221),
    raised: Color(0xFF2C2C2A),
    line: Color(0x1AFFFFFF),
    text: Color(0xFFF2F2F0),
    inkSoft: Color(0xFFCFCFCB),
    muted: Color(0xFFA1A19C),
    accent: TinglangBrand.orangeBright,
    onAccent: Color(0xFF1A0F08),
    accentInk: Color(0xFFFF9A62),
    accentSoft: Color(0x26FF8A4C),
    warning: Color(0xFFE8B04A),
    danger: Color(0xFFFF7B72),
    success: Color(0xFF5BC48F),
    shadow: Color(0x66000000),
  );

  @override
  TinglangColors copyWith({
    Color? canvas,
    Color? sidebar,
    Color? surface,
    Color? raised,
    Color? line,
    Color? text,
    Color? inkSoft,
    Color? muted,
    Color? accent,
    Color? onAccent,
    Color? accentInk,
    Color? accentSoft,
    Color? warning,
    Color? danger,
    Color? success,
    Color? shadow,
  }) => TinglangColors(
    canvas: canvas ?? this.canvas,
    sidebar: sidebar ?? this.sidebar,
    surface: surface ?? this.surface,
    raised: raised ?? this.raised,
    line: line ?? this.line,
    text: text ?? this.text,
    inkSoft: inkSoft ?? this.inkSoft,
    muted: muted ?? this.muted,
    accent: accent ?? this.accent,
    onAccent: onAccent ?? this.onAccent,
    accentInk: accentInk ?? this.accentInk,
    accentSoft: accentSoft ?? this.accentSoft,
    warning: warning ?? this.warning,
    danger: danger ?? this.danger,
    success: success ?? this.success,
    shadow: shadow ?? this.shadow,
  );

  @override
  TinglangColors lerp(TinglangColors? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return TinglangColors(
      canvas: mix(canvas, other.canvas),
      sidebar: mix(sidebar, other.sidebar),
      surface: mix(surface, other.surface),
      raised: mix(raised, other.raised),
      line: mix(line, other.line),
      text: mix(text, other.text),
      inkSoft: mix(inkSoft, other.inkSoft),
      muted: mix(muted, other.muted),
      accent: mix(accent, other.accent),
      onAccent: mix(onAccent, other.onAccent),
      accentInk: mix(accentInk, other.accentInk),
      accentSoft: mix(accentSoft, other.accentSoft),
      warning: mix(warning, other.warning),
      danger: mix(danger, other.danger),
      success: mix(success, other.success),
      shadow: mix(shadow, other.shadow),
    );
  }
}

extension TinglangThemeContext on BuildContext {
  /// The active colour tokens.
  TinglangColors get sl => Theme.of(this).extension<TinglangColors>() ?? TinglangColors.light;
}

abstract final class TinglangTheme {
  static ThemeData light() => build(Brightness.light);
  static ThemeData dark() => build(Brightness.dark);

  static ThemeData build(Brightness brightness) {
    final c = brightness == Brightness.dark ? TinglangColors.dark : TinglangColors.light;
    final scheme = ColorScheme(
      brightness: brightness,
      primary: c.accent,
      onPrimary: c.onAccent,
      secondary: c.accentInk,
      onSecondary: c.onAccent,
      error: c.danger,
      onError: brightness == Brightness.dark ? c.onAccent : Colors.white,
      surface: c.surface,
      onSurface: c.text,
      onSurfaceVariant: c.muted,
      outline: c.line,
      outlineVariant: c.line,
      surfaceContainerHighest: c.raised,
      surfaceContainerHigh: c.raised,
      surfaceContainer: c.surface,
      surfaceContainerLow: c.surface,
      surfaceContainerLowest: c.surface,
      primaryContainer: c.accentSoft,
      onPrimaryContainer: c.accentInk,
      secondaryContainer: c.accentSoft,
      onSecondaryContainer: c.accentInk,
    );
    TextStyle on(TextStyle s, [Color? color]) =>
        s.copyWith(color: color ?? c.text, fontFamilyFallback: SlType.cjkFallback);
    final control = RoundedRectangleBorder(borderRadius: SlRadius.all(SlRadius.md));
    const buttonPadding = EdgeInsets.symmetric(horizontal: 16, vertical: 14);
    const buttonText = TextStyle(fontSize: 14, fontWeight: FontWeight.w600);
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.canvas,
      canvasColor: c.canvas,
      dividerColor: c.line,
      dividerTheme: DividerThemeData(color: c.line, thickness: 1, space: 1),
      splashFactory: InkSparkle.splashFactory,
      extensions: [c],
      textTheme: TextTheme(
        headlineLarge: on(SlType.display),
        headlineMedium: on(SlType.headline),
        titleLarge: on(SlType.title),
        titleMedium: on(SlType.subtitle),
        titleSmall: on(SlType.label),
        bodyLarge: on(SlType.bodyLarge),
        bodyMedium: on(SlType.body),
        bodySmall: on(SlType.caption, c.muted),
        labelLarge: on(buttonText),
        labelMedium: on(SlType.label),
        labelSmall: on(SlType.micro, c.muted),
      ),
      iconTheme: IconThemeData(color: c.inkSoft, size: 20),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.raised,
        hintStyle: on(SlType.body, c.muted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: SlRadius.all(SlRadius.md),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: SlRadius.all(SlRadius.md),
          borderSide: BorderSide(color: c.accent, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.accent,
          foregroundColor: c.onAccent,
          disabledBackgroundColor: c.raised,
          disabledForegroundColor: c.muted,
          padding: buttonPadding,
          textStyle: buttonText,
          shape: control,
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.text,
          padding: buttonPadding,
          textStyle: buttonText,
          side: BorderSide(color: c.line),
          shape: control,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.accentInk,
          textStyle: buttonText,
          shape: control,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: c.inkSoft, shape: control),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: c.surface,
          foregroundColor: c.inkSoft,
          selectedBackgroundColor: c.accentSoft,
          selectedForegroundColor: c.accentInk,
          side: BorderSide(color: c.line),
          textStyle: SlType.label,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? c.onAccent : c.muted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? c.accent : c.raised,
        ),
        trackOutlineColor: WidgetStateProperty.all(c.line),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? c.accent : null,
        ),
        checkColor: WidgetStateProperty.all(c.onAccent),
        side: BorderSide(color: c.muted),
        shape: RoundedRectangleBorder(borderRadius: SlRadius.all(4)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? c.accent : c.muted,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.surface,
        selectedColor: c.accentSoft,
        labelStyle: on(SlType.label, c.inkSoft),
        side: BorderSide(color: c.line),
        shape: StadiumBorder(side: BorderSide(color: c.line)),
        showCheckmark: false,
      ),
      listTileTheme: ListTileThemeData(
        selectedColor: c.accentInk,
        selectedTileColor: c.accentSoft,
        iconColor: c.inkSoft,
        shape: control,
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: SlRadius.all(SlRadius.lg),
          side: BorderSide(color: c.line),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: SlRadius.all(SlRadius.lg)),
        titleTextStyle: on(SlType.title),
        contentTextStyle: on(SlType.body, c.inkSoft),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: SlRadius.all(SlRadius.md),
          side: BorderSide(color: c.line),
        ),
        textStyle: on(SlType.body),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStateProperty.all(c.surface),
          surfaceTintColor: WidgetStateProperty.all(Colors.transparent),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: SlRadius.all(SlRadius.md),
              side: BorderSide(color: c.line),
            ),
          ),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: c.text, borderRadius: SlRadius.all(SlRadius.sm)),
        textStyle: on(SlType.caption, c.surface),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: c.text,
        unselectedLabelColor: c.muted,
        indicatorColor: c.accent,
        dividerColor: c.line,
        labelStyle: on(SlType.label),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.sidebar,
        indicatorColor: c.accentSoft,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.text,
        contentTextStyle: on(SlType.body, c.surface),
        actionTextColor: c.accent,
        shape: RoundedRectangleBorder(borderRadius: SlRadius.all(SlRadius.md)),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: c.accent,
        thumbColor: c.accent,
        inactiveTrackColor: c.raised,
        overlayColor: c.accentSoft,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.accent,
        linearTrackColor: c.raised,
        circularTrackColor: c.raised,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(c.muted.withValues(alpha: .35)),
        radius: const Radius.circular(8),
      ),
    );
  }
}

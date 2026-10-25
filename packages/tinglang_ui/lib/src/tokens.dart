// finesse · register=product · shell=sidebar-workbench+floating-panel
// palette=true-neutral+orange · type=system-fixed-scale · SOUL=6 SPECTACLE=2 DENSITY=6
import 'package:flutter/widgets.dart';

/// Fixed brand colours. Prefer [TinglangColors] in widgets; these are for the
/// rare place that must not change with the theme (e.g. the logo).
abstract final class TinglangBrand {
  /// The one accent: "listening", the record button, selection.
  static const orange = Color(0xFFD9642A);

  /// The accent on dark surfaces (and the floating panel).
  static const orangeBright = Color(0xFFFF8A4C);
  static const ink = Color(0xFF171716);
  static const paper = Color(0xFFF7F7F6);
}

/// 4-pt spacing scale.
abstract final class SlSpace {
  static const xxs = 2.0;
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const page = 32.0;
}

/// Controls 12, cards 20, floating shells 28.
abstract final class SlRadius {
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 20.0;
  static const xl = 28.0;
  static const pill = 999.0;

  static BorderRadius all(double r) => BorderRadius.all(Radius.circular(r));
}

/// Fixed type scale (12/13/14/16/18/24/28) on the platform system font. CJK
/// falls back to the OS UI font for Chinese so mixed English/中文 lines share a
/// baseline.
abstract final class SlType {
  static const cjkFallback = <String>[
    'PingFang SC',
    'Hiragino Sans GB',
    'Microsoft YaHei UI',
    'Noto Sans CJK SC',
  ];

  static const display = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -.6,
    height: 1.2,
  );
  static const headline = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: -.4,
    height: 1.25,
  );
  static const title = TextStyle(fontSize: 18, fontWeight: FontWeight.w600, height: 1.35);
  static const subtitle = TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.4);
  static const body = TextStyle(fontSize: 14, height: 1.5);
  static const bodyLarge = TextStyle(fontSize: 16, height: 1.6);

  /// Small headings inside cards and short labels.
  static const label = TextStyle(fontSize: 13, fontWeight: FontWeight.w600, height: 1.4);
  static const caption = TextStyle(fontSize: 12, height: 1.4);
  static const micro = TextStyle(fontSize: 11, height: 1.3);
}

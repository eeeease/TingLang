import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/models.dart';
import '../l10n/app_localizations.dart';
import 'brand_mark_geometry.dart';
import 'errors.dart';

extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

abstract final class Brand {
  static IconData areaIcon(Area area) => switch (area) {
    Area.nba => Icons.sports_basketball_outlined,
    Area.gaming => Icons.sports_esports_outlined,
    Area.cinema => Icons.movie_outlined,
    Area.life => Icons.wb_sunny_outlined,
    Area.podcasts => Icons.podcasts_outlined,
    Area.personal => Icons.graphic_eq_rounded,
  };

  static String areaLabel(AppLocalizations l, Area area) => switch (area) {
    Area.nba => l.areaNba,
    Area.gaming => l.areaGaming,
    Area.cinema => l.areaCinema,
    Area.life => l.areaLife,
    Area.podcasts => l.areaPodcasts,
    Area.personal => l.areaPersonal,
  };
}

/// The Tinglang mark: a thin, sharp sound wave that softens and thickens into
/// a rounded "hi". Drawn as vectors from assets/brand/svg (see
/// brand_mark_geometry.dart); orange to ink on paper, orange to paper on dark.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 42});

  /// The mark's width; its height follows the drawing's proportions.
  final double size;

  /// Below 48 pt the small-size drawing (heavier strokes, larger dot) reads better.
  static BrandMarkDrawing drawingFor(double size) => size < 48 ? brandMarkSmall : brandMarkRegular;

  @override
  Widget build(BuildContext context) {
    final drawing = drawingFor(size);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      label: 'TingLang',
      image: true,
      child: CustomPaint(
        size: Size(size, size * drawing.viewBox.height / drawing.viewBox.width),
        painter: BrandMarkPainter(drawing, dark ? drawing.dark : drawing.light),
      ),
    );
  }
}

class BrandMarkPainter extends CustomPainter {
  const BrandMarkPainter(this.drawing, this.colors);
  final BrandMarkDrawing drawing;
  final BrandMarkColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    final box = drawing.viewBox;
    canvas
      ..scale(size.width / box.width, size.height / box.height)
      ..translate(-box.left, -box.top);
    // Like the SVG's userSpaceOnUse gradient: viewBox coordinates, end colours padded.
    final shader = ui.Gradient.linear(
      drawing.gradientStart,
      drawing.gradientEnd,
      colors.colors,
      colors.stops,
    );
    canvas
      ..drawPath(drawing.wave, Paint()..shader = shader)
      ..drawPath(
        drawing.letters,
        Paint()
          ..shader = shader
          ..style = PaintingStyle.stroke
          ..strokeWidth = drawing.strokeWidth
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      )
      ..drawCircle(drawing.dotCenter, drawing.dotRadius, Paint()..color = colors.dot);
  }

  @override
  bool shouldRepaint(BrandMarkPainter oldDelegate) =>
      oldDelegate.drawing != drawing || oldDelegate.colors != colors;
}

Future<void> reportAction(
  BuildContext context,
  Future<void> Function() action, {
  String? success,
}) async {
  try {
    await action();
    if (context.mounted && success != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(success)));
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(describeError(context.l10n, error)),
          duration: const Duration(seconds: 8),
        ),
      );
    }
  }
}

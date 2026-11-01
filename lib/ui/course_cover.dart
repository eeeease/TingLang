import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/models.dart';
import '../services/app_controller.dart';

/// A course's cover at 16:9: its picture, else its line pattern.
class CourseCover extends StatelessWidget {
  const CourseCover({super.key, required this.app, required this.course});
  final AppController app;
  final Course course;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([app.covers, app]),
    builder: (context, _) {
      final covers = app.covers;
      final file = covers.image(course.id);
      final pattern = PatternCover(
        key: ValueKey('cover-pattern-${course.id}'),
        seed: covers.seed(course.id),
      );
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: file == null
            ? pattern
            : Image.file(
                file,
                key: ValueKey('cover-image-${course.id}'),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => pattern,
              ),
      );
    },
  );
}

/// Lines in a few colours, all chosen by [seed]: stripes, waves, rings,
/// rays or tiles. The same seed always draws the same cover.
class PatternCover extends StatelessWidget {
  const PatternCover({super.key, required this.seed});
  final int seed;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: PatternPainter(seed), child: const SizedBox.expand());
}

typedef _Palette = ({Color ground, List<Color> lines});

class PatternPainter extends CustomPainter {
  PatternPainter(this.seed);
  final int seed;

  static const palettes = <_Palette>[
    (ground: Color(0xFF1F2A44), lines: [Color(0xFFFF7A59), Color(0xFFFFD3B6), Color(0xFF6C8EAD)]),
    (ground: Color(0xFF12372A), lines: [Color(0xFFADBC9F), Color(0xFFFBFADA), Color(0xFF6E9C7E)]),
    (ground: Color(0xFF2D1B3D), lines: [Color(0xFFE0A458), Color(0xFFC9ADA7), Color(0xFF9A8CC8)]),
    (ground: Color(0xFF0B3954), lines: [Color(0xFFBFD7EA), Color(0xFFE0FF4F), Color(0xFF3FB8C4)]),
    (ground: Color(0xFFF4E9D8), lines: [Color(0xFFD9643A), Color(0xFF2E4057), Color(0xFF8C9A9E)]),
    (ground: Color(0xFFE8F3EE), lines: [Color(0xFF1B998B), Color(0xFF2D3047), Color(0xFFFF9B71)]),
    (ground: Color(0xFF111827), lines: [Color(0xFF60A5FA), Color(0xFFF472B6), Color(0xFFFBBF24)]),
    (ground: Color(0xFF7A3B2E), lines: [Color(0xFFF2CC8F), Color(0xFFE07A5F), Color(0xFFF4F1DE)]),
    (ground: Color(0xFFFAF3E0), lines: [Color(0xFF1E1E1E), Color(0xFFE63946), Color(0xFF457B9D)]),
    (ground: Color(0xFF004E64), lines: [Color(0xFF9FFFCB), Color(0xFF25A18E), Color(0xFF7AE582)]),
    (ground: Color(0xFF2A1A12), lines: [Color(0xFFFF8A3D), Color(0xFFFFC48C), Color(0xFF8A5A44)]),
    (ground: Color(0xFFE9E3F5), lines: [Color(0xFF5B4B8A), Color(0xFFF28C8C), Color(0xFF2E2A4F)]),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(seed);
    final palette = palettes[random.nextInt(palettes.length)];
    final rect = Offset.zero & size;
    canvas
      ..clipRect(rect)
      ..drawRect(rect, Paint()..color = palette.ground);
    // Sizes are in hundredths of the short side, so every size looks alike.
    final u = size.shortestSide / 100;
    Paint line() => Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..color = palette.lines[random.nextInt(palette.lines.length)]
      ..strokeWidth = u * (0.8 + random.nextDouble() * 3.2);
    switch (random.nextInt(5)) {
      case 0:
        _stripes(canvas, size, random, u, line);
      case 1:
        _waves(canvas, size, random, u, line);
      case 2:
        _rings(canvas, size, random, u, line);
      case 3:
        _rays(canvas, size, random, u, line);
      default:
        _tiles(canvas, size, random, u, line);
    }
  }

  void _stripes(Canvas canvas, Size size, math.Random random, double u, Paint Function() line) {
    final reach = size.longestSide;
    canvas
      ..save()
      ..translate(size.width / 2, size.height / 2)
      ..rotate((random.nextDouble() * 120 - 60) * math.pi / 180);
    final gap = u * (6 + random.nextDouble() * 12);
    for (var y = -reach; y <= reach; y += gap * (0.6 + random.nextDouble() * 0.8)) {
      canvas.drawLine(Offset(-reach, y), Offset(reach, y), line());
    }
    canvas.restore();
  }

  void _waves(Canvas canvas, Size size, math.Random random, double u, Paint Function() line) {
    final count = 6 + random.nextInt(9);
    final length = size.width / (0.6 + random.nextDouble() * 2.4);
    final height = u * (3 + random.nextDouble() * 12);
    final drift = random.nextDouble() * 0.8;
    for (var i = 0; i < count; i++) {
      final base = size.height * (i + 0.5) / count;
      final path = Path();
      for (var x = 0.0; x <= size.width; x += 2) {
        final y = base + height * math.sin(2 * math.pi * x / length + i * drift);
        x == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
      }
      canvas.drawPath(path, line());
    }
  }

  void _rings(Canvas canvas, Size size, math.Random random, double u, Paint Function() line) {
    final center = Offset(
      size.width * (random.nextDouble() * 1.4 - 0.2),
      size.height * (random.nextDouble() * 1.4 - 0.2),
    );
    final gap = u * (5 + random.nextDouble() * 10);
    final reach = size.longestSide * 1.6;
    for (var r = gap; r < reach; r += gap) {
      canvas.drawCircle(center, r, line());
    }
  }

  void _rays(Canvas canvas, Size size, math.Random random, double u, Paint Function() line) {
    final from = Offset(
      random.nextBool() ? -size.width * 0.1 : size.width * 1.1,
      size.height * random.nextDouble(),
    );
    final count = 40 + random.nextInt(40);
    final start = random.nextDouble() * math.pi * 2;
    final reach = size.longestSide * 2;
    for (var i = 0; i < count; i++) {
      final angle = start + i * math.pi * 2 / count;
      canvas.drawLine(from, from + Offset(math.cos(angle), math.sin(angle)) * reach, line());
    }
  }

  /// Truchet tiles: two quarter circles per square, turned at random.
  void _tiles(Canvas canvas, Size size, math.Random random, double u, Paint Function() line) {
    final cell = u * (12 + random.nextDouble() * 16);
    final paint = line()..strokeWidth = u * (1 + random.nextDouble() * 2.5);
    final r = cell / 2;
    for (var y = 0.0; y < size.height; y += cell) {
      for (var x = 0.0; x < size.width; x += cell) {
        final turned = random.nextBool();
        final a = turned ? Offset(x + cell, y) : Offset(x, y);
        final b = turned ? Offset(x, y + cell) : Offset(x + cell, y + cell);
        final sweepA = turned ? math.pi / 2 : 0.0;
        final sweepB = turned ? -math.pi / 2 : math.pi;
        canvas
          ..drawArc(Rect.fromCircle(center: a, radius: r), sweepA, math.pi / 2, false, paint)
          ..drawArc(Rect.fromCircle(center: b, radius: r), sweepB, math.pi / 2, false, paint);
      }
    }
  }

  @override
  bool shouldRepaint(PatternPainter oldDelegate) => oldDelegate.seed != seed;
}

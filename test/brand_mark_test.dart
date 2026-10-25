import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinglang/ui/brand.dart';
import 'package:tinglang/ui/brand_mark_geometry.dart';

Future<void> _pump(WidgetTester tester, double size, Brightness brightness) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: Center(child: BrandMark(size: size)),
    ),
  );
  // Let the theme change finish animating.
  await tester.pumpAndSettle();
}

Finder get _paint =>
    find.descendant(of: find.byType(BrandMark), matching: find.byType(CustomPaint));

BrandMarkPainter _painter(WidgetTester tester) =>
    tester.widget<CustomPaint>(_paint).painter! as BrandMarkPainter;

bool _inside(Rect outer, Rect inner) =>
    inner.left >= outer.left &&
    inner.top >= outer.top &&
    inner.right <= outer.right &&
    inner.bottom <= outer.bottom;

void main() {
  test('the small drawing is used below 48 pt, the regular one from 48 pt', () {
    expect(BrandMark.drawingFor(22), same(brandMarkSmall));
    expect(BrandMark.drawingFor(47.9), same(brandMarkSmall));
    expect(BrandMark.drawingFor(48), same(brandMarkRegular));
    expect(BrandMark.drawingFor(70), same(brandMarkRegular));
  });

  testWidgets('light: orange to ink with an ink dot; dark: orange to paper', (tester) async {
    await _pump(tester, 24, Brightness.light);
    var painter = _painter(tester);
    expect(painter.drawing, same(brandMarkSmall));
    expect(painter.colors, same(brandMarkSmall.light));
    expect(painter.colors.colors.first, const Color(0xFFF27D38));
    expect(painter.colors.colors.last, const Color(0xFF1C1B19));
    expect(painter.colors.dot, const Color(0xFF1C1B19));

    await _pump(tester, 24, Brightness.dark);
    painter = _painter(tester);
    expect(painter.colors, same(brandMarkSmall.dark));
    expect(painter.colors.colors.first, const Color(0xFFFF8A4C));
    expect(painter.colors.colors.last, const Color(0xFFF4F2EE));
    expect(painter.colors.dot, const Color(0xFFF4F2EE));
  });

  testWidgets('size is the width; the height keeps the drawing proportions', (tester) async {
    await _pump(tester, 70, Brightness.light);
    final box = brandMarkRegular.viewBox;
    expect(_painter(tester).drawing, same(brandMarkRegular));
    expect(tester.getSize(_paint), Size(70, 70 * box.height / box.width));
    expect(find.bySemanticsLabel('TingLang'), findsOneWidget);
  });

  test('every shape stays inside its viewBox', () {
    for (final drawing in [brandMarkRegular, brandMarkSmall]) {
      final box = drawing.viewBox;
      expect(_inside(box, drawing.wave.getBounds()), isTrue);
      expect(_inside(box, drawing.letters.getBounds().inflate(drawing.strokeWidth / 2)), isTrue);
      expect(
        _inside(box, Rect.fromCircle(center: drawing.dotCenter, radius: drawing.dotRadius)),
        isTrue,
      );
      // Light and dark share one gradient line; stops run from 0 to 1.
      for (final colors in [drawing.light, drawing.dark]) {
        expect(colors.stops.first, 0);
        expect(colors.stops.last, 1);
        expect(colors.colors, hasLength(colors.stops.length));
      }
    }
  });
}

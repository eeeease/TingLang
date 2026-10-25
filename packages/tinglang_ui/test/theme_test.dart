import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinglang_ui/tinglang_ui.dart';

double contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + .05) / (lo + .05);
}

void main() {
  test('orange is the one accent; light uses a deeper fill so white labels pass', () {
    expect(TinglangColors.dark.accent, TinglangBrand.orangeBright);
    expect(TinglangColors.light.accent.toARGB32() >> 16 & 0xFF, greaterThan(0xA0));
    expect(contrast(Colors.white, TinglangColors.light.accent), greaterThanOrEqualTo(4.5));
  });
  for (final colors in [TinglangColors.light, TinglangColors.dark]) {
    test('text and accent ink meet WCAG AA on surfaces '
        '(${colors == TinglangColors.light ? 'light' : 'dark'})', () {
      for (final background in [colors.surface, colors.canvas]) {
        expect(contrast(colors.text, background), greaterThanOrEqualTo(4.5));
        expect(contrast(colors.inkSoft, background), greaterThanOrEqualTo(4.5));
        expect(contrast(colors.muted, background), greaterThanOrEqualTo(4.5));
        expect(contrast(colors.accentInk, background), greaterThanOrEqualTo(4.5));
        expect(contrast(colors.danger, background), greaterThanOrEqualTo(4.5));
      }
      expect(contrast(colors.onAccent, colors.accent), greaterThanOrEqualTo(4.5));
    });
  }
  testWidgets('themes expose tokens through context.sl', (tester) async {
    late TinglangColors seen;
    await tester.pumpWidget(
      MaterialApp(
        theme: TinglangTheme.light(),
        darkTheme: TinglangTheme.dark(),
        themeMode: ThemeMode.dark,
        home: Builder(
          builder: (context) {
            seen = context.sl;
            return const Scaffold(
              body: SlEmptyState(
                icon: Icons.podcasts,
                title: 'Empty',
                body: 'Nothing yet',
                badges: [SlBadge.cloud('Cloud')],
              ),
            );
          },
        ),
      ),
    );
    expect(seen, TinglangColors.dark);
    expect(find.text('Cloud'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

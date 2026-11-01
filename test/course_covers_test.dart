import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinglang/core/library_store.dart';
import 'package:tinglang/core/models.dart';
import 'package:tinglang/l10n/app_localizations.dart';
import 'package:tinglang/services/app_controller.dart';
import 'package:tinglang/services/course_covers.dart';
import 'package:tinglang/ui/course_cover.dart';
import 'package:tinglang/ui/library_page.dart';
import 'package:tinglang_ui/tinglang_ui.dart';

import 'update/update_fakes.dart';

Course _course(String id, [Map<String, Object?> raw = const {}]) => Course(
  id: id,
  title: 'A talk',
  area: Area.podcasts,
  clips: const [],
  raw: raw,
  importedAt: DateTime.utc(2026, 11, 1),
);

void main() {
  late Directory dir;
  late AppController app;
  const jpeg = [0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3];
  const png = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('tinglang-covers-');
    app = AppController(LibraryStore(dir), LibraryState());
  });
  tearDown(() async {
    app.dispose();
    await dir.delete(recursive: true);
  });

  group('online courses', () {
    test('YouTube ids come from the page address in its usual forms', () {
      for (final url in [
        'https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=10s',
        'https://youtu.be/dQw4w9WgXcQ',
        'https://m.youtube.com/shorts/dQw4w9WgXcQ',
        'https://www.youtube.com/embed/dQw4w9WgXcQ',
      ]) {
        expect(youtubeVideoId(Uri.parse(url)), 'dQw4w9WgXcQ', reason: url);
      }
      expect(youtubeVideoId(Uri.parse('https://www.bilibili.com/video/BV1')), isNull);
      expect(youtubeVideoId(Uri.parse('https://www.youtube.com/watch?v=short')), isNull);
    });

    test('only https pages play online', () {
      expect(_course('x', {'tinglang_source_url': 'http://insecure.example/v'}).sourceUrl, isNull);
      expect(_course('x', {'tinglang_source_url': 'https://example.com/v'}).playsOnline, isTrue);
    });
  });

  group('covers', () {
    test('every course has a pattern of its own until it is shuffled', () async {
      final covers = app.covers;
      expect(covers.image('c1'), isNull);
      expect(covers.seed('c1'), covers.seed('c1'));
      expect(covers.seed('c1'), isNot(covers.seed('c2')));
      final before = covers.seed('c1');
      await covers.shuffle('c1', math.Random(7));
      expect(covers.seed('c1'), isNot(before));
      expect(covers.seed('c2'), CourseCovers(app).seed('c2'));
    });

    test('a chosen picture comes first and can be removed again', () async {
      final covers = app.covers;
      expect(await covers.saveOwn('c1', jpeg), isTrue);
      expect(covers.image('c1')!.path, endsWith('covers/c1.jpg'));

      final picture = File('${dir.path}/mine.png')..writeAsBytesSync(png);
      await covers.choose('c1', picture);
      expect(covers.image('c1')!.readAsBytesSync(), png);
      expect(covers.custom('c1')!.path, endsWith('mine/c1.png'));

      await covers.clearCustom('c1');
      expect(covers.custom('c1'), isNull);
      expect(covers.image('c1')!.readAsBytesSync(), jpeg);
    });

    test('only pictures are kept', () async {
      final text = File('${dir.path}/notes.png')..writeAsStringSync('not a picture');
      await expectLater(app.covers.choose('c1', text), throwsFormatException);
      expect(await app.covers.saveOwn('c1', [1, 2, 3, 4]), isFalse);
      expect(app.covers.image('c1'), isNull);
    });
  });

  testWidgets('a course card without a picture draws its pattern and offers covers', (
    tester,
  ) async {
    // Made inside the test, so its saves run in the test's clock.
    final app = AppController(MemoryStore(), LibraryState());
    addTearDown(app.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: TinglangTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: Scaffold(
          body: SizedBox(
            width: 360,
            child: CourseCard(course: _course('c1'), app: app, onTap: () {}),
          ),
        ),
      ),
    );
    expect(find.byType(PatternCover), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('course-menu-c1')));
    await tester.pumpAndSettle();
    expect(find.text('更换封面图片…'), findsOneWidget);
    expect(find.text('换一个花纹'), findsOneWidget);
    expect(find.text('移除封面图片'), findsNothing);

    final seed = app.covers.seed('c1');
    await tester.tap(find.text('换一个花纹'));
    await app.flush();
    await tester.pumpAndSettle();
    expect(app.covers.seed('c1'), isNot(seed));
    expect((tester.widget<PatternCover>(find.byType(PatternCover))).seed, app.covers.seed('c1'));
  });
}

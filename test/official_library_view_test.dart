import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinglang/core/library_store.dart';
import 'package:tinglang/l10n/app_localizations.dart';
import 'package:tinglang/services/app_controller.dart';
import 'package:tinglang/services/official_library.dart';
import 'package:tinglang/ui/official_library_view.dart';
import 'package:tinglang_api/tinglang_api.dart';
import 'package:tinglang_ui/tinglang_ui.dart';

import 'update/update_fakes.dart' show MemoryStore;

void main() {
  testWidgets('official courses show as cards with an add button', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final app = AppController(MemoryStore(), LibraryState());
    final official =
        OfficialLibraryService(
            app: app,
            api: () => TinglangApi(ServerUrl.parse('https://api.tinglang.example')),
          )
          // Already read, so the view asks nothing.
          ..library = const OfficialLibrary(
            courses: [
              LibraryEntry(
                id: 'lex-0490-state-of-ai-in-2026',
                title: 'State of AI in 2026 | Lex Fridman Podcast #490',
                clipCount: 16,
                version: 'v1',
                area: 'podcasts',
                sourceLabel: 'Lex Fridman Podcast · YouTube',
                learnerLevel: 'B2',
              ),
            ],
          );
    await tester.pumpWidget(
      MaterialApp(
        theme: TinglangTheme.light(),
        locale: const Locale('zh'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: OfficialLibraryView(official: official, onOpen: (_) {}),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('State of AI in 2026 | Lex Fridman Podcast #490'), findsOneWidget);
    expect(find.textContaining('Lex Fridman Podcast · YouTube'), findsOneWidget);
    expect(find.byKey(const ValueKey('official-add-lex-0490-state-of-ai-in-2026')), findsOneWidget);
    expect(find.textContaining('连接 tinglang.app'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('categories filter the cards; courses in none show under Other', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final app = AppController(MemoryStore(), LibraryState());
    LibraryEntry entry(String id, String? category) =>
        LibraryEntry(id: id, title: 'Course $id', clipCount: 3, version: 'v1', category: category);
    final official =
        OfficialLibraryService(
            app: app,
            api: () => TinglangApi(ServerUrl.parse('https://api.tinglang.example')),
          )
          ..library = OfficialLibrary(
            categories: const [
              LibraryCategory(id: 'news', names: {'en': 'News', 'zh': '新闻时事'}),
              LibraryCategory(id: 'sports', names: {'en': 'Sports', 'zh': '体育'}),
              LibraryCategory(id: 'health', names: {'en': 'Health'}),
            ],
            courses: [
              entry('a', 'news'),
              entry('b', 'sports'),
              entry('c', 'sports'),
              entry('d', null),
            ],
          );
    await tester.pumpWidget(
      MaterialApp(
        theme: TinglangTheme.light(),
        locale: const Locale('zh'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: OfficialLibraryView(official: official, onOpen: (_) {}),
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining('Course '), findsNWidgets(4));
    // Named in the app's language; a category without courses is not offered.
    expect(find.text('新闻时事'), findsOneWidget);
    expect(find.text('Health'), findsNothing);
    await tester.tap(find.text('体育'));
    await tester.pump();
    expect(find.text('Course b'), findsOneWidget);
    expect(find.text('Course c'), findsOneWidget);
    expect(find.text('Course a'), findsNothing);
    await tester.tap(find.text('其他'));
    await tester.pump();
    expect(find.text('Course d'), findsOneWidget);
    expect(find.textContaining('Course '), findsOneWidget);
    await tester.tap(find.text('全部'));
    await tester.pump();
    expect(find.textContaining('Course '), findsNWidgets(4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('signed out, the preview says how many courses there are and offers sign-in', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final app = AppController(MemoryStore(), LibraryState());
    final account = _Account();
    LibraryEntry entry(String id) =>
        LibraryEntry(id: id, title: 'Course $id', clipCount: 3, version: 'v1', category: 'news');
    final official =
        OfficialLibraryService(
            app: app,
            account: account,
            api: () => TinglangApi(ServerUrl.parse('https://api.tinglang.example')),
          )
          ..library = OfficialLibrary(
            preview: true,
            courseCount: 2118,
            categories: const [
              LibraryCategory(id: 'news', names: {'en': 'News', 'zh': '新闻时事'}, courseCount: 101),
            ],
            courses: [entry('a'), entry('b'), entry('c')],
          );
    await tester.pumpWidget(
      MaterialApp(
        theme: TinglangTheme.light(),
        locale: const Locale('zh'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: OfficialLibraryView(official: official, onOpen: (_) {}),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('未登录时，每个分类只显示 3 门课程。登录后可以看到全部 2118 门。'), findsOneWidget);
    await tester.tap(find.text('新闻时事'));
    await tester.pump();
    expect(find.text('这个分类还有 98 门课程，登录后可见'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('official-sign-in')));
    await tester.pump();
    expect(account.signIns, 1);
    expect(tester.takeException(), isNull);
  });
}

final class _Account extends ChangeNotifier implements LibraryAccount {
  int signIns = 0;
  @override
  bool get signedIn => false;
  @override
  Object? get error => null;
  @override
  Future<void> signIn() async => signIns++;
}

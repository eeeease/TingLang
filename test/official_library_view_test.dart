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
}

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinglang/core/db/database.dart';
import 'package:tinglang/core/library_store.dart';
import 'package:tinglang/core/live_repository.dart';
import 'package:tinglang/l10n/app_localizations.dart';
import 'package:tinglang/services/app_controller.dart';
import 'package:tinglang/services/live_controller.dart';
import 'package:tinglang/services/panel_settings.dart';
import 'package:tinglang/ui/language_setup_dialog.dart';
import 'package:tinglang_ui/tinglang_ui.dart';

import 'update/update_fakes.dart' show MemoryStore;

void main() {
  testWidgets('the first start saves the languages and lets captions start', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final app = AppController(MemoryStore(), LibraryState());
    final db = TinglangDatabase.memory();
    addTearDown(() => tester.runAsync(db.close));
    final live = LiveController(repository: LiveRepository(db));
    bool? started;
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
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async =>
                  started = await showLanguageSetup(context, app: app, live: live),
              child: const Text('start'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('start'));
    await tester.pumpAndSettle();
    expect(find.text('实时字幕的语言'), findsOneWidget);
    expect(find.textContaining('logo 的菜单'), findsOneWidget);

    // Recognise English (preset), translate into nothing.
    await tester.tap(find.byKey(const ValueKey('language-setup-translate')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('不翻译').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('language-setup-start')));
    await tester.pumpAndSettle();

    expect(started, isTrue);
    expect(app.setting(languagesChosenKey, ''), 'true');
    expect(app.setting(liveTranslateKey, ''), 'false');
    final request = liveRequestFrom(app);
    expect((request.language, request.translateTo), ('en', null));
  });
}

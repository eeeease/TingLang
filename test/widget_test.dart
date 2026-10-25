import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinglang/core/library_store.dart';
import 'package:tinglang/services/app_controller.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:tinglang/l10n/app_localizations.dart';
import 'package:tinglang_ui/tinglang_ui.dart';
import 'package:tinglang/ui/review_page.dart';

void main() {
  testWidgets('empty Review says how cards arrive, not invented statistics', (tester) async {
    // Real dart:io must run inside tester.runAsync: the testWidgets fake-async
    // zone would otherwise never flush the real IO completion microtask.
    final dir = (await tester.runAsync(() => Directory.systemTemp.createTemp('tinglang-widget-')))!;
    final app = AppController(LibraryStore(dir), LibraryState());
    addTearDown(() async {
      app.dispose();
      await tester.runAsync(() => dir.delete(recursive: true));
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: TinglangTheme.dark(),
        locale: const Locale('zh'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ReviewPage(app: app, onOpen: (_, _) {}),
        ),
      ),
    );
    expect(find.text('还没有要复习的表达'), findsOneWidget);
    expect(find.text('学习课程时收藏有用的表达，到期后会回到这里。'), findsOneWidget);
    expect(find.textContaining(RegExp(r'\d')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinglang/core/library_store.dart';
import 'package:tinglang/l10n/app_localizations.dart';
import 'package:tinglang/services/app_controller.dart';
import 'package:tinglang/services/panel_settings.dart';
import 'package:tinglang/ui/settings_page.dart';
import 'package:tinglang_ui/tinglang_ui.dart';

void main() {
  Future<void> pumpSettings(WidgetTester tester, Map<String, String> settings) async {
    final dir = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('tinglang-settings-'),
    ))!;
    final app = AppController(LibraryStore(dir), LibraryState(settings: settings));
    addTearDown(() async {
      app.dispose();
      await tester.runAsync(() => dir.delete(recursive: true));
    });
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
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
          body: SettingsPage(app: app, tab: SettingsTab.captions),
        ),
      ),
    );
  }

  testWidgets('Settings offers the panel layout and how many lines it keeps', (tester) async {
    await pumpSettings(tester, {});
    expect(find.text('悬浮窗排列'), findsOneWidget);
    expect(find.text('上下'), findsOneWidget);
    expect(find.text('悬浮窗可回看的行数'), findsOneWidget);
    expect(find.text('100 行'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Settings shows the saved layout and scroll-back', (tester) async {
    await pumpSettings(tester, {PanelKeys.layout: 'sideBySide', PanelKeys.scrollback: '500'});
    expect(find.text('左右对照'), findsOneWidget);
    expect(find.text('500 行'), findsOneWidget);
  });

  testWidgets('Settings has one tab per kind of setting; each shows only its own', (tester) async {
    await pumpSettings(tester, {});
    // The captions tab is shown; general settings are on their own tab.
    expect(find.text('悬浮窗排列'), findsOneWidget);
    expect(find.text('界面语言'), findsNothing);
    for (final label in ['通用', '实时字幕', '数据', '关于']) {
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('settings-tabs')),
          matching: find.text(label),
        ),
        findsOneWidget,
      );
    }
    // Without the services the app passes in, their tabs are not offered.
    expect(find.text('语音识别'), findsNothing);
    expect(find.text('AI 服务'), findsNothing);
  });
}

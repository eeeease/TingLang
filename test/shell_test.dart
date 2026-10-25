import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinglang/app.dart';
import 'package:tinglang/core/library_store.dart';
import 'package:tinglang/core/db/database.dart';
import 'package:tinglang/core/live_repository.dart';
import 'package:tinglang/services/app_controller.dart';
import 'package:tinglang/services/live_controller.dart';
import 'package:tinglang/services/transcription_controller.dart';
import 'package:tinglang/services/playback_hub.dart';
import 'package:tinglang/services/recording_service.dart';

void main() {
  testWidgets('sidebar reaches every section; UI language is a separate setting', (tester) async {
    // The record plugin creates its native recorder eagerly; no recording happens here.
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('com.llfbandit.record/messages'),
      (call) async => null,
    );
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final dir = (await tester.runAsync(() => Directory.systemTemp.createTemp('tinglang-shell-')))!;
    final store = LibraryStore(dir);
    final app = AppController(
      store,
      LibraryState(
        settings: {AppController.uiLocaleKey: 'zh', AppController.learningLanguageKey: 'ja'},
      ),
    );
    addTearDown(() => tester.runAsync(() => dir.delete(recursive: true)));
    final db = TinglangDatabase.memory();
    addTearDown(() => tester.runAsync(db.close));
    final live = LiveController(repository: LiveRepository(db));
    await tester.pumpWidget(
      TinglangApp(
        controller: app,
        playback: PlaybackHub(),
        recorder: RecordingService(store),
        live: live,
        transcription: TranscriptionController(repository: live.repository, store: store),
        navigation: ValueNotifier(null),
        exitNotice: ValueNotifier(null),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> tap(Finder finder) async {
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    // History opens first: captions, review and speaking are its tabs. The
    // mark and the name share a line, with the version under the name.
    expect(find.text('听浪'), findsOneWidget);
    expect(find.text('v$appVersion'), findsOneWidget);
    final brand = find.byKey(const ValueKey('sidebar-brand'));
    expect(tester.widget(brand), isA<Row>());
    expect(find.text('还没有记录'), findsOneWidget);
    await tap(find.text('复习'));
    expect(find.text('还没有要复习的表达'), findsOneWidget);
    await tap(find.text('说说'));
    expect(find.text('可以聊训练、游戏、学习，或今天的一件小事。也可以完全换一个话题。'), findsOneWidget);

    // Library: mine, discover, shared.
    await tap(find.byKey(const ValueKey('nav-library')));
    expect(find.text('从一段你真正感兴趣的内容开始。'), findsOneWidget);
    await tap(find.text('发现'));
    expect(find.text('精选播客与频道即将加入'), findsOneWidget);
    await tap(find.text('共享'));
    expect(find.text('社区共享即将上线'), findsOneWidget);

    await tap(find.byKey(const ValueKey('nav-settings')));
    expect(find.text('通用'), findsOneWidget);
    expect(find.text('界面语言'), findsOneWidget);
    expect(find.text('显示悬浮窗'), findsNothing, reason: 'the captions tab holds it');
    await tap(find.text('实时字幕'));
    expect(find.text('显示悬浮窗'), findsOneWidget);
    await tap(find.text('关于'));
    expect(find.text('版本 $appVersion'), findsOneWidget);

    // Coming back keeps the tab that was open.
    await tap(find.byKey(const ValueKey('nav-records')));
    expect(find.text('可以聊训练、游戏、学习，或今天的一件小事。也可以完全换一个话题。'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Switching the interface language leaves the learning language alone.
    await tester.runAsync(() => app.setSetting(AppController.uiLocaleKey, 'en'));
    await tester.pumpAndSettle();
    expect(find.text('TingLang'), findsWidgets);
    expect(find.text('History'), findsWidgets);
    expect(app.setting(AppController.learningLanguageKey, 'en'), 'ja');
  });

  test('settings map to locale and theme mode', () {
    expect(uiLocaleFor('system'), isNull);
    expect(uiLocaleFor('zh'), const Locale('zh'));
    expect(themeModeFor('dark'), ThemeMode.dark);
    expect(themeModeFor('bogus'), ThemeMode.system);
  });
}

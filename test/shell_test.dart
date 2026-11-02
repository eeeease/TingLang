import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinglang/app.dart';
import 'package:tinglang/core/library_store.dart';
import 'package:tinglang/core/db/database.dart';
import 'package:tinglang/core/live_repository.dart';
import 'package:tinglang/core/review.dart';
import 'package:tinglang/services/panel_coordinator.dart';
import 'package:tinglang/services/app_controller.dart';
import 'package:tinglang/services/live_controller.dart';
import 'package:tinglang/services/transcription_controller.dart';
import 'package:tinglang/services/playback_hub.dart';
import 'package:tinglang/services/recording_service.dart';
import 'package:tinglang/services/update_service.dart';

import 'update/update_fakes.dart' show MemoryStore;

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
    await tap(find.text('官方素材'));
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

  testWidgets('the count by History is cards due: it says so and opens Review', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('com.llfbandit.record/messages'),
      (call) async => null,
    );
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final app = AppController(
      MemoryStore(),
      LibraryState(
        settings: {AppController.uiLocaleKey: 'zh'},
        reviews: [
          ReviewCard(
            id: 'r1',
            courseId: 'c',
            clipId: 'a',
            text: 'show up',
            meaning: '坚持参与',
            dueAt: DateTime.utc(2026),
          ),
        ],
      ),
    );
    final db = TinglangDatabase.memory();
    addTearDown(() => tester.runAsync(db.close));
    final live = LiveController(repository: LiveRepository(db));
    final navigation = ValueNotifier<ShellRequest?>(null);
    await tester.pumpWidget(
      TinglangApp(
        controller: app,
        playback: PlaybackHub(),
        recorder: RecordingService(MemoryStore()),
        live: live,
        transcription: TranscriptionController(repository: live.repository, store: MemoryStore()),
        navigation: navigation,
        exitNotice: ValueNotifier(null),
      ),
    );
    await tester.pumpAndSettle();

    final count = find.byKey(const ValueKey('nav-records-count'));
    expect(count, findsOneWidget);
    expect(find.byTooltip('1 张卡片待复习，点这里复习'), findsOneWidget);
    expect(find.text('坚持参与'), findsNothing, reason: 'History opens on captions');
    await tester.tap(count);
    await tester.pumpAndSettle();
    expect(find.text('坚持参与'), findsOneWidget);

    // The panel's history button, with cards due, opens Review too.
    await tester.tap(find.text('字幕'));
    await tester.pumpAndSettle();
    expect(find.text('坚持参与'), findsNothing);
    navigation.value = const OpenHistory();
    await tester.pumpAndSettle();
    expect(find.text('坚持参与'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a newer version puts a green arrow on the mark that opens the update', (
    tester,
  ) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('com.llfbandit.record/messages'),
      (call) async => null,
    );
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final release = UpdateRelease.fromGitHub({
      'tag_name': 'v99.0.0',
      'draft': false,
      'prerelease': false,
      'assets': [
        for (final name in ['Tinglang-99.0.0-macOS.zip', 'Tinglang-99.0.0-macOS.zip.sha256'])
          {
            'name': name,
            'size': 100,
            'browser_download_url':
                'https://github.com/eeeease/TingLang/releases/download/v99.0.0/$name',
          },
      ],
    }, UpdateEndpoints.gitHub)!;
    final store = MemoryStore();
    final app = AppController(
      store,
      LibraryState(
        settings: {
          AppController.uiLocaleKey: 'en',
          UpdateService.releaseKey: jsonEncode(release.toJson()),
        },
      ),
    );
    final updates = UpdateService(app: app, appVersion: appVersion);
    addTearDown(updates.dispose);
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
        updates: updates,
      ),
    );
    await tester.pumpAndSettle();

    // The whole arrow sits on the mark inside the sidebar's brand row, so a
    // click anywhere on it lands.
    final badge = find.byKey(const ValueKey('update-badge'));
    final row = tester.getRect(find.byKey(const ValueKey('sidebar-brand')));
    final arrow = tester.getRect(badge);
    expect(
      row.contains(arrow.topLeft) && row.contains(arrow.bottomRight - const Offset(1, 1)),
      isTrue,
    );
    await tester.tapAt(arrow.topRight + const Offset(-3, 3));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('update-dialog')), findsOneWidget);
    expect(find.text('TingLang 99.0.0 is available'), findsOneWidget);
  });

  testWidgets(
    'a recording can be renamed from History; an empty name goes back to the first line',
    (tester) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('com.llfbandit.record/messages'),
        (call) async => null,
      );
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final store = MemoryStore();
      final app = AppController(store, LibraryState(settings: {AppController.uiLocaleKey: 'en'}));
      final db = TinglangDatabase.memory();
      addTearDown(() => tester.runAsync(db.close));
      final repository = LiveRepository(db);
      await tester.runAsync(() async {
        await repository.createSession(
          id: 's1',
          origin: 'live_system',
          language: 'en',
          title: '',
          startedAt: DateTime.now().toUtc(),
        );
        await repository.addSegments('s1', [
          (
            id: 's1-0',
            startMs: 0,
            endMs: 2000,
            text: 'Hello from the panel.',
            language: 'en',
            wordsJson: null,
          ),
        ]);
        await repository.endSession('s1', status: 'completed', endedAt: DateTime.now().toUtc());
      });
      final live = LiveController(repository: repository);
      await tester.pumpWidget(
        TinglangApp(
          controller: app,
          playback: PlaybackHub(),
          recorder: RecordingService(store),
          live: live,
          transcription: TranscriptionController(repository: repository, store: store),
          navigation: ValueNotifier(null),
          exitNotice: ValueNotifier(null),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Hello from the panel.'), findsOneWidget);

      Future<void> rename(String name) async {
        await tester.tap(find.byTooltip('More'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('session-rename')));
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(const ValueKey('session-rename-field')), name);
        await tester.tap(find.byKey(const ValueKey('session-rename-save')));
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pumpAndSettle();
      }

      await rename('  Lakers recap  ');
      expect(find.text('Lakers recap'), findsOneWidget);
      expect((await tester.runAsync(() => repository.session('s1')))!.title, 'Lakers recap');

      await rename('');
      expect(find.text('Hello from the panel.'), findsOneWidget);
    },
  );

  test('settings map to locale and theme mode', () {
    expect(uiLocaleFor('system'), isNull);
    expect(uiLocaleFor('zh'), const Locale('zh'));
    expect(themeModeFor('dark'), ThemeMode.dark);
    expect(themeModeFor('bogus'), ThemeMode.system);
  });
}

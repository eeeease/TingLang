// docs/CLOUD.md §10: before the user signs in, the app sends nothing to a
// server; when the server cannot be reached, everything local keeps working.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinglang/app.dart';
import 'package:tinglang/core/db/database.dart';
import 'package:tinglang/core/library_store.dart';
import 'package:tinglang/core/live_repository.dart';
import 'package:tinglang/services/app_controller.dart';
import 'package:tinglang/services/cloud/cloud_controller.dart';
import 'package:tinglang/services/cloud/cloud_services.dart';
import 'package:tinglang/services/live_controller.dart';
import 'package:tinglang/services/playback_hub.dart';
import 'package:tinglang/services/recording_service.dart';
import 'package:tinglang/services/speech_model_service.dart';
import 'package:tinglang/services/transcription_controller.dart';
import 'package:tinglang_native/tinglang_native.dart';
import 'package:tinglang_platform_interface/testing.dart';
import 'package:tinglang_api/tinglang_api.dart';

import 'cloud_fakes.dart';

void main() {
  late AppController app;
  late FakeWebAuthenticator browser;
  late InMemorySecretStore secrets;
  final opened = <Uri>[];

  Future<CloudController> launch(
    WidgetTester tester,
    Map<String, String> settings, {
    String server = 'https://api.tinglang.example',
    DateTime Function()? now,
  }) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('com.llfbandit.record/messages'),
      (call) async => null,
    );
    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final dir = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('tinglang-offline-'),
    ))!;
    addTearDown(() => tester.runAsync(() => dir.delete(recursive: true)));
    final store = LibraryStore(dir);
    app = AppController(
      store,
      LibraryState(settings: {AppController.uiLocaleKey: 'zh', ...settings}),
    );
    final db = TinglangDatabase.memory();
    addTearDown(() => tester.runAsync(db.close));
    final live = LiveController(repository: LiveRepository(db));
    browser = FakeWebAuthenticator();
    secrets = InMemorySecretStore();
    final cloud = CloudController(
      app: app,
      clientVersion: '0.4.0',
      officialServer: server,
      now: now,
      connect: (server) => CloudClient(server, secrets: secrets, browser: browser),
    );
    // Speech settings with every cloud speech service the app ships.
    final models = ModelStore('${dir.path}/data');
    final speech = SpeechModelService(
      app: app,
      store: models,
      downloader: ModelDownloader(store: models, appVersion: 'test'),
      platform: fakeTinglangPlatform(FakeProbes.macos(const OsVersion(14, 2)))..models = models,
      cloudSecrets: CloudAsrSecrets(() => secrets),
    );
    addTearDown(speech.dispose);
    await tester.pumpWidget(
      TinglangApp(
        controller: app,
        playback: PlaybackHub(),
        recorder: RecordingService(store),
        live: live,
        transcription: TranscriptionController(repository: live.repository, store: store),
        navigation: ValueNotifier(null),
        exitNotice: ValueNotifier(null),
        cloud: cloud,
        speechModels: speech,
        openUrl: (url) async => opened.add(url),
      ),
    );
    await tester.pumpAndSettle();
    return cloud;
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  /// Lets real IO (files, sockets) progress and flushes the test's fake
  /// microtasks in turn, until [done] or about four seconds.
  Future<void> settle(WidgetTester tester, bool Function() done) async {
    for (var i = 0; i < 200 && !done(); i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    expect(done(), isTrue, reason: 'did not finish in time');
    await tester.pumpAndSettle();
  }

  Map<String, String> signedInCache() => {
    CloudController.signedInKey: 'true',
    CloudController.metaKey: jsonEncode(contractExample('getMeta/response.200.json')),
    CloudController.accountKey: jsonEncode(contractExample('getAccount/response.200.json')),
    CloudController.entitlementsKey: jsonEncode(
      contractExample('getEntitlements/response.200.json'),
    ),
  };

  testWidgets('starting the app and using every page signed out opens no connection', (
    tester,
  ) async {
    final network = NoNetwork();
    final before = HttpOverrides.current;
    HttpOverrides.global = network;
    addTearDown(() => HttpOverrides.global = before);

    await launch(tester, const {});
    await tap(tester, find.text('复习'));
    await tap(tester, find.text('说说'));
    await tap(tester, find.byKey(const ValueKey('nav-library')));
    await tap(tester, find.text('发现'));
    await tap(tester, find.text('共享'));
    await tap(tester, find.byKey(const ValueKey('nav-settings')));
    // Every settings tab, the cloud speech settings included.
    for (final tab in ['实时字幕', '数据', '关于', '语音识别']) {
      await tap(tester, find.text(tab));
    }
    await tap(tester, find.byKey(const ValueKey('speech-choose-cloud')));
    await settle(tester, () => find.byKey(const ValueKey('cloud-save')).evaluate().isNotEmpty);
    // The account lives in the sidebar; opening it contacts nobody.
    await tap(tester, find.byKey(const ValueKey('nav-account')));
    expect(find.byKey(const ValueKey('account-sign-in')), findsOneWidget);
    expect(find.textContaining('登录会在浏览器中打开 api.tinglang.example'), findsOneWidget);
    expect(
      find.descendant(of: find.byType(Dialog), matching: find.text('云端')),
      findsOneWidget,
      reason: 'the account is labelled as a cloud feature',
    );
    // Plans open on the website; the app has no payment.
    await tap(tester, find.byKey(const ValueKey('account-plans')));
    expect(opened.single.toString(), 'https://tinglang.app/pricing');

    expect(network.created, isEmpty, reason: 'no HttpClient may exist before sign-in');
    expect(browser.opened, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a cached sign-in does not contact the server at startup either', (tester) async {
    final network = NoNetwork();
    final before = HttpOverrides.current;
    HttpOverrides.global = network;
    addTearDown(() => HttpOverrides.global = before);

    final cloud = await launch(tester, signedInCache());
    expect(find.text('Learner'), findsOneWidget, reason: 'the sidebar names the account');
    await tap(tester, find.byKey(const ValueKey('nav-account')));
    expect(cloud.signedIn, isTrue);
    expect(find.text('套餐：Pro'), findsOneWidget);
    // Shown because this server offers it, hidden otherwise.
    expect(find.byKey(const ValueKey('cloud-service-jobs.transcribe')), findsOneWidget);
    expect(find.byKey(const ValueKey('cloud-service-llm_gateway')), findsOneWidget);
    expect(find.textContaining('已用 42 / 600 分钟'), findsOneWidget);
    expect(network.created, isEmpty);
  });

  testWidgets('with the server unreachable, local features keep working', (tester) async {
    final before = HttpOverrides.current;
    HttpOverrides.global = RealNetwork();
    addTearDown(() => HttpOverrides.global = before);
    final port = (await tester.runAsync(deadPort))!;
    final cloud = await launch(
      tester,
      signedInCache(),
      server: 'http://127.0.0.1:$port',
      now: () => DateTime.utc(2026, 10, 23, 12),
    );

    final refreshing = cloud.refresh();
    await settle(tester, () => cloud.offline && !cloud.busy);
    await refreshing;
    expect(cloud.offline, isTrue);
    expect(cloud.error, isA<ApiUnreachable>());
    expect(cloud.signedIn, isTrue, reason: 'being offline is not signing out');

    await tap(tester, find.byKey(const ValueKey('nav-account')));
    expect(find.textContaining('暂时连不上 127.0.0.1，显示的是'), findsOneWidget);
    expect(find.textContaining('请检查地址和网络；本机功能不受影响'), findsOneWidget);
    expect(find.text('套餐：Pro'), findsOneWidget);
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pumpAndSettle();

    // Local work: import the sample course and open it from the library.
    final installing = app.installDemo();
    await settle(tester, () => app.state.courses.isNotEmpty);
    await installing;
    await tap(tester, find.byKey(const ValueKey('nav-library')));
    expect(find.text('Small reps. Real progress.'), findsWidgets);
    expect(app.state.courses, hasLength(1));

    // Settings still save locally.
    final saving = app.setSetting(AppController.themeKey, 'dark');
    await settle(tester, () => app.setting(AppController.themeKey, 'system') == 'dark');
    await saving;
    expect(tester.takeException(), isNull);
  });
}

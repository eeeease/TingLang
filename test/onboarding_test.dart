import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinglang/app.dart';
import 'package:tinglang/core/db/database.dart';
import 'package:tinglang/core/library_store.dart';
import 'package:tinglang/core/live_repository.dart';
import 'package:tinglang/l10n/app_localizations.dart';
import 'package:tinglang/services/app_controller.dart';
import 'package:tinglang/services/live_controller.dart';
import 'package:tinglang/services/playback_hub.dart';
import 'package:tinglang/services/recording_service.dart';
import 'package:tinglang/services/speech_model_service.dart';
import 'package:tinglang/services/transcription_controller.dart';
import 'package:tinglang/ui/onboarding_dialog.dart';
import 'package:tinglang_native/tinglang_native.dart';
import 'package:tinglang_platform_interface/testing.dart';
import 'package:tinglang_ui/tinglang_ui.dart';

import 'update/update_fakes.dart' show MemoryStore;

void main() {
  group('the guide', () {
    late Directory dir;
    late AppController app;
    late ModelStore store;
    late SpeechModelService models;
    late int httpClients;
    late PlatformProbe probe;
    late List<SystemSettingsPane> opened;
    late int micRequests;

    // Made inside each test: the controller's saves must run in the
    // widget test's zone.
    Future<void> prepare() async {
      dir = Directory.systemTemp.createTempSync('tinglang-onboarding-');
      app = AppController(
        MemoryStore(),
        LibraryState(settings: {AppController.onboardingKey: AppController.onboardingPending}),
      );
      store = ModelStore('${dir.path}/data');
      httpClients = 0;
      // macOS 14.2: the recommended live model is a download.
      final platform = fakeTinglangPlatform(FakeProbes.macos(const OsVersion(14, 2)))
        ..models = store;
      models = SpeechModelService(
        app: app,
        store: store,
        platform: platform,
        downloader: ModelDownloader(
          store: store,
          appVersion: 'test',
          httpClient: () {
            httpClients++;
            return HttpClient();
          },
        ),
      );
      await models.refresh();
      probe = FakeProbes.macos(
        const OsVersion(14, 2),
        permissions: {PermissionKind.microphone: PermissionState.notDetermined},
      );
      opened = [];
      micRequests = 0;
      addTearDown(() {
        models.dispose();
        dir.deleteSync(recursive: true);
      });
    }

    /// Opens the guide from a button and returns how it ended.
    Future<Future<OnboardingOutcome?> Function()> open(WidgetTester tester) async {
      await prepare();
      OnboardingOutcome? outcome;
      final access = PermissionAccess(
        probe: () async => probe,
        requestMicrophone: () async {
          micRequests++;
          probe = FakeProbes.macos(
            const OsVersion(14, 2),
            permissions: {PermissionKind.microphone: PermissionState.granted},
          );
          return true;
        },
        openSettings: (pane) async => opened.add(pane),
      );
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: TinglangTheme.light(),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async => outcome = await showOnboarding(
                  context,
                  app: app,
                  models: models,
                  access: access,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      return () async => outcome;
    }

    Future<void> tap(WidgetTester tester, Finder finder) async {
      await tester.ensureVisible(finder);
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    testWidgets('permissions, the model and the basics; finishing marks the guide done', (
      tester,
    ) async {
      final outcome = await open(tester);
      await tap(tester, find.text('open'));
      expect(find.text('Welcome to TingLang'), findsOneWidget);
      expect(find.text('Step 1 of 3'), findsOneWidget);

      // System audio cannot be checked beforehand; the microphone is asked
      // for here and shows its new state.
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('permission-system-audio')),
          matching: find.text('Asked on first use'),
        ),
        findsOneWidget,
      );
      await tap(tester, find.byKey(const ValueKey('permission-microphone-allow')));
      expect(micRequests, 1);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('permission-microphone')),
          matching: find.text('Allowed'),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('permission-microphone-allow')), findsNothing);
      await tap(
        tester,
        find.descendant(
          of: find.byKey(const ValueKey('permission-system-audio')),
          matching: find.text('Open System Settings'),
        ),
      );
      await tap(
        tester,
        find.descendant(
          of: find.byKey(const ValueKey('permission-full-disk')),
          matching: find.text('Open System Settings'),
        ),
      );
      expect(opened, [SystemSettingsPane.screenRecording, SystemSettingsPane.fullDiskAccess]);

      // The model: nothing is chosen until the user says so; the model this
      // Mac would use is named with its size and asks before downloading.
      await tap(tester, find.byKey(const ValueKey('onboarding-next')));
      expect(find.text('Step 2 of 3'), findsOneWidget);
      expect(models.setupChosen, isFalse);
      final recommended = models.automaticModel(SpeechUse.live)!;
      expect(recommended.isSherpa, isTrue);
      final size = (models.missingBytes(recommended) / 1e6).round();
      final download = find.byKey(const ValueKey('onboarding-model-download'));
      expect(
        find.descendant(of: download, matching: find.text('Download $size MB')),
        findsOneWidget,
      );
      await tap(tester, download);
      expect(models.mode, RecognitionMode.local, reason: 'a download chooses the local mode');
      expect(find.byKey(const ValueKey('speech-download-confirm')), findsOneWidget);
      await tap(tester, find.text('Cancel'));
      expect(httpClients, 0, reason: 'no request without consent');
      expect(models.downloads, isEmpty);

      // The cloud explains what comes next instead of a model.
      await tap(tester, find.byKey(const ValueKey('onboarding-mode-cloud')));
      expect(models.mode, RecognitionMode.cloud);
      expect(find.byKey(const ValueKey('onboarding-model')), findsNothing);
      expect(find.textContaining('enter your own key'), findsOneWidget);
      await tap(tester, find.byKey(const ValueKey('onboarding-mode-local')));
      expect(models.mode, RecognitionMode.local);
      expect(find.byKey(const ValueKey('onboarding-model')), findsOneWidget);

      await tap(tester, find.byKey(const ValueKey('onboarding-next')));
      expect(find.text('Step 3 of 3'), findsOneWidget);
      expect(find.text('Start live captions'), findsOneWidget);
      expect(find.byKey(const ValueKey('onboarding-skip')), findsNothing);
      await tap(tester, find.byKey(const ValueKey('onboarding-back')));
      expect(find.text('Step 2 of 3'), findsOneWidget);
      await tap(tester, find.byKey(const ValueKey('onboarding-next')));
      await tap(tester, find.text('Get started'));
      expect(find.byKey(const ValueKey('onboarding')), findsNothing);
      expect(await outcome(), OnboardingOutcome.finished);
      expect(app.setting(AppController.onboardingKey, ''), AppController.onboardingDone);
    });

    testWidgets('finishing with the cloud and no key leads on to its settings', (tester) async {
      final outcome = await open(tester);
      await tap(tester, find.text('open'));
      await tap(tester, find.byKey(const ValueKey('onboarding-next')));
      await tap(tester, find.byKey(const ValueKey('onboarding-mode-cloud')));
      await tap(tester, find.byKey(const ValueKey('onboarding-next')));
      await tap(tester, find.byKey(const ValueKey('onboarding-next')));
      expect(await outcome(), OnboardingOutcome.setUpCloud);
    });

    testWidgets('skipping chooses nothing and does not come back', (tester) async {
      final outcome = await open(tester);
      await tap(tester, find.text('open'));
      await tap(tester, find.byKey(const ValueKey('onboarding-skip')));
      expect(await outcome(), OnboardingOutcome.skipped);
      expect(models.setupChosen, isFalse);
      expect(micRequests, 0);
      expect(app.setting(AppController.onboardingKey, ''), AppController.onboardingDone);
    });
  });

  group('in the app', () {
    Future<AppController> start(WidgetTester tester, Map<String, String> settings) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('com.llfbandit.record/messages'),
        (call) async => null,
      );
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final store = MemoryStore();
      final app = AppController(
        store,
        LibraryState(settings: {AppController.uiLocaleKey: 'zh', ...settings}),
      );
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
      return app;
    }

    testWidgets('a new library opens the guide once', (tester) async {
      final app = await start(tester, {
        AppController.onboardingKey: AppController.onboardingPending,
      });
      expect(find.text('欢迎使用听浪'), findsOneWidget);
      await tester.tap(find.text('跳过'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('onboarding')), findsNothing);
      expect(app.setting(AppController.onboardingKey, ''), AppController.onboardingDone);
    });

    testWidgets('a library from before the guide does not open it; Settings does', (tester) async {
      await start(tester, {});
      expect(find.byKey(const ValueKey('onboarding')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('nav-settings')));
      await tester.pumpAndSettle();
      expect(find.text('新手引导'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('onboarding-open')));
      await tester.pumpAndSettle();
      expect(find.text('欢迎使用听浪'), findsOneWidget);
      expect(find.text('授权'), findsOneWidget);
    });
  });
}

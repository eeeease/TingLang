import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:tinglang_native/tinglang_native.dart';
import 'package:tinglang_ui/tinglang_ui.dart';

import 'app.dart';
import 'core/db/sqlite_library_store.dart';
import 'core/generation/lexicon.dart';
import 'core/live_repository.dart';
import 'core/providers/provider_repository.dart';
import 'l10n/app_localizations.dart';
import 'services/app_controller.dart';
import 'services/cloud/cloud_controller.dart';
import 'services/cloud/cloud_services.dart';
import 'services/course_generation.dart';
import 'services/app_exit.dart';
import 'services/live_controller.dart';
import 'services/panel_coordinator.dart';
import 'services/panel_settings.dart' show localizationsFor;
import 'services/speech_model_service.dart';
import 'services/sync_service.dart';
import 'services/transcription_controller.dart';
import 'services/update_service.dart';
import 'services/playback_hub.dart';
import 'services/recording_service.dart';
import 'services/voice_memos.dart';
import 'ui/brand.dart';
import 'ui/settings_page.dart' show learningLanguages;
import 'ui/speech_model_names.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'Tinglang',
    ], await rootBundle.loadString('assets/legal/AGPL-3.0.txt'));
  });
  DesktopShell? shell;
  try {
    // Native capabilities; nothing here touches the network.
    TinglangNative.install();
    shell = await _desktopShell();
    // Dart is up: from here on the app decides when the main window shows.
    await shell?.ready();
    final support = await getApplicationSupportDirectory();
    final dataFolder = Directory(p.join(support.path, 'Tinglang'));
    // No data folder yet: TingLang was never opened on this Mac (for this
    // user), so the first-start guide opens once.
    final firstStart = !dataFolder.existsSync();
    final store = SqliteLibraryStore.open(dataFolder);
    final state = await store.load();
    MediaKit.ensureInitialized();
    final controller = AppController(store, state);
    if (firstStart) {
      await controller.setSetting(AppController.onboardingKey, AppController.onboardingPending);
    }
    final repository = LiveRepository(store.db);
    final live = LiveController(repository: repository, libraryRoot: store.root);
    final recorder = RecordingService(store);
    // Captions from the microphone ask macOS first (it asks only once).
    live.requestMicrophone = recorder.requestPermission;
    final transcription = TranscriptionController(repository: repository, store: store);
    // Downloaded speech models live in <data>/models. Nothing is fetched
    // until the user presses a download button that names the size.
    final modelStore = ModelStore(store.root.path);
    if (TinglangPlatform.isInstalled) TinglangPlatform.instance.models = modelStore;
    final speechModels = SpeechModelService(
      app: controller,
      store: modelStore,
      downloader: ModelDownloader(store: modelStore, appVersion: appVersion),
    );
    live
      ..models = speechModels
      ..modelText = L10nModelText(
        () => localizationsFor(controller),
        languageName: (code) => learningLanguages[code] ?? code,
      );
    transcription.models = speechModels;
    final secrets = await _secretStore();
    final providers = ProviderRepository(
      store.db,
      secrets,
      ProviderCatalog.fromJson(await rootBundle.loadString('assets/providers/catalog.v1.json')),
    );
    final generation = CourseGenerationService(
      live: repository,
      app: controller,
      providers: providers,
      cache: LlmCacheStore(store.db),
      loadLexicon: () async => Lexicon.fromGzip(
        (await rootBundle.load('assets/lexicon/en.v1.json.gz')).buffer.asUint8List(),
      ),
    );
    // Optional cloud account: reads cached settings only; it talks to a
    // server when the user signs in (docs/CLOUD.md §10).
    final browser = await _webAuthenticator();
    final cloud = CloudController(
      app: controller,
      clientVersion: appVersion,
      officialServer: CloudController.official,
      connect: (server) => CloudClient(
        server,
        secrets: secrets,
        browser: browser,
        userAgent: 'TingLang/$appVersion (macos)',
      ),
    );
    await cloud.forgetLegacyServer();
    await live.init();
    final voiceMemos = VoiceMemoService(
      app: controller,
      transcription: transcription,
      shell: shell,
    );
    await voiceMemos.init();
    // iCloud Drive sync: off by default; reads nothing from iCloud until the
    // user turns it on in Settings (macOS does the syncing).
    final sync = SyncService(
      app: controller,
      repository: repository,
      drive: await _cloudDrive(),
      appVersion: appVersion,
    );
    unawaited(sync.start());
    final navigation = ValueNotifier<ShellRequest?>(null);
    final exitNotice = ValueNotifier<String?>(null);
    // The floating panel is the front door; it works before (and without)
    // the main window, so it is wired here rather than in the widget tree.
    await PanelCoordinator(
      app: controller,
      live: live,
      transcription: transcription,
      navigation: navigation,
      shell: shell,
      voiceMemos: voiceMemos,
      languageName: (code) => learningLanguages[code] ?? code,
    ).start();
    // Today's new recordings, once the user has used the import list.
    unawaited(voiceMemos.checkInBackground());
    AppLifecycleListener(
      onResume: () => unawaited(voiceMemos.checkInBackground()),
      onExitRequested: () => handleExitRequest(
        app: controller,
        recorder: recorder,
        live: live,
        notice: exitNotice,
        shell: shell,
      ),
    );
    // Updates from GitHub Releases: nothing is sent at startup; the first
    // automatic check runs a minute after launch, at most once a day, and
    // only while Settings → General allows it. Installing goes through the
    // exit handler above (never while a recording runs or is unsaved).
    final updates = UpdateService(
      app: controller,
      appVersion: appVersion,
      busy: () => exitBlockedByRecording(app: controller, recorder: recorder),
    );
    updates.start();
    // Opt-in automation hook for local verification (never set in normal
    // launches).
    if (Platform.environment['TINGLANG_AUTOSTART_LIVE'] == '1') unawaited(live.toggle());
    runApp(
      TinglangApp(
        controller: controller,
        playback: PlaybackHub(),
        recorder: recorder,
        live: live,
        transcription: transcription,
        navigation: navigation,
        exitNotice: exitNotice,
        generation: generation,
        providers: providers,
        voiceMemos: voiceMemos,
        cloud: cloud,
        openUrl: shell?.openUrl,
        speechModels: speechModels,
        sync: sync,
        updates: updates,
        openSystemSettings: shell?.openSystemSettings,
      ),
    );
    // Without the panel (hidden by the user, or no panel on this system) the
    // main window is the only way in; the first-start guide opens in it.
    final onboarding =
        controller.setting(AppController.onboardingKey, '') == AppController.onboardingPending;
    if (!live.panelVisible || onboarding) await shell?.showMainWindow();
  } catch (error, stack) {
    runApp(StartupFailure(error: error, stack: stack));
    try {
      await shell?.showMainWindow();
    } on Object catch (e) {
      debugPrint('Could not show the main window: $e');
    }
  }
}

/// The app's window controller; null without native support (tests).
Future<DesktopShell?> _desktopShell() async {
  if (!TinglangPlatform.isInstalled) return null;
  final platform = TinglangPlatform.instance;
  final choice = platform.shells.pick(await platform.probe());
  return choice.hasSelection ? choice.create() : null;
}

/// The platform's secret store (Keychain on macOS); null when none exists,
/// in which case keys cannot be saved (they are never stored elsewhere).
Future<SecretStore?> _secretStore() async {
  if (!TinglangPlatform.isInstalled) return null;
  final platform = TinglangPlatform.instance;
  final choice = platform.secrets.pick(await platform.probe());
  return choice.hasSelection ? choice.create() : null;
}

/// iCloud Drive download states for sync; null where there is none.
Future<CloudDriveSupport?> _cloudDrive() async {
  if (!TinglangPlatform.isInstalled) return null;
  final platform = TinglangPlatform.instance;
  final choice = platform.cloudDrive.pick(await platform.probe());
  return choice.hasSelection ? choice.create() : null;
}

/// The system browser session for cloud sign-in; null where there is none.
Future<WebAuthenticator?> _webAuthenticator() async {
  if (!TinglangPlatform.isInstalled) return null;
  final platform = TinglangPlatform.instance;
  final choice = platform.webAuth.pick(await platform.probe());
  return choice.hasSelection ? choice.create() : null;
}

class StartupFailure extends StatelessWidget {
  const StartupFailure({super.key, required this.error, required this.stack});
  final Object error;
  final StackTrace stack;
  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: TinglangTheme.light(),
    darkTheme: TinglangTheme.dark(),
    debugShowCheckedModeBanner: false,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(
      builder: (context) {
        final l = context.l10n;
        return Scaffold(
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: SizedBox(
                width: 760,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const BrandMark(size: 70),
                    const SizedBox(height: 24),
                    Text(l.startupFailedTitle, style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 16),
                    SelectableText(error.toString()),
                    const SizedBox(height: 20),
                    SlNotice(l.startupFailedNotice),
                    const SizedBox(height: 18),
                    FilledButton(
                      onPressed: () => Clipboard.setData(ClipboardData(text: '$error\n$stack')),
                      child: Text(l.copyErrorDetails),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinglang/core/db/database.dart';
import 'package:tinglang/core/library_store.dart';
import 'package:tinglang/core/live_repository.dart';
import 'package:tinglang/l10n/app_localizations.dart';
import 'package:tinglang/services/app_controller.dart';
import 'package:tinglang/services/live_controller.dart';
import 'package:tinglang/services/panel_coordinator.dart';
import 'package:tinglang/services/panel_settings.dart';
import 'package:tinglang/services/transcription_controller.dart';
import 'package:tinglang/services/voice_memos.dart';
import 'package:tinglang_native/tinglang_native.dart';
import 'package:tinglang_platform_interface/testing.dart';

/// Plain English sentences so assertions read naturally.
final class _Text implements LivePanelText {
  @override
  String get preparing => 'Getting ready';
  @override
  String get downloading => 'Downloading';
  @override
  String speechModelNeeded(String language) => 'Download the $language model';
  @override
  String translationPackNeeded(String source, String target) => 'Get the $source→$target pack';
  @override
  String get silentSystemAudio => 'Switched to screen recording';
  @override
  String get screenRecordingCapture => 'Using screen recording';
  @override
  String get download => 'Download';
  @override
  String get retry => 'Try again';
  @override
  String get saved => 'Saved';
  @override
  String summary(Duration length, int words) => '${length.inSeconds}s · $words words';
  @override
  String failed(String detail) => 'Failed: $detail';
  @override
  String unavailable(String reason) => 'Unavailable: $reason';
  @override
  String importing(int count) => 'Importing $count';
}

/// A pipeline that first needs its speech model (like a fresh Mac) or a
/// translation pack.
final class _SetupHost implements LivePipelineHost, LiveSetupSupport {
  _SetupHost({this.installed = false, this.packInstalled = true});
  final inner = FakeLivePipelineHost(PipelineTopology.nativeMacos);
  bool installed, packInstalled;
  @override
  PipelineTopology get topology => inner.topology;
  @override
  Future<LiveSession> start(LivePipelineConfig config) => inner.start(config);
  @override
  Future<AssetState> speechAssets(String locale) async =>
      installed ? AssetState.installed : AssetState.downloadable;
  @override
  Future<void> installSpeechAssets(String locale) async => installed = true;
  @override
  Future<AssetState> translationPack(LanguagePair pair) async =>
      packInstalled ? AssetState.installed : AssetState.downloadable;
  @override
  Future<void> installTranslationPack(LanguagePair pair) async => packInstalled = true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late TinglangDatabase db;
  late FakeCaptionOverlay overlay;
  late FakeLivePipelineHost host;

  TinglangPlatform platform({LivePipelineHost? pipeline}) {
    final p = TinglangPlatform(probeSource: FakeProbeSource(FakeProbes.macos(const OsVersion(26))));
    overlay = FakeCaptionOverlay();
    host = FakeLivePipelineHost(PipelineTopology.nativeMacos);
    p.pipelines.register(
      BackendFactory<LivePipelineHost>(BackendCatalog.nativeMacosPipeline, () => pipeline ?? host),
    );
    p.overlays.register(BackendFactory<CaptionOverlay>(BackendCatalog.nsPanel, () => overlay));
    return p;
  }

  Future<LiveController> controller({LivePipelineHost? pipeline}) async {
    final live =
        LiveController(
            repository: LiveRepository(db),
            platform: platform(pipeline: pipeline),
            flushInterval: const Duration(milliseconds: 20),
          )
          ..panelText = _Text()
          ..requestBuilder = () => const LiveRequest(
            source: AudioSourceKind.systemAudio,
            language: 'en',
            translateTo: 'zh-Hans',
          );
    await live.init();
    await live.showPanel(const CaptionStyle(), const {'start': 'Start'});
    return live;
  }

  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

  setUp(() => db = TinglangDatabase.memory());
  tearDown(() => db.close());

  test('the panel opens idle and follows a capture to a saved summary', () async {
    final live = await controller();
    addTearDown(live.dispose);
    expect(overlay.visible, isTrue);
    expect(overlay.strings['start'], 'Start');
    expect(overlay.states.last.phase, OverlayPhase.idle);
    expect(overlay.states.last.canStart, isTrue);

    overlay.emit(const OverlayActionRequested(OverlayAction.toggle));
    await settle();
    expect(live.status, LiveStatus.running);
    expect(overlay.states.last.phase, OverlayPhase.listening);
    expect(overlay.states.last.startedAt, isNotNull);

    final session = host.sessions.single;
    session.emitCaption(const AsrFinal('s-0', text: 'Small reps add up.', startMs: 0, endMs: 1500));
    session.emitCaption(const AsrPartial('s-1', text: 'Every', startMs: 1600));
    await settle();
    overlay.emit(const OverlayActionRequested(OverlayAction.toggle));
    await settle();
    final saved = overlay.states.last;
    expect(saved.phase, OverlayPhase.saved);
    expect(saved.sessionId, session.sessionId);
    expect(saved.message, 'Saved');
    expect(saved.summary, endsWith('· 4 words'));
  });

  test('pushes only real changes, not every caption line', () async {
    final live = await controller();
    addTearDown(live.dispose);
    await live.toggle();
    final before = overlay.states.length;
    for (var i = 0; i < 5; i++) {
      host.sessions.single.emitCaption(AsrPartial('p-$i', text: 'line $i', startMs: i * 100));
    }
    await settle();
    expect(overlay.states.length, before);
    await live.stop();
  });

  test('a missing speech model is offered as a download, then capture starts', () async {
    final setup = _SetupHost();
    final live = await controller(pipeline: setup);
    addTearDown(live.dispose);
    overlay.emit(const OverlayActionRequested(OverlayAction.toggle));
    await settle();
    final need = overlay.states.last;
    expect(need.phase, OverlayPhase.needsSetup);
    expect(need.message, 'Download the en model');
    expect(need.action, OverlayAction.install);
    expect(need.actionLabel, 'Download');

    overlay.emit(const OverlayActionRequested(OverlayAction.install));
    await settle();
    expect(setup.installed, isTrue);
    expect(live.status, LiveStatus.running);
    expect(overlay.states.last.phase, OverlayPhase.listening);
    await live.stop();
  });

  test('a missing translation pack is explained while listening and offered after', () async {
    final setup = _SetupHost(installed: true, packInstalled: false);
    final live = await controller(pipeline: setup);
    addTearDown(live.dispose);
    overlay.emit(const OverlayActionRequested(OverlayAction.toggle));
    await settle();
    expect(live.status, LiveStatus.running);
    expect(overlay.states.last.phase, OverlayPhase.listening);
    expect(overlay.states.last.message, 'Get the en→zh-Hans pack');

    // Nothing was said, so no summary: the panel offers the pack instead.
    overlay.emit(const OverlayActionRequested(OverlayAction.toggle));
    await settle();
    final offer = overlay.states.last;
    expect(offer.phase, OverlayPhase.needsSetup);
    expect(offer.message, 'Get the en→zh-Hans pack');
    expect(offer.action, OverlayAction.install);
    overlay.emit(const OverlayActionRequested(OverlayAction.install));
    await settle();
    expect(setup.packInstalled, isTrue);
    expect(live.setupNeed, isNull);
    // Fetching the pack does not start another capture by itself.
    expect(live.status, LiveStatus.idle);
  });

  test('requests that are not about captions go to the app', () async {
    final live = await controller();
    addTearDown(live.dispose);
    final forwarded = <OverlayEvent>[];
    live.onPanelEvent = (event) async => forwarded.add(event);
    overlay
      ..emit(const OverlayActionRequested(OverlayAction.openSession, 'abc'))
      ..emit(const OverlayFilesDropped(['/tmp/a.m4a']));
    await settle();
    expect(forwarded, hasLength(2));
    expect((forwarded.first as OverlayActionRequested).value, 'abc');
    expect(live.status, LiveStatus.idle);
  });

  group('saved look', () {
    Future<AppController> withSettings(Map<String, String> settings) async {
      final dir = await Directory.systemTemp.createTemp('tinglang-look-');
      addTearDown(() => dir.delete(recursive: true));
      final app = AppController(LibraryStore(dir), LibraryState(settings: settings));
      addTearDown(app.dispose);
      return app;
    }

    test('layout and scroll-back round-trip through the settings', () async {
      const style = CaptionStyle(layout: CaptionLayout.sideBySide, scrollback: 500);
      final app = await withSettings(captionStyleSettings(style));
      expect(captionStyleFrom(app), style);
    });

    test('defaults: stacked, 100 lines; odd values are clamped or ignored', () async {
      expect(captionStyleFrom(await withSettings({})).layout, CaptionLayout.stacked);
      expect(captionStyleFrom(await withSettings({})).scrollback, 100);
      final odd = captionStyleFrom(
        await withSettings({PanelKeys.layout: 'diagonal', PanelKeys.scrollback: '5'}),
      );
      expect(odd.layout, CaptionLayout.stacked);
      expect(odd.scrollback, 50);
      expect(captionStyleFrom(await withSettings({PanelKeys.scrollback: '99999'})).scrollback, 500);
    });

    test('the panel gets every label it draws, in both languages', () {
      for (final locale in AppLocalizations.supportedLocales) {
        final strings = panelStrings(lookupAppLocalizations(locale));
        for (final key in [
          'layout',
          'layoutStacked',
          'layoutSideBySide',
          'locked',
          'lockToggle',
          'jumpToLatest',
          'newLines',
          'hintRecord',
          'hintStop',
          'hintMenu',
        ]) {
          expect(strings[key], isNotEmpty, reason: '$key ($locale)');
        }
        expect(strings['newLines'], contains('{n}'));
        // The record button's hint names the global shortcut LiveController registers.
        expect(strings['hintRecord'], contains('⌘⇧T'));
        expect(strings['hintStop'], contains('⌘⇧T'));
        expect(strings['hintMenu'], contains(lookupAppLocalizations(locale).appTitle));
      }
    });
  });

  group('PanelCoordinator', () {
    late Directory dir;
    late AppController app;
    late LiveController live;
    late PanelCoordinator coordinator;
    late FakeDesktopShell shell;
    late ValueNotifier<ShellRequest?> navigation;
    late FakeFileTranscriber transcriber;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('tinglang-panel-');
      app = AppController(
        LibraryStore(dir),
        LibraryState(settings: {AppController.uiLocaleKey: 'en'}),
      );
      live = await controller();
      transcriber = FakeFileTranscriber(BackendCatalog.speechAnalyzerFile.id);
      final files = TinglangPlatform(
        probeSource: FakeProbeSource(FakeProbes.macos(const OsVersion(26))),
      )..fileAsr.register(BackendFactory(BackendCatalog.speechAnalyzerFile, () => transcriber));
      shell = FakeDesktopShell();
      navigation = ValueNotifier(null);
      coordinator = PanelCoordinator(
        app: app,
        live: live,
        transcription: TranscriptionController(
          repository: live.repository,
          store: LibraryStore(dir),
          platform: files,
        ),
        navigation: navigation,
        shell: shell,
      );
      await coordinator.start();
    });
    tearDown(() async {
      coordinator.dispose();
      live.dispose();
      await dir.delete(recursive: true);
    });

    test('opening history or a session shows the main window with a request', () async {
      await coordinator.handle(const OverlayActionRequested(OverlayAction.openHistory));
      expect(navigation.value, isA<OpenHistory>());
      await coordinator.handle(const OverlayActionRequested(OverlayAction.makeCourse, 's1'));
      expect(
        navigation.value,
        isA<OpenSession>().having((r) => r.makeCourse, 'makeCourse', isTrue),
      );
      expect(shell.mainWindowShown, 2);
    });

    test('a refused capture permission opens its System Settings pane, not the app', () async {
      live.setupNeed = const CapturePermissionNeeded(PermissionKind.microphone);
      await coordinator.handle(const OverlayActionRequested(OverlayAction.openSettings));
      live.setupNeed = const CapturePermissionNeeded(PermissionKind.systemAudio);
      await coordinator.handle(const OverlayActionRequested(OverlayAction.openSettings));
      expect(shell.openedSettings, [
        SystemSettingsPane.microphone,
        SystemSettingsPane.screenRecording,
      ]);
      expect(navigation.value, isNull);
      expect(shell.mainWindowShown, 0);
    });

    test('a look chosen on the panel is saved and applied', () async {
      final style = const CaptionStyle().copyWith(
        mode: CaptionMode.text,
        background: CaptionBackground.clear,
        textColor: 0xFFFFE16B,
        fontSize: 30,
      );
      await coordinator.handle(OverlayStyleChanged(style));
      expect(app.setting(PanelKeys.mode, ''), 'text');
      expect(captionStyleFrom(app), style);
      expect(overlay.style, style);
    });

    test('layout and scroll-back chosen in Settings reach the panel', () async {
      await app.setSettings({PanelKeys.layout: 'sideBySide', PanelKeys.scrollback: '200'});
      await settle();
      expect(overlay.style?.layout, CaptionLayout.sideBySide);
      expect(overlay.style?.scrollback, 200);
      expect(live.panelStyle.scrollback, 200);
    });

    test('a lock chosen on the panel is kept and the Dock menu unlocks it', () async {
      await coordinator.handle(
        OverlayStyleChanged(const CaptionStyle().copyWith(clickThrough: true)),
      );
      expect(app.setting(PanelKeys.clickThrough, ''), 'true');
      expect(overlay.style?.clickThrough, isTrue);
      await coordinator.handle(const OverlayActionRequested(OverlayAction.unlock));
      expect(app.setting(PanelKeys.clickThrough, ''), 'false');
      expect(overlay.style?.clickThrough, isFalse);
    });

    test('the audio source and the hidden state are remembered', () async {
      await coordinator.handle(const OverlayActionRequested(OverlayAction.useMicrophone));
      expect(app.setting(liveSourceKey, ''), 'microphone');
      expect(live.requestBuilder!().source, AudioSourceKind.microphone);
      await coordinator.handle(const OverlayActionRequested(OverlayAction.hide));
      expect(app.setting(PanelKeys.visible, ''), 'false');
      expect(live.panelVisible, isFalse);
    });

    test('the show-panel switch and the theme follow the settings', () async {
      expect(shell.appearance, ShellAppearance.system);
      await app.setSetting(AppController.themeKey, 'dark');
      await settle();
      expect(shell.appearance, ShellAppearance.dark);

      await app.setSetting(PanelKeys.visible, 'false');
      await settle();
      expect(overlay.visible, isFalse);
      // Captions still need somewhere to appear: starting brings it back.
      await live.toggle();
      await settle();
      expect(overlay.visible, isTrue);
      await live.stop();

      await app.setSetting(PanelKeys.visible, 'true');
      await settle();
      expect(overlay.visible, isTrue);
      expect(live.panelVisible, isTrue);
    });

    test("today's new Voice Memos show on the panel and open the list", () async {
      final memo = File('${dir.path}/memo.m4a')..writeAsBytesSync(List.filled(16, 1));
      final library = FakeVoiceMemoLibrary([
        VoiceMemo(
          id: 'a',
          title: 'Standup',
          recordedAt: DateTime.now().toUtc(),
          duration: const Duration(seconds: 5),
          path: memo.path,
        ),
      ]);
      final memos = VoiceMemoService(
        app: app,
        transcription: coordinator.transcription,
        platform: TinglangPlatform(
          probeSource: FakeProbeSource(FakeProbes.macos(const OsVersion(26))),
        )..voiceMemos.register(BackendFactory(BackendCatalog.appleVoiceMemos, () => library)),
      );
      final withMemos = PanelCoordinator(
        app: app,
        live: live,
        transcription: coordinator.transcription,
        navigation: navigation,
        shell: shell,
        voiceMemos: memos,
      );
      await withMemos.start();
      addTearDown(withMemos.dispose);
      await memos.refresh();
      expect(overlay.states.last.newRecordings, 1);
      await withMemos.handle(const OverlayActionRequested(OverlayAction.showRecordings));
      expect(navigation.value, isA<OpenVoiceMemos>());
    });

    test('dropped audio is transcribed; other files are ignored', () async {
      final memo = File('${dir.path}/memo.m4a')..writeAsBytesSync(List.filled(16, 3));
      final notes = File('${dir.path}/notes.txt')..writeAsStringSync('hi');
      await coordinator.handle(OverlayFilesDropped([memo.path, notes.path]));
      expect(coordinator.transcription.jobs, hasLength(1));
      expect(coordinator.transcription.jobs.single.title, 'memo');
      expect(overlay.states.last.phase, OverlayPhase.notice);
      expect(overlay.states.last.message, 'Importing 1 file(s). Progress shows in History.');
      expect(navigation.value, isNull);

      // Dropped on the main window: History opens to show the progress.
      await coordinator.handle(OverlayFilesDropped([memo.path], mainWindow: true));
      expect(navigation.value, isA<OpenHistory>());
    });

    test('share files dropped or opened in Finder go to the import in the main window', () async {
      final package = File('${dir.path}/Talk.tinglang')..writeAsStringSync('zip');
      final memo = File('${dir.path}/memo.m4a')..writeAsBytesSync(List.filled(16, 4));
      await coordinator.handle(OverlayFilesDropped([package.path, memo.path]));
      expect(
        navigation.value,
        isA<ImportPackages>().having((r) => r.paths, 'paths', [package.path]),
      );
      expect(shell.mainWindowShown, 1);
      // Audio in the same drop is still transcribed.
      expect(coordinator.transcription.jobs, hasLength(1));

      // Opened in Finder before the window took the first request: both wait.
      shell.openFiles(['/Users/me/Downloads/Course.tinglang']);
      await pumpEventQueue();
      expect((navigation.value! as ImportPackages).paths, [
        package.path,
        '/Users/me/Downloads/Course.tinglang',
      ]);
      expect(shell.pendingFiles, isEmpty);
      expect(shell.mainWindowShown, 2);
    });

    test('files opened in Finder before the app was ready are imported once it is', () async {
      // A cold launch by a double-click: the shell kept the file.
      final early = FakeDesktopShell()..openFiles(['/Users/me/Early.tinglang']);
      final cold = PanelCoordinator(
        app: app,
        live: live,
        transcription: coordinator.transcription,
        navigation: navigation,
        shell: early,
      );
      addTearDown(cold.dispose);
      await cold.start();
      expect((navigation.value! as ImportPackages).paths, ['/Users/me/Early.tinglang']);
      expect(early.mainWindowShown, 1);
      expect(await early.takeOpenedFiles(), isEmpty);
    });
  });
}

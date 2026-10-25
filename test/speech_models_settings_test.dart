import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinglang/core/library_store.dart';
import 'package:tinglang/l10n/app_localizations.dart';
import 'package:tinglang/services/app_controller.dart';
import 'package:tinglang/services/speech_model_service.dart';
import 'package:tinglang/ui/speech_models_panel.dart';
import 'package:tinglang_native/tinglang_native.dart';
import 'package:tinglang_platform_interface/testing.dart';
import 'package:tinglang_ui/tinglang_ui.dart';

void main() {
  late Directory dir;
  late AppController app;
  late ModelStore store;
  late int httpClients;
  late SpeechModelService service;

  /// Puts [pack] on disk as if downloaded: files of the catalog sizes
  /// (sparse) and a receipt. Nothing is hashed for `installed`.
  Future<void> fakeInstall(ModelPack pack) async {
    final folder = Directory(store.directoryOf(pack.id))..createSync(recursive: true);
    for (final file in pack.files) {
      final raf = File('${folder.path}/${file.name}').openSync(mode: FileMode.write);
      raf.truncateSync(file.bytes);
      raf.closeSync();
    }
    await store.writeReceipt(pack);
  }

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('tinglang-speech-');
    app = AppController(LibraryStore(Directory('${dir.path}/library')), LibraryState());
    store = ModelStore('${dir.path}/data');
    httpClients = 0;
    final platform = fakeTinglangPlatform(FakeProbes.macos(const OsVersion(14, 2)))..models = store;
    service = SpeechModelService(
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
    await service.refresh();
  });
  tearDown(() {
    service.dispose();
    dir.deleteSync(recursive: true);
  });

  group('settings', () {
    test('defaults: automatic models, balanced tier, US English', () {
      expect(service.modelFor(SpeechUse.live), isNull);
      expect(service.modelFor(SpeechUse.file), isNull);
      final options = service.optionsFor('en');
      expect(options.latency, LatencyTier.balanced);
      expect(options.locale, 'en-US');
      expect(options.dictation, const DictationHints());
    });

    test('saved choices are read back; nonsense falls back', () async {
      await app.setSetting(SpeechKeys.latency, 'fastest');
      await app.setSetting(SpeechKeys.accent, 'en-GB');
      await app.setSetting(SpeechKeys.farField, 'true');
      await service.choose(SpeechUse.live, SpeechModels.smallEnglishStreaming.id);
      expect(service.modelFor(SpeechUse.live), 'sherpa.zipformer_en_small');
      final options = service.optionsFor('en');
      expect(options.latency, LatencyTier.fastest);
      expect(options.locale, 'en-GB');
      expect(options.dictation.farField, isTrue);
      expect(service.optionsFor('zh-Hans').locale, isNull, reason: 'accents are English only');

      await app.setSetting(SpeechKeys.latency, 'warp');
      await app.setSetting(SpeechKeys.accent, 'en-XX');
      await app.setSetting(SpeechKeys.liveModel, 'removed.model');
      expect(service.optionsFor('en').latency, LatencyTier.balanced);
      expect(service.optionsFor('en').locale, isNull);
      expect(service.modelFor(SpeechUse.live), isNull);
    });
  });

  group('downloads and deletion', () {
    test('the shared VAD is counted once and kept while a model needs it', () async {
      final small = SpeechModels.smallEnglishStreaming,
          medium = SpeechModels.mediumEnglishStreaming;
      expect(
        service.missingBytes(small),
        small.pack!.downloadBytes + SpeechModels.vad.downloadBytes,
      );
      await fakeInstall(SpeechModels.vad);
      await fakeInstall(small.pack!);
      await fakeInstall(medium.pack!);
      expect(service.missingBytes(small), 0);
      expect(service.missingBytes(medium), 0);
      expect(service.isInstalled(small), isTrue);

      await service.choose(SpeechUse.live, small.id);
      await service.delete(small);
      expect(store.installed, {SpeechModels.vad.id, medium.pack!.id});
      expect(service.modelFor(SpeechUse.live), isNull, reason: 'a deleted choice falls back');

      await service.delete(medium);
      expect(store.installed, isEmpty, reason: 'the VAD goes with the last model');
      expect(Directory(store.directoryOf(SpeechModels.vad.id)).existsSync(), isFalse);
      expect(httpClients, 0);
    });

    test('downloaded packs make the model available in the next probe', () async {
      expect(
        service.availability(SpeechModels.xasrStreaming, SpeechUse.live),
        isA<NeedsDownload>(),
      );
      await fakeInstall(SpeechModels.vad);
      await fakeInstall(SpeechModels.xasrStreaming.pack!);
      await service.refresh();
      expect(service.availability(SpeechModels.xasrStreaming, SpeechUse.live), isA<Available>());
      expect(
        service.availability(SpeechModels.appleSpeech, SpeechUse.live),
        isA<Unsupported>(),
        reason: 'macOS 14.2',
      );
    });
  });

  testWidgets('Settings asks before downloading and names the size; cancel downloads nothing', (
    tester,
  ) async {
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
          body: SingleChildScrollView(
            child: SpeechModelsPanel(app: app, models: service),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Needs macOS 26'), findsWidgets);
    // A model row: three ratings and the size, no description or licence.
    final small = SpeechModels.smallEnglishStreaming;
    String dots(int n) => '●' * n + '○' * (3 - n);
    expect(
      find.text(
        'Accuracy ${dots(small.ratings.accuracy)}  ·  Speed ${dots(small.ratings.speed)}'
        '  ·  CPU medium  ·  ${(small.diskBytes / 1e6).round()} MB',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Licence'), findsNothing);

    final button = find.byKey(const ValueKey('speech-download-sherpa.zipformer_en_small'));
    await tester.ensureVisible(button);
    expect(find.descendant(of: button, matching: find.text('Download 46 MB')), findsOneWidget);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('Download Zipformer English 20M?'), findsOneWidget);
    expect(find.textContaining('46 MB from huggingface.co'), findsOneWidget);
    expect(find.textContaining('Apache-2.0'), findsWidgets);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(httpClients, 0, reason: 'no request without consent');
    expect(service.downloads, isEmpty);
    expect(downloaderJob(service), isNull);
  });

  group('cloud recognition', cloudTests);
}

/// A cloud service for settings tests; only [verify] is called.
final class _Service implements CloudAsrProvider {
  final verified = <CloudCredentials>[];
  @override
  CloudAsrInfo get info => CloudAsrInfo(
    id: 'tencent',
    fields: const [
      CloudField(CloudFieldKeys.appId, kind: CloudFieldKind.text),
      CloudField(CloudFieldKeys.secretKey),
    ],
    languages: const {'en', 'zh'},
    consoleUrl: Uri.parse('https://console.example.invalid'),
    live: false,
  );
  @override
  List<String> hosts(CloudCredentials credentials) => const ['asr.example.invalid'];
  @override
  Future<void> verify(CloudCredentials credentials) async {
    verified.add(credentials);
    if (credentials[CloudFieldKeys.secretKey] != 'good') {
      throw const CloudAsrError(CloudAsrErrorKind.unauthorized, 'refused');
    }
  }

  @override
  Future<CloudAsrStream> openStream(CloudCredentials c, CloudStreamOptions o) =>
      throw UnimplementedError();
  @override
  Future<List<CloudSegment>> transcribeFile(
    CloudCredentials c,
    CloudFileRequest r, {
    void Function(double progress)? onProgress,
    CloudCancelToken? cancel,
  }) => throw UnimplementedError();
}

/// Lets real IO (settings saves) finish between frames until [done].
Future<void> settle(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 100 && !done(); i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
  }
  expect(done(), isTrue, reason: 'did not finish in time');
  await tester.pumpAndSettle();
}

void cloudTests() {
  late Directory dir;
  late AppController app;
  late SpeechModelService service;
  late TinglangPlatform platform;
  late InMemorySecretStore secrets;
  late _Service provider;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('tinglang-cloud-speech-');
    app = AppController(LibraryStore(Directory('${dir.path}/library')), LibraryState());
    final store = ModelStore('${dir.path}/data');
    platform = fakeTinglangPlatform(FakeProbes.macos(const OsVersion(14, 2)))..models = store;
    secrets = InMemorySecretStore();
    provider = _Service();
    service = SpeechModelService(
      app: app,
      store: store,
      platform: platform,
      downloader: ModelDownloader(store: store, appVersion: 'test'),
      cloudProviders: [provider],
      cloudSecrets: CloudAsrSecrets(() => secrets),
    );
    await service.refresh();
  });
  tearDown(() {
    service.dispose();
    dir.deleteSync(recursive: true);
  });

  test('nothing is chosen at first; choosing either way counts', () async {
    expect(service.setupChosen, isFalse);
    expect(service.mode, RecognitionMode.local);
    await service.setMode(RecognitionMode.local);
    expect(service.setupChosen, isTrue);
  });

  test('cloud mode uses the service once its key is saved, and only for what it offers', () async {
    await service.chooseCloudProvider('tencent');
    expect(service.mode, RecognitionMode.cloud);
    expect(service.cloudNeedsSetup, isTrue);
    expect(service.modelFor(SpeechUse.file), 'cloud.tencent');
    expect(service.modelFor(SpeechUse.live), isNull, reason: 'no live recognition: local auto');
    expect(platform.enabledCloudBackends, isEmpty, reason: 'no key yet');

    await service.saveCloudCredentials('tencent', {'appId': '1', 'secretKey': 's'});
    expect(service.cloudNeedsSetup, isFalse);
    expect(platform.enabledCloudBackends, {'cloud.tencent'});
    expect(await secrets.read('asr:tencent'), contains('"appId":"1"'));
    expect(app.state.settings.values.join(), isNot(contains('"s"')), reason: 'not in the database');

    await service.setMode(RecognitionMode.local);
    expect(service.modelFor(SpeechUse.file), isNull);
    expect(platform.enabledCloudBackends, isEmpty);

    await service.setMode(RecognitionMode.cloud);
    await service.forgetCloudCredentials('tencent');
    expect(platform.enabledCloudBackends, isEmpty);
    expect(await secrets.read('asr:tencent'), isNull);
  });

  test('a saved key is found again after a restart', () async {
    await service.chooseCloudProvider('tencent');
    await service.saveCloudCredentials('tencent', {'appId': '1', 'secretKey': 's'});
    final again = SpeechModelService(
      app: app,
      store: service.store,
      platform: platform..enabledCloudBackends = const {},
      downloader: service.downloader,
      cloudProviders: [provider],
      cloudSecrets: CloudAsrSecrets(() => secrets),
    );
    addTearDown(again.dispose);
    await again.refresh();
    expect(again.cloudNeedsSetup, isFalse);
    expect(platform.enabledCloudBackends, {'cloud.tencent'});
  });

  testWidgets('first start asks how to recognise; the cloud form saves to the Keychain', (
    tester,
  ) async {
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
          body: SingleChildScrollView(
            child: SpeechModelsPanel(app: app, models: service),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('How should TingLang recognise speech?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('speech-choose-cloud')));
    await settle(tester, () => find.byKey(const ValueKey('cloud-save')).evaluate().isNotEmpty);
    expect(find.text('How should TingLang recognise speech?'), findsNothing);
    expect(find.text('Audio is sent to asr.example.invalid.'), findsOneWidget);
    expect(find.textContaining('has no live recognition'), findsOneWidget);

    // Missing field: nothing is saved.
    await tester.tap(find.byKey(const ValueKey('cloud-save')));
    await tester.pumpAndSettle();
    expect(find.text('Enter App ID.'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('cloud-field-tencent-appId')), '125');
    await tester.enterText(find.byKey(const ValueKey('cloud-field-tencent-secretKey')), 'bad');
    await tester.tap(find.byKey(const ValueKey('cloud-test')));
    await settle(tester, () => find.text('The key was rejected.').evaluate().isNotEmpty);
    expect(find.text('The key was rejected.'), findsOneWidget);
    expect(await tester.runAsync(() => secrets.read('asr:tencent')), isNull);

    await tester.enterText(find.byKey(const ValueKey('cloud-field-tencent-secretKey')), 'good');
    await tester.tap(find.byKey(const ValueKey('cloud-save')));
    await settle(tester, () => find.text('Saved.').evaluate().isNotEmpty);
    expect(find.text('Saved.'), findsOneWidget);
    expect(await tester.runAsync(() => secrets.read('asr:tencent')), contains('good'));
    expect(platform.enabledCloudBackends, {'cloud.tencent'});
    // The secret is not shown again; leaving it empty keeps it.
    final field = tester.widget<TextField>(
      find.byKey(const ValueKey('cloud-field-tencent-secretKey')),
    );
    expect(field.controller!.text, isEmpty);
    expect(find.byKey(const ValueKey('cloud-forget')), findsOneWidget);
  });
}

DownloadJob? downloaderJob(SpeechModelService service) =>
    service.downloader.jobFor(SpeechModels.smallEnglishStreaming.pack!.id);

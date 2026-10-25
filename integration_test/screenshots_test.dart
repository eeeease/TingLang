// README screenshots, rendered by the real app on this Mac (system fonts,
// real platform) from a temporary library with original sample content.
// Only runs when asked:
//
//   fvm flutter test integration_test/screenshots_test.dart -d macos \
//     --dart-define=TINGLANG_SCREENSHOTS=$PWD/docs/screenshots
//
// It never reads the user's data folder or Keychain and drives the app only
// through the widget tester (no system-level input).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path/path.dart' as p;
import 'package:tinglang/app.dart';
import 'package:tinglang/core/db/sqlite_library_store.dart';
import 'package:tinglang/core/live_repository.dart';
import 'package:tinglang/core/providers/provider_repository.dart';
import 'package:tinglang/services/app_controller.dart';
import 'package:tinglang/services/live_controller.dart';
import 'package:tinglang/services/panel_coordinator.dart';
import 'package:tinglang/services/playback_hub.dart';
import 'package:tinglang/services/recording_service.dart';
import 'package:tinglang/services/speech_model_service.dart';
import 'package:tinglang/services/transcription_controller.dart';
import 'package:tinglang/l10n/app_localizations.dart';
import 'package:tinglang_native/tinglang_native.dart';
import 'package:tinglang_platform_interface/testing.dart' show InMemorySecretStore;

const _out = String.fromEnvironment('TINGLANG_SCREENSHOTS');

/// An original short talk (written for this project) with translations.
const _talk = [
  (
    'Most people think listening is passive, but it is the hardest part of learning a language.',
    '很多人以为听是被动的，其实它是学语言最难的部分。',
  ),
  ('When a native speaker talks, the words run together like waves.', '母语者说话时，单词像海浪一样连成一片。'),
  ('You hear the rhythm before you hear the meaning.', '你先听到节奏，然后才听懂意思。'),
  (
    'So instead of switching to a new podcast every day, stay with one episode for a week.',
    '所以别每天换一个新播客，同一期听上一周。',
  ),
  ('Play a sentence, pause, and try to write down every word you caught.', '播放一句，暂停，试着写下你听到的每个词。'),
  ('The gaps in your notes show you exactly what to practise next.', '笔记里的空白，正好告诉你下一步该练什么。'),
  ('Then say the sentence out loud, copying the stress and the pauses.', '然后把这句话大声说出来，模仿重音和停顿。'),
  (
    'After a few days, the same episode sounds slower, and that is your ear getting faster.',
    '几天以后，同一期节目听起来变慢了——那是你的耳朵变快了。',
  ),
];

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('README screenshots', (tester) async {
    if (_out.isEmpty) {
      markTestSkipped('Set --dart-define=TINGLANG_SCREENSHOTS=<folder> to render screenshots.');
      return;
    }
    final platform = TinglangNative.install();
    MediaKit.ensureInitialized();
    final dir = await Directory.systemTemp.createTemp('tinglang-shots-');
    addTearDown(() => dir.delete(recursive: true));
    final store = SqliteLibraryStore.open(dir);
    final app = AppController(store, await store.load());
    await app.setSettings({AppController.themeKey: 'light', AppController.uiLocaleKey: 'en'});
    final repository = LiveRepository(store.db);
    final live = LiveController(repository: repository, platform: platform);
    await live.init();
    final models = ModelStore(p.join(dir.path, 'models'));
    platform.models = models;
    final secrets = InMemorySecretStore();
    final speech = SpeechModelService(
      app: app,
      store: models,
      downloader: ModelDownloader(store: models, appVersion: appVersion),
      platform: platform,
      cloudSecrets: CloudAsrSecrets(() => secrets),
    );
    final providers = ProviderRepository(
      store.db,
      secrets,
      ProviderCatalog.fromJson(await rootBundle.loadString('assets/providers/catalog.v1.json')),
    );
    final navigation = ValueNotifier<ShellRequest?>(null);

    // Sample content: the demo course and three caption sessions.
    await app.installDemo();
    final wav = await rootBundle.load('assets/demo/consistency.wav');
    final media = File(p.join(store.root.path, 'media', 'sample-talk.wav'))
      ..createSync(recursive: true)
      ..writeAsBytesSync(wav.buffer.asUint8List());
    await repository.addMedia(
      id: 'sample-talk',
      kind: 'audio',
      relPath: p.relative(media.path, from: store.root.path),
      durationMs: 36000,
    );
    final now = DateTime.now().toUtc();
    Future<String> session(String id, String title, DateTime at, int lines, {int from = 0}) async {
      await repository.createSession(
        id: id,
        origin: 'live_system',
        language: 'en',
        title: title,
        startedAt: at,
      );
      await repository.addSegments(id, [
        for (var i = 0; i < lines; i++)
          (
            id: '$id-$i',
            startMs: i * 4300,
            endMs: i * 4300 + 4000,
            text: _talk[(from + i) % _talk.length].$1,
            language: 'en',
            wordsJson: null,
          ),
      ]);
      await repository.addTranslations([
        for (var i = 0; i < lines; i++)
          (
            segmentId: '$id-$i',
            target: 'zh-Hans',
            text: _talk[(from + i) % _talk.length].$2,
            provider: BackendCatalog.appleTranslation.id,
          ),
      ]);
      await repository.endSession(
        id,
        status: 'completed',
        endedAt: at.add(const Duration(minutes: 3)),
      );
      return id;
    }

    final main = await session('talk', 'Listening is a skill', now, _talk.length);
    await repository.attachMedia(main, 'sample-talk');
    await session('standup', '', now.subtract(const Duration(hours: 2)), 4, from: 3);
    await session('match', '', now.subtract(const Duration(days: 1)), 6, from: 1);

    await binding.setSurfaceSize(const Size(1240, 780));
    const shotKey = ValueKey('screenshot');
    await tester.pumpWidget(
      RepaintBoundary(
        key: shotKey,
        child: TinglangApp(
          controller: app,
          playback: PlaybackHub(),
          recorder: RecordingService(store),
          live: live,
          transcription: TranscriptionController(repository: repository, store: store),
          navigation: navigation,
          exitNotice: ValueNotifier(null),
          providers: providers,
          speechModels: speech,
          // Shows the "Get a key" link; nothing is opened.
          openUrl: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> settle([int ms = 600]) async {
      for (var i = 0; i < ms ~/ 50; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    Future<void> shot(String locale, String name) async {
      await settle();
      final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(shotKey));
      final image = await boundary.toImage(pixelRatio: 2);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File(p.join(_out, locale, '$name.png'))..createSync(recursive: true);
      file.writeAsBytesSync(png!.buffer.asUint8List());
    }

    Future<void> tap(Finder finder) async {
      await tester.ensureVisible(finder);
      await tester.tap(finder);
      await settle();
    }

    for (final locale in ['en', 'zh']) {
      await app.setSetting(AppController.uiLocaleKey, locale);
      await settle();
      final l = lookupAppLocalizations(Locale(locale));

      // History: today's and yesterday's captions.
      await tap(find.byKey(const ValueKey('nav-records')));
      await tap(find.text(l.tabCaptions));
      await shot(locale, '1-history');

      // One session, sentence by sentence, with the player.
      navigation.value = OpenSession(main);
      await settle(1500);
      await shot(locale, '2-session');
      await tap(find.text(l.sessionDictation));
      final field = find.byType(TextField);
      if (field.evaluate().isNotEmpty) {
        await tester.enterText(
          field.first,
          'Most people think listening is passive, but it is the hardest part',
        );
        await tap(find.text(l.dictationCheck));
      }
      await shot(locale, '3-dictation');
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await settle();

      // The library and a course made from what was heard.
      await tap(find.byKey(const ValueKey('nav-library')));
      await shot(locale, '4-library');
      final course = find.text('Small reps. Real progress.');
      if (course.evaluate().isNotEmpty) {
        await tap(course.first);
        await settle(1200);
        await shot(locale, '5-course');
      }

      // Settings: speech recognition on this Mac, then a cloud API.
      await tap(find.byKey(const ValueKey('nav-settings')));
      await tap(find.text(l.settingsSpeechModels));
      await speech.setMode(RecognitionMode.local);
      await shot(locale, '6-speech-local');
      if (speech.cloudProviders.isNotEmpty) {
        await speech.chooseCloudProvider(speech.cloudProviders.first.info.id);
        await settle();
        await shot(locale, '7-speech-cloud');
      }
      await speech.setMode(RecognitionMode.local);
    }
    expect(tester.takeException(), isNull);
  });
}

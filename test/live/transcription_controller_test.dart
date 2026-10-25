import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tinglang/core/db/database.dart';
import 'package:tinglang/core/library_store.dart';
import 'package:tinglang/core/live_repository.dart';
import 'package:tinglang/services/speech_model_service.dart';
import 'package:tinglang/services/transcription_controller.dart';
import 'package:tinglang_native/tinglang_native.dart';
import 'package:tinglang_platform_interface/testing.dart';

void main() {
  late Directory dir;
  late TinglangDatabase db;
  late LiveRepository repo;
  late FakeFileTranscriber transcriber;
  late TranscriptionController controller;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('tinglang-import-');
    db = TinglangDatabase.memory();
    repo = LiveRepository(db);
    transcriber = FakeFileTranscriber(
      BackendCatalog.speechAnalyzerFile.id,
      output: const [
        TranscriptSegment(
          startMs: 0,
          endMs: 1500,
          text: 'Hello there.',
          words: [TimedWord('Hello', 0, 600), TimedWord('there.', 700, 1500)],
        ),
        TranscriptSegment(startMs: 1600, endMs: 3000, text: 'General Kenobi.'),
      ],
      info: const MediaInfo(durationMs: 3000, hasVideo: true, hasAudio: true),
    );
    final platform = TinglangPlatform(
      probeSource: FakeProbeSource(FakeProbes.macos(const OsVersion(26))),
    )..fileAsr.register(BackendFactory(BackendCatalog.speechAnalyzerFile, () => transcriber));
    controller = TranscriptionController(
      repository: repo,
      store: LibraryStore(Directory('${dir.path}/library')),
      platform: platform,
    );
  });
  tearDown(() async {
    await db.close();
    await dir.delete(recursive: true);
  });

  Future<ImportJob> run(String name) async {
    final file = File('${dir.path}/$name')..writeAsBytesSync(List.filled(64, 7));
    final job = await controller.importFile(file, language: 'en', translateTo: 'zh-Hans');
    while (job.status == ImportStatus.copying || job.status == ImportStatus.transcribing) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    return job;
  }

  test('import copies media, stores a media-timed session with words and translations', () async {
    final job = await run('talk.mp4');
    expect(job.status, ImportStatus.done, reason: job.error);
    final session = (await repo.session(job.sessionId))!;
    expect(session.origin, 'file');
    expect(session.timeBase, 'media');
    expect(session.status, 'completed');
    final media = (await repo.media(session.mediaId!))!;
    expect(media.kind, 'video');
    expect(media.durationMs, 3000);
    expect(File('${dir.path}/library/${media.relPath}').existsSync(), isTrue);
    final lines = await repo.lines(job.sessionId);
    expect(lines.map((l) => (l.text, l.translation)), [
      ('Hello there.', '[zh-Hans] Hello there.'),
      ('General Kenobi.', '[zh-Hans] General Kenobi.'),
    ]);
    expect(lines.first.wordsJson, contains('"w":"Hello"'));
    expect(lines.last.wordsJson, isNull);
  });

  test('Voice Memos QuickTime audio (.qta) is accepted', () async {
    final job = await run('memo.qta');
    expect(job.status, ImportStatus.done, reason: job.error);
    final session = (await repo.session(job.sessionId))!;
    expect((await repo.media(session.mediaId!))!.relPath, endsWith('.qta'));
  });

  test('unsupported formats fail before copying anything', () async {
    final job = await run('clip.mkv');
    expect(job.status, ImportStatus.failed);
    expect(job.error, contains('.mkv'));
    expect(job.failure, isA<ImportFailure>());
    expect(await db.select(db.sessions).get(), isEmpty);
    expect(Directory('${dir.path}/library/media').existsSync(), isFalse);
  });

  test('a file without audio is refused and leaves no session', () async {
    transcriber = FakeFileTranscriber(
      BackendCatalog.speechAnalyzerFile.id,
      info: const MediaInfo(durationMs: 1000, hasVideo: true, hasAudio: false),
    );
    final platform = TinglangPlatform(
      probeSource: FakeProbeSource(FakeProbes.macos(const OsVersion(26))),
    )..fileAsr.register(BackendFactory(BackendCatalog.speechAnalyzerFile, () => transcriber));
    controller = TranscriptionController(
      repository: repo,
      store: LibraryStore(Directory('${dir.path}/library')),
      platform: platform,
    );
    final job = await run('silent.mov');
    expect(job.status, ImportStatus.failed);
    expect(await db.select(db.sessions).get(), isEmpty);
  });

  group('chosen file model', () {
    late TinglangPlatform platform;
    late _Models models;

    void use(OsVersion version, {Set<String> assets = const {}, String? model}) {
      platform = fakeTinglangPlatform(FakeProbes.macos(version, installedAssets: assets))
        ..speechAssets = FakeSpeechAssetSupport(
          installed: {
            FakeSpeechAssetSupport.key('en-US', SpeechEngine.appleSpeech),
            FakeSpeechAssetSupport.key('en-US', SpeechEngine.appleDictation),
          },
        );
      models = _Models(model);
      controller = TranscriptionController(
        repository: repo,
        store: LibraryStore(Directory('${dir.path}/library')),
        platform: platform,
        models: models,
      );
    }

    /// Replaces [spec]'s fake with one instance the test can inspect.
    FakeFileTranscriber watch(BackendSpec spec) {
      final fake = FakeFileTranscriber(spec.id);
      platform.fileAsr.register(BackendFactory<FileTranscriber>(spec, () => fake));
      return fake;
    }

    test('macOS 14.2 without a downloaded model refuses before copying', () async {
      use(const OsVersion(14, 2));
      final job = await run('talk.m4a');
      expect(job.status, ImportStatus.failed);
      expect(
        job.failure,
        isA<ImportFailure>()
            .having((f) => f.problem, 'problem', ImportProblem.modelMissing)
            .having((f) => f.detail, 'model', SpeechModels.xasrOffline.id),
      );
      expect(Directory('${dir.path}/library/media').existsSync(), isFalse);
      expect(await db.select(db.sessions).get(), isEmpty);
    });

    test('a chosen Parakeet without its files is reported, not swapped for Apple', () async {
      use(const OsVersion(26), model: SpeechModels.parakeet.id);
      final job = await run('talk.m4a');
      expect((job.failure! as ImportFailure).detail, SpeechModels.parakeet.id);
    });

    test('a downloaded sherpa model transcribes on 14.2', () async {
      use(
        const OsVersion(14, 2),
        assets: SpeechModels.parakeet.requiredAssets,
        model: SpeechModels.parakeet.id,
      );
      final parakeet = watch(BackendCatalog.sherpaParakeet);
      final job = await run('talk.m4a');
      expect(job.status, ImportStatus.done, reason: job.error);
      expect(parakeet.jobs, hasLength(1));
    });

    test('Apple Dictation is used for files and gets the accent', () async {
      use(const OsVersion(26), model: SpeechModels.appleDictation.id);
      models.options = const SpeechOptions(
        locale: 'en-US',
        dictation: DictationHints(shortForm: true),
      );
      final dictation = watch(BackendCatalog.dictationFile);
      final job = await run('talk.m4a');
      expect(job.status, ImportStatus.done, reason: job.error);
      expect(dictation.jobs, hasLength(1));
    });

    test('a missing macOS accent asset is reported before copying', () async {
      use(const OsVersion(26));
      models.options = const SpeechOptions(locale: 'en-IN');
      final job = await run('talk.m4a');
      expect(
        job.failure,
        isA<ImportFailure>()
            .having((f) => f.problem, 'problem', ImportProblem.speechAssetMissing)
            .having((f) => f.detail, 'locale', 'en-IN'),
      );
      expect(Directory('${dir.path}/library/media').existsSync(), isFalse);
    });

    test('cloud chosen without a key refuses before copying; nothing runs here', () async {
      use(const OsVersion(26), model: 'cloud.azure');
      models.cloudMissing = true;
      final apple = watch(BackendCatalog.speechAnalyzerFile);
      final job = await run('talk.m4a');
      expect(
        job.failure,
        isA<ImportFailure>().having((f) => f.problem, 'problem', ImportProblem.cloudNotSetUp),
      );
      expect(apple.jobs, isEmpty);
      expect(Directory('${dir.path}/library/media').existsSync(), isFalse);

      // A key is saved but the app has not enabled the backend: still refused.
      models.cloudMissing = false;
      final again = await run('talk.m4a');
      expect((again.failure! as ImportFailure).problem, ImportProblem.cloudNotSetUp);
      expect(apple.jobs, isEmpty);
    });

    test('an enabled cloud service transcribes the file, also on 14.2', () async {
      use(const OsVersion(14, 2), model: 'cloud.azure');
      platform.enabledCloudBackends = {'cloud.azure'};
      final azure = watch(BackendCatalog.azureCloud);
      final job = await run('talk.m4a');
      expect(job.status, ImportStatus.done, reason: job.error);
      expect(azure.jobs, hasLength(1));
    });
  });
}

final class _Models implements SpeechModelSource {
  _Models(this.file);
  final String? file;
  SpeechOptions options = const SpeechOptions();
  bool cloudMissing = false;
  @override
  String? modelFor(SpeechUse use) => use == SpeechUse.file ? file : null;
  @override
  bool get setupChosen => true;
  @override
  bool get cloudNeedsSetup => cloudMissing;
  @override
  SpeechOptions optionsFor(String language) => options;
  @override
  int missingBytes(SpeechModel model) => model.downloadBytes;
  @override
  Future<void> download(SpeechModel model, {void Function(double fraction)? onProgress}) =>
      throw StateError('file imports never download');
  @override
  Future<void> cancelDownload(SpeechModel model) async {}
}

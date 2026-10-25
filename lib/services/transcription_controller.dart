import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:tinglang_native/tinglang_native.dart';

import '../core/dictation.dart';
import '../core/library_store.dart';
import '../core/live_repository.dart';
import 'app_controller.dart';
import 'speech_model_service.dart';

enum ImportStatus { copying, transcribing, done, failed, cancelled }

enum ImportProblem {
  unsupportedFormat,
  noAudio,
  noEngine,

  /// The chosen model's files are not downloaded ([ImportFailure.detail] is
  /// the model id).
  modelMissing,

  /// macOS has not downloaded its speech model for the language yet
  /// ([ImportFailure.detail] is the locale).
  speechAssetMissing,

  /// Cloud recognition is chosen but its service has no saved credentials
  /// ([ImportFailure.detail] is the backend id, or null).
  cloudNotSetUp,

  /// The chosen cloud service does not recognise the language
  /// ([ImportFailure.detail] is the backend id).
  cloudLanguageUnsupported,
}

/// Why an import was refused; the UI turns [problem] into a localised sentence.
class ImportFailure implements Exception {
  const ImportFailure(this.problem, [this.detail]);
  final ImportProblem problem;

  /// The offending extension for [ImportProblem.unsupportedFormat], the
  /// model id or the locale for the missing-model problems.
  final String? detail;

  @override
  String toString() => switch (problem) {
    ImportProblem.unsupportedFormat => 'Unsupported format: .$detail',
    ImportProblem.noAudio => 'This file has no audio track',
    ImportProblem.noEngine => 'No file transcription engine on this computer',
    ImportProblem.modelMissing => 'The speech model $detail is not downloaded',
    ImportProblem.speechAssetMissing => 'The macOS speech model for $detail is not installed',
    ImportProblem.cloudNotSetUp => 'No credentials are saved for cloud recognition',
    ImportProblem.cloudLanguageUnsupported => '$detail does not recognise this language',
  };
}

/// One imported file being copied, transcribed and translated.
class ImportJob extends ChangeNotifier {
  ImportJob(this.sessionId, this.title, {this.sourceRef});
  final String sessionId;
  final String title;

  /// Where the file came from (see `Sessions.sourceRef`), if anywhere known.
  final String? sourceRef;
  ImportStatus status = ImportStatus.copying;
  double progress = 0;
  int segments = 0;
  String? error;

  /// The exception behind [error], for a localised message.
  Object? failure;
  TranscriptionJob? _job;

  void _set({ImportStatus? status, double? progress, Object? failure}) {
    if (status != null) this.status = status;
    if (progress != null) this.progress = progress;
    if (failure != null) {
      this.failure = failure;
      error = '$failure';
    }
    notifyListeners();
  }

  Future<void> cancel() async => _job?.cancel();
}

/// Transcribes [media] in the learning language and translates it into the
/// native language from [app]'s settings (no translation when they match).
Future<ImportJob> transcribeMedia(
  AppController app,
  TranscriptionController transcription,
  File media, {
  String origin = 'file',
  String? sourceRef,
  String? title,
  DateTime? recordedAt,
}) {
  final language = app.setting(AppController.learningLanguageKey, 'en');
  final native = app.setting(AppController.nativeLanguageKey, 'zh-Hans');
  return transcription.importFile(
    media,
    language: language,
    translateTo: native == language ? null : native,
    origin: origin,
    sourceRef: sourceRef,
    title: title,
    recordedAt: recordedAt,
  );
}

/// Imports local audio/video into the library (content-addressed copy),
/// transcribes it with word timings, translates it and saves the result as a
/// `file` session whose times are offsets into the media.
class TranscriptionController extends ChangeNotifier {
  TranscriptionController({
    required this.repository,
    required this.store,
    TinglangPlatform? platform,
    this.batchSize = 20,
    this.models,
  }) : _platform = platform ?? (TinglangPlatform.isInstalled ? TinglangPlatform.instance : null);

  final LiveRepository repository;
  final LibraryStore store;
  final TinglangPlatform? _platform;
  final int batchSize;

  /// The chosen file model and the accent; null uses the platform's pick.
  SpeechModelSource? models;
  final jobs = <ImportJob>[];

  /// Formats AVFoundation can decode; MKV/WebM/Ogg are refused up front.
  /// `qta` is QuickTime audio, which Voice Memos uses next to `m4a`.
  static const extensions = [
    'mp3',
    'm4a',
    'qta',
    'aac',
    'wav',
    'aiff',
    'aif',
    'flac',
    'mp4',
    'mov',
    'm4v',
  ];

  /// The transcriber for [language], or why there is none. Never
  /// downloads: a missing model is reported so the user can approve it.
  Future<FileTranscriber> _transcriber(String language) async {
    final platform = _platform;
    if (platform == null) throw const ImportFailure(ImportProblem.noEngine);
    final preferredModel = models?.modelFor(SpeechUse.file);
    if (models?.cloudNeedsSetup ?? false) {
      throw ImportFailure(ImportProblem.cloudNotSetUp, preferredModel);
    }
    if (preferredModel != null && BackendCatalog.isCloudAsr(preferredModel)) {
      // Never silently transcribe on this Mac instead, or the other way round.
      final choice = platform.fileAsr.pick(await platform.probe(), preferredModel);
      if (!choice.usedPreference) {
        throw ImportFailure(ImportProblem.cloudNotSetUp, preferredModel);
      }
      final transcriber = choice.create();
      if (!transcriber.languages.contains(baseLanguage(language))) {
        throw ImportFailure(ImportProblem.cloudLanguageUnsupported, preferredModel);
      }
      return transcriber;
    }
    final wanted = preferredModel == null ? null : SpeechModels.byId(preferredModel);
    final choice = platform.fileAsr.pick(await platform.probe(), wanted?.backendId(SpeechUse.file));
    if (wanted != null && !choice.usedPreference && choice.preferredAvailability is NeedsDownload) {
      throw ImportFailure(ImportProblem.modelMissing, wanted.id);
    }
    if (!choice.hasSelection) {
      for (final candidate in choice.candidates) {
        if (candidate.availability is! NeedsDownload) continue;
        final model = SpeechModels.all.where(
          (m) => m.backendId(SpeechUse.file) == candidate.factory.id,
        );
        if (model.isNotEmpty) throw ImportFailure(ImportProblem.modelMissing, model.first.id);
      }
      throw const ImportFailure(ImportProblem.noEngine);
    }
    final id = choice.id!;
    final model = SpeechModels.all.where((m) => m.backendId(SpeechUse.file) == id).firstOrNull;
    final assets = platform.speechAssets;
    if (model != null && model.isApple && assets != null) {
      final locale = models?.optionsFor(language).locale ?? defaultRecognitionLocale(language);
      if (await assets.status(locale, model.engine) == AssetState.downloadable) {
        throw ImportFailure(ImportProblem.speechAssetMissing, locale);
      }
    }
    return choice.create();
  }

  /// Returns the new session id; progress is reported through the job.
  /// [origin], [sourceRef], [title] and [recordedAt] describe where the file
  /// came from (a Voice Memo keeps its own title and recording time).
  Future<ImportJob> importFile(
    File source, {
    required String language,
    String? translateTo,
    String origin = 'file',
    String? sourceRef,
    String? title,
    DateTime? recordedAt,
  }) async {
    final name = title == null || title.trim().isEmpty
        ? p.basenameWithoutExtension(source.path)
        : title.trim();
    final job = ImportJob(newId(), name, sourceRef: sourceRef);
    jobs.insert(0, job);
    notifyListeners();
    unawaited(
      _run(
        job,
        source,
        language,
        translateTo == language ? null : translateTo,
        origin: origin,
        startedAt: (recordedAt ?? DateTime.now()).toUtc(),
      ),
    );
    return job;
  }

  Future<void> _run(
    ImportJob job,
    File source,
    String language,
    String? translateTo, {
    required String origin,
    required DateTime startedAt,
  }) async {
    var sessionCreated = false;
    try {
      final extension = p.extension(source.path).replaceFirst('.', '').toLowerCase();
      if (!extensions.contains(extension)) {
        throw ImportFailure(ImportProblem.unsupportedFormat, extension);
      }
      final transcriber = await _transcriber(language);
      final relative = await store.importMedia(source);
      final absolute = store.resolve(relative);
      final info = await transcriber.inspect(absolute);
      if (!info.hasAudio) throw const ImportFailure(ImportProblem.noAudio);
      final mediaId = p.basenameWithoutExtension(relative);
      await repository.addMedia(
        id: mediaId,
        kind: info.hasVideo ? 'video' : 'audio',
        relPath: relative,
        sha256: mediaId,
        durationMs: info.durationMs,
        title: job.title,
      );
      await repository.createSession(
        id: job.sessionId,
        origin: origin,
        language: language,
        title: job.title,
        startedAt: startedAt,
        timeBase: 'media',
        mediaId: mediaId,
        sourceRef: job.sourceRef,
      );
      sessionCreated = true;
      job._set(status: ImportStatus.transcribing, progress: 0);

      final run = transcriber.transcribe(
        absolute,
        FileTranscriptionOptions(
          language: language,
          translateTo: translateTo,
          speech: models?.optionsFor(language) ?? const SpeechOptions(),
        ),
      );
      job._job = run;
      final pending = <NewSegment>[];
      final pendingTranslations =
          <({String segmentId, String target, String text, String provider})>[];
      var index = 0;
      var write = Future<void>.value();
      void flush() {
        final segments = [...pending];
        pending.clear();
        final translations = [...pendingTranslations];
        pendingTranslations.clear();
        write = write.then((_) async {
          await repository.addSegments(job.sessionId, segments);
          await repository.addTranslations(translations);
        });
      }

      final subs = <StreamSubscription<Object?>>[
        run.progress.listen((v) => job._set(progress: v)),
        run.segments.listen((s) {
          pending.add((
            id: '${job.sessionId}-${index++}',
            startMs: s.startMs,
            endMs: s.endMs,
            text: s.text,
            language: language,
            wordsJson: wordsToJson(s.words),
          ));
          job.segments = index;
          if (pending.length >= batchSize) flush();
        }),
        run.translations.listen((t) {
          if (translateTo == null) return;
          pendingTranslations.add((
            segmentId: '${job.sessionId}-${t.$1}',
            target: translateTo,
            text: t.$2,
            provider: BackendCatalog.appleTranslation.id,
          ));
          // Translations reference saved segments: flush segments first.
          if (pendingTranslations.length >= batchSize) flush();
        }),
      ];
      await run.result;
      for (final sub in subs) {
        await sub.cancel();
      }
      flush();
      await write;
      await repository.endSession(
        job.sessionId,
        status: 'completed',
        endedAt: DateTime.now().toUtc(),
      );
      job._set(status: ImportStatus.done, progress: 1);
    } catch (e) {
      final cancelled = '$e'.contains('Cancel');
      if (sessionCreated) {
        await repository.endSession(
          job.sessionId,
          status: cancelled ? 'interrupted' : 'failed',
          endedAt: DateTime.now().toUtc(),
        );
      }
      job._set(status: cancelled ? ImportStatus.cancelled : ImportStatus.failed, failure: e);
    }
    notifyListeners();
  }
}

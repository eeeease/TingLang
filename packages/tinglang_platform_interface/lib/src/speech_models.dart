import 'package:meta/meta.dart';

import 'platform_probe.dart';

/// How hard the recogniser works for earlier captions. Higher tiers cost
/// more CPU; the numbers shown in Settings come from
/// docs/perf/asr-bench-2026-10.md and the 0.4 latency measurements.
enum LatencyTier {
  /// Captions update about 4 times a second; lines end after a longer pause.
  powerSaver,

  /// The default: 10 updates a second.
  balanced,

  /// Apple: `fastResults`, higher task priority, the model kept loaded and
  /// (macOS 27+) resource limits ignored. sherpa: 50 ms feeds and a shorter
  /// end-of-line pause (0.5 s; X-ASR keeps 0.8 s, see SherpaStreamingAsr).
  fastest,
}

/// What a [SpeechModel] runs on.
enum SpeechEngine {
  /// Apple SpeechTranscriber (system asset per locale, macOS 26+).
  appleSpeech,

  /// Apple DictationTranscriber (system asset per locale, macOS 26+), with
  /// optional content hints.
  appleDictation,

  /// sherpa-onnx online (streaming) transducer, downloaded by Tinglang.
  sherpaStreaming,

  /// sherpa-onnx offline transducer over VAD segments, downloaded by Tinglang.
  sherpaOffline,
}

/// Where a model can be used.
enum SpeechUse { live, file }

/// sherpa-onnx model family; selects the recogniser config.
enum SherpaModelType {
  /// Zipformer transducer (icefall): encoder/decoder/joiner + tokens.
  zipformerTransducer,

  /// NeMo transducer (Parakeet TDT): `model_type: nemo_transducer`.
  nemoTransducer,
}

/// Which pack files a sherpa-onnx transducer config points at.
@immutable
final class SherpaFiles {
  const SherpaFiles({
    required this.encoder,
    required this.decoder,
    required this.joiner,
    this.tokens = 'tokens.txt',
  });
  final String encoder, decoder, joiner, tokens;
}

/// One downloadable file, verified against [sha256] after download.
@immutable
final class ModelFile {
  const ModelFile({
    required this.name,
    required this.url,
    required this.bytes,
    required this.sha256,
  });

  /// File name inside the model's folder.
  final String name;

  /// https only, from k2-fsa's GitHub releases or Hugging Face (pinned to a
  /// commit). Empty when the file comes out of the pack's [ModelArchive].
  final String url;
  final int bytes;

  /// Lower-case hex SHA-256 of the file's bytes.
  final String sha256;
}

/// A release archive (`.tar.bz2`) that holds a pack's files, for models that
/// are only published that way. Verified as a whole, then each extracted
/// file is verified against its [ModelFile.sha256].
@immutable
final class ModelArchive {
  const ModelArchive({
    required this.url,
    required this.bytes,
    required this.sha256,
    required this.folder,
  });
  final String url;
  final int bytes;
  final String sha256;

  /// Top-level folder inside the archive that contains the files.
  final String folder;
}

@immutable
final class ModelLicense {
  const ModelLicense(this.name, this.url, {this.attribution});

  /// SPDX-style short name, e.g. `Apache-2.0`, `CC-BY-4.0`.
  final String name;
  final String url;

  /// Credit line the licence asks for (shown next to the model).
  final String? attribution;
}

/// A downloadable pack of files stored under `<data>/models/<id>/`.
@immutable
final class ModelPack {
  const ModelPack({
    required this.id,
    required this.files,
    required this.license,
    this.source,
    this.archive,
  });

  /// Asset id, as used in [BackendSpec.assets] and [PlatformProbe.installedAssets].
  final String id;
  final List<ModelFile> files;
  final ModelLicense license;

  /// Human-readable origin (release page or repository).
  final String? source;

  /// Set when the files are extracted from one release archive.
  final ModelArchive? archive;

  /// Size on disk once installed.
  int get bytes => files.fold(0, (sum, f) => sum + f.bytes);

  /// What the download transfers (the archive, or the files).
  int get downloadBytes => archive?.bytes ?? bytes;
}

/// Relative ratings shown in Settings (1 = least, 3 = most).
@immutable
final class ModelRatings {
  const ModelRatings({required this.accuracy, required this.speed, required this.cpuPercent});

  /// 3 = most accurate of the offered models on the benchmark sets.
  final int accuracy;

  /// 3 = earliest captions.
  final int speed;

  /// Measured CPU while captioning or transcribing (100 = one core),
  /// including Apple's out-of-process speech services
  /// (docs/perf/asr-latency-2026-10.md).
  final double cpuPercent;
}

/// A recommended speech recognition choice in Settings → Speech models.
@immutable
final class SpeechModel {
  const SpeechModel({
    required this.id,
    required this.engine,
    required this.uses,
    required this.languages,
    required this.ratings,
    this.pack,
    this.sherpaType,
    this.minMacos,
    this.license,
    this.fileBackendId,
    this.sherpaFiles,
  });

  /// Equal to the backend id (`speech_transcriber`, `sherpa.xasr_zh_en_480`…).
  final String id;
  final SpeechEngine engine;
  final Set<SpeechUse> uses;

  /// BCP-47 base languages recognised (`en`, `zh-Hans`).
  final Set<String> languages;
  final ModelRatings ratings;

  /// Files Tinglang downloads; null for Apple system assets.
  final ModelPack? pack;
  final SherpaModelType? sherpaType;
  final OsVersion? minMacos;

  /// Licence of the weights; for Apple engines, null (part of macOS).
  final ModelLicense? license;

  /// Backend id in the `fileAsr` registry when it differs from [id] (Apple
  /// engines register live and file backends separately).
  final String? fileBackendId;

  /// File names inside [pack] for the recogniser config (sherpa only).
  final SherpaFiles? sherpaFiles;

  /// The backend that runs this model for [use].
  String backendId(SpeechUse use) => use == SpeechUse.file ? fileBackendId ?? id : id;

  bool get isApple => engine == SpeechEngine.appleSpeech || engine == SpeechEngine.appleDictation;
  bool get isSherpa => !isApple;

  /// Download size including the shared VAD; 0 for system assets.
  int get downloadBytes => pack == null ? 0 : pack!.downloadBytes + SpeechModels.vad.downloadBytes;

  /// Size on disk once installed, including the shared VAD.
  int get diskBytes => pack == null ? 0 : pack!.bytes + SpeechModels.vad.bytes;

  /// Asset ids that must be installed before this model can run.
  Set<String> get requiredAssets => pack == null ? const {} : {pack!.id, SpeechModels.vad.id};
}

/// Apple DictationTranscriber content hints offered in Settings.
@immutable
final class DictationHints {
  const DictationHints({this.farField = false, this.shortForm = false});

  /// Speech from across a room or through speakers.
  final bool farField;

  /// Short utterances (commands, single phrases).
  final bool shortForm;

  @override
  bool operator ==(Object other) =>
      other is DictationHints && other.farField == farField && other.shortForm == shortForm;

  @override
  int get hashCode => Object.hash(farField, shortForm);
}

/// The user's speech choices for a live session or a file job.
@immutable
final class SpeechOptions {
  const SpeechOptions({
    this.latency = LatencyTier.balanced,
    this.locale,
    this.dictation = const DictationHints(),
  });
  final LatencyTier latency;

  /// Recognition locale override (an English accent such as `en-GB`); null
  /// derives it from the language.
  final String? locale;

  /// Used only when the engine is [SpeechEngine.appleDictation].
  final DictationHints dictation;

  @override
  bool operator ==(Object other) =>
      other is SpeechOptions &&
      other.latency == latency &&
      other.locale == locale &&
      other.dictation == dictation;

  @override
  int get hashCode => Object.hash(latency, locale, dictation);
}

/// Apple Speech knobs per [LatencyTier] (see `SpeechAnalyzer.Options` and
/// `SpeechTranscriber.ReportingOption` in the macOS SDK).
@immutable
final class AppleLatencyParams {
  const AppleLatencyParams({
    required this.fastResults,
    required this.priority,
    required this.modelRetention,
    required this.ignoresResourceLimits,
    required this.partialIntervalMs,
    required this.frequentFinalization,
  });

  /// `SpeechTranscriber.ReportingOption.fastResults`.
  final bool fastResults;

  /// `TaskPriority` name: `utility`, `userInitiated` or `high`.
  final String priority;

  /// `SpeechAnalyzer.Options.ModelRetention`: `whileInUse`, `lingering`,
  /// `processLifetime`.
  final String modelRetention;

  /// macOS 27+ only; ignored on 26.
  final bool ignoresResourceLimits;

  /// How often coalesced partials go to the panel and Dart.
  final int partialIntervalMs;

  /// `DictationTranscriber.ReportingOption.frequentFinalization` (live).
  /// On for every tier: without it Dictation ended a line ~15 s after the
  /// speech (p50, docs/perf/asr-latency-2026-10.md).
  final bool frequentFinalization;
}

/// sherpa-onnx knobs per [LatencyTier].
@immutable
final class SherpaLatencyParams {
  const SherpaLatencyParams({
    required this.numThreads,
    required this.feedMs,
    required this.endpointSilenceMs,
    required this.partialIntervalMs,
  });

  /// onnxruntime intra-op threads (spinning disabled).
  final int numThreads;

  /// Audio handed to the recogniser per decode step.
  final int feedMs;

  /// Trailing silence that ends a line (endpoint rule 2).
  final int endpointSilenceMs;

  /// Minimum gap between partials sent to the UI (the panel takes ≤ 10 Hz).
  final int partialIntervalMs;
}

abstract final class LatencyTiers {
  static AppleLatencyParams apple(LatencyTier tier) => switch (tier) {
    LatencyTier.powerSaver => const AppleLatencyParams(
      fastResults: false,
      priority: 'utility',
      modelRetention: 'whileInUse',
      ignoresResourceLimits: false,
      partialIntervalMs: 250,
      frequentFinalization: true,
    ),
    LatencyTier.balanced => const AppleLatencyParams(
      fastResults: false,
      priority: 'userInitiated',
      modelRetention: 'lingering',
      ignoresResourceLimits: false,
      partialIntervalMs: 100,
      frequentFinalization: true,
    ),
    LatencyTier.fastest => const AppleLatencyParams(
      fastResults: true,
      priority: 'high',
      modelRetention: 'processLifetime',
      ignoresResourceLimits: true,
      partialIntervalMs: 50,
      frequentFinalization: true,
    ),
  };

  static SherpaLatencyParams sherpa(LatencyTier tier) => switch (tier) {
    LatencyTier.powerSaver => const SherpaLatencyParams(
      numThreads: 1,
      feedMs: 200,
      endpointSilenceMs: 1000,
      partialIntervalMs: 250,
    ),
    LatencyTier.balanced => const SherpaLatencyParams(
      numThreads: 1,
      feedMs: 100,
      endpointSilenceMs: 800,
      partialIntervalMs: 100,
    ),
    // One thread on every tier: a second onnxruntime thread cost about 9
    // points of CPU for ~0.03 s earlier words (docs/perf/asr-latency-2026-10.md).
    LatencyTier.fastest => const SherpaLatencyParams(
      numThreads: 1,
      feedMs: 50,
      endpointSilenceMs: 500,
      partialIntervalMs: 100,
    ),
  };
}

/// English accents (SpeechTranscriber/DictationTranscriber locales) offered
/// in Settings; each is a separate system asset.
const englishAccents = [
  'en-US',
  'en-GB',
  'en-AU',
  'en-IN',
  'en-CA',
  'en-IE',
  'en-NZ',
  'en-SG',
  'en-ZA',
];

/// The recommended models, in the order Settings shows them. Download
/// metadata (URLs, sizes, SHA-256) is checked in `speech_models_test.dart`
/// and listed in NOTICE.md.
abstract final class SpeechModels {
  static const _macos26 = OsVersion(26);
  static const _k2Releases = 'https://github.com/k2-fsa/sherpa-onnx/releases/tag/asr-models';
  static const _k2Download = 'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models';
  static const _xasrLicense = ModelLicense(
    'Apache-2.0',
    'https://github.com/Gilgamesh-J/X-ASR',
    attribution:
        'X-ASR by SJTU, Shanghai Innovation Institute, Fudan and HUST; ONNX export by k2-fsa',
  );
  static const _parakeetLicense = ModelLicense(
    'CC-BY-4.0',
    'https://huggingface.co/nvidia/parakeet-tdt-0.6b-v2',
    attribution: 'Parakeet TDT 0.6B v2 by NVIDIA (CC-BY-4.0); ONNX int8 export by k2-fsa',
  );
  static const _parakeetHf =
      'https://huggingface.co/csukuangfj/sherpa-onnx-nemo-parakeet-tdt-0.6b-v2-int8/resolve/1ab9323565ddb038682214b292f588070a538ce2';
  static const _zipformer20mLicense = ModelLicense(
    'Apache-2.0',
    'https://huggingface.co/desh2608/icefall-asr-librispeech-pruned-transducer-stateless7-streaming-small',
    attribution: 'icefall streaming zipformer (20M, LibriSpeech); ONNX export by k2-fsa',
  );
  static const _zipformer66mLicense = ModelLicense(
    'Apache-2.0',
    'https://huggingface.co/Zengwei/icefall-asr-librispeech-streaming-zipformer-2023-05-17',
    attribution: 'icefall streaming zipformer (66M, LibriSpeech); ONNX export by k2-fsa',
  );
  static const _zipformer66mHf =
      'https://huggingface.co/csukuangfj/sherpa-onnx-streaming-zipformer-en-2023-06-26/resolve/672fbf1b30579d6585301139bb363f42a0ad4a24';
  static const _zipformer20mHf =
      'https://huggingface.co/csukuangfj/sherpa-onnx-streaming-zipformer-en-20M-2023-02-17/resolve/d42f2d9f7ca24806fb667456a18a9f1b60f70d16';

  /// Silero VAD, shared by every sherpa model (gates silence before the
  /// recogniser, and splits files into segments).
  static const vad = ModelPack(
    id: 'silero-vad',
    source: _k2Releases,
    license: ModelLicense('MIT', 'https://github.com/snakers4/silero-vad/blob/master/LICENSE'),
    files: [
      ModelFile(
        name: 'silero_vad.onnx',
        url: '$_k2Download/silero_vad.onnx',
        bytes: 643854,
        sha256: '9e2449e1087496d8d4caba907f23e0bd3f78d91fa552479bb9c23ac09cbb1fd6',
      ),
    ],
  );

  static const appleSpeech = SpeechModel(
    id: 'speech_transcriber',
    engine: SpeechEngine.appleSpeech,
    uses: {SpeechUse.live, SpeechUse.file},
    languages: {'en', 'zh-Hans', 'zh-Hant', 'ja', 'ko', 'es', 'fr', 'de'},
    ratings: ModelRatings(accuracy: 3, speed: 3, cpuPercent: 3),
    minMacos: _macos26,
    fileBackendId: 'speech_analyzer_file',
  );

  static const appleDictation = SpeechModel(
    id: 'dictation_transcriber',
    engine: SpeechEngine.appleDictation,
    uses: {SpeechUse.live, SpeechUse.file},
    languages: {'en', 'zh-Hans', 'zh-Hant', 'ja', 'ko', 'es', 'fr', 'de'},
    ratings: ModelRatings(accuracy: 1, speed: 2, cpuPercent: 11),
    minMacos: _macos26,
    fileBackendId: 'dictation_file',
  );

  /// X-ASR zh-en streaming zipformer, 480 ms chunks, int8 (live; en + zh).
  static const xasrStreaming = SpeechModel(
    id: 'sherpa.xasr_zh_en_480',
    engine: SpeechEngine.sherpaStreaming,
    uses: {SpeechUse.live},
    languages: {'en', 'zh-Hans'},
    ratings: ModelRatings(accuracy: 2, speed: 2, cpuPercent: 16),
    sherpaType: SherpaModelType.zipformerTransducer,
    sherpaFiles: SherpaFiles(
      encoder: 'encoder.int8.onnx',
      decoder: 'decoder.onnx',
      joiner: 'joiner.int8.onnx',
    ),
    pack: ModelPack(
      id: 'xasr-zh-en-480ms-int8',
      source: _k2Releases,
      license: _xasrLicense,
      archive: ModelArchive(
        url:
            '$_k2Download/sherpa-onnx-x-asr-480ms-streaming-zipformer-transducer-zh-en-punct-int8-2026-06-05.tar.bz2',
        bytes: 133895136,
        sha256: 'fa5f63d618e5a01526e275a358bb7772e403f84808a4769fba52cffd8160bf74',
        folder:
            'sherpa-onnx-x-asr-480ms-streaming-zipformer-transducer-zh-en-punct-int8-2026-06-05',
      ),
      files: [
        ModelFile(
          name: 'encoder.int8.onnx',
          url: '',
          bytes: 155278641,
          sha256: '908596dcc137a73b95be908ca55e88caa1b3dbbe8027c171615f4b0609c5eb1e',
        ),
        ModelFile(
          name: 'decoder.onnx',
          url: '',
          bytes: 11309084,
          sha256: 'a1cbc9eac2d5e3fb6617a218c67ad6daaa7f4e0fd225f08b2c22ab0413c8c257',
        ),
        ModelFile(
          name: 'joiner.int8.onnx',
          url: '',
          bytes: 2581422,
          sha256: 'aedb7fa697b2ab43f20499826fff7c997eea7d67db77be97769aeeeb726e63b3',
        ),
        ModelFile(
          name: 'tokens.txt',
          url: '',
          bytes: 58806,
          sha256: 'b818a60878b9aae978cbb8ad594acbd403d76d1af2e31ef4197c84e2dbdba27c',
        ),
      ],
    ),
    license: _xasrLicense,
  );

  /// A small English streaming zipformer: earliest captions, least CPU,
  /// less accurate.
  static const smallEnglishStreaming = SpeechModel(
    id: 'sherpa.zipformer_en_small',
    engine: SpeechEngine.sherpaStreaming,
    uses: {SpeechUse.live},
    languages: {'en'},
    ratings: ModelRatings(accuracy: 1, speed: 3, cpuPercent: 13),
    sherpaType: SherpaModelType.zipformerTransducer,
    sherpaFiles: SherpaFiles(
      encoder: 'encoder-epoch-99-avg-1.int8.onnx',
      decoder: 'decoder-epoch-99-avg-1.onnx',
      joiner: 'joiner-epoch-99-avg-1.int8.onnx',
    ),
    pack: ModelPack(
      id: 'zipformer-en-small-int8',
      source: 'https://huggingface.co/csukuangfj/sherpa-onnx-streaming-zipformer-en-20M-2023-02-17',
      license: _zipformer20mLicense,
      files: [
        ModelFile(
          name: 'encoder-epoch-99-avg-1.int8.onnx',
          url: '$_zipformer20mHf/encoder-epoch-99-avg-1.int8.onnx',
          bytes: 42845182,
          sha256: '3810755ce7c3ab26b42a8bcf39d191308fa27fb0f53358823ba46141d03b7eb3',
        ),
        ModelFile(
          name: 'decoder-epoch-99-avg-1.onnx',
          url: '$_zipformer20mHf/decoder-epoch-99-avg-1.onnx',
          bytes: 2092272,
          sha256: '45a7f940ecfb53d89fa270ad11b88b961e53a317203eb24b1c8e95ed208b0f30',
        ),
        ModelFile(
          name: 'joiner-epoch-99-avg-1.int8.onnx',
          url: '$_zipformer20mHf/joiner-epoch-99-avg-1.int8.onnx',
          bytes: 259572,
          sha256: 'e085d73b593cf9b0707f370dbd656d58327d3fe36d80d849202ef81df02cb01e',
        ),
        ModelFile(
          name: 'tokens.txt',
          url: '$_zipformer20mHf/tokens.txt',
          bytes: 5048,
          sha256: '49e3c2646595fd907228b3c6787069658f67b17377c60aeb8619c4551b2316fb',
        ),
      ],
    ),
    license: _zipformer20mLicense,
  );

  /// A 66M English streaming zipformer (320 ms chunks): between the small
  /// model and X-ASR.
  static const mediumEnglishStreaming = SpeechModel(
    id: 'sherpa.zipformer_en_medium',
    engine: SpeechEngine.sherpaStreaming,
    uses: {SpeechUse.live},
    languages: {'en'},
    ratings: ModelRatings(accuracy: 1, speed: 2, cpuPercent: 15),
    sherpaType: SherpaModelType.zipformerTransducer,
    sherpaFiles: SherpaFiles(
      encoder: 'encoder-epoch-99-avg-1-chunk-16-left-128.int8.onnx',
      decoder: 'decoder-epoch-99-avg-1-chunk-16-left-128.onnx',
      joiner: 'joiner-epoch-99-avg-1-chunk-16-left-128.int8.onnx',
    ),
    pack: ModelPack(
      id: 'zipformer-en-66m-int8',
      source: 'https://huggingface.co/csukuangfj/sherpa-onnx-streaming-zipformer-en-2023-06-26',
      license: _zipformer66mLicense,
      files: [
        ModelFile(
          name: 'encoder-epoch-99-avg-1-chunk-16-left-128.int8.onnx',
          url: '$_zipformer66mHf/encoder-epoch-99-avg-1-chunk-16-left-128.int8.onnx',
          bytes: 71083163,
          sha256: '563fde436d16cf7607cf408cd6b30909819d03162652ef389c2450ced3f45ac1',
        ),
        ModelFile(
          name: 'decoder-epoch-99-avg-1-chunk-16-left-128.onnx',
          url: '$_zipformer66mHf/decoder-epoch-99-avg-1-chunk-16-left-128.onnx',
          bytes: 2092621,
          sha256: '7bf787f90b194b307e5a4ad6a34fadb4e748304c35f78a8d66358a05b13ee6ef',
        ),
        ModelFile(
          name: 'joiner-epoch-99-avg-1-chunk-16-left-128.int8.onnx',
          url: '$_zipformer66mHf/joiner-epoch-99-avg-1-chunk-16-left-128.int8.onnx',
          bytes: 259335,
          sha256: 'd944208d660d67c8d72cd2acaeac971fa5ceb8c80e76c1968148846fedd6e297',
        ),
        ModelFile(
          name: 'tokens.txt',
          url: '$_zipformer66mHf/tokens.txt',
          bytes: 5048,
          sha256: '49e3c2646595fd907228b3c6787069658f67b17377c60aeb8619c4551b2316fb',
        ),
      ],
    ),
    license: _zipformer66mLicense,
  );

  /// X-ASR zh-en offline zipformer with punctuation, int8 (files).
  static const xasrOffline = SpeechModel(
    id: 'sherpa.xasr_zh_en_offline',
    engine: SpeechEngine.sherpaOffline,
    uses: {SpeechUse.file},
    languages: {'en', 'zh-Hans'},
    ratings: ModelRatings(accuracy: 2, speed: 2, cpuPercent: 3.4),
    sherpaType: SherpaModelType.zipformerTransducer,
    sherpaFiles: SherpaFiles(
      encoder: 'encoder-epoch-99-avg-1.int8.onnx',
      decoder: 'decoder-epoch-99-avg-1.onnx',
      joiner: 'joiner-epoch-99-avg-1.int8.onnx',
    ),
    pack: ModelPack(
      id: 'xasr-zh-en-offline-punct-int8',
      source: _k2Releases,
      license: _xasrLicense,
      archive: ModelArchive(
        url:
            '$_k2Download/sherpa-onnx-x-asr-zipformer-transducer-zh-en-punct-int8-2026-06-03.tar.bz2',
        bytes: 136396739,
        sha256: '5d02c36d7b44e886b7c8f0d8e051f8713acab96c264bb6ef9e718be39a6a2224',
        folder: 'sherpa-onnx-x-asr-zipformer-transducer-zh-en-punct-int8-2026-06-03',
      ),
      files: [
        ModelFile(
          name: 'encoder-epoch-99-avg-1.int8.onnx',
          url: '',
          bytes: 161015713,
          sha256: '7f6aa62056efd8af9da13e0faa81cd3f284d2fb2e3b63de56fd2dfd3450910dc',
        ),
        ModelFile(
          name: 'decoder-epoch-99-avg-1.onnx',
          url: '',
          bytes: 11309084,
          sha256: '72f47405d3c1033bebccbef82f90071e7b4ba3e71b9c986f2b74244b25723aed',
        ),
        ModelFile(
          name: 'joiner-epoch-99-avg-1.int8.onnx',
          url: '',
          bytes: 2581422,
          sha256: 'aedb7fa697b2ab43f20499826fff7c997eea7d67db77be97769aeeeb726e63b3',
        ),
        ModelFile(
          name: 'tokens.txt',
          url: '',
          bytes: 58806,
          sha256: 'b818a60878b9aae978cbb8ad594acbd403d76d1af2e31ef4197c84e2dbdba27c',
        ),
      ],
    ),
    license: _xasrLicense,
  );

  /// NVIDIA Parakeet TDT 0.6B v2, int8 (files; English, most accurate).
  static const parakeet = SpeechModel(
    id: 'sherpa.parakeet_tdt_v2',
    engine: SpeechEngine.sherpaOffline,
    uses: {SpeechUse.file},
    languages: {'en'},
    ratings: ModelRatings(accuracy: 3, speed: 1, cpuPercent: 22),
    sherpaType: SherpaModelType.nemoTransducer,
    sherpaFiles: SherpaFiles(
      encoder: 'encoder.int8.onnx',
      decoder: 'decoder.int8.onnx',
      joiner: 'joiner.int8.onnx',
    ),
    pack: ModelPack(
      id: 'parakeet-tdt-0.6b-v2-int8',
      source: 'https://huggingface.co/csukuangfj/sherpa-onnx-nemo-parakeet-tdt-0.6b-v2-int8',
      license: _parakeetLicense,
      files: [
        ModelFile(
          name: 'encoder.int8.onnx',
          url: '$_parakeetHf/encoder.int8.onnx',
          bytes: 652184296,
          sha256: 'a32b12d17bbbc309d0686fbbcc2987b5e9b8333a7da83fa6b089f0a2acd651ab',
        ),
        ModelFile(
          name: 'decoder.int8.onnx',
          url: '$_parakeetHf/decoder.int8.onnx',
          bytes: 7257753,
          sha256: 'b6bb64963457237b900e496ee9994b59294526439fbcc1fecf705b31a15c6b4e',
        ),
        ModelFile(
          name: 'joiner.int8.onnx',
          url: '$_parakeetHf/joiner.int8.onnx',
          bytes: 1739080,
          sha256: '7946164367946e7f9f29a122407c3252b680dbae9a51343eb2488d057c3c43d2',
        ),
        ModelFile(
          name: 'tokens.txt',
          url: '$_parakeetHf/tokens.txt',
          bytes: 9384,
          sha256: 'ec182b70dd42113aff6c5372c75cac58c952443eb22322f57bbd7f53977d497d',
        ),
      ],
    ),
    license: _parakeetLicense,
  );

  static const all = <SpeechModel>[
    appleSpeech,
    appleDictation,
    xasrStreaming,
    smallEnglishStreaming,
    mediumEnglishStreaming,
    xasrOffline,
    parakeet,
  ];

  static SpeechModel? byId(String id) {
    for (final model in all) {
      if (model.id == id) return model;
    }
    return null;
  }

  static List<SpeechModel> forUse(SpeechUse use) => [
    for (final model in all)
      if (model.uses.contains(use)) model,
  ];

  /// Every pack Tinglang can download (models plus the VAD).
  static List<ModelPack> get packs => [
    vad,
    for (final model in all)
      if (model.pack != null) model.pack!,
  ];

  static ModelPack? packById(String id) {
    for (final pack in packs) {
      if (pack.id == id) return pack;
    }
    return null;
  }
}

/// Where downloaded packs live and which are complete. Implemented with
/// dart:io in `tinglang_native` (`<data>/models/<pack id>/`).
abstract interface class ModelInventory {
  /// Pack ids whose files are all present and verified.
  Set<String> get installed;

  /// Absolute folder of [packId] (whether or not it is installed).
  String directoryOf(String packId);
}

/// The OS recognition locale for a learning-language code, before any accent
/// chosen in Settings.
String defaultRecognitionLocale(String language) => switch (language) {
  'en' => 'en-US',
  'zh-Hans' || 'zh' => 'zh-CN',
  'zh-Hant' => 'zh-TW',
  'ja' => 'ja-JP',
  'ko' => 'ko-KR',
  'es' => 'es-ES',
  'fr' => 'fr-FR',
  'de' => 'de-DE',
  _ => language,
};

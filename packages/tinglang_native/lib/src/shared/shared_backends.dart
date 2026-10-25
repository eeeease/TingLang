import 'package:tinglang_platform_interface/tinglang_platform_interface.dart';

import 'cloud_backends.dart';
import 'portable_pipeline.dart';
import 'sherpa_file_transcriber.dart';
import 'sherpa_streaming_asr.dart';

/// Registers backends implemented once in Dart for every OS:
///
/// - `liveAsr`: every [SpeechModels] entry on [SpeechEngine.sherpaStreaming]
///   as a [SherpaStreamingAsr] (worker isolate reading the capture ring);
/// - `fileAsr`: every [SpeechEngine.sherpaOffline] entry as a
///   [SherpaFileTranscriber], decoding with the platform's [MediaDecoder]
///   picked per job and translating with its translator when one is ready;
/// - `liveAsr` and `fileAsr`: every cloud speech service as `cloud.<id>`
///   ([registerCloudBackends]; never used unless the user enabled it);
/// - `pipelines`: `pipeline.portable` ([PortablePipelineHost]).
///
/// Model folders come from [TinglangPlatform.models] when a session or job
/// starts (a [StateError] if the app has not set it). Each spec's model
/// assets gate selection, so nothing is picked before its pack and the VAD
/// are installed. Native registrations made later replace these by id.
void registerSharedBackends(TinglangPlatform platform) {
  String directoryOf(String packId) {
    final models =
        platform.models ??
        (throw StateError('TinglangPlatform.models is not set; model packs are unavailable.'));
    return models.directoryOf(packId);
  }

  for (final model in SpeechModels.all) {
    final spec = _spec(model.id);
    if (spec == null || model.sherpaFiles == null) continue;
    final sentenceCase = uppercaseModels.contains(model.id);
    switch (model.engine) {
      case SpeechEngine.sherpaStreaming:
        platform.liveAsr.register(
          BackendFactory<StreamingAsrBackend>(
            spec,
            () => SherpaStreamingAsr(model, directoryOf: directoryOf, sentenceCase: sentenceCase),
          ),
        );
      case SpeechEngine.sherpaOffline:
        platform.fileAsr.register(
          BackendFactory<FileTranscriber>(
            spec,
            () => SherpaFileTranscriber(
              model,
              directoryOf: directoryOf,
              sentenceCase: sentenceCase,
              decoder: () async {
                final probe = await platform.probe();
                return platform.decoders.pick(probe).create();
              },
              translatorFor: (pair) async {
                final probe = await platform.probe();
                final choice = platform.translators.pick(probe);
                if (!choice.hasSelection) return null;
                final translator = choice.create();
                return translatorReady(translator, pair, probe) ? translator : null;
              },
            ),
          ),
        );
      case SpeechEngine.appleSpeech || SpeechEngine.appleDictation:
        break;
    }
  }
  registerCloudBackends(platform);
  platform.pipelines.register(
    BackendFactory<LivePipelineHost>(
      BackendCatalog.portablePipeline,
      () => PortablePipelineHost(platform),
    ),
  );
}

/// Models that emit upper case without punctuation (LibriSpeech
/// zipformers); their text is shown sentence-cased.
final uppercaseModels = {
  SpeechModels.smallEnglishStreaming.id,
  SpeechModels.mediumEnglishStreaming.id,
};

BackendSpec? _spec(String id) {
  for (final specs in BackendCatalog.byCapability.values) {
    for (final spec in specs) {
      if (spec.id == id) return spec;
    }
  }
  return null;
}

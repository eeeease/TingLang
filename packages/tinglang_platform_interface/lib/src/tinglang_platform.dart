import 'backend_registry.dart';
import 'capabilities/audio_capture.dart';
import 'capabilities/cloud_drive.dart';
import 'capabilities/live_pipeline.dart';
import 'capabilities/media.dart';
import 'capabilities/services.dart';
import 'capabilities/streaming_asr.dart';
import 'capabilities/voice_memos.dart';
import 'catalog.dart';
import 'platform_probe.dart';
import 'speech_models.dart';

/// The app's single entry point to native capabilities: one
/// [BackendRegistry] per capability plus the host probe.
///
/// `tinglang_native` builds the real instance at startup and assigns
/// [instance]; tests assign a fake (see `fakeTinglangPlatform`).
final class TinglangPlatform {
  TinglangPlatform({required this.probeSource});

  static TinglangPlatform? _instance;

  static TinglangPlatform get instance =>
      _instance ??
      (throw StateError(
        'TinglangPlatform.instance is not installed. '
        'Call TinglangNative.install() during startup.',
      ));

  static set instance(TinglangPlatform value) => _instance = value;
  static bool get isInstalled => _instance != null;

  final PlatformProbeSource probeSource;

  final systemAudio = BackendRegistry<AudioCaptureBackend>(
    'systemAudio',
    preferences: BackendCatalog.systemAudioOrder,
  );
  final microphone = BackendRegistry<AudioCaptureBackend>(
    'microphone',
    preferences: BackendCatalog.microphoneOrder,
  );
  final liveAsr = BackendRegistry<StreamingAsrBackend>(
    'liveAsr',
    preferences: BackendCatalog.liveAsrOrder,
  );
  final fileAsr = BackendRegistry<FileTranscriber>(
    'fileAsr',
    preferences: BackendCatalog.fileAsrOrder,
  );
  final decoders = BackendRegistry<MediaDecoder>(
    'decoders',
    preferences: BackendCatalog.decoderOrder,
  );
  final translators = BackendRegistry<TranslatorBackend>(
    'translators',
    preferences: BackendCatalog.translatorOrder,
  );
  final overlays = BackendRegistry<CaptionOverlay>(
    'overlays',
    preferences: BackendCatalog.overlayOrder,
  );
  final hotkeys = BackendRegistry<GlobalHotkeys>('hotkeys');
  final shells = BackendRegistry<DesktopShell>('shells');
  final secrets = BackendRegistry<SecretStore>('secrets');
  final youtube = BackendRegistry<YouTubePlayer>('youtube');
  final voiceMemos = BackendRegistry<VoiceMemoLibrary>('voiceMemos');
  final webAuth = BackendRegistry<WebAuthenticator>('webAuth');

  /// Download states and requests for the user's iCloud Drive folder (sync).
  final cloudDrive = BackendRegistry<CloudDriveSupport>('cloudDrive');
  final pipelines = BackendRegistry<LivePipelineHost>(
    'pipelines',
    preferences: BackendCatalog.pipelineOrder,
  );

  /// Downloaded model packs (set by the app once its data folder is known).
  /// Their ids are added to every probe's [PlatformProbe.installedAssets].
  ModelInventory? models;

  /// OS speech assets (Apple engines); registered by the macOS provider.
  SpeechAssetSupport? speechAssets;

  /// Cloud backends the user has chosen and set up (set by the app from its
  /// settings). Added to every probe's [PlatformProbe.enabledCloudBackends];
  /// a cloud backend is never available otherwise.
  Set<String> enabledCloudBackends = const {};

  Future<PlatformProbe> probe() async {
    var probe = await probeSource.probe();
    final installed = models?.installed;
    if (installed != null && installed.isNotEmpty) {
      probe = probe.copyWith(installedAssets: {...probe.installedAssets, ...installed});
    }
    if (enabledCloudBackends.isNotEmpty) {
      probe = probe.copyWith(
        enabledCloudBackends: {...probe.enabledCloudBackends, ...enabledCloudBackends},
      );
    }
    return probe;
  }

  /// All registries keyed by capability name, for diagnostics screens.
  Map<String, BackendRegistry<Object>> get registries => {
    for (final registry in <BackendRegistry<Object>>[
      systemAudio,
      microphone,
      liveAsr,
      fileAsr,
      decoders,
      translators,
      overlays,
      hotkeys,
      shells,
      secrets,
      youtube,
      voiceMemos,
      webAuth,
      cloudDrive,
      pipelines,
    ])
      registry.capability: registry,
  };
}

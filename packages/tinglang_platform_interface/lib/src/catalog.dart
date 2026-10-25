import 'backend_registry.dart';
import 'platform_probe.dart';

const _both = {HostOs.macos, HostOs.windows};
const _mac = {HostOs.macos};
const _win = {HostOs.windows};

/// Every backend id Tinglang knows, with its gates, and each capability's
/// default platform order. Real and fake implementations register against
/// these specs.
///
/// Defaults follow the M0 benchmark (docs/perf/asr-bench-2026-10.md): on
/// macOS 26+ Apple SpeechTranscriber (native pipeline) first; elsewhere
/// X-ASR through sherpa-onnx.
abstract final class BackendCatalog {
  // System audio.
  static const coreAudioTap = BackendSpec(
    id: 'coreaudio_tap',
    platforms: _mac,
    minVersions: {HostOs.macos: OsVersion(14, 2)},
    permissions: {PermissionKind.systemAudio},
  );
  static const screenCaptureKit = BackendSpec(
    id: 'screencapturekit',
    platforms: _mac,
    minVersions: {HostOs.macos: OsVersion(13)},
    permissions: {PermissionKind.screenCapture},
  );

  /// Per-process loopback (AUDIOCLIENT_ACTIVATION_TYPE_PROCESS_LOOPBACK).
  static const processLoopback = BackendSpec(
    id: 'process_loopback',
    platforms: _win,
    minVersions: {HostOs.windows: OsVersion(10, 0, 20348)},
  );
  static const endpointLoopback = BackendSpec(id: 'endpoint_loopback', platforms: _win);

  // Microphone.
  static const avAudioEngineMic = BackendSpec(
    id: 'avaudioengine_mic',
    platforms: _mac,
    permissions: {PermissionKind.microphone},
  );
  static const wasapiMic = BackendSpec(
    id: 'wasapi_mic',
    platforms: _win,
    permissions: {PermissionKind.microphone},
  );

  /// Silero VAD, required by every sherpa backend (see [SpeechModels.vad]).
  static const vadAsset = 'silero-vad';

  // Live ASR.
  static const sherpaXasrZhEn = BackendSpec(
    id: 'sherpa.xasr_zh_en_480',
    platforms: _both,
    assets: {'xasr-zh-en-480ms-int8', vadAsset},
  );

  /// The small English streaming model: earliest captions, least CPU.
  static const sherpaZipformerEnSmall = BackendSpec(
    id: 'sherpa.zipformer_en_small',
    platforms: _both,
    assets: {'zipformer-en-small-int8', vadAsset},
  );

  /// A mid-size English streaming model (66M, 320 ms chunks): more
  /// accurate than the small one, still light.
  static const sherpaZipformerEnMedium = BackendSpec(
    id: 'sherpa.zipformer_en_medium',
    platforms: _both,
    assets: {'zipformer-en-66m-int8', vadAsset},
  );
  static const speechTranscriber = BackendSpec(
    id: 'speech_transcriber',
    platforms: _mac,
    minVersions: {HostOs.macos: OsVersion(26)},
  );

  /// Apple DictationTranscriber (content hints: far field, short form).
  static const dictationTranscriber = BackendSpec(
    id: 'dictation_transcriber',
    platforms: _mac,
    minVersions: {HostOs.macos: OsVersion(26)},
  );

  // Cloud speech services (bring your own key; `tinglang_cloud_asr`). Each
  // id is both a live and a file backend; neither is ever picked unless the
  // user chose it and it is in [PlatformProbe.enabledCloudBackends].
  static const tencentCloud = BackendSpec(id: 'cloud.tencent', platforms: _both, cloud: true);
  static const dashscopeCloud = BackendSpec(id: 'cloud.dashscope', platforms: _both, cloud: true);
  static const xfyunCloud = BackendSpec(id: 'cloud.xfyun', platforms: _both, cloud: true);
  static const sonioxCloud = BackendSpec(id: 'cloud.soniox', platforms: _both, cloud: true);
  static const assemblyaiCloud = BackendSpec(id: 'cloud.assemblyai', platforms: _both, cloud: true);
  static const azureCloud = BackendSpec(id: 'cloud.azure', platforms: _both, cloud: true);

  /// The cloud speech specs, in display order.
  static const cloudAsr = [
    tencentCloud,
    dashscopeCloud,
    xfyunCloud,
    sonioxCloud,
    assemblyaiCloud,
    azureCloud,
  ];

  // File ASR and decoding.
  static const speechAnalyzerFile = BackendSpec(
    id: 'speech_analyzer_file',
    platforms: _mac,
    minVersions: {HostOs.macos: OsVersion(26)},
  );
  static const dictationFile = BackendSpec(
    id: 'dictation_file',
    platforms: _mac,
    minVersions: {HostOs.macos: OsVersion(26)},
  );
  static const sherpaParakeet = BackendSpec(
    id: 'sherpa.parakeet_tdt_v2',
    platforms: _both,
    assets: {'parakeet-tdt-0.6b-v2-int8', vadAsset},
  );
  static const sherpaXasrOffline = BackendSpec(
    id: 'sherpa.xasr_zh_en_offline',
    platforms: _both,
    assets: {'xasr-zh-en-offline-punct-int8', vadAsset},
  );
  static const avAssetReader = BackendSpec(id: 'avassetreader', platforms: _mac);
  static const mediaFoundation = BackendSpec(id: 'media_foundation', platforms: _win);

  // Translation.
  static const appleTranslation = BackendSpec(
    id: 'apple_translation',
    platforms: _mac,
    minVersions: {HostOs.macos: OsVersion(15)},
  );
  static const bergamot = BackendSpec(id: 'bergamot', platforms: _win);

  /// User's own LLM key. Treated as cloud even when pointed at a local
  /// server: the app cannot verify where the endpoint sends text.
  static const byokLlm = BackendSpec(id: 'byok_llm', platforms: _both, cloud: true);

  // Overlay, hotkeys, secrets, YouTube.
  static const nsPanel = BackendSpec(id: 'nspanel', platforms: _mac);
  static const layeredDirectWrite = BackendSpec(id: 'layered_dwrite', platforms: _win);
  static const carbonHotkeys = BackendSpec(id: 'carbon_hotkeys', platforms: _mac);
  static const win32Hotkeys = BackendSpec(id: 'register_hotkey', platforms: _win);
  static const appKitShell = BackendSpec(id: 'appkit_shell', platforms: _mac);
  static const win32Shell = BackendSpec(id: 'win32_shell', platforms: _win);
  static const keychain = BackendSpec(id: 'keychain', platforms: _mac);
  static const credentialManager = BackendSpec(id: 'credential_manager', platforms: _win);
  static const wkWebViewYouTube = BackendSpec(id: 'youtube_wkwebview', platforms: _mac);

  /// Reads Apple's Voice Memos library. Full Disk Access is required but
  /// cannot be queried ahead of time; listing reports it instead.
  static const appleVoiceMemos = BackendSpec(id: 'apple_voice_memos', platforms: _mac);

  /// Download states and requests for files in the user's iCloud Drive
  /// (FileManager ubiquitous-item APIs). Not a cloud backend: macOS does the
  /// syncing and Tinglang only reads and writes a folder, and only after the
  /// user turns sync on.
  static const icloudDrive = BackendSpec(id: 'icloud_drive', platforms: _mac);

  // Sign-in for the optional cloud services: a system browser session, so
  // the account page (and its passwords and passkeys) stays in the browser.
  static const webAuthenticationSession = BackendSpec(
    id: 'web_authentication_session',
    platforms: _mac,
  );
  static const floatingWebViewYouTube = BackendSpec(
    id: 'youtube_webview_win_floating',
    platforms: _win,
  );

  // Pipelines.
  static const portablePipeline = BackendSpec(id: 'pipeline.portable', platforms: _both);
  static const nativeMacosPipeline = BackendSpec(
    id: 'pipeline.native_macos',
    platforms: _mac,
    minVersions: {HostOs.macos: OsVersion(26)},
  );

  /// A relay through a Tinglang server (not built). Cloud speech services
  /// run in the portable pipeline: capture and the ring are the same, only
  /// the recogniser is remote.
  static const cloudPipeline = BackendSpec(id: 'pipeline.cloud', platforms: _both, cloud: true);

  static const systemAudioOrder = {
    HostOs.macos: ['coreaudio_tap', 'screencapturekit'],
    HostOs.windows: ['process_loopback', 'endpoint_loopback'],
  };
  static const microphoneOrder = {
    HostOs.macos: ['avaudioengine_mic'],
    HostOs.windows: ['wasapi_mic'],
  };
  static const liveAsrOrder = {
    HostOs.macos: [
      'speech_transcriber',
      'dictation_transcriber',
      'sherpa.xasr_zh_en_480',
      'sherpa.*',
      'cloud.*',
    ],
    HostOs.windows: ['sherpa.xasr_zh_en_480', 'sherpa.*', 'cloud.*'],
  };
  static const fileAsrOrder = {
    HostOs.macos: [
      'speech_analyzer_file',
      'dictation_file',
      'sherpa.xasr_zh_en_offline',
      'sherpa.*',
      'cloud.*',
    ],
    HostOs.windows: ['sherpa.xasr_zh_en_offline', 'sherpa.*', 'cloud.*'],
  };
  static const decoderOrder = {
    HostOs.macos: ['avassetreader'],
    HostOs.windows: ['media_foundation'],
  };
  static const translatorOrder = {
    HostOs.macos: ['apple_translation', 'byok_llm'],
    HostOs.windows: ['bergamot', 'byok_llm'],
  };
  static const overlayOrder = {
    HostOs.macos: ['nspanel'],
    HostOs.windows: ['layered_dwrite'],
  };
  static const pipelineOrder = {
    HostOs.macos: ['pipeline.native_macos', 'pipeline.portable', 'pipeline.cloud'],
    HostOs.windows: ['pipeline.portable', 'pipeline.cloud'],
  };

  /// The live pipeline that runs [asrBackendId]: Apple recognisers run
  /// inside the Swift pipeline (topology A); sherpa-onnx and cloud services
  /// in the portable one (topology B).
  static String pipelineFor(String asrBackendId) => switch (asrBackendId) {
    'speech_transcriber' || 'dictation_transcriber' => nativeMacosPipeline.id,
    _ => portablePipeline.id,
  };

  /// Whether [backendId] is a cloud speech service.
  static bool isCloudAsr(String backendId) => backendId.startsWith('cloud.');

  /// All specs, grouped by capability name (as used by [TinglangPlatform]).
  static const byCapability = <String, List<BackendSpec>>{
    'systemAudio': [coreAudioTap, screenCaptureKit, processLoopback, endpointLoopback],
    'microphone': [avAudioEngineMic, wasapiMic],
    'liveAsr': [
      sherpaXasrZhEn,
      sherpaZipformerEnSmall,
      sherpaZipformerEnMedium,
      speechTranscriber,
      dictationTranscriber,
      ...cloudAsr,
    ],
    'fileAsr': [speechAnalyzerFile, dictationFile, sherpaParakeet, sherpaXasrOffline, ...cloudAsr],
    'decoders': [avAssetReader, mediaFoundation],
    'translators': [appleTranslation, bergamot, byokLlm],
    'overlays': [nsPanel, layeredDirectWrite],
    'hotkeys': [carbonHotkeys, win32Hotkeys],
    'shells': [appKitShell, win32Shell],
    'secrets': [keychain, credentialManager],
    'youtube': [wkWebViewYouTube, floatingWebViewYouTube],
    'voiceMemos': [appleVoiceMemos],
    'webAuth': [webAuthenticationSession],
    'cloudDrive': [icloudDrive],
    'pipelines': [portablePipeline, nativeMacosPipeline, cloudPipeline],
  };
}

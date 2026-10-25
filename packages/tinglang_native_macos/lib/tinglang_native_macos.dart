import 'package:tinglang_platform_interface/tinglang_platform_interface.dart';

import 'src/host_api.g.dart';
import 'src/live.dart';
import 'src/portable.dart';
import 'src/speech_assets.dart';
import 'src/voice_memos.dart';

export 'src/live.dart'
    show
        MacLiveSession,
        MacCaptionOverlay,
        MacDesktopShell,
        MacCloudDrive,
        cloudItemState,
        MacWebAuthenticator,
        MacFileTranscriber,
        overlayEvent,
        recognitionLocale,
        speechLocale;
export 'src/portable.dart'
    show
        MacAppleRecognizer,
        MacAudioCaptureBackend,
        MacNativeAudioSource,
        MacMediaDecoder,
        MacTranslator;
export 'src/speech_assets.dart' show MacSpeechAssetSupport, SpeechAssetInstallCanceled;
export 'src/voice_memos.dart' show MacVoiceMemoLibrary;

/// macOS provider backed by the Swift plugin's Pigeon host API.
final class TinglangNativeMacos extends NativeBackendProvider {
  TinglangNativeMacos({TinglangHostApi? api, MacEvents? events})
    : _api = api ?? TinglangHostApi(),
      _events = events ?? MacEvents();

  /// Called by Flutter's generated plugin registrant before `main`.
  static void registerWith() {
    NativeBackendProvider.current = TinglangNativeMacos();
  }

  final TinglangHostApi _api;
  final MacEvents _events;

  @override
  String get name => 'macos-swift';

  @override
  Future<PlatformProbe> probe() async => probeFromHost(await _api.probe());

  /// Topology A (macOS 26+): capture, Apple recognisers, Apple Translation
  /// and the caption panel run in Swift behind `pipeline.native_macos`. For
  /// the portable pipeline (macOS 14.2+) Swift provides capture into a PCM
  /// ring, decoding, Apple Translation and the panel.
  @override
  void registerBackends(TinglangPlatform platform) {
    Availability appleSpeech(PlatformProbe probe) => probe.speechLocales.isEmpty
        ? const Unsupported('SpeechTranscriber reports no locales')
        : const Available();
    platform.pipelines.register(
      BackendFactory(
        BackendCatalog.nativeMacosPipeline,
        () => MacNativePipelineHost(_api, _events),
        check: appleSpeech,
      ),
    );
    platform.liveAsr.register(
      BackendFactory(
        BackendCatalog.speechTranscriber,
        () => const MacAppleRecognizer(SpeechEngine.appleSpeech),
        check: appleSpeech,
      ),
    );
    platform.liveAsr.register(
      BackendFactory(
        BackendCatalog.dictationTranscriber,
        () => const MacAppleRecognizer(SpeechEngine.appleDictation),
        check: appleSpeech,
      ),
    );
    platform.fileAsr.register(
      BackendFactory(BackendCatalog.speechAnalyzerFile, () => MacFileTranscriber(_api, _events)),
    );
    platform.fileAsr.register(
      BackendFactory(
        BackendCatalog.dictationFile,
        () => MacFileTranscriber(_api, _events, engine: SpeechEngine.appleDictation),
      ),
    );
    platform.systemAudio.register(
      BackendFactory(
        BackendCatalog.coreAudioTap,
        () => MacAudioCaptureBackend(_api, _events, AudioSourceKind.systemAudio),
      ),
    );
    platform.microphone.register(
      BackendFactory(
        BackendCatalog.avAudioEngineMic,
        () => MacAudioCaptureBackend(_api, _events, AudioSourceKind.microphone),
      ),
    );
    platform.decoders.register(
      BackendFactory(BackendCatalog.avAssetReader, () => MacMediaDecoder(_api)),
    );
    platform.translators.register(
      BackendFactory(
        BackendCatalog.appleTranslation,
        () => MacTranslator(_api),
        check: (probe) => probe.isAtLeast(const OsVersion(26))
            ? const Available()
            : const Unsupported('Apple Translation with installed packs needs macOS 26'),
      ),
    );
    platform.speechAssets = MacSpeechAssetSupport(_api, _events);
    platform.secrets.register(
      BackendFactory(BackendCatalog.keychain, () => MacKeychainSecretStore(_api)),
    );
    platform.overlays.register(
      BackendFactory(BackendCatalog.nsPanel, () => MacCaptionOverlay(_api, _events)),
    );
    platform.shells.register(
      BackendFactory(BackendCatalog.appKitShell, () => MacDesktopShell(_api, _events)),
    );
    platform.hotkeys.register(
      BackendFactory(BackendCatalog.carbonHotkeys, () => MacGlobalHotkeys(_api, _events)),
    );
    platform.voiceMemos.register(
      BackendFactory(BackendCatalog.appleVoiceMemos, MacVoiceMemoLibrary.new),
    );
    platform.webAuth.register(
      BackendFactory(BackendCatalog.webAuthenticationSession, () => MacWebAuthenticator(_api)),
    );
    platform.cloudDrive.register(
      BackendFactory(BackendCatalog.icloudDrive, () => MacCloudDrive(_api)),
    );
  }
}

PlatformProbe probeFromHost(HostProbe host) => PlatformProbe(
  os: HostOs.macos,
  version: OsVersion(host.osMajor, host.osMinor, host.osPatch),
  arch: switch (host.arch) {
    'arm64' => CpuArch.arm64,
    'x86_64' => CpuArch.x64,
    _ => CpuArch.other,
  },
  hasNeuralEngine: host.arch == 'arm64',
  speechLocales: host.speechLocales.toSet(),
  permissions: {
    PermissionKind.microphone: _state(host.microphone),
    PermissionKind.screenCapture: _state(host.screenCapture),
  },
);

PermissionState _state(PermissionStatus status) => switch (status) {
  PermissionStatus.granted => PermissionState.granted,
  PermissionStatus.denied => PermissionState.denied,
  PermissionStatus.restricted => PermissionState.restricted,
  PermissionStatus.notDetermined => PermissionState.notDetermined,
};

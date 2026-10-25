import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:tinglang_native/tinglang_native.dart';

import 'app_controller.dart';

/// Settings keys for speech recognition (stored in `app_meta`).
abstract final class SpeechKeys {
  /// Model id for live captions; missing or `auto` lets the platform pick.
  static const liveModel = 'asr_live_model';

  /// Model id for file transcription; missing or `auto` lets the platform pick.
  static const fileModel = 'asr_file_model';

  /// A [LatencyTier] name.
  static const latency = 'asr_latency';

  /// English accent for Apple's recognisers (`en-US`, `en-GB`…).
  static const accent = 'asr_accent_en';
  static const farField = 'asr_dictation_far_field';
  static const shortForm = 'asr_dictation_short_form';

  static const auto = 'auto';

  /// `local` (models on this Mac) or `cloud` (a cloud speech service);
  /// missing until the user has chosen.
  static const mode = 'asr_mode';

  /// The chosen cloud service ([CloudAsrInfo.id]).
  static const cloudProvider = 'asr_cloud_provider';
}

/// How speech is recognised: on this Mac, or by a cloud service with the
/// user's own key.
enum RecognitionMode { local, cloud }

/// The user's speech choices as stored in settings.
SpeechOptions speechOptionsFrom(AppController app, {required String language}) {
  final accent = app.setting(SpeechKeys.accent, 'en-US');
  return SpeechOptions(
    latency:
        LatencyTier.values.asNameMap()[app.setting(SpeechKeys.latency, '')] ?? LatencyTier.balanced,
    // An accent only means something for English.
    locale: language == 'en' && englishAccents.contains(accent) ? accent : null,
    dictation: DictationHints(
      farField: app.setting(SpeechKeys.farField, 'false') == 'true',
      shortForm: app.setting(SpeechKeys.shortForm, 'false') == 'true',
    ),
  );
}

/// What the live and file controllers need from the speech-model settings
/// and downloads. Implemented by [SpeechModelService]; faked in tests.
abstract interface class SpeechModelSource {
  /// The model the user chose for [use] (a `cloud.<id>` backend in cloud
  /// mode); null lets the platform pick.
  String? modelFor(SpeechUse use);

  /// Whether the user has chosen how speech is recognised (see
  /// [SpeechModelService.setupChosen]).
  bool get setupChosen;

  /// Cloud mode is on, but no service with saved credentials is chosen.
  bool get cloudNeedsSetup;

  SpeechOptions optionsFor(String language);

  /// Bytes still to download for [model] (its pack and the shared VAD).
  int missingBytes(SpeechModel model);

  /// Downloads what [model] is missing. Called only after the user pressed a
  /// download button next to a message that named [missingBytes].
  Future<void> download(SpeechModel model, {void Function(double fraction)? onProgress});

  /// Stops [download]; it then fails with [DownloadCancelled]. Partial files
  /// stay so the next download resumes.
  Future<void> cancelDownload(SpeechModel model);
}

/// Progress of one model download shown in Settings and on the panel.
@immutable
class ModelDownloadState {
  const ModelDownloadState(this.received, this.total);
  final int received, total;
  double get fraction => total == 0 ? 0 : (received / total).clamp(0, 1);
}

/// Speech-model choices, downloads and deletions (Settings → Speech
/// models), over the [ModelStore] in `<data>/models` and the OS speech
/// assets for Apple's engines.
class SpeechModelService extends ChangeNotifier implements SpeechModelSource {
  SpeechModelService({
    required this.app,
    required this.store,
    required this.downloader,
    TinglangPlatform? platform,
    List<CloudAsrProvider>? cloudProviders,
    CloudAsrSecrets? cloudSecrets,
  }) : _platform = platform ?? (TinglangPlatform.isInstalled ? TinglangPlatform.instance : null),
       cloudProviders = cloudProviders ?? CloudAsrProviders.all {
    this.cloudSecrets =
        cloudSecrets ??
        CloudAsrSecrets(() async {
          final platform = _platform;
          return platform == null ? null : platformSecretStore(platform);
        });
    _storeSub = store.changes.listen((_) => unawaited(refresh()));
    app.addListener(_syncCloud);
    _syncCloud();
  }

  final AppController app;
  final ModelStore store;
  final ModelDownloader downloader;
  final TinglangPlatform? _platform;
  late final StreamSubscription<Set<String>> _storeSub;

  /// Cloud speech services offered in Settings.
  final List<CloudAsrProvider> cloudProviders;

  /// Their credentials, one Keychain entry each.
  late final CloudAsrSecrets cloudSecrets;

  /// Services whose credentials are saved (as far as read so far: the
  /// chosen one on [refresh], others when Settings shows them).
  final savedCloud = <String>{};

  PlatformProbe? probe;
  SpeechLocaleInventory? locales;
  final downloads = <String, ModelDownloadState>{};
  final _cancelled = <String>{};

  /// OS speech asset installs in progress, keyed `engine/locale`.
  final appleInstalls = <String, double>{};
  final _appleJobs = <String, SpeechAssetInstall>{};

  SpeechAssetSupport? get appleAssets => _platform?.speechAssets;

  /// Re-reads the probe (installed packs), the OS speech locales and
  /// whether the chosen cloud service has credentials.
  Future<void> refresh() async {
    final provider = cloudProvider;
    if (provider != null) await _readSaved(provider.info.id);
    final platform = _platform;
    if (platform == null) {
      notifyListeners();
      return;
    }
    probe = await platform.probe();
    try {
      locales = await platform.speechAssets?.inventory();
    } catch (e) {
      debugPrint('Speech locales unavailable: $e');
    }
    notifyListeners();
  }

  RecognitionMode get mode => app.setting(SpeechKeys.mode, '') == RecognitionMode.cloud.name
      ? RecognitionMode.cloud
      : RecognitionMode.local;

  /// Whether the user has said how speech is recognised: picked a mode or a
  /// model. Until then, starting captions without a ready model asks first.
  @override
  bool get setupChosen =>
      app.setting(SpeechKeys.mode, '').isNotEmpty || _localChoice(SpeechUse.live) != null;

  /// The chosen cloud service (also while the local mode is on).
  CloudAsrProvider? get cloudProvider {
    final id = app.setting(SpeechKeys.cloudProvider, '');
    return cloudProviders.where((p) => p.info.id == id).firstOrNull;
  }

  /// Whether [use] runs in the cloud: cloud mode, a service is chosen and
  /// it offers [use] (otherwise the local choice applies).
  bool usesCloud(SpeechUse use) {
    final provider = cloudProvider;
    return mode == RecognitionMode.cloud &&
        provider != null &&
        (use == SpeechUse.live ? provider.info.live : provider.info.file);
  }

  /// Cloud mode is on but the chosen service has no saved credentials (or
  /// no service is chosen).
  @override
  bool get cloudNeedsSetup {
    if (mode != RecognitionMode.cloud) return false;
    final provider = cloudProvider;
    return provider == null || !savedCloud.contains(provider.info.id);
  }

  /// The backend id for [use]: a cloud service in cloud mode, else the
  /// chosen local model; null lets the platform pick.
  @override
  String? modelFor(SpeechUse use) {
    if (usesCloud(use)) return 'cloud.${cloudProvider!.info.id}';
    return _localChoice(use);
  }

  String? _localChoice(SpeechUse use) {
    final id = app.setting(use == SpeechUse.live ? SpeechKeys.liveModel : SpeechKeys.fileModel, '');
    return id.isEmpty || id == SpeechKeys.auto || SpeechModels.byId(id) == null ? null : id;
  }

  /// The local model chosen for [use] (ignoring cloud mode); null is
  /// automatic.
  String? localModelFor(SpeechUse use) => _localChoice(use);

  Future<void> setMode(RecognitionMode mode) async {
    await app.setSetting(SpeechKeys.mode, mode.name);
    final provider = cloudProvider;
    if (mode == RecognitionMode.cloud && provider != null) await _readSaved(provider.info.id);
    _syncCloud();
  }

  Future<void> chooseCloudProvider(String id) async {
    await app.setSettings({
      SpeechKeys.mode: RecognitionMode.cloud.name,
      SpeechKeys.cloudProvider: id,
    });
    await _readSaved(id);
    _syncCloud();
  }

  /// Saved credentials of service [id], or null.
  Future<CloudCredentials?> cloudCredentials(String id) async {
    final values = await cloudSecrets.read(id);
    _markSaved(id, values != null && values.isNotEmpty);
    return values;
  }

  Future<void> saveCloudCredentials(String id, CloudCredentials values) async {
    await cloudSecrets.write(id, values);
    _markSaved(id, true);
  }

  Future<void> forgetCloudCredentials(String id) async {
    await cloudSecrets.delete(id);
    _markSaved(id, false);
  }

  /// "Test connection": the service's cheapest call with [values].
  Future<void> verifyCloud(String id, CloudCredentials values) async {
    final provider =
        cloudProviders.where((p) => p.info.id == id).firstOrNull ??
        (throw StateError('Unknown cloud service $id.'));
    await provider.verify(values);
  }

  Future<void> _readSaved(String id) async {
    try {
      final values = await cloudSecrets.read(id);
      _markSaved(id, values != null && values.isNotEmpty);
    } on Object catch (e) {
      debugPrint('Cloud credentials unreadable: $e');
    }
  }

  void _markSaved(String id, bool saved) {
    final changed = saved ? savedCloud.add(id) : savedCloud.remove(id);
    _syncCloud();
    if (changed) notifyListeners();
  }

  /// Tells the platform which cloud backend may run: the chosen service in
  /// cloud mode once its credentials are saved; none otherwise.
  void _syncCloud() {
    final platform = _platform;
    if (platform == null) return;
    final provider = cloudProvider;
    platform.enabledCloudBackends =
        mode == RecognitionMode.cloud && provider != null && savedCloud.contains(provider.info.id)
        ? {'cloud.${provider.info.id}'}
        : const {};
  }

  Future<void> choose(SpeechUse use, String? modelId) => app.setSetting(
    use == SpeechUse.live ? SpeechKeys.liveModel : SpeechKeys.fileModel,
    modelId ?? SpeechKeys.auto,
  );

  @override
  SpeechOptions optionsFor(String language) => speechOptionsFrom(app, language: language);

  /// What "automatic" resolves to for [use] on this Mac right now: the
  /// model that runs, or else the first local one that only needs a
  /// download (what starting captions would offer to download). Null before
  /// [refresh] or when nothing can run here.
  SpeechModel? automaticModel(SpeechUse use) {
    final probe = this.probe, platform = _platform;
    if (probe == null || platform == null) return null;
    final choice = (use == SpeechUse.live ? platform.liveAsr : platform.fileAsr).pick(probe);
    final id =
        choice.id ??
        choice.candidates
            .where((c) => !c.factory.spec.cloud && c.availability is NeedsDownload)
            .firstOrNull
            ?.factory
            .id;
    return id == null ? null : SpeechModels.all.where((m) => m.backendId(use) == id).firstOrNull;
  }

  /// Whether [model] can run here at all (OS version, platform).
  Availability availability(SpeechModel model, SpeechUse use) {
    final probe = this.probe, platform = _platform;
    if (probe == null || platform == null) return const Unsupported('not probed yet');
    final registry = use == SpeechUse.live ? platform.liveAsr : platform.fileAsr;
    final factory = registry.byId(model.backendId(use));
    if (factory == null) return Unsupported('${model.id} is not available here');
    return factory.availability(probe);
  }

  bool isInstalled(SpeechModel model) => store.installed.containsAll(model.requiredAssets);

  /// Whether only the model's own pack is on disk (the VAD is shared).
  bool hasOwnPack(SpeechModel model) =>
      model.pack != null && store.installed.contains(model.pack!.id);

  List<ModelPack> _missing(SpeechModel model) => [
    for (final id in model.requiredAssets)
      if (!store.installed.contains(id)) SpeechModels.packById(id)!,
  ];

  @override
  int missingBytes(SpeechModel model) => _missing(model).fold(0, (s, p) => s + p.downloadBytes);

  @override
  Future<void> download(SpeechModel model, {void Function(double fraction)? onProgress}) async {
    final packs = _missing(model);
    final total = packs.fold(0, (s, p) => s + p.downloadBytes);
    if (total == 0) return;
    _cancelled.remove(model.id);
    var done = 0;
    void report(int received) {
      final state = ModelDownloadState(done + received, total);
      downloads[model.id] = state;
      onProgress?.call(state.fraction);
      notifyListeners();
    }

    report(0);
    try {
      for (final pack in packs) {
        if (_cancelled.contains(model.id)) throw const DownloadCancelled();
        // The user agreed to [total] for this model; each pack's consent
        // records its own share of it.
        final job = downloader.start(pack, consent: DownloadConsent.forPack(pack));
        final sub = job.progress.listen((p) => report(p.received));
        try {
          await job.done;
        } finally {
          await sub.cancel();
        }
        done += pack.downloadBytes;
        report(0);
      }
    } finally {
      downloads.remove(model.id);
      store.refresh();
      await refresh();
    }
  }

  @override
  Future<void> cancelDownload(SpeechModel model) async {
    _cancelled.add(model.id);
    for (final id in model.requiredAssets) {
      downloader.jobFor(id)?.cancel();
    }
  }

  /// Deletes [model]'s own pack; the shared VAD goes with the last sherpa
  /// model that used it.
  Future<void> delete(SpeechModel model) async {
    final pack = model.pack;
    if (pack == null) return;
    await downloader.delete(pack.id);
    final vadStillUsed = SpeechModels.all.any(
      (m) => m.pack != null && m.pack!.id != pack.id && store.installed.contains(m.pack!.id),
    );
    if (!vadStillUsed) await downloader.delete(SpeechModels.vad.id);
    // A deleted choice falls back to automatic.
    for (final use in SpeechUse.values) {
      if (_localChoice(use) == model.id) await choose(use, null);
    }
    await refresh();
  }

  static String appleKey(String locale, SpeechEngine engine) => '${engine.name}/$locale';

  bool appleInstalled(String locale, SpeechEngine engine) {
    final inventory = locales;
    if (inventory == null) return false;
    return (engine == SpeechEngine.appleDictation
            ? inventory.dictationInstalled
            : inventory.speechInstalled)
        .contains(locale);
  }

  /// Asks macOS to download its speech model for [locale]; the user pressed
  /// a button that said so.
  Future<void> installApple(String locale, SpeechEngine engine) async {
    final assets = appleAssets;
    if (assets == null) return;
    final key = appleKey(locale, engine);
    if (_appleJobs.containsKey(key)) return;
    final job = assets.install(locale, engine);
    _appleJobs[key] = job;
    appleInstalls[key] = 0;
    notifyListeners();
    final sub = job.progress.listen((v) {
      appleInstalls[key] = v;
      notifyListeners();
    });
    try {
      await job.done;
    } finally {
      await sub.cancel();
      _appleJobs.remove(key);
      appleInstalls.remove(key);
      await refresh();
    }
  }

  Future<void> cancelApple(String locale, SpeechEngine engine) async =>
      _appleJobs[appleKey(locale, engine)]?.cancel();

  Future<void> releaseApple(String locale, SpeechEngine engine) async {
    await appleAssets?.release(locale, engine);
    await refresh();
  }

  @override
  void dispose() {
    app.removeListener(_syncCloud);
    _storeSub.cancel();
    super.dispose();
  }
}

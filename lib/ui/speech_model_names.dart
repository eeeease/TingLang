import 'package:intl/intl.dart';
import 'package:tinglang_native/tinglang_native.dart';

import '../l10n/app_localizations.dart';
import '../services/live_controller.dart';

/// The model's name in the interface language; null for an unknown model.
String? speechModelName(AppLocalizations l, SpeechModel? model) => switch (model?.id) {
  'speech_transcriber' => l.speechModelAppleSpeech,
  'dictation_transcriber' => l.speechModelAppleDictation,
  'sherpa.xasr_zh_en_480' => l.speechModelXasr,
  'sherpa.zipformer_en_small' => l.speechModelSmallEn,
  'sherpa.zipformer_en_medium' => l.speechModelMediumEn,
  'sherpa.xasr_zh_en_offline' => l.speechModelXasrOffline,
  'sherpa.parakeet_tdt_v2' => l.speechModelParakeet,
  _ => null,
};

/// A cloud speech service's name; [id] is `tencent` or `cloud.tencent`.
String cloudServiceName(AppLocalizations l, String id) =>
    switch (id.startsWith('cloud.') ? id.substring(6) : id) {
      'tencent' => l.cloudTencent,
      'dashscope' => l.cloudDashscope,
      'xfyun' => l.cloudXfyun,
      'soniox' => l.cloudSoniox,
      'assemblyai' => l.cloudAssemblyai,
      'azure' => l.cloudAzure,
      final other => other,
    };

/// Label of a credential field ([CloudFieldKeys]).
String cloudFieldLabel(AppLocalizations l, String key) => switch (key) {
  CloudFieldKeys.apiKey => l.cloudFieldApiKey,
  CloudFieldKeys.apiSecret => l.cloudFieldApiSecret,
  CloudFieldKeys.appId => l.cloudFieldAppId,
  CloudFieldKeys.secretId => l.cloudFieldSecretId,
  CloudFieldKeys.secretKey => l.cloudFieldSecretKey,
  CloudFieldKeys.region => l.cloudFieldRegion,
  _ => key,
};

/// Label of a region choice id.
String cloudRegionLabel(AppLocalizations l, String id) => switch (id) {
  'cn' => l.cloudRegionCn,
  'intl' => l.cloudRegionIntl,
  'us' => l.cloudRegionUs,
  'eu' => l.cloudRegionEu,
  _ => id,
};

/// Why a recogniser stopped, in the user's words.
String asrFailureMessage(AppLocalizations l, AsrFailure failure) {
  final service = cloudServiceName(l, failure.backendId ?? '');
  return switch (failure.reason) {
    AsrFailureReason.unauthorized => l.asrFailedUnauthorized(service),
    AsrFailureReason.quotaExceeded => l.asrFailedQuota(service),
    AsrFailureReason.rateLimited => l.asrFailedRateLimited(service),
    AsrFailureReason.network => l.asrFailedNetwork(service),
    AsrFailureReason.unsupportedLanguage => l.asrFailedLanguage(service),
    AsrFailureReason.audioTooLong => l.asrFailedTooLong(service),
    AsrFailureReason.other => l.asrFailedOther(service, failure.message),
  };
}

/// "Low", "medium" or "high" CPU from the measured percentage.
String cpuLevel(AppLocalizations l, double percent) => percent <= 5
    ? l.speechCpuLow
    : percent <= 15
    ? l.speechCpuMedium
    : l.speechCpuHigh;

/// Decimal megabytes, as download sizes are usually quoted ("169 MB").
String formatBytes(AppLocalizations l, int bytes) {
  final number = NumberFormat.decimalPattern(l.localeName);
  if (bytes >= 1000 * 1000 * 1000) {
    return '${(NumberFormat('0.0', l.localeName)).format(bytes / 1e9)} GB';
  }
  if (bytes >= 1000 * 1000) return '${number.format((bytes / 1e6).round())} MB';
  return '${number.format((bytes / 1e3).ceil())} KB';
}

/// Panel messages about speech models in the interface language.
final class L10nModelText implements LiveModelText {
  L10nModelText(this._l, {String Function(String code)? languageName})
    : _languageName = languageName ?? ((code) => code);

  /// Read on every use so the panel follows the interface language.
  final AppLocalizations Function() _l;
  final String Function(String code) _languageName;

  @override
  String modelName(SpeechModel model) => speechModelName(_l(), model) ?? model.id;
  @override
  String modelNeeded(String name, String size) => _l().panelModelNeeded(name, size);
  @override
  String downloadSize(String size) => _l().speechDownload(size);
  @override
  String downloading(String name, int percent) => _l().panelDownloadingModel(name, '$percent');
  @override
  String languageUnsupported(String name, String language) =>
      _l().panelLanguageUnsupported(name, _languageName(language));
  @override
  String get cancel => _l().speechCancel;
  @override
  String get openSettings => _l().panelOpenSettings;
  @override
  String size(int bytes) => formatBytes(_l(), bytes);
  @override
  String get chooseRecognizer => _l().panelChooseRecognizer;
  @override
  String cloudNotSetUp(String? service) =>
      service == null ? _l().panelCloudNotChosen : _l().panelCloudNotSetUp(service);
  @override
  String cloudLanguageUnsupported(String service, String language) =>
      _l().panelCloudLanguage(service, _languageName(language));
  @override
  String recognizerFailed(AsrFailure failure) => asrFailureMessage(_l(), failure);
  @override
  String cloudServiceName(String backendId) => _serviceName(_l(), backendId);
  @override
  String cloudLabel(String backendId) => _l().panelCloudLabel(_serviceName(_l(), backendId));
}

/// [cloudServiceName], for [L10nModelText], whose method has the same name.
const _serviceName = cloudServiceName;

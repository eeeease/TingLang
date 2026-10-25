import 'dart:io';

import 'package:flutter/services.dart';
import 'package:tinglang_api/tinglang_api.dart';
import 'package:tinglang_native/tinglang_native.dart'
    show AsrFailure, CloudAsrError, CloudAsrErrorKind, SpeechModels;

import '../core/share_package.dart';
import '../l10n/app_localizations.dart';
import '../services/cloud/cloud_services.dart';
import '../services/transcription_controller.dart';
import 'speech_model_names.dart';

/// One sentence a person can act on. Dart's type prefixes ("Bad state:",
/// "FormatException:") and plugin error codes never reach the screen.
String describeError(AppLocalizations l, Object error) {
  if (error is ImportFailure) {
    return switch (error.problem) {
      ImportProblem.unsupportedFormat => l.errorUnsupportedFormat(error.detail ?? ''),
      ImportProblem.noAudio => l.errorNoAudio,
      ImportProblem.noEngine => l.errorNoTranscriber,
      ImportProblem.modelMissing => l.errorModelMissing(
        speechModelName(l, SpeechModels.byId(error.detail ?? '')) ?? error.detail ?? '',
      ),
      ImportProblem.speechAssetMissing => l.errorSpeechAssetMissing(error.detail ?? ''),
      ImportProblem.cloudNotSetUp => l.errorCloudNotSetUp,
      ImportProblem.cloudLanguageUnsupported => l.asrFailedLanguage(
        cloudServiceName(l, error.detail ?? ''),
      ),
    };
  }
  if (error is AsrFailure) return asrFailureMessage(l, error);
  if (error is CloudAsrError) {
    // "Test connection" in Settings, where the service is named already.
    return error.kind == CloudAsrErrorKind.unauthorized
        ? l.providerTestUnauthorized
        : l.errorWithDetail(error.message);
  }
  if (error is ShareFailure) {
    return switch (error.problem) {
      ShareProblem.notAPackage => l.shareNotPackage,
      ShareProblem.newerVersion => l.shareNewerVersion,
      ShareProblem.missingContent => l.shareIncomplete,
      ShareProblem.tooLarge => l.shareTooLarge,
      ShareProblem.unsupportedMedia => l.shareUnsupportedMedia,
    };
  }
  // file_picker reports a missing user-selected file entitlement this way.
  if (error is PlatformException && error.code.startsWith('ENTITLEMENT')) {
    return l.errorFileDialog;
  }
  if (error is PathNotFoundException) return l.errorFileMissing;
  final detail = switch (error) {
    PlatformException(:final message) => message ?? error.code,
    FileSystemException(:final message) => message,
    FormatException(:final message) => message,
    StateError(:final message) => message,
    _ => '$error'.replaceFirst(RegExp(r'^Exception:\s*'), ''),
  };
  return l.errorWithDetail(detail);
}

/// Cloud failures by their stable codes (docs/CLOUD.md §9); the server's own
/// text is never shown.
String describeCloudError(AppLocalizations l, Object error, {required String host}) =>
    switch (error) {
      ApiUnreachable() => l.cloudErrorUnreachable(host),
      CloudUnsupported(reason: CloudUnsupportedReason.noAccounts) => l.cloudErrorNoAccounts,
      CloudUnsupported(reason: CloudUnsupportedReason.noBrowserSession) => l.cloudErrorNoBrowser,
      CloudUnsupported(reason: CloudUnsupportedReason.noSecureStorage) => l.cloudErrorNoKeychain,
      AuthFailure(reason: AuthFailureReason.canceled) => l.cloudErrorCanceled,
      AuthFailure(reason: AuthFailureReason.invalidGrant || AuthFailureReason.signedOut) =>
        l.cloudErrorSessionEnded,
      AuthFailure() => l.cloudErrorSignIn,
      ApiBadResponse() => l.cloudErrorBadResponse,
      ApiProblemException(:final code, :final problem) => switch (code) {
        ProblemCode.unauthorized => l.cloudErrorSessionEnded,
        ProblemCode.clientTooOld => l.cloudErrorClientTooOld,
        ProblemCode.entitlementRequired => l.cloudErrorEntitlement,
        ProblemCode.quotaExceeded => l.cloudErrorQuota,
        ProblemCode.rateLimited => l.cloudErrorRateLimited,
        ProblemCode.featureDisabled || ProblemCode.notFound => l.cloudErrorFeatureDisabled,
        ProblemCode.serverUnavailable => l.cloudErrorMaintenance,
        _ => l.cloudErrorServer(problem.code),
      },
      _ => describeError(l, error),
    };

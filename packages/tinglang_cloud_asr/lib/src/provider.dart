import 'dart:async';
import 'dart:typed_data';

import 'package:meta/meta.dart';

/// What a provider needs from the user. Labels live in the app's l10n files
/// (keyed by [CloudField.key]); this package only names the fields.
enum CloudFieldKind {
  /// Shown as typed (app id, region name).
  text,

  /// A key or secret: obscured, stored in the platform secret store.
  secret,

  /// One of [CloudField.choices] (region ids such as `cn`, `intl`, `us`, `eu`).
  choice,
}

@immutable
final class CloudField {
  const CloudField(
    this.key, {
    this.kind = CloudFieldKind.secret,
    this.choices = const [],
    this.defaultValue,
    this.optional = false,
  });

  /// One of [CloudFieldKeys]; the app maps it to a label.
  final String key;
  final CloudFieldKind kind;

  /// Choice ids, in display order ([CloudFieldKind.choice] only).
  final List<String> choices;
  final String? defaultValue;
  final bool optional;
}

/// Field keys the app has labels for. Add a key here and in both .arb files
/// together.
abstract final class CloudFieldKeys {
  static const apiKey = 'apiKey';
  static const apiSecret = 'apiSecret';
  static const appId = 'appId';
  static const secretId = 'secretId';
  static const secretKey = 'secretKey';
  static const region = 'region';
}

/// Credentials as entered: [CloudField.key] → value.
typedef CloudCredentials = Map<String, String>;

/// Facts about a provider for Settings and the consent line.
@immutable
final class CloudAsrInfo {
  const CloudAsrInfo({
    required this.id,
    required this.fields,
    required this.languages,
    required this.consoleUrl,
    this.docsUrl,
    this.live = true,
    this.file = true,
    this.maxFileMs,
    this.maxFileBytes,
  });

  /// Stable id: the backend ids are `cloud.<id>` (see `BackendCatalog`).
  final String id;
  final List<CloudField> fields;

  /// Base language codes the service recognises (`en`, `zh`, `ja`, …).
  final Set<String> languages;

  /// Where the user creates the key (shown as a link).
  final Uri consoleUrl;
  final Uri? docsUrl;

  /// Whether [CloudAsrProvider.openStream] / [CloudAsrProvider.transcribeFile]
  /// are offered.
  final bool live, file;

  /// Longest / largest audio one [CloudAsrProvider.transcribeFile] call
  /// accepts; the caller splits longer files. Null: no practical limit.
  final int? maxFileMs, maxFileBytes;
}

/// One timed word, only when the service reports it.
@immutable
final class CloudWord {
  const CloudWord(this.text, this.startMs, this.endMs);
  final String text;
  final int startMs, endMs;

  @override
  String toString() => 'CloudWord($text, $startMs–$endMs)';
}

/// A recognised piece of speech. In a stream, partials ([isFinal] false)
/// and the final that replaces them share [id]; times are milliseconds from
/// the first sample sent on that stream. In a file result every segment is
/// final and times are offsets into that file.
@immutable
final class CloudSegment {
  const CloudSegment({
    required this.id,
    required this.text,
    required this.startMs,
    required this.endMs,
    this.isFinal = true,
    this.words,
    this.language,
  });
  final String id;
  final String text;
  final int startMs, endMs;
  final bool isFinal;
  final List<CloudWord>? words;

  /// Detected language when the service reports it.
  final String? language;

  @override
  String toString() =>
      'CloudSegment($id, ${isFinal ? 'final' : 'partial'}, $startMs–$endMs, "$text")';
}

enum CloudAsrErrorKind {
  /// Key, secret or app id rejected.
  unauthorized,

  /// Out of balance, free tier used up, or the service not activated.
  quotaExceeded,

  /// Too many requests or concurrent streams; retry later.
  rateLimited,

  /// The service refused the request as malformed.
  badRequest,
  unsupportedLanguage,

  /// Longer or larger than the service accepts in one request.
  audioTooLong,

  /// Could not reach the service (DNS, TLS, connection reset, timeout).
  network,

  /// The service failed (5xx or its own internal error code).
  server,

  /// The service ended a stream normally at its own time limit; the caller
  /// opens a new one.
  sessionEnded,
  cancelled,

  /// A reply this adapter does not understand.
  protocol,
}

/// The only error type adapters throw or put on a stream. [message] may be
/// shown to the user: it is the service's own message (or ours) and never
/// contains credentials or audio.
final class CloudAsrError implements Exception {
  const CloudAsrError(this.kind, this.message, {this.statusCode, this.providerCode});
  final CloudAsrErrorKind kind;
  final String message;

  /// HTTP status, when there was one.
  final int? statusCode;

  /// The service's own error code, when it sent one.
  final String? providerCode;

  /// Whether opening a new stream or retrying later can help.
  bool get retryable => switch (kind) {
    CloudAsrErrorKind.network ||
    CloudAsrErrorKind.server ||
    CloudAsrErrorKind.rateLimited ||
    CloudAsrErrorKind.sessionEnded => true,
    _ => false,
  };

  @override
  String toString() =>
      'CloudAsrError(${kind.name}${statusCode == null ? '' : ', HTTP $statusCode'}'
      '${providerCode == null ? '' : ', code $providerCode'}): $message';
}

@immutable
final class CloudStreamOptions {
  const CloudStreamOptions({required this.language, this.sampleRate = 16000});

  /// BCP-47 (`en`, `en-US`, `en-GB`, `zh-Hans`, `ja`, …). Adapters map it to
  /// the service's own code and throw [CloudAsrErrorKind.unsupportedLanguage]
  /// when they cannot.
  final String language;
  final int sampleRate;
}

@immutable
final class CloudFileRequest {
  const CloudFileRequest({
    required this.wav,
    required this.durationMs,
    required this.language,
    this.wordTimestamps = true,
  });

  /// A complete WAV file: 16 kHz mono 16-bit PCM ([wavFromPcm16]).
  final Uint8List wav;
  final int durationMs;

  /// BCP-47, as in [CloudStreamOptions.language].
  final String language;
  final bool wordTimestamps;
}

/// Cancels a [CloudAsrProvider.transcribeFile] call: adapters check it
/// between steps (upload, each poll) and stop with
/// [CloudAsrErrorKind.cancelled].
final class CloudCancelToken {
  final _done = Completer<void>();
  bool get isCancelled => _done.isCompleted;
  Future<void> get whenCancelled => _done.future;
  void cancel() {
    if (!_done.isCompleted) _done.complete();
  }

  /// Throws [CloudAsrErrorKind.cancelled] once cancelled.
  void check() {
    if (isCancelled) throw const CloudAsrError(CloudAsrErrorKind.cancelled, 'Cancelled.');
  }
}

/// A live recognition stream. Feed audio with [addPcm]; results and a fatal
/// error (always a [CloudAsrError]) arrive on [segments], which closes after
/// [finish] or [cancel] completes, or after an error.
abstract interface class CloudAsrStream {
  Stream<CloudSegment> get segments;

  /// 16-bit little-endian mono PCM at [CloudStreamOptions.sampleRate], in
  /// chunks of 40–200 ms. Adapters re-chunk to the frame size their service
  /// wants and pace nothing: the caller sends audio as it is captured.
  void addPcm(Uint8List pcm16le);

  /// Ends the audio and completes once the service has sent its last
  /// result, or after [timeout].
  Future<void> finish({Duration timeout = const Duration(seconds: 10)});

  /// Closes at once; pending results are dropped.
  Future<void> cancel();
}

/// A cloud speech service. Implementations are pure Dart (`dart:io`), run in
/// a worker isolate, create no `HttpClient` or socket before a call, and
/// never put credentials into errors, logs or results.
abstract interface class CloudAsrProvider {
  CloudAsrInfo get info;

  /// Host names audio and credentials go to with [credentials] (for the
  /// consent line, e.g. `asr.cloud.tencent.com`).
  List<String> hosts(CloudCredentials credentials);

  /// Checks [credentials] with the cheapest call the service offers (no
  /// audio when it allows). Throws a [CloudAsrError].
  Future<void> verify(CloudCredentials credentials);

  /// Opens a live stream. Throws a [CloudAsrError] if the service refuses.
  Future<CloudAsrStream> openStream(CloudCredentials credentials, CloudStreamOptions options);

  /// Transcribes one file of at most [CloudAsrInfo.maxFileMs] /
  /// [CloudAsrInfo.maxFileBytes]. [onProgress] gets 0.0–1.0 when the service
  /// reports progress (upload counts as the first part).
  Future<List<CloudSegment>> transcribeFile(
    CloudCredentials credentials,
    CloudFileRequest request, {
    void Function(double progress)? onProgress,
    CloudCancelToken? cancel,
  });
}

/// Base language of a BCP-47 tag: `en-GB` → `en`, `zh-Hans` → `zh`.
String baseLanguage(String tag) => tag.split(RegExp('[-_]')).first.toLowerCase();

/// Reads a required credential or throws [CloudAsrErrorKind.unauthorized]
/// naming the field (never its value).
String requireField(CloudCredentials credentials, String key) {
  final value = credentials[key]?.trim() ?? '';
  if (value.isEmpty) {
    throw CloudAsrError(CloudAsrErrorKind.unauthorized, 'Missing $key.');
  }
  return value;
}

import 'dart:math' as math;

import 'errors.dart';

/// Reads one JSON object strictly for required fields and leniently for the
/// rest: unknown fields are ignored, open string sets stay as strings.
class _Read {
  _Read(Object? value, this.what)
    : json = value is Map<String, Object?>
          ? value
          : throw ApiBadResponse('$what: expected an object');
  final Map<String, Object?> json;
  final String what;

  Never _bad(String key, String expected) => throw ApiBadResponse('$what.$key: expected $expected');

  String str(String key) {
    final v = json[key];
    return v is String ? v : _bad(key, 'a string');
  }

  String? optStr(String key) {
    final v = json[key];
    return v == null ? null : (v is String ? v : _bad(key, 'a string'));
  }

  num number(String key) {
    final v = json[key];
    return v is num ? v : _bad(key, 'a number');
  }

  int? optInt(String key) {
    final v = json[key];
    return v == null ? null : (v is int ? v : _bad(key, 'an integer'));
  }

  bool boolean(String key) {
    final v = json[key];
    return v is bool ? v : _bad(key, 'true or false');
  }

  DateTime date(String key) => _parseDate(str(key)) ?? _bad(key, 'an RFC 3339 time');
  DateTime? optDate(String key) =>
      json[key] == null ? null : (_parseDate(str(key)) ?? _bad(key, 'an RFC 3339 time'));

  Uri uri(String key) => Uri.tryParse(str(key)) ?? _bad(key, 'a URI');
  Uri? optUri(String key) => json[key] == null ? null : uri(key);

  Map<String, Object?> obj(String key) {
    final v = json[key];
    return v is Map<String, Object?> ? v : _bad(key, 'an object');
  }

  Map<String, Object?>? optObj(String key) => json[key] == null ? null : obj(key);

  List<Object?> list(String key) {
    final v = json[key];
    return v is List<Object?> ? v : _bad(key, 'a list');
  }

  List<Object?>? optList(String key) => json[key] == null ? null : list(key);

  static DateTime? _parseDate(String text) {
    // RFC 3339 requires a zone; DateTime.parse would accept local times.
    if (!RegExp(r'(Z|[+-]\d\d:\d\d)$', caseSensitive: false).hasMatch(text)) return null;
    return DateTime.tryParse(text)?.toUtc();
  }
}

/// RFC 3339 in UTC, without fractional seconds when there are none.
String rfc3339(DateTime time) {
  final t = time.toUtc();
  String two(int n) => n.toString().padLeft(2, '0');
  final base =
      '${t.year.toString().padLeft(4, '0')}-${two(t.month)}-${two(t.day)}'
      'T${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  final ms = t.millisecond;
  return ms == 0 ? '${base}Z' : '$base.${ms.toString().padLeft(3, '0')}Z';
}

void _put(Map<String, Object?> json, String key, Object? value) {
  if (value != null) json[key] = value;
}

/// Problem codes the client knows; anything else is [unknown].
enum ProblemCode {
  unauthorized,
  forbidden,
  entitlementRequired,
  quotaExceeded,
  rateLimited,
  validationFailed,
  notFound,
  conflict,
  idempotencyKeyReused,
  uploadExpired,
  uploadTooLarge,
  jobFailed,
  clientTooOld,
  featureDisabled,
  serverUnavailable,
  unknown;

  static ProblemCode parse(String code) =>
      values.firstWhere((c) => c != unknown && _snake(c.name) == code, orElse: () => unknown);
}

String _snake(String camel) =>
    camel.replaceAllMapped(RegExp('[A-Z]'), (m) => '_${m[0]!.toLowerCase()}');

/// RFC 9457 problem details with the contract's stable [code].
class ApiProblem {
  const ApiProblem({
    required this.status,
    required this.code,
    this.type,
    this.title,
    this.detail,
    this.instance,
    this.errors,
  });

  factory ApiProblem.fromJson(Object? value) {
    final r = _Read(value, 'problem');
    final status = r.number('status');
    return ApiProblem(
      status: status is int ? status : status.round(),
      code: r.str('code'),
      type: r.optStr('type'),
      title: r.optStr('title'),
      detail: r.optStr('detail'),
      instance: r.optStr('instance'),
      errors: r.optList('errors')?.map(FieldProblem.fromJson).toList(),
    );
  }

  final int status;

  /// As sent; see [knownCode].
  final String code;
  final String? type, title, detail, instance;
  final List<FieldProblem>? errors;
  ProblemCode get knownCode => ProblemCode.parse(code);

  Map<String, Object?> toJson() {
    final json = <String, Object?>{};
    _put(json, 'type', type);
    _put(json, 'title', title);
    json['status'] = status;
    _put(json, 'detail', detail);
    _put(json, 'instance', instance);
    json['code'] = code;
    _put(json, 'errors', errors?.map((e) => e.toJson()).toList());
    return json;
  }
}

class FieldProblem {
  const FieldProblem({required this.field, required this.code, this.detail});
  factory FieldProblem.fromJson(Object? value) {
    final r = _Read(value, 'problem.errors[]');
    return FieldProblem(field: r.str('field'), code: r.str('code'), detail: r.optStr('detail'));
  }
  final String field, code;
  final String? detail;
  Map<String, Object?> toJson() => {'field': field, 'code': code, 'detail': ?detail};
}

/// `GET /v1/meta`: what a server offers.
class ApiMeta {
  const ApiMeta({
    required this.apiVersion,
    required this.features,
    this.server,
    this.minClientVersion = const {},
    this.auth,
    this.web,
  });

  factory ApiMeta.fromJson(Object? value) {
    final r = _Read(value, 'meta');
    final minimum = r.optObj('min_client_version') ?? const {};
    return ApiMeta(
      apiVersion: r.str('api_version'),
      server: r.json['server'] == null ? null : ServerInfo.fromJson(r.json['server']),
      minClientVersion: {
        for (final e in minimum.entries)
          if (e.value is String) e.key: e.value! as String,
      },
      auth: r.json['auth'] == null ? null : AuthConfig.fromJson(r.json['auth']),
      features: CloudFeatures(r.obj('features')),
      web: r.json['web'] == null ? null : WebLinks.fromJson(r.json['web']),
    );
  }

  final String apiVersion;
  final ServerInfo? server;

  /// Platform → lowest client version the server still serves.
  final Map<String, String> minClientVersion;

  /// Absent when the server has no accounts.
  final AuthConfig? auth;
  final CloudFeatures features;
  final WebLinks? web;

  /// Whether [clientVersion] on [platform] is too old for this server.
  bool requiresNewerClient(String platform, String clientVersion) {
    final minimum = minClientVersion[platform];
    return minimum != null && compareVersions(clientVersion, minimum) < 0;
  }

  Map<String, Object?> toJson() {
    final json = <String, Object?>{'api_version': apiVersion};
    _put(json, 'server', server?.toJson());
    if (minClientVersion.isNotEmpty) json['min_client_version'] = minClientVersion;
    _put(json, 'auth', auth?.toJson());
    json['features'] = features.raw;
    _put(json, 'web', web?.toJson());
    return json;
  }
}

/// Compares dotted numeric versions (`0.4.0` < `0.10.0`); a build suffix
/// after `+` or `-` is ignored.
int compareVersions(String a, String b) {
  List<int> parts(String v) =>
      v.split(RegExp('[+-]')).first.split('.').map((p) => int.tryParse(p) ?? 0).toList();
  final x = parts(a), y = parts(b);
  for (var i = 0; i < math.max(x.length, y.length); i++) {
    final d = (i < x.length ? x[i] : 0).compareTo(i < y.length ? y[i] : 0);
    if (d != 0) return d;
  }
  return 0;
}

/// Feature switches. Anything missing, unknown or not `true` is off, so a
/// server that implements only part of the contract still works.
class CloudFeatures {
  const CloudFeatures(this.raw);
  static const none = CloudFeatures({});
  final Map<String, Object?> raw;

  /// `isOn('llm_gateway')`, `isOn('jobs.transcribe')`.
  bool isOn(String path) {
    Object? node = raw;
    for (final part in path.split('.')) {
      if (node is! Map<String, Object?>) return false;
      node = node[part];
    }
    return node == true;
  }

  bool get accounts => isOn('accounts');
  bool get entitlements => isOn('entitlements');
  bool get llmGateway => isOn('llm_gateway');
  bool job(JobKind kind) => kind != JobKind.unknown && isOn('jobs.${kind.wire}');
}

class ServerInfo {
  const ServerInfo({required this.name, this.termsUrl, this.privacyUrl});
  factory ServerInfo.fromJson(Object? value) {
    final r = _Read(value, 'meta.server');
    return ServerInfo(
      name: r.str('name'),
      termsUrl: r.optUri('terms_url'),
      privacyUrl: r.optUri('privacy_url'),
    );
  }
  final String name;
  final Uri? termsUrl, privacyUrl;
  Map<String, Object?> toJson() => {
    'name': name,
    'terms_url': ?termsUrl?.toString(),
    'privacy_url': ?privacyUrl?.toString(),
  };
}

/// OAuth 2.1 / OIDC settings of the server's identity provider.
class AuthConfig {
  const AuthConfig({
    required this.issuer,
    required this.authorizationEndpoint,
    required this.tokenEndpoint,
    required this.clientId,
    required this.redirectUri,
    this.revocationEndpoint,
    this.scopes = const [],
  });

  factory AuthConfig.fromJson(Object? value) {
    final r = _Read(value, 'meta.auth');
    return AuthConfig(
      issuer: r.uri('issuer'),
      authorizationEndpoint: r.uri('authorization_endpoint'),
      tokenEndpoint: r.uri('token_endpoint'),
      revocationEndpoint: r.optUri('revocation_endpoint'),
      clientId: r.str('client_id'),
      scopes: [
        for (final s in r.optList('scopes') ?? const <Object?>[])
          if (s is String) s,
      ],
      redirectUri: r.uri('redirect_uri'),
    );
  }

  final Uri issuer, authorizationEndpoint, tokenEndpoint, redirectUri;
  final Uri? revocationEndpoint;
  final String clientId;
  final List<String> scopes;

  Map<String, Object?> toJson() => {
    'issuer': issuer.toString(),
    'authorization_endpoint': authorizationEndpoint.toString(),
    'token_endpoint': tokenEndpoint.toString(),
    'revocation_endpoint': ?revocationEndpoint?.toString(),
    'client_id': clientId,
    if (scopes.isNotEmpty) 'scopes': scopes,
    'redirect_uri': redirectUri.toString(),
  };
}

class WebLinks {
  const WebLinks({this.accountUrl, this.pricingUrl});
  factory WebLinks.fromJson(Object? value) {
    final r = _Read(value, 'meta.web');
    return WebLinks(accountUrl: r.optUri('account_url'), pricingUrl: r.optUri('pricing_url'));
  }
  final Uri? accountUrl, pricingUrl;
  Map<String, Object?> toJson() => {
    'account_url': ?accountUrl?.toString(),
    'pricing_url': ?pricingUrl?.toString(),
  };
}

/// `GET /v1/account`.
class Account {
  const Account({required this.id, required this.createdAt, this.email, this.displayName});
  factory Account.fromJson(Object? value) {
    final r = _Read(value, 'account');
    return Account(
      id: r.str('id'),
      email: r.optStr('email'),
      displayName: r.optStr('display_name'),
      createdAt: r.date('created_at'),
    );
  }
  final String id;
  final String? email, displayName;
  final DateTime createdAt;
  Map<String, Object?> toJson() => {
    'id': id,
    'email': ?email,
    'display_name': ?displayName,
    'created_at': rfc3339(createdAt),
  };
}

enum EntitlementStatus {
  active,
  trialing,
  pastDue,
  canceled,
  expired,
  none,
  unknown;

  static EntitlementStatus parse(String s) =>
      values.firstWhere((v) => v != unknown && _snake(v.name) == s, orElse: () => unknown);
}

/// `GET /v1/entitlements`. Display only: the server checks every call.
class Entitlements {
  const Entitlements({
    required this.plan,
    required this.status,
    required this.features,
    required this.checkedAt,
    this.validUntil,
    this.graceUntil,
  });

  factory Entitlements.fromJson(Object? value) {
    final r = _Read(value, 'entitlements');
    return Entitlements(
      plan: r.str('plan'),
      status: r.str('status'),
      features: {
        for (final e in r.obj('features').entries) e.key: FeatureEntitlement.fromJson(e.value),
      },
      validUntil: r.optDate('valid_until'),
      checkedAt: r.date('checked_at'),
      graceUntil: r.optDate('grace_until'),
    );
  }

  final String plan;

  /// As sent; see [knownStatus].
  final String status;
  final Map<String, FeatureEntitlement> features;
  final DateTime checkedAt;
  final DateTime? validUntil, graceUntil;
  EntitlementStatus get knownStatus => EntitlementStatus.parse(status);
  bool enabled(String feature) => features[feature]?.enabled ?? false;

  /// Whether a cached copy may still be shown while the server is unreachable.
  bool usableOffline(DateTime now) => graceUntil != null && now.isBefore(graceUntil!);

  Map<String, Object?> toJson() => {
    'plan': plan,
    'status': status,
    'features': {for (final e in features.entries) e.key: e.value.toJson()},
    'valid_until': ?(validUntil == null ? null : rfc3339(validUntil!)),
    'checked_at': rfc3339(checkedAt),
    'grace_until': ?(graceUntil == null ? null : rfc3339(graceUntil!)),
  };
}

class FeatureEntitlement {
  const FeatureEntitlement({required this.enabled, this.quota});
  factory FeatureEntitlement.fromJson(Object? value) {
    final r = _Read(value, 'entitlements.features[]');
    return FeatureEntitlement(
      enabled: r.boolean('enabled'),
      quota: r.json['quota'] == null ? null : Quota.fromJson(r.json['quota']),
    );
  }
  final bool enabled;
  final Quota? quota;
  Map<String, Object?> toJson() => {'enabled': enabled, 'quota': ?quota?.toJson()};
}

class Quota {
  const Quota({required this.unit, required this.limit, required this.used, this.resetsAt});
  factory Quota.fromJson(Object? value) {
    final r = _Read(value, 'quota');
    return Quota(
      unit: r.str('unit'),
      limit: r.number('limit'),
      used: r.number('used'),
      resetsAt: r.optDate('resets_at'),
    );
  }

  /// `minute`, `credit`, or a unit added later.
  final String unit;
  final num limit, used;
  final DateTime? resetsAt;
  num get remaining => math.max(0, limit - used);
  Map<String, Object?> toJson() => {
    'unit': unit,
    'limit': limit,
    'used': used,
    'resets_at': ?(resetsAt == null ? null : rfc3339(resetsAt!)),
  };
}

enum JobKind {
  transcribe,
  translate,
  course,
  unknown;

  String get wire => name;
  static JobKind parse(String s) =>
      values.firstWhere((v) => v != unknown && v.name == s, orElse: () => unknown);
}

enum JobStatus {
  awaitingUpload,
  queued,
  running,
  succeeded,
  failed,
  canceled,
  expired,

  /// Shown as still in progress.
  unknown;

  static JobStatus parse(String s) =>
      values.firstWhere((v) => v != unknown && _snake(v.name) == s, orElse: () => unknown);
  bool get finished => this == succeeded || this == failed || this == canceled || this == expired;
}

/// A cloud job.
class Job {
  const Job({
    required this.id,
    required this.kind,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.expiresAt,
    this.progress,
    this.uploads,
    this.error,
  });

  factory Job.fromJson(Object? value) {
    final r = _Read(value, 'job');
    return Job(
      id: r.str('id'),
      kind: r.str('kind'),
      status: r.str('status'),
      createdAt: r.date('created_at'),
      updatedAt: r.date('updated_at'),
      expiresAt: r.optDate('expires_at'),
      progress: r.json['progress'] == null ? null : JobProgress.fromJson(r.json['progress']),
      uploads: r.optList('uploads')?.map(UploadTarget.fromJson).toList(),
      error: r.json['error'] == null ? null : ApiProblem.fromJson(r.json['error']),
    );
  }

  final String id;

  /// As sent; see [knownKind] and [knownStatus].
  final String kind, status;
  final DateTime createdAt, updatedAt;
  final DateTime? expiresAt;
  final JobProgress? progress;
  final List<UploadTarget>? uploads;
  final ApiProblem? error;
  JobKind get knownKind => JobKind.parse(kind);
  JobStatus get knownStatus => JobStatus.parse(status);

  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kind,
    'status': status,
    'created_at': rfc3339(createdAt),
    'updated_at': rfc3339(updatedAt),
    'expires_at': ?(expiresAt == null ? null : rfc3339(expiresAt!)),
    'progress': ?progress?.toJson(),
    'uploads': ?uploads?.map((u) => u.toJson()).toList(),
    'error': ?error?.toJson(),
  };
}

class JobProgress {
  const JobProgress({required this.fraction, this.stage});
  factory JobProgress.fromJson(Object? value) {
    final r = _Read(value, 'job.progress');
    return JobProgress(fraction: r.number('fraction'), stage: r.optStr('stage'));
  }

  /// 0 to 1.
  final num fraction;
  final String? stage;
  Map<String, Object?> toJson() => {'fraction': fraction, 'stage': ?stage};
}

/// A presigned URL for one input file. It carries its own authorisation, so
/// the account's token is never sent with the upload.
class UploadTarget {
  const UploadTarget({
    required this.name,
    required this.url,
    required this.method,
    required this.expiresAt,
    required this.maxBytes,
    this.headers = const {},
  });

  factory UploadTarget.fromJson(Object? value) {
    final r = _Read(value, 'upload');
    final headers = r.optObj('headers') ?? const {};
    final maxBytes = r.number('max_bytes');
    return UploadTarget(
      name: r.str('name'),
      url: r.uri('url'),
      method: r.str('method'),
      headers: {
        for (final e in headers.entries)
          if (e.value is String) e.key: e.value! as String,
      },
      expiresAt: r.date('expires_at'),
      maxBytes: maxBytes.toInt(),
    );
  }

  final String name, method;
  final Uri url;
  final Map<String, String> headers;
  final DateTime expiresAt;
  final int maxBytes;

  Map<String, Object?> toJson() => {
    'name': name,
    'url': url.toString(),
    'method': method,
    if (headers.isNotEmpty) 'headers': headers,
    'expires_at': rfc3339(expiresAt),
    'max_bytes': maxBytes,
  };
}

/// The media a job will upload.
class MediaInput {
  const MediaInput({required this.bytes, required this.contentType, this.name, this.durationMs});
  factory MediaInput.fromJson(Object? value) {
    final r = _Read(value, 'media');
    return MediaInput(
      name: r.optStr('name'),
      bytes: r.number('bytes').toInt(),
      contentType: r.str('content_type'),
      durationMs: r.optInt('duration_ms'),
    );
  }
  final String? name;
  final int bytes;
  final String contentType;
  final int? durationMs;
  Map<String, Object?> toJson() => {
    'name': ?name,
    'bytes': bytes,
    'content_type': contentType,
    'duration_ms': ?durationMs,
  };
}

class JobEstimateRequest {
  const JobEstimateRequest({
    required this.kind,
    this.media,
    this.language,
    this.targetLanguage,
    this.lineCount,
    this.characterCount,
  });
  factory JobEstimateRequest.fromJson(Object? value) {
    final r = _Read(value, 'estimate request');
    return JobEstimateRequest(
      kind: JobKind.parse(r.str('kind')),
      media: r.json['media'] == null ? null : MediaInput.fromJson(r.json['media']),
      language: r.optStr('language'),
      targetLanguage: r.optStr('target_language'),
      lineCount: r.optInt('line_count'),
      characterCount: r.optInt('character_count'),
    );
  }
  final JobKind kind;
  final MediaInput? media;
  final String? language, targetLanguage;
  final int? lineCount, characterCount;
  Map<String, Object?> toJson() => {
    'kind': kind.wire,
    'media': ?media?.toJson(),
    'language': ?language,
    'target_language': ?targetLanguage,
    'line_count': ?lineCount,
    'character_count': ?characterCount,
  };
}

class JobEstimate {
  const JobEstimate({
    required this.kind,
    required this.allowed,
    required this.costUnit,
    required this.costAmount,
    this.reason,
    this.quota,
    this.etaSeconds,
  });
  factory JobEstimate.fromJson(Object? value) {
    final r = _Read(value, 'estimate');
    final cost = _Read(r.obj('cost'), 'estimate.cost');
    return JobEstimate(
      kind: r.str('kind'),
      allowed: r.boolean('allowed'),
      reason: r.optStr('reason'),
      costUnit: cost.str('unit'),
      costAmount: cost.number('amount'),
      quota: r.json['quota'] == null ? null : Quota.fromJson(r.json['quota']),
      etaSeconds: r.optInt('eta_seconds'),
    );
  }
  final String kind;
  final bool allowed;

  /// A problem code when not [allowed].
  final String? reason;
  final String costUnit;
  final num costAmount;
  final Quota? quota;
  final int? etaSeconds;
  Map<String, Object?> toJson() => {
    'kind': kind,
    'allowed': allowed,
    'reason': ?reason,
    'cost': {'unit': costUnit, 'amount': costAmount},
    'quota': ?quota?.toJson(),
    'eta_seconds': ?etaSeconds,
  };
}

/// The user's agreement to send this job's content to [host].
class Consent {
  const Consent({required this.acknowledgedAt, required this.host});
  factory Consent.fromJson(Object? value) {
    final r = _Read(value, 'consent');
    return Consent(acknowledgedAt: r.date('acknowledged_at'), host: r.str('host'));
  }
  final DateTime acknowledgedAt;
  final String host;
  Map<String, Object?> toJson() => {'acknowledged_at': rfc3339(acknowledgedAt), 'host': host};
}

class JobCreateRequest {
  const JobCreateRequest({
    required this.kind,
    required this.consent,
    this.media,
    this.language,
    this.targetLanguage,
    this.transcript,
    this.learner,
  });
  factory JobCreateRequest.fromJson(Object? value) {
    final r = _Read(value, 'job request');
    return JobCreateRequest(
      kind: JobKind.parse(r.str('kind')),
      media: r.json['media'] == null ? null : MediaInput.fromJson(r.json['media']),
      language: r.optStr('language'),
      targetLanguage: r.optStr('target_language'),
      transcript: r.optObj('transcript'),
      learner: r.optObj('learner'),
      consent: Consent.fromJson(r.json['consent']),
    );
  }
  final JobKind kind;
  final MediaInput? media;
  final String? language, targetLanguage;

  /// A `.tinglang` transcript.json document, for translate and course jobs.
  final Map<String, Object?>? transcript;
  final Map<String, Object?>? learner;
  final Consent consent;
  Map<String, Object?> toJson() => {
    'kind': kind.wire,
    'media': ?media?.toJson(),
    'language': ?language,
    'target_language': ?targetLanguage,
    'transcript': ?transcript,
    'learner': ?learner,
    'consent': consent.toJson(),
  };
}

class JobPage {
  const JobPage({required this.items, this.nextCursor});
  factory JobPage.fromJson(Object? value) {
    final r = _Read(value, 'jobs');
    return JobPage(
      items: r.list('items').map(Job.fromJson).toList(),
      nextCursor: r.optStr('next_cursor'),
    );
  }
  final List<Job> items;
  final String? nextCursor;
  Map<String, Object?> toJson() => {
    'items': items.map((j) => j.toJson()).toList(),
    'next_cursor': nextCursor,
  };
}

/// A finished job's output. The documents keep their own formats: a
/// `.tinglang` transcript.json or an English V3 course.json.
class JobResult {
  const JobResult({required this.kind, this.transcript, this.course, this.download});
  factory JobResult.fromJson(Object? value) {
    final r = _Read(value, 'result');
    final result = JobResult(
      kind: r.str('kind'),
      transcript: r.optObj('transcript'),
      course: r.optObj('course'),
      download: r.json['download'] == null ? null : ResultDownload.fromJson(r.json['download']),
    );
    final present = [result.transcript, result.course, result.download].nonNulls.length;
    if (present != 1) {
      throw const ApiBadResponse('result: expected one of transcript, course or download');
    }
    return result;
  }
  final String kind;
  final Map<String, Object?>? transcript, course;
  final ResultDownload? download;
  Map<String, Object?> toJson() => {
    'kind': kind,
    'transcript': ?transcript,
    'course': ?course,
    'download': ?download?.toJson(),
  };
}

class ResultDownload {
  const ResultDownload({required this.url, required this.expiresAt, this.contentType});
  factory ResultDownload.fromJson(Object? value) {
    final r = _Read(value, 'result.download');
    return ResultDownload(
      url: r.uri('url'),
      expiresAt: r.date('expires_at'),
      contentType: r.optStr('content_type'),
    );
  }
  final Uri url;
  final DateTime expiresAt;
  final String? contentType;
  Map<String, Object?> toJson() => {
    'url': url.toString(),
    'expires_at': rfc3339(expiresAt),
    'content_type': ?contentType,
  };
}

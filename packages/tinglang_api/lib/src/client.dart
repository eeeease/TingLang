import 'dart:convert';
import 'dart:io';

import 'errors.dart';
import 'http.dart';
import 'models.dart';
import 'server_url.dart';

/// Supplies the bearer token for authenticated calls ([AuthSession] in
/// practice). [force] asks for a new one after the server answered 401.
abstract interface class TokenSource {
  Future<String> accessToken({bool force = false});
}

/// The `/v1` endpoints of api/openapi.yaml. Constructing it sends nothing.
class TinglangApi {
  TinglangApi(
    this.server, {
    this.tokens,
    HttpClient? http,
    String? userAgent,
    Duration timeout = const Duration(seconds: 30),
  }) : _transport = HttpTransport(http: http, userAgent: userAgent, timeout: timeout);

  final ServerUrl server;
  final TokenSource? tokens;
  final HttpTransport _transport;

  Future<ApiMeta> getMeta() async => ApiMeta.fromJson(await _get('/meta', auth: false));
  Future<Account> getAccount() async => Account.fromJson(await _get('/account'));

  /// The official library: every course with [tokens], else the preview.
  /// Sign-in is optional here: without a usable token (none stored, the
  /// session gone) the preview is asked for instead of failing.
  Future<OfficialLibrary> getLibrary() async => OfficialLibrary.fromJson(
    (await _call('GET', '/library', auth: false, optionalAuth: true)).json(),
  );

  /// One official course as an English V3 course document (the client
  /// validates it with its course codec). Courses outside the preview need
  /// [tokens].
  Future<Map<String, Object?>> getLibraryCourse(String id) async {
    final json = (await _call(
      'GET',
      '/library/${Uri.encodeComponent(id)}',
      auth: false,
      optionalAuth: true,
    )).json();
    if (json is! Map<String, Object?>) throw const ApiBadResponse('course: expected an object');
    return json;
  }

  Future<Entitlements> getEntitlements() async =>
      Entitlements.fromJson(await _get('/entitlements'));

  Future<JobEstimate> estimateJob(JobEstimateRequest request) async =>
      JobEstimate.fromJson(await _send('POST', '/jobs/estimate', body: request.toJson()));

  /// Repeat with the same [idempotencyKey] until the outcome is known.
  Future<Job> createJob(JobCreateRequest request, {required String idempotencyKey}) async =>
      Job.fromJson(
        await _send(
          'POST',
          '/jobs',
          body: request.toJson(),
          headers: {'Idempotency-Key': idempotencyKey},
        ),
      );

  Future<JobPage> listJobs({String? cursor, int? limit}) async => JobPage.fromJson(
    await _get('/jobs', query: {'cursor': ?cursor, 'limit': ?limit?.toString()}),
  );

  /// The job and the server's suggested wait before polling again.
  Future<(Job, Duration?)> getJob(String id) async {
    final reply = await _call('GET', '/jobs/${Uri.encodeComponent(id)}');
    return (Job.fromJson(reply.json()), reply.retryAfter);
  }

  Future<Job> startJob(String id) async =>
      Job.fromJson(await _send('POST', '/jobs/${Uri.encodeComponent(id)}/start'));
  Future<JobResult> getJobResult(String id) async =>
      JobResult.fromJson(await _get('/jobs/${Uri.encodeComponent(id)}/result'));
  Future<Job> cancelJob(String id) async =>
      Job.fromJson(await _send('POST', '/jobs/${Uri.encodeComponent(id)}/cancel'));

  /// Uploads one input to its presigned URL. The account token is not sent:
  /// the URL carries its own authorisation and may point at another host.
  Future<void> upload(UploadTarget target, Stream<List<int>> bytes, int length) async {
    if (length > target.maxBytes) {
      throw ApiProblemException(
        ApiProblem(status: 413, code: 'upload_too_large', title: 'File too large'),
      );
    }
    ServerUrl.checkSecure(target.url);
    final reply = await _transport.send(
      target.method,
      target.url,
      headers: target.headers,
      stream: bytes,
      contentLength: length,
    );
    if (!reply.ok) throw reply.problem();
  }

  void close() => _transport.close();

  Future<Object?> _get(String path, {bool auth = true, Map<String, String>? query}) async =>
      (await _call('GET', path, auth: auth, query: query)).json();

  Future<Object?> _send(
    String method,
    String path, {
    Map<String, Object?>? body,
    Map<String, String> headers = const {},
  }) async => (await _call(method, path, body: body, headers: headers)).json();

  /// [optionalAuth]: send the token when one can be had, else ask as
  /// signed out (and again signed out if the server refuses the token).
  Future<HttpReply> _call(
    String method,
    String path, {
    bool auth = true,
    bool optionalAuth = false,
    Map<String, String>? query,
    Map<String, Object?>? body,
    Map<String, String> headers = const {},
  }) async {
    final uri = server.api(path, query);
    Future<String?> token({required bool force}) async {
      final source = tokens;
      if (optionalAuth) {
        if (source == null) return null;
        try {
          return await source.accessToken(force: force);
        } on Object {
          // No usable session (none stored, revoked, unreadable).
          return null;
        }
      }
      if (!auth) return null;
      if (source == null) {
        throw const AuthFailure('Not signed in', reason: AuthFailureReason.signedOut);
      }
      return source.accessToken(force: force);
    }

    Future<(HttpReply, bool)> attempt({required bool force, bool anonymous = false}) async {
      final all = {'Accept': 'application/json, application/problem+json', ...headers};
      final bearer = anonymous ? null : await token(force: force);
      if (bearer != null) all['Authorization'] = 'Bearer $bearer';
      if (body != null) all['Content-Type'] = 'application/json';
      final reply = await _transport.send(
        method,
        uri,
        headers: all,
        body: body == null ? null : utf8.encode(jsonEncode(body)),
      );
      return (reply, bearer != null);
    }

    var (reply, sent) = await attempt(force: false);
    // One retry with a fresh token: the cached one may have just expired.
    if (reply.status == 401 && sent) (reply, sent) = await attempt(force: true);
    if (reply.status == 401 && sent && optionalAuth) {
      (reply, sent) = await attempt(force: false, anonymous: true);
    }
    if (!reply.ok) throw reply.problem();
    return reply;
  }
}

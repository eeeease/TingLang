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

  Future<HttpReply> _call(
    String method,
    String path, {
    bool auth = true,
    Map<String, String>? query,
    Map<String, Object?>? body,
    Map<String, String> headers = const {},
  }) async {
    final uri = server.api(path, query);
    Future<HttpReply> attempt({required bool force}) async {
      final all = {'Accept': 'application/json, application/problem+json', ...headers};
      if (auth) {
        final source = tokens;
        if (source == null) {
          throw const AuthFailure('Not signed in', reason: AuthFailureReason.signedOut);
        }
        all['Authorization'] = 'Bearer ${await source.accessToken(force: force)}';
      }
      if (body != null) all['Content-Type'] = 'application/json';
      return _transport.send(
        method,
        uri,
        headers: all,
        body: body == null ? null : utf8.encode(jsonEncode(body)),
      );
    }

    var reply = await attempt(force: false);
    // One retry with a fresh token: the cached one may have just expired.
    if (reply.status == 401 && auth) reply = await attempt(force: true);
    if (!reply.ok) throw reply.problem();
    return reply;
  }
}

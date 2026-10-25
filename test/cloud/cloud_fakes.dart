import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:tinglang/services/cloud/cloud_services.dart';
import 'package:tinglang_api/tinglang_api.dart';

/// A file from the contract fixtures in `api/examples/`.
Map<String, Object?> contractExample(String path) =>
    jsonDecode(File('api/examples/$path').readAsStringSync()) as Map<String, Object?>;

/// Any [HttpClient] the code under test creates is counted, and any use of
/// it fails, so a test can prove that nothing went to the network.
final class NoNetwork extends HttpOverrides {
  final created = <StackTrace>[];
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    created.add(StackTrace.current);
    return _FailingHttpClient();
  }
}

final class _FailingHttpClient implements HttpClient {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('A test without network used HttpClient.${invocation.memberName}');
}

/// The real dart:io client, for tests that need a refused connection.
final class RealNetwork extends HttpOverrides {}

/// An [AccountService] answering with the contract examples; set [failure]
/// to make the calls that reach the "server" throw.
final class FakeAccountService implements AccountService {
  FakeAccountService(this.server);

  @override
  final ServerUrl server;
  ApiMeta meta = ApiMeta.fromJson(contractExample('getMeta/response.200.json'));
  Account account = Account.fromJson(contractExample('getAccount/response.200.json'));
  Entitlements entitlements = Entitlements.fromJson(
    contractExample('getEntitlements/response.200.json'),
  );
  Object? failure;

  /// Fails only the sign-in step (the browser part).
  Object? signInFailure;
  bool session = false;

  /// Every call that would have gone to the server, in order.
  final calls = <String>[];

  Future<T> _call<T>(String name, T Function() answer) async {
    calls.add(name);
    final f = failure;
    if (f != null) throw f;
    return answer();
  }

  @override
  Future<ApiMeta> fetchMeta() => _call('meta', () => meta);
  @override
  Future<void> signIn(ApiMeta meta) => _call('signIn', () {
    final f = signInFailure;
    if (f != null) throw f;
    session = true;
  });
  @override
  Future<bool> hasSession() async => session;
  @override
  Future<Account> fetchAccount(ApiMeta meta) => _call('account', () => account);
  @override
  Future<Entitlements> fetchEntitlements(ApiMeta meta) => _call('entitlements', () => entitlements);
  @override
  Future<void> signOut(ApiMeta? meta) async {
    calls.add('signOut');
    session = false;
  }
}

/// A [CloudJobService] that runs every job in memory: awaiting upload →
/// queued → running → succeeded with the contract's example transcript.
final class FakeCloudJobService implements CloudJobService {
  final jobs = <String, Job>{};
  final uploaded = <String, List<int>>{};
  final keys = <String, String>{};
  var _next = 0;

  Job _with(Job job, String status, {num? fraction}) => Job(
    id: job.id,
    kind: job.kind,
    status: status,
    createdAt: job.createdAt,
    updatedAt: DateTime.utc(2026, 10, 23, 8, 0, ++_next),
    progress: fraction == null ? null : JobProgress(fraction: fraction),
  );

  @override
  Future<JobEstimate> estimate(ApiMeta meta, JobEstimateRequest request) async => JobEstimate(
    kind: request.kind.wire,
    allowed: true,
    costUnit: 'minute',
    costAmount: ((request.media?.durationMs ?? 0) / 60000).ceil(),
  );

  @override
  Future<Job> create(
    ApiMeta meta,
    JobCreateRequest request, {
    required String idempotencyKey,
  }) async {
    final existing = keys[idempotencyKey];
    if (existing != null) return jobs[existing]!;
    final id = 'job_${jobs.length + 1}';
    final job = Job(
      id: id,
      kind: request.kind.wire,
      status: request.media == null ? 'queued' : 'awaiting_upload',
      createdAt: DateTime.utc(2026, 10, 23, 8),
      updatedAt: DateTime.utc(2026, 10, 23, 8),
      uploads: request.media == null
          ? null
          : [
              UploadTarget(
                name: 'media',
                url: Uri.parse('https://storage.example/$id'),
                method: 'PUT',
                expiresAt: DateTime.utc(2030),
                maxBytes: 1 << 30,
              ),
            ],
    );
    keys[idempotencyKey] = id;
    return jobs[id] = job;
  }

  @override
  Future<void> upload(ApiMeta meta, UploadTarget target, File file) async =>
      uploaded[target.url.pathSegments.last] = await file.readAsBytes();

  @override
  Future<Job> start(ApiMeta meta, String id) async => jobs[id] = _with(jobs[id]!, 'queued');

  @override
  Future<(Job, Duration?)> poll(ApiMeta meta, String id) async {
    final job = jobs[id]!;
    final next = switch (job.knownStatus) {
      JobStatus.queued => _with(job, 'running', fraction: 0.5),
      JobStatus.running => _with(job, 'succeeded', fraction: 1),
      _ => job,
    };
    return (jobs[id] = next, next.knownStatus.finished ? null : const Duration(seconds: 1));
  }

  @override
  Future<JobResult> result(ApiMeta meta, String id) async =>
      JobResult.fromJson(contractExample('getJobResult/response.200.json'));

  @override
  Future<Job> cancel(ApiMeta meta, String id) async => jobs[id] = _with(jobs[id]!, 'canceled');
}

/// One request a [LocalServer] received.
class Seen {
  Seen(this.method, this.uri, this.headers, this.body);
  final String method;
  final Uri uri;
  final HttpHeaders headers;
  final String body;
  String? header(String name) => headers.value(name);
}

/// An HTTP server on 127.0.0.1 answering through [handler].
class LocalServer {
  LocalServer._(this._server) {
    _server.listen((request) async {
      final body = await utf8.decoder.bind(request).join();
      final seen = Seen(request.method, request.uri, request.headers, body);
      requests.add(seen);
      final (status, json) = handler(seen);
      request.response.statusCode = status;
      if (json != null) {
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode(json));
      }
      await request.response.close();
    });
  }

  static Future<LocalServer> start() async =>
      LocalServer._(await HttpServer.bind(InternetAddress.loopbackIPv4, 0));

  final HttpServer _server;
  final requests = <Seen>[];
  (int, Object?) Function(Seen request) handler = (_) => (404, null);
  String get origin => 'http://127.0.0.1:${_server.port}';
  Future<void> close() => _server.close(force: true);
}

/// A port nothing listens on.
Future<int> deadPort() async {
  final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = socket.port;
  await socket.close();
  return port;
}

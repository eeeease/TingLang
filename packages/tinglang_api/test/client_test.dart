import 'dart:convert';

import 'package:test/test.dart';
import 'package:tinglang_api/tinglang_api.dart';

import 'support.dart';

class _Tokens implements TokenSource {
  _Tokens(this.values);
  final List<String> values;
  final forced = <bool>[];
  @override
  Future<String> accessToken({bool force = false}) async {
    forced.add(force);
    return values[forced.length - 1];
  }
}

void main() {
  late LocalServer server;
  setUp(() async => server = await LocalServer.start());
  tearDown(() => server.close());

  TinglangApi api({TokenSource? tokens}) => TinglangApi(
    ServerUrl.parse(server.origin),
    tokens: tokens,
    userAgent: 'Tinglang/0.4.0 (macos)',
  );

  test('meta needs no token and parses the contract example', () async {
    server.handler = (_) => Reply.json(example('getMeta/response.200.json'));
    final meta = await api().getMeta();
    expect(meta.auth!.redirectUri.scheme, 'tinglang');
    final seen = server.requests.single;
    expect(seen.uri.path, '/v1/meta');
    expect(seen.header('authorization'), isNull);
    expect(seen.header('user-agent'), 'Tinglang/0.4.0 (macos)');
  });

  test('authenticated calls without a session send nothing', () async {
    await expectLater(
      api().getAccount(),
      throwsA(isA<AuthFailure>().having((e) => e.reason, 'reason', AuthFailureReason.signedOut)),
    );
    expect(server.requests, isEmpty);
  });

  test('a 401 is retried once with a fresh token', () async {
    server.handler = (r) => r.header('authorization') == 'Bearer stale'
        ? Reply.problem(example('getAccount/response.401.json'))
        : Reply.json(example('getEntitlements/response.200.json'));
    final tokens = _Tokens(['stale', 'fresh']);
    final ent = await api(tokens: tokens).getEntitlements();
    expect(ent.plan, 'pro');
    expect(tokens.forced, [false, true]);
    expect(server.requests.map((r) => r.header('authorization')), ['Bearer stale', 'Bearer fresh']);
  });

  test('problems keep their code and Retry-After', () async {
    server.handler = (_) => Reply.problem(
      {'status': 429, 'code': 'rate_limited', 'title': 'Slow down'},
      headers: {'Retry-After': '7'},
    );
    await expectLater(
      api(tokens: _Tokens(['t'])).listJobs(),
      throwsA(
        isA<ApiProblemException>()
            .having((e) => e.code, 'code', ProblemCode.rateLimited)
            .having((e) => e.retryAfter, 'retryAfter', const Duration(seconds: 7)),
      ),
    );
  });

  test('an error without a problem body still maps by status', () async {
    server.handler = (_) => const Reply(503, '<html>down</html>', {}, 'text/html');
    await expectLater(
      api().getMeta(),
      throwsA(
        isA<ApiProblemException>().having((e) => e.code, 'code', ProblemCode.serverUnavailable),
      ),
    );
  });

  test('a server that is not there is reported as unreachable', () async {
    final port = await deadPort();
    final client = TinglangApi(ServerUrl.parse('http://127.0.0.1:$port'));
    await expectLater(client.getMeta(), throwsA(isA<ApiUnreachable>()));
  });

  test('a non-JSON success is a bad response, not a crash', () async {
    server.handler = (_) => const Reply(200, 'hello', {}, 'text/plain');
    await expectLater(api().getMeta(), throwsA(isA<ApiBadResponse>()));
  });

  test('creating a job sends the Idempotency-Key and the request body', () async {
    server.handler = (_) => Reply.json(example('createJob/response.201.json'), status: 201);
    final request = JobCreateRequest.fromJson(example('createJob/request.json'));
    final job = await api(tokens: _Tokens(['t'])).createJob(request, idempotencyKey: 'k' * 24);
    expect(job.knownStatus, JobStatus.awaitingUpload);
    final seen = server.requests.single;
    expect(seen.method, 'POST');
    expect(seen.uri.path, '/v1/jobs');
    expect(seen.header('idempotency-key'), 'k' * 24);
    expect(jsonDecode(seen.body), example('createJob/request.json'));
  });

  test('polling returns the suggested wait', () async {
    server.handler = (_) =>
        Reply.json(example('getJob/response.200.json'), headers: {'Retry-After': '5'});
    final (job, wait) = await api(tokens: _Tokens(['t'])).getJob('job_01HZXA3M0F6R');
    expect(job.progress!.fraction, 0.4);
    expect(wait, const Duration(seconds: 5));
    expect(server.requests.single.uri.path, '/v1/jobs/job_01HZXA3M0F6R');
  });

  test('cursor pagination passes the cursor and limit', () async {
    server.handler = (_) => Reply.json(example('listJobs/response.200.next.json'));
    final page = await api(tokens: _Tokens(['t'])).listJobs(cursor: 'c_1', limit: 50);
    expect(page.nextCursor, 'c_2');
    expect(server.requests.single.uri.queryParameters, {'cursor': 'c_1', 'limit': '50'});
  });

  group('uploads', () {
    UploadTarget target(String url, {int max = 100}) => UploadTarget(
      name: 'media',
      url: Uri.parse(url),
      method: 'PUT',
      headers: const {'content-type': 'audio/mp4'},
      expiresAt: DateTime.utc(2030),
      maxBytes: max,
    );

    test('go to the presigned URL without the account token', () async {
      server.handler = (_) => const Reply(200);
      final tokens = _Tokens(['secret']);
      await api(tokens: tokens).upload(
        target('${server.origin}/storage/upload?sig=1'),
        Stream.value(utf8.encode('audio')),
        5,
      );
      final seen = server.requests.single;
      expect(seen.method, 'PUT');
      expect(seen.uri.path, '/storage/upload');
      expect(seen.header('authorization'), isNull);
      expect(seen.header('content-type'), 'audio/mp4');
      expect(seen.body, 'audio');
      expect(tokens.forced, isEmpty);
    });

    test('are refused when too large or not over https', () async {
      await expectLater(
        api().upload(target('${server.origin}/u', max: 4), Stream.value([1, 2, 3, 4, 5]), 5),
        throwsA(
          isA<ApiProblemException>().having((e) => e.code, 'code', ProblemCode.uploadTooLarge),
        ),
      );
      await expectLater(
        api().upload(target('http://storage.example.com/u'), Stream.value([1]), 1),
        throwsA(isA<ServerUrlException>()),
      );
      expect(server.requests, isEmpty);
    });
  });

  group('server addresses', () {
    test('https is required except on this machine', () {
      expect(ServerUrl.parse('api.example.com').toString(), 'https://api.example.com');
      expect(ServerUrl.parse('https://api.example.com/v1/').toString(), 'https://api.example.com');
      expect(
        ServerUrl.parse('https://example.com/tinglang/').api('/meta').toString(),
        'https://example.com/tinglang/v1/meta',
      );
      expect(ServerUrl.parse('http://localhost:8787').host, 'localhost');
      expect(
        ServerUrl.parse('http://127.0.0.1:8787').api('/meta').toString(),
        'http://127.0.0.1:8787/v1/meta',
      );
      for (final bad in [
        'http://api.example.com',
        'ftp://api.example.com',
        'https://user:pw@api.example.com',
        'https://api.example.com/?x=1',
        '',
        'https://',
      ]) {
        expect(() => ServerUrl.parse(bad), throwsA(isA<ServerUrlException>()), reason: bad);
      }
    });
  });
}

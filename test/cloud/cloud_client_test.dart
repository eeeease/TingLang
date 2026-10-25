import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tinglang/services/cloud/cloud_services.dart';
import 'package:tinglang_platform_interface/tinglang_platform_interface.dart';
import 'package:tinglang_platform_interface/testing.dart';
import 'package:tinglang_api/tinglang_api.dart';

import 'cloud_fakes.dart';

void main() {
  late LocalServer server;
  late InMemorySecretStore secrets;
  late FakeWebAuthenticator browser;
  late CloudClient client;

  /// The contract's meta, with every endpoint on the local server.
  ApiMeta meta() {
    final json = contractExample('getMeta/response.200.json');
    final auth = json['auth']! as Map<String, Object?>;
    auth['issuer'] = '${server.origin}/auth/v1';
    auth['authorization_endpoint'] = '${server.origin}/auth/v1/oauth/authorize';
    auth['token_endpoint'] = '${server.origin}/auth/v1/oauth/token';
    auth['revocation_endpoint'] = '${server.origin}/v1/auth/revoke';
    return ApiMeta.fromJson(json);
  }

  setUp(() async {
    server = await LocalServer.start();
    secrets = InMemorySecretStore();
    browser = FakeWebAuthenticator((url) {
      final state = url.queryParameters['state']!;
      return Uri.parse('tinglang://oauth/callback?code=code-1&state=$state');
    });
    client = CloudClient(
      ServerUrl.parse(server.origin),
      secrets: secrets,
      browser: browser,
      userAgent: 'Tinglang/0.4.0 (macos)',
    );
    server.handler = (r) => switch ((r.method, r.uri.path)) {
      ('GET', '/v1/meta') => (200, meta().toJson()),
      ('POST', '/auth/v1/oauth/token') => (
        200,
        {
          'access_token': 'access-${Uri.splitQueryString(r.body)['grant_type']}',
          'token_type': 'bearer',
          'expires_in': 3600,
          'refresh_token': 'refresh-1',
        },
      ),
      ('GET', '/v1/account') => (200, contractExample('getAccount/response.200.json')),
      ('GET', '/v1/entitlements') => (200, contractExample('getEntitlements/response.200.json')),
      ('POST', '/v1/auth/revoke') => (200, null),
      _ => (404, {'status': 404, 'code': 'not_found'}),
    };
  });
  tearDown(() => server.close());

  test('creating the client and checking for a session send nothing', () async {
    expect(await client.hasSession(), isFalse);
    expect(server.requests, isEmpty);
  });

  test('sign-in goes through the browser session and keeps only the refresh token', () async {
    await client.signIn(meta());
    expect(browser.schemes, ['tinglang']);
    expect(browser.opened.single.path, '/auth/v1/oauth/authorize');
    expect(await secrets.read('account:${server.origin}'), 'refresh-1');
    expect(await client.hasSession(), isTrue);

    final account = await client.fetchAccount(meta());
    expect(account.email, 'learner@example.com');
    final call = server.requests.last;
    expect(call.header('authorization'), 'Bearer access-authorization_code');
    expect(call.header('user-agent'), 'Tinglang/0.4.0 (macos)');
  });

  test('closing the sign-in window stores nothing', () async {
    browser.respond = (_) => throw const WebAuthCanceled();
    await expectLater(
      client.signIn(meta()),
      throwsA(isA<AuthFailure>().having((e) => e.reason, 'reason', AuthFailureReason.canceled)),
    );
    expect(await client.hasSession(), isFalse);
    expect(server.requests, isEmpty);
  });

  test('without a browser session or secure storage, sign-in is refused up front', () async {
    final noBrowser = CloudClient(ServerUrl.parse(server.origin), secrets: secrets, browser: null);
    await expectLater(noBrowser.signIn(meta()), throwsA(isA<CloudUnsupported>()));
    final noStore = CloudClient(ServerUrl.parse(server.origin), secrets: null, browser: browser);
    await expectLater(noStore.signIn(meta()), throwsA(isA<CloudUnsupported>()));
    expect(server.requests, isEmpty);
  });

  test('signing out revokes on the server and removes the Keychain entry', () async {
    await client.signIn(meta());
    await client.signOut(meta());
    final revoke = server.requests.last;
    expect(revoke.uri.path, '/v1/auth/revoke');
    expect(Uri.splitQueryString(revoke.body)['token'], 'refresh-1');
    expect(await secrets.read('account:${server.origin}'), isNull);
  });

  test('a cloud job: create, upload, start, poll, result', () async {
    final dir = await Directory.systemTemp.createTemp('tinglang-job-');
    addTearDown(() => dir.delete(recursive: true));
    final media = File('${dir.path}/memo.m4a')..writeAsBytesSync(utf8.encode('fake audio'));
    final created = contractExample('createJob/response.201.json');
    (((created['uploads']! as List<Object?>).single! as Map<String, Object?>))['url'] =
        '${server.origin}/storage/upload?token=example';
    var polls = 0;
    final succeeded =
        (contractExample('listJobs/response.200.json')['items']! as List<Object?>).single;
    server.handler = (r) => switch ((r.method, r.uri.path)) {
      ('POST', '/auth/v1/oauth/token') => (
        200,
        {'access_token': 'a', 'token_type': 'bearer', 'expires_in': 3600, 'refresh_token': 'r'},
      ),
      ('POST', '/v1/jobs') => (201, created),
      ('PUT', '/storage/upload') => (200, null),
      ('POST', '/v1/jobs/job_01HZXA3M0F6R/start') => (
        202,
        contractExample('startJob/response.202.json'),
      ),
      // Running first, then the succeeded job from the list example.
      ('GET', '/v1/jobs/job_01HZXA3M0F6R') => (
        200,
        ++polls == 1 ? contractExample('getJob/response.200.json') : succeeded,
      ),
      ('GET', '/v1/jobs/job_01HZXA3M0F6R/result') => (
        200,
        contractExample('getJobResult/response.200.json'),
      ),
      _ => (404, {'status': 404, 'code': 'not_found'}),
    };
    await client.signIn(meta());
    final request = JobCreateRequest.fromJson(contractExample('createJob/request.json'));
    final job = await client.create(meta(), request, idempotencyKey: 'k' * 32);
    expect(job.knownStatus, JobStatus.awaitingUpload);
    await client.upload(meta(), job.uploads!.single, media);
    final upload = server.requests.firstWhere((r) => r.uri.path == '/storage/upload');
    expect(upload.body, 'fake audio');
    expect(upload.header('authorization'), isNull);
    expect((await client.start(meta(), job.id)).knownStatus, JobStatus.queued);
    expect((await client.poll(meta(), job.id)).$1.knownStatus, JobStatus.running);
    expect((await client.poll(meta(), job.id)).$1.knownStatus, JobStatus.succeeded);
    final result = await client.result(meta(), job.id);
    final lines = result.transcript!['lines']! as List<Object?>;
    expect((lines.first! as Map<String, Object?>)['text'], 'Small reps add up to real progress.');
  });

  test('the in-memory job service follows the same states', () async {
    final jobs = FakeCloudJobService();
    final request = JobCreateRequest.fromJson(contractExample('createJob/request.json'));
    final job = await jobs.create(meta(), request, idempotencyKey: 'same-key-for-both');
    expect(await jobs.create(meta(), request, idempotencyKey: 'same-key-for-both'), same(job));
    await jobs.start(meta(), job.id);
    expect((await jobs.poll(meta(), job.id)).$1.knownStatus, JobStatus.running);
    final (done, wait) = await jobs.poll(meta(), job.id);
    expect(done.knownStatus, JobStatus.succeeded);
    expect(wait, isNull);
  });
}

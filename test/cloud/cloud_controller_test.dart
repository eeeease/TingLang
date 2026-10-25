import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tinglang/core/library_store.dart';
import 'package:tinglang/services/app_controller.dart';
import 'package:tinglang/services/cloud/cloud_controller.dart';
import 'package:tinglang/services/cloud/cloud_services.dart';
import 'package:tinglang_api/tinglang_api.dart';

import 'cloud_fakes.dart';

void main() {
  late Directory dir;
  late AppController app;
  late List<FakeAccountService> connected;
  var now = DateTime.utc(2026, 10, 23, 9);

  CloudController controller({String? official, String version = '0.4.0'}) => CloudController(
    app: app,
    clientVersion: version,
    officialServer: official,
    now: () => now,
    connect: (server) {
      final service = FakeAccountService(server);
      connected.add(service);
      return service;
    },
  );

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('tinglang-cloud-');
    app = AppController(LibraryStore(dir), LibraryState());
    connected = [];
    now = DateTime.utc(2026, 10, 23, 9);
  });
  tearDown(() async {
    app.dispose();
    await dir.delete(recursive: true);
  });

  test('without a server address there is no account and nothing to contact', () async {
    final cloud = controller();
    expect(cloud.server, isNull);
    await cloud.signIn();
    await cloud.refresh();
    expect(connected, isEmpty);
    expect(cloud.features.accounts, isFalse);
  });

  test('the official server is api.tinglang.app', () {
    expect(CloudController.official, 'https://api.tinglang.app');
    expect(controller(official: CloudController.official).server!.host, 'api.tinglang.app');
  });

  test('a session on a server typed in an earlier build is forgotten, contacting nobody', () async {
    await app.setSettings({
      CloudController.legacyServerKey: 'https://dev.example.com',
      CloudController.signedInKey: 'true',
      CloudController.accountKey: '{"id":"x"}',
    });
    final cloud = controller(official: 'https://api.tinglang.example');
    await cloud.forgetLegacyServer();
    expect(cloud.signedIn, isFalse);
    expect(app.setting(CloudController.legacyServerKey, ''), isEmpty);
    expect(connected, isEmpty);
    await cloud.forgetLegacyServer(); // nothing left: no change
    expect(cloud.signedIn, isFalse);
  });

  test('signing in loads the offer, the account and the plan, and caches them', () async {
    final cloud = controller(official: 'https://api.tinglang.example');
    await cloud.signIn();
    expect(cloud.error, isNull);
    expect(connected.single.calls, ['meta', 'signIn', 'account', 'entitlements']);
    expect(cloud.signedIn, isTrue);
    expect(cloud.account!.email, 'learner@example.com');
    expect(cloud.entitlements!.plan, 'pro');
    expect(cloud.offers('llm_gateway'), isTrue);
    expect(cloud.offers('jobs.course'), isFalse);

    // A restart reads the cache; nothing is fetched until the user asks.
    final again = controller(official: 'https://api.tinglang.example');
    connected.clear();
    expect(again.signedIn, isTrue);
    expect(again.account!.id, 'acct_01HZX4Q8W2K7');
    expect(again.offers('jobs.transcribe'), isTrue);
    expect(connected, isEmpty);
  });

  test('a client older than the server allows is not signed in', () async {
    final cloud = controller(official: 'https://api.tinglang.example', version: '0.3.0');
    await cloud.signIn();
    expect(cloud.signedIn, isFalse);
    expect(
      cloud.error,
      isA<ApiProblemException>().having((e) => e.code, 'code', ProblemCode.clientTooOld),
    );
    expect(connected.single.calls, ['meta']);
  });

  test('a server without accounts says so', () async {
    final cloud = CloudController(
      app: app,
      clientVersion: '0.4.0',
      officialServer: 'https://api.tinglang.example',
      connect: (server) =>
          FakeAccountService(server)
            ..meta = ApiMeta.fromJson(contractExample('getMeta/response.200.minimal.json')),
    );
    await cloud.signIn();
    expect(cloud.signedIn, isFalse);
    expect(
      cloud.error,
      isA<CloudUnsupported>().having((e) => e.reason, 'reason', CloudUnsupportedReason.noAccounts),
    );
  });

  test('closing the sign-in window leaves the app signed out', () async {
    final cloud = CloudController(
      app: app,
      clientVersion: '0.4.0',
      officialServer: 'https://api.tinglang.example',
      connect: (server) =>
          FakeAccountService(server)
            ..signInFailure = const AuthFailure('closed', reason: AuthFailureReason.canceled),
    );
    await cloud.signIn();
    expect(cloud.signedIn, isFalse);
    expect(cloud.error, isA<AuthFailure>());
  });

  test('offline, the cached plan stays visible until its grace period ends', () async {
    final cloud = controller(official: 'https://api.tinglang.example');
    await cloud.signIn();
    connected.single.failure = const ApiUnreachable('Cannot reach api.tinglang.example');
    await cloud.refresh();
    expect(cloud.offline, isTrue);
    expect(cloud.error, isA<ApiUnreachable>());
    expect(cloud.signedIn, isTrue);
    expect(cloud.account!.email, 'learner@example.com');
    expect(cloud.planConfirmed, isTrue, reason: 'grace_until is 2026-10-30');
    now = DateTime.utc(2026, 10, 31);
    expect(cloud.planConfirmed, isFalse);
  });

  test('a session that ended on the server signs out here too', () async {
    final cloud = controller(official: 'https://api.tinglang.example');
    await cloud.signIn();
    connected.single.failure = const AuthFailure('gone', reason: AuthFailureReason.invalidGrant);
    await cloud.refresh();
    expect(cloud.signedIn, isFalse);
    expect(cloud.account, isNull);
  });

  test('signing out always forgets the account', () async {
    final cloud = controller(official: 'https://api.tinglang.example');
    await cloud.signIn();
    await cloud.signOut();
    expect(cloud.signedIn, isFalse);
    expect(cloud.account, isNull);
    expect(connected.single.calls.last, 'signOut');
  });
}

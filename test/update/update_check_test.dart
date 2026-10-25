// The fake GitHub API is a loopback server; nothing leaves this machine.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tinglang/services/app_controller.dart';
import 'package:tinglang/services/update_service.dart';

import '../cloud/cloud_fakes.dart' show NoNetwork;
import 'update_fakes.dart';

void main() {
  late FakeGitHub github;
  late AppController app;
  late FakeTimers timers;
  var now = DateTime.utc(2026, 10, 25, 9);

  setUp(() async {
    github = FakeGitHub();
    await github.start();
    app = memoryApp();
    timers = FakeTimers();
    now = DateTime.utc(2026, 10, 25, 9);
  });
  tearDown(() => github.close());

  UpdateService service({
    String version = '0.4.0',
    UpdateEndpoints? endpoints,
    HttpClient Function()? httpClient,
  }) {
    final updates = UpdateService(
      app: app,
      appVersion: version,
      endpoints: endpoints ?? github.endpoints,
      httpClient: httpClient,
      clock: () => now,
      timer: timers.call,
    );
    addTearDown(updates.dispose);
    return updates;
  }

  group('a check', () {
    test('finds a newer release and remembers it', () async {
      github.release = github.releaseJson('0.10.0');
      final updates = service(version: '0.9.0');
      await updates.checkNow();
      expect(updates.available?.version, ReleaseVersion.tryParse('0.10.0'));
      expect(updates.lastResult, UpdateCheckResult.available);
      expect(updates.showBanner, isTrue);
      expect(updates.stage, UpdateStage.idle);
      expect(updates.lastCheck, now);
      expect(app.setting(UpdateService.releaseKey, ''), contains('0.10.0'));

      // After a restart the banner comes back from the cache, without asking.
      github.requests.clear();
      final again = service(version: '0.9.0');
      expect(again.available?.version, ReleaseVersion.tryParse('0.10.0'));
      expect(again.lastResult, isNull);
      expect(github.requests, isEmpty);
    });

    test('asks GitHub the documented way and sends nothing about the user', () async {
      github.release = github.releaseJson('0.5.0');
      await service().checkNow();
      expect(github.paths, [FakeGitHub.latestPath]);
      final headers = github.requests.single.headers;
      expect(headers.value(HttpHeaders.acceptHeader), 'application/vnd.github+json');
      expect(headers.value(HttpHeaders.userAgentHeader), 'Tinglang/0.4.0 (macos)');
      expect(headers.value(HttpHeaders.cookieHeader), isNull);
      expect(headers.value(HttpHeaders.authorizationHeader), isNull);
      expect(github.requests.single.headers.value('x-github-api-version'), '2022-11-28');
    });

    test('the same or an older version is up to date and clears the cache', () async {
      app = memoryApp({
        UpdateService.releaseKey: jsonEncode(
          UpdateRelease.fromGitHub(github.releaseJson('0.5.0'), github.endpoints)!.toJson(),
        ),
      });
      github.release = github.releaseJson('0.4.0');
      final updates = service(version: '0.5.0');
      await updates.checkNow();
      expect(updates.available, isNull);
      expect(updates.lastResult, UpdateCheckResult.upToDate);
      expect(app.setting(UpdateService.releaseKey, 'x'), '');

      github.release = github.releaseJson('0.3.9');
      await updates.checkNow();
      expect(updates.lastResult, UpdateCheckResult.upToDate);
      expect(updates.showBanner, isFalse);
    });

    test('a private repository, a rate limit or a server error is silently nothing', () async {
      for (final status in [404, 403, 429, 500, 502]) {
        github
          ..releaseStatus = status
          ..release = {'message': 'Not Found'};
        final updates = service();
        await updates.checkNow();
        expect(updates.available, isNull, reason: '$status');
        expect(updates.lastResult, UpdateCheckResult.unknown, reason: '$status');
        expect(updates.stage, UpdateStage.idle);
        expect(updates.failure, isNull);
        expect(updates.showBanner, isFalse);
        // It still counts as a check, so a private repository is not asked
        // again before the day is over.
        expect(updates.lastCheck, now);
      }
    });

    test('an answer that is not a usable release is nothing too', () async {
      final answers = <Object?>[
        github.releaseJson('0.5.0', prerelease: true),
        github.releaseJson('0.5.0', draft: true),
        github.releaseJson('0.5.0', withChecksum: false),
        github.releaseJson('0.5.0', archiveUrl: 'https://evil.example/Tinglang-0.5.0-macOS.zip'),
        {'tag_name': 'v0.5.0'},
        [1, 2, 3],
      ];
      for (final answer in answers) {
        github.release = answer;
        final updates = service();
        await updates.checkNow();
        expect(updates.available, isNull, reason: '$answer');
        expect(updates.lastResult, UpdateCheckResult.unknown);
      }
      github.releaseBody = '{"tag_name": "v0.5.0", ';
      final updates = service();
      await updates.checkNow();
      expect(updates.lastResult, UpdateCheckResult.unknown);
      expect(updates.failure, isNull);
    });

    test('no connection is nothing as well, and keeps an update found earlier', () async {
      final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final dead = socket.port;
      await socket.close();
      final endpoints = UpdateEndpoints(
        latestRelease: Uri.parse('http://127.0.0.1:$dead${FakeGitHub.latestPath}'),
        allowLoopback: true,
      );
      final known = UpdateRelease.fromGitHub(github.releaseJson('0.5.0'), github.endpoints)!;
      app = memoryApp({UpdateService.releaseKey: jsonEncode(known.toJson())});
      final updates = service(endpoints: endpoints);
      await updates.checkNow();
      expect(updates.lastResult, UpdateCheckResult.unknown);
      expect(updates.failure, isNull);
      expect(updates.available?.version, known.version);
    });

    test('a redirect away from api.github.com is not followed', () async {
      github.redirects[FakeGitHub.latestPath] = 'http://localhost:${github.port}/elsewhere';
      final updates = service();
      await updates.checkNow();
      expect(updates.lastResult, UpdateCheckResult.unknown);
      expect(github.paths, [FakeGitHub.latestPath]);
    });

    test('the real endpoint is https on api.github.com, so loopback is refused there', () async {
      // Without the test switch the loopback server does not count as GitHub.
      final network = NoNetwork();
      await HttpOverrides.runZoned(() async {
        final updates = service(
          endpoints: UpdateEndpoints(latestRelease: Uri.parse(github.url(FakeGitHub.latestPath))),
        );
        await updates.checkNow();
        expect(updates.lastResult, UpdateCheckResult.unknown);
      }, createHttpClient: network.createHttpClient);
      expect(network.created, isEmpty);
      expect(github.requests, isEmpty);
    });
  });

  group('automatic checks', () {
    test('wait a while after launch, then come once a day', () async {
      github.release = github.releaseJson('0.4.0');
      final updates = service()..start();
      expect(github.requests, isEmpty, reason: 'nothing at startup');
      expect(timers.active.single.delay, updates.startDelay);
      expect(updates.startDelay, greaterThanOrEqualTo(const Duration(seconds: 30)));

      timers.fire();
      await _until(() => !updates.checking);
      expect(github.requests, hasLength(1));
      expect(updates.lastResult, UpdateCheckResult.upToDate);
      expect(timers.active.single.delay, const Duration(hours: 24));
    });

    test('a check earlier today is not repeated before the day is over', () async {
      app = memoryApp({
        UpdateService.lastCheckKey: now.subtract(const Duration(hours: 3)).toIso8601String(),
      });
      service().start();
      expect(timers.active.single.delay, const Duration(hours: 21));
      expect(github.requests, isEmpty);
    });

    test('a check long ago still waits for the start delay', () async {
      app = memoryApp({
        UpdateService.lastCheckKey: now.subtract(const Duration(days: 30)).toIso8601String(),
      });
      final updates = service()..start();
      expect(timers.active.single.delay, updates.startDelay);
    });

    test('a failed save does not turn into a request loop', () async {
      app = AppController(_FailingStore(), memoryApp().state);
      github.release = github.releaseJson('0.4.0');
      final updates = service()..start();
      timers.fire();
      await _until(() => !updates.checking);
      expect(github.requests, hasLength(1));
      expect(updates.lastCheck, isNull, reason: 'the save failed');
      expect(timers.active.single.delay, const Duration(hours: 24));
    });

    test('with the setting off nothing is sent and no HttpClient is made', () async {
      final network = NoNetwork();
      app = memoryApp({UpdateService.autoCheckKey: 'false'});
      await HttpOverrides.runZoned(() async {
        final updates = service()..start();
        expect(updates.autoCheck, isFalse);
        expect(timers.active, isEmpty);
        // Unrelated settings changes do not schedule anything either.
        await app.setSetting(AppController.themeKey, 'dark');
        expect(timers.active, isEmpty);
      }, createHttpClient: network.createHttpClient);
      expect(network.created, isEmpty);
      expect(github.requests, isEmpty);
    });

    test(
      'turning it off cancels the pending check; on schedules one; Check now always asks',
      () async {
        github.release = github.releaseJson('0.5.0');
        final updates = service()..start();
        final first = timers.active.single;
        await updates.setAutoCheck(false);
        expect(first.isActive, isFalse);
        expect(timers.active, isEmpty);
        expect(app.setting(UpdateService.autoCheckKey, ''), 'false');

        await updates.checkNow();
        expect(github.requests, hasLength(1));
        expect(updates.available, isNotNull);
        expect(timers.active, isEmpty, reason: 'still off');

        await updates.setAutoCheck(true);
        expect(timers.active.single.delay, const Duration(hours: 24));
      },
    );

    test('a check due during a download waits instead of spinning', () async {
      final updates = _Downloading(app, github.endpoints, timers, () => now)..start();
      addTearDown(updates.dispose);
      now = now.add(const Duration(minutes: 5));
      timers.fire();
      expect(github.requests, isEmpty);
      expect(timers.active.single.delay, updates.startDelay);
    });

    test('dispose cancels the pending check', () {
      final updates = UpdateService(
        app: app,
        appVersion: '0.4.0',
        endpoints: github.endpoints,
        clock: () => now,
        timer: timers.call,
      )..start();
      final pending = timers.active.single;
      updates.dispose();
      expect(pending.isActive, isFalse);
    });

    test('a dismissed update stays hidden until a newer one', () async {
      github.release = github.releaseJson('0.5.0');
      final updates = service();
      await updates.checkNow();
      expect(updates.showBanner, isTrue);
      updates.dismiss();
      expect(updates.showBanner, isFalse);
      expect(updates.available, isNotNull, reason: 'Settings still offers it');
      github.release = github.releaseJson('0.6.0');
      await updates.checkNow();
      expect(updates.showBanner, isTrue);
    });
  });
}

/// An update download that is under way.
final class _Downloading extends UpdateService {
  _Downloading(
    AppController app,
    UpdateEndpoints endpoints,
    FakeTimers timers,
    DateTime Function() clock,
  ) : super(app: app, appVersion: '0.4.0', endpoints: endpoints, timer: timers.call, clock: clock);

  @override
  UpdateStage get stage => UpdateStage.downloading;
}

/// Every save fails, as with a full disk.
final class _FailingStore extends MemoryStore {
  @override
  Future<void> save(_) async => throw const FileSystemException('disk full');
}

Future<void> _until(bool Function() done) async {
  for (var i = 0; i < 200 && !done(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  expect(done(), isTrue, reason: 'did not happen in time');
}

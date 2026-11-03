import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinglang/core/library_store.dart';
import 'package:tinglang/services/app_controller.dart';
import 'package:tinglang/services/official_library.dart';
import 'package:tinglang_api/tinglang_api.dart';

void main() {
  late Directory dir;
  late AppController app;
  late HttpServer server;
  late String base;
  late Map<String, Object?> course;
  late List<String> requests;
  late List<String?> tokensSeen;
  var version = 'v1';
  var foreignCover = false;
  final jpeg = [0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3, 4];

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('tinglang-official-');
    app = AppController(LibraryStore(dir), LibraryState());
    course = jsonDecode(
      File('api/examples/getLibraryCourse/response.200.json').readAsStringSync(),
    ) as Map<String, Object?>;
    requests = [];
    tokensSeen = [];
    version = 'v1';
    foreignCover = false;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    base = 'http://127.0.0.1:${server.port}';
    server.listen((request) async {
      requests.add(request.uri.path);
      final authorization = request.headers.value(HttpHeaders.authorizationHeader);
      tokensSeen.add(authorization);
      final response = request.response;
      final id = course['podcast_id'];
      switch (request.uri.path) {
        case '/v1/library':
          response.headers.contentType = ContentType.json;
          response.write(
            jsonEncode({
              if (authorization == null) 'preview': true,
              'course_count': 40,
              'courses': [
                {
                  'id': id,
                  'title': course['title'],
                  'area': 'podcasts',
                  'source_label': 'Demo · YouTube',
                  'cover_url': foreignCover
                      ? 'https://example.com/cover.jpg'
                      : '$base/v1/library/$id/cover.jpg',
                  'clip_count': (course['clips']! as List).length,
                  'version': version,
                },
              ],
            }),
          );
        case final path when path == '/v1/library/$id':
          response.headers.contentType = ContentType.json;
          response.write(jsonEncode(course));
        case final path when path == '/v1/library/$id/cover.jpg':
          response.add(jpeg);
        default:
          response.statusCode = 404;
      }
      await response.close();
    });
  });
  tearDown(() async {
    await server.close(force: true);
    app.dispose();
    await dir.delete(recursive: true);
  });

  OfficialLibraryService service() =>
      OfficialLibraryService(app: app, api: () => TinglangApi(ServerUrl.parse(base)));

  test('nothing is asked until the library is opened', () {
    service();
    expect(requests, isEmpty);
  });

  test('a course is added with its cover; a newer version is offered as an update', () async {
    final official = service();
    await official.load();
    final entry = official.library!.courses.single;
    expect(official.added(entry), isFalse);
    expect(official.coverFor(entry.id), isNull);

    final added = await official.add(entry);
    expect(added.id, entry.id);
    expect(app.state.courses.single.sourceLabel, 'Demo · YouTube');
    expect(official.coverFor(entry.id)!.readAsBytesSync(), jpeg);
    expect(official.added(entry), isTrue);
    expect(official.updatable(entry), isFalse);

    version = 'v2';
    await official.load(force: true);
    expect(official.updatable(official.library!.courses.single), isTrue);
    await official.add(official.library!.courses.single);
    expect(official.updatable(official.library!.courses.single), isFalse);
    expect(app.state.courses, hasLength(1), reason: 'an update replaces the course');
  });

  test('covers come only from the library server', () async {
    foreignCover = true;
    final official = service();
    await official.load();
    final entry = official.library!.courses.single;
    await official.add(entry);
    expect(official.coverFor(entry.id), isNull);
    expect(requests.where((r) => r.endsWith('cover.jpg')), isEmpty);
  });

  test('signed out it is the preview; signing in or out asks an opened library again', () async {
    final account = _Account();
    final official = OfficialLibraryService(
      app: app,
      account: account,
      api: () =>
          TinglangApi(ServerUrl.parse(base), tokens: account.signedIn ? const _Tokens() : null),
    );
    addTearDown(official.dispose);
    // Not opened yet: signing in asks nothing.
    await account.signIn();
    await account.signOut();
    expect(requests, isEmpty);

    await official.load();
    expect(official.library!.preview, isTrue);
    expect(official.library!.courseCount, 40);

    await official.signIn();
    await _settle(official);
    expect(official.library!.preview, isFalse);
    expect(tokensSeen, [null, 'Bearer access-1']);

    await account.signOut();
    await _settle(official);
    expect(official.library!.preview, isTrue);
    expect(tokensSeen.last, isNull);
  });

  test('a failed sign-in from the library is reported', () async {
    final account = _Account()..failure = const AuthFailure('Sign-in canceled');
    final official = OfficialLibraryService(
      app: app,
      account: account,
      api: () => TinglangApi(ServerUrl.parse(base)),
    );
    addTearDown(official.dispose);
    await expectLater(official.signIn(), throwsA(isA<AuthFailure>()));
  });

  test('an unreachable server is an error to show, not a crash', () async {
    await server.close(force: true);
    final official = service();
    await official.load();
    expect(official.library, isNull);
    expect(official.error, isNotNull);
  });
}

/// Waits for a reload started by a sign-in change.
Future<void> _settle(OfficialLibraryService official) async {
  for (var i = 0; i < 200; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
    if (!official.loading) return;
  }
}

final class _Account extends ChangeNotifier implements LibraryAccount {
  @override
  bool signedIn = false;
  @override
  Object? error;
  Object? failure;

  @override
  Future<void> signIn() async {
    error = failure;
    signedIn = failure == null;
    notifyListeners();
  }

  Future<void> signOut() async {
    signedIn = false;
    notifyListeners();
  }
}

final class _Tokens implements TokenSource {
  const _Tokens();
  @override
  Future<String> accessToken({bool force = false}) async => 'access-1';
}

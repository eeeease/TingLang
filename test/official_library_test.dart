import 'dart:convert';
import 'dart:io';

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
    version = 'v1';
    foreignCover = false;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    base = 'http://127.0.0.1:${server.port}';
    server.listen((request) async {
      requests.add(request.uri.path);
      final response = request.response;
      final id = course['podcast_id'];
      switch (request.uri.path) {
        case '/v1/library':
          response.headers.contentType = ContentType.json;
          response.write(
            jsonEncode({
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

  test('an unreachable server is an error to show, not a crash', () async {
    await server.close(force: true);
    final official = service();
    await official.load();
    expect(official.library, isNull);
    expect(official.error, isNotNull);
  });
}

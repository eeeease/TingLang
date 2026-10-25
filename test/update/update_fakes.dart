import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:tinglang/core/library_store.dart';
import 'package:tinglang/services/app_controller.dart';
import 'package:tinglang/services/update_service.dart';

/// A library store that keeps nothing on disk.
class MemoryStore extends LibraryStore {
  MemoryStore() : super(Directory.systemTemp);
  int saves = 0;

  @override
  Future<void> save(LibraryState state) async => saves++;
}

AppController memoryApp([Map<String, String> settings = const {}]) =>
    AppController(MemoryStore(), LibraryState(settings: {...settings}));

/// Timers that fire only when a test says so.
final class FakeTimers {
  final timers = <FakeTimer>[];

  Timer call(Duration delay, void Function() callback) {
    final timer = FakeTimer(delay, callback);
    timers.add(timer);
    return timer;
  }

  List<FakeTimer> get active => [
    for (final t in timers)
      if (t.isActive) t,
  ];

  /// Fires the one active timer.
  void fire() {
    final pending = active;
    if (pending.length != 1) throw StateError('${pending.length} active timers');
    pending.single.fire();
  }
}

final class FakeTimer implements Timer {
  FakeTimer(this.delay, this._callback);
  final Duration delay;
  final void Function() _callback;
  bool cancelled = false, fired = false;

  void fire() {
    fired = true;
    _callback();
  }

  @override
  void cancel() => cancelled = true;

  @override
  bool get isActive => !cancelled && !fired;

  @override
  int get tick => fired ? 1 : 0;
}

typedef SeenRequest = ({String path, HttpHeaders headers});

/// Stands in for api.github.com and the release downloads on 127.0.0.1.
final class FakeGitHub {
  late final HttpServer _http;
  final requests = <SeenRequest>[];

  /// The answer to the latest-release request.
  Object? release;
  int releaseStatus = HttpStatus.ok;
  String? releaseBody;

  /// Download paths → bytes.
  final files = <String, List<int>>{};
  final redirects = <String, String>{};

  /// Pause between 16 KiB chunks of a download.
  Duration chunkDelay = Duration.zero;

  static const latestPath = '/repos/eeeease/TingLang/releases/latest';

  Future<void> start() async {
    _http = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _http.listen((request) => _handle(request).catchError((Object _) {}));
  }

  Future<void> close() => _http.close(force: true);

  int get port => _http.port;
  String url(String path) => 'http://127.0.0.1:$port$path';

  UpdateEndpoints get endpoints =>
      UpdateEndpoints(latestRelease: Uri.parse(url(latestPath)), allowLoopback: true);

  List<String> get paths => [for (final r in requests) r.path];

  Future<void> _handle(HttpRequest request) async {
    final path = request.uri.path;
    requests.add((path: path, headers: request.headers));
    final response = request.response;
    if (redirects[path] case final location?) {
      response
        ..statusCode = HttpStatus.found
        ..headers.set(HttpHeaders.locationHeader, location);
      return response.close();
    }
    if (path == latestPath) {
      response.statusCode = releaseStatus;
      response.headers.contentType = ContentType.json;
      response.write(releaseBody ?? jsonEncode(release));
      return response.close();
    }
    final body = files[path];
    if (body == null) {
      response.statusCode = HttpStatus.notFound;
      return response.close();
    }
    response.contentLength = body.length;
    const chunk = 16 * 1024;
    for (var i = 0; i < body.length; i += chunk) {
      response.add(body.sublist(i, (i + chunk).clamp(0, body.length)));
      await response.flush();
      if (chunkDelay > Duration.zero) await Future<void>.delayed(chunkDelay);
    }
    await response.close();
  }

  /// A release object as the GitHub REST API sends it, with both files
  /// served here.
  Map<String, Object?> releaseJson(
    String version, {
    bool draft = false,
    bool prerelease = false,
    int? archiveSize,
    String? archiveUrl,
    bool withChecksum = true,
  }) {
    final zip = 'Tinglang-$version-macOS.zip';
    final zipPath = '/download/v$version/$zip';
    return {
      'tag_name': 'v$version',
      'name': 'Tinglang $version',
      'draft': draft,
      'prerelease': prerelease,
      'html_url': 'https://github.com/eeeease/TingLang/releases/tag/v$version',
      'body': '## Changes\n- something',
      'assets': [
        {
          'name': zip,
          'state': 'uploaded',
          'size': archiveSize ?? files[zipPath]?.length ?? 1000,
          'browser_download_url': archiveUrl ?? url(zipPath),
        },
        if (withChecksum)
          {
            'name': '$zip.sha256',
            'state': 'uploaded',
            'size': files['$zipPath.sha256']?.length ?? 90,
            'browser_download_url': url('$zipPath.sha256'),
          },
      ],
    };
  }

  /// Serves [zip] and its `shasum -a 256` line (or [checksumLine]) for
  /// [version], and makes it the latest release.
  void publish(String version, List<int> zip, {String? checksumLine, int? listedSize}) {
    final name = 'Tinglang-$version-macOS.zip';
    final path = '/download/v$version/$name';
    files[path] = zip;
    files['$path.sha256'] = utf8.encode(checksumLine ?? '${sha256.convert(zip)}  $name\n');
    release = releaseJson(version, archiveSize: listedSize);
  }
}

/// Writes a fake app bundle (never run): an Info.plist and an executable
/// file. Returns the bundle path.
Future<String> fakeBundle(
  String folder, {
  String name = 'Tinglang.app',
  String bundleId = 'dev.eeeease.tinglang',
  required String version,
}) async {
  final bundle = p.join(folder, name);
  await Directory(p.join(bundle, 'Contents', 'MacOS')).create(recursive: true);
  await File(p.join(bundle, 'Contents', 'Info.plist')).writeAsString('''
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>Tinglang</string>
  <key>CFBundleIdentifier</key>
  <string>$bundleId</string>
  <key>CFBundleShortVersionString</key>
  <string>$version</string>
</dict>
</plist>
''');
  final binary = File(p.join(bundle, 'Contents', 'MacOS', 'Tinglang'));
  await binary.writeAsString('#!/bin/sh\nexit 0\n');
  await Process.run('/bin/chmod', ['755', binary.path]);
  return bundle;
}

/// `ditto -c -k --keepParent`, as the release workflow packs the app.
Future<List<int>> zipBundle(String bundle, String into) async {
  final zip = p.join(into, '${p.basenameWithoutExtension(bundle)}.zip');
  final result = await Process.run('/usr/bin/ditto', ['-c', '-k', '--keepParent', bundle, zip]);
  if (result.exitCode != 0) throw StateError('ditto: ${result.stderr}');
  return File(zip).readAsBytes();
}

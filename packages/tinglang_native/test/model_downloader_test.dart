// Every test talks to a local HttpServer on 127.0.0.1; nothing leaves the
// machine (refused redirects are refused before connecting).
import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:tinglang_native/tinglang_native.dart';

List<int> _bytes(int n, int seed) => List.generate(n, (i) => (i * 31 + seed * 7 + (i >> 8)) & 0xff);
String _sha(List<int> bytes) => sha256.convert(bytes).toString();

typedef _Seen = ({String path, String? range, String? userAgent});

/// Serves [files] with Range support; knobs simulate misbehaving servers.
final class _Server {
  late final HttpServer _http;
  final files = <String, List<int>>{};
  final redirects = <String, String>{};
  final requests = <_Seen>[];
  bool ignoreRange = false;
  int? forceStatus;
  bool stall = false;
  int chunkSize = 64 * 1024;
  Duration chunkDelay = Duration.zero;
  final _closed = Completer<void>();

  Future<void> start() async {
    _http = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _http.listen((request) => _handle(request).catchError((Object _) {}));
  }

  String url(String path) => 'http://127.0.0.1:${_http.port}$path';

  Future<void> close() async {
    if (!_closed.isCompleted) _closed.complete();
    await _http.close(force: true);
  }

  Future<void> _handle(HttpRequest request) async {
    final path = request.uri.path;
    final range = request.headers.value(HttpHeaders.rangeHeader);
    requests.add((path: path, range: range, userAgent: request.headers.value('user-agent')));
    final response = request.response;
    if (redirects[path] case final location?) {
      response
        ..statusCode = HttpStatus.found
        ..headers.set(HttpHeaders.locationHeader, location);
      return response.close();
    }
    if (forceStatus case final status?) {
      response.statusCode = status;
      return response.close();
    }
    final body = files[path];
    if (body == null) {
      response.statusCode = HttpStatus.notFound;
      return response.close();
    }
    var start = 0;
    if (range != null && !ignoreRange) {
      start = int.parse(RegExp(r'bytes=(\d+)-').firstMatch(range)!.group(1)!);
      if (start >= body.length) {
        response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
        return response.close();
      }
      response
        ..statusCode = HttpStatus.partialContent
        ..headers.set(
          HttpHeaders.contentRangeHeader,
          'bytes $start-${body.length - 1}/${body.length}',
        );
    }
    response.contentLength = body.length - start;
    if (stall) {
      await response.flush();
      await _closed.future;
      return;
    }
    for (var i = start; i < body.length; i += chunkSize) {
      response.add(body.sublist(i, (i + chunkSize).clamp(0, body.length)));
      await response.flush();
      if (chunkDelay > Duration.zero) await Future<void>.delayed(chunkDelay);
    }
    await response.close();
  }
}

void main() {
  late Directory data;
  late _Server server;
  late ModelStore store;
  late int clients;
  final a = _bytes(300 * 1024, 1);
  final b = _bytes(20 * 1024, 2);

  ModelFile file(String name, List<int> bytes, {String? path, String? sha}) => ModelFile(
    name: name,
    url: server.url(path ?? '/$name'),
    bytes: bytes.length,
    sha256: sha ?? _sha(bytes),
  );

  ModelPack packOf(List<ModelFile> files, {String id = 'test-pack', ModelArchive? archive}) =>
      ModelPack(
        id: id,
        license: const ModelLicense('MIT', 'https://example.invalid'),
        files: files,
        archive: archive,
      );

  ModelDownloader downloaderFor(
    List<ModelPack> catalog, {
    Duration idleTimeout = const Duration(seconds: 10),
    Duration progressInterval = const Duration(milliseconds: 100),
  }) {
    store = ModelStore(data.path, catalog: catalog);
    return ModelDownloader(
      store: store,
      appVersion: '1.2.3',
      idleTimeout: idleTimeout,
      progressInterval: progressInterval,
      httpClient: () {
        clients++;
        return HttpClient();
      },
    );
  }

  String path(ModelPack pack, String name) => p.join(store.directoryOf(pack.id), name);
  bool exists(ModelPack pack, String name) =>
      FileSystemEntity.typeSync(path(pack, name)) != FileSystemEntityType.notFound;

  setUp(() async {
    clients = 0;
    data = await Directory.systemTemp.createTemp('tinglang-download-');
    server = _Server();
    await server.start();
    server.files['/a.onnx'] = a;
    server.files['/tokens.txt'] = b;
  });
  tearDown(() async {
    await server.close();
    await data.delete(recursive: true);
  });

  group('consent', () {
    test('missing consent throws before any HttpClient or request', () {
      final pack = packOf([file('a.onnx', a)]);
      final downloader = downloaderFor([pack]);
      expect(() => downloader.install(pack, consent: null), throwsStateError);
      expect(clients, 0);
      expect(server.requests, isEmpty);
      expect(Directory(store.root).existsSync(), isFalse);
    });

    test('consent for another pack or another size is refused', () {
      final pack = packOf([file('a.onnx', a)]);
      final other = packOf([file('tokens.txt', b)], id: 'other');
      final downloader = downloaderFor([pack, other]);
      expect(
        () => downloader.install(pack, consent: DownloadConsent.forPack(other)),
        throwsStateError,
      );
      expect(
        () => downloader.start(
          pack,
          consent: DownloadConsent(
            packId: pack.id,
            bytes: pack.bytes - 1,
            agreedAt: DateTime(2026),
          ),
        ),
        throwsStateError,
      );
      expect(clients, 0);
      expect(server.requests, isEmpty);
    });

    test('constructing the downloader creates no HttpClient', () {
      downloaderFor(SpeechModels.packs);
      expect(clients, 0);
    });
  });

  test('installs, reports monotonic progress and writes the receipt', () async {
    final pack = packOf([file('a.onnx', a), file('tokens.txt', b)]);
    final downloader = downloaderFor([pack], progressInterval: Duration.zero);
    server
      ..chunkSize = 16 * 1024
      ..chunkDelay = const Duration(milliseconds: 2);
    final progress = <DownloadProgress>[];
    await downloader.install(
      pack,
      consent: DownloadConsent.forPack(pack),
      onProgress: progress.add,
    );
    expect(progress.length, greaterThan(3));
    for (var i = 1; i < progress.length; i++) {
      expect(progress[i].received, greaterThan(progress[i - 1].received));
    }
    expect(progress.last.received, pack.bytes);
    expect(progress.every((e) => e.total == pack.bytes && e.packId == pack.id), isTrue);
    expect(store.installed, {pack.id});
    expect(await File(path(pack, 'a.onnx')).readAsBytes(), a);
    expect(await File(path(pack, 'tokens.txt')).readAsBytes(), b);
    expect(exists(pack, 'a.onnx.part'), isFalse);
    expect(store.readReceipt(pack.id)!['a.onnx'], (bytes: a.length, sha256: _sha(a)));
    expect(server.requests.map((r) => r.userAgent).toSet(), {'Tinglang/1.2.3'});
    expect(server.requests.map((r) => r.range), [null, null]);
    expect(clients, 1);
    expect(downloader.jobFor(pack.id), isNull);

    // Installed packs finish without any network access.
    await downloader.install(pack, consent: DownloadConsent.forPack(pack));
    expect(clients, 1);
    expect(server.requests, hasLength(2));
  });

  test('progress is throttled', () async {
    final pack = packOf([file('a.onnx', a)]);
    final downloader = downloaderFor([pack], progressInterval: const Duration(seconds: 10));
    server.chunkSize = 4 * 1024;
    final progress = <DownloadProgress>[];
    await downloader.install(
      pack,
      consent: DownloadConsent.forPack(pack),
      onProgress: progress.add,
    );
    expect(progress.length, lessThanOrEqualTo(3));
    expect(progress.last.received, pack.bytes);
  });

  test('a second start returns the running job', () async {
    final pack = packOf([file('a.onnx', a)]);
    final downloader = downloaderFor([pack]);
    final first = downloader.start(pack, consent: DownloadConsent.forPack(pack));
    final second = downloader.start(pack, consent: DownloadConsent.forPack(pack));
    expect(identical(first, second), isTrue);
    expect(downloader.jobFor(pack.id), same(first));
    await first.done;
    expect(server.requests, hasLength(1));
  });

  test('a checksum mismatch leaves no file, part or receipt', () async {
    final pack = packOf([file('a.onnx', a, sha: '0' * 64)]);
    final downloader = downloaderFor([pack]);
    await expectLater(
      downloader.install(pack, consent: DownloadConsent.forPack(pack)),
      throwsA(
        isA<ChecksumMismatch>()
            .having((e) => e.file, 'file', 'a.onnx')
            .having((e) => e.expected, 'expected', '0' * 64)
            .having((e) => e.actual, 'actual', _sha(a)),
      ),
    );
    expect(exists(pack, 'a.onnx'), isFalse);
    expect(exists(pack, 'a.onnx.part'), isFalse);
    expect(exists(pack, ModelStore.receiptName), isFalse);
    expect(store.installed, isEmpty);
  });

  test('a longer body than the catalog says is a mismatch', () async {
    server.files['/a.onnx'] = [...a, 1, 2, 3];
    final pack = packOf([file('a.onnx', a)]);
    final downloader = downloaderFor([pack]);
    await expectLater(
      downloader.install(pack, consent: DownloadConsent.forPack(pack)),
      throwsA(isA<ChecksumMismatch>()),
    );
    expect(exists(pack, 'a.onnx.part'), isFalse);
  });

  test('cancel keeps the part; the next install resumes with Range', () async {
    final big = _bytes(1024 * 1024, 3);
    server
      ..files['/big.onnx'] = big
      ..chunkSize = 16 * 1024
      ..chunkDelay = const Duration(milliseconds: 20);
    final pack = packOf([file('big.onnx', big)]);
    final downloader = downloaderFor([pack], progressInterval: Duration.zero);
    final job = downloader.start(pack, consent: DownloadConsent.forPack(pack));
    job.progress.firstWhere((e) => e.received > 100 * 1024).then((_) => job.cancel());
    await expectLater(job.done, throwsA(isA<DownloadCancelled>()));
    expect(job.isCancelled, isTrue);
    final partLength = File(path(pack, 'big.onnx.part')).lengthSync();
    expect(partLength, inExclusiveRange(0, big.length));
    expect(exists(pack, 'big.onnx'), isFalse);
    expect(exists(pack, ModelStore.receiptName), isFalse);
    expect(store.refresh(), isEmpty);

    server.chunkDelay = Duration.zero;
    final progress = <DownloadProgress>[];
    await downloader.install(
      pack,
      consent: DownloadConsent.forPack(pack),
      onProgress: progress.add,
    );
    expect(server.requests.last.range, 'bytes=$partLength-');
    expect(progress.first.received, greaterThanOrEqualTo(partLength));
    expect(await File(path(pack, 'big.onnx')).readAsBytes(), big);
    expect(store.installed, {pack.id});
  });

  test('a server that ignores Range restarts from zero', () async {
    final pack = packOf([file('a.onnx', a)]);
    final downloader = downloaderFor([pack]);
    await Directory(store.directoryOf(pack.id)).create(recursive: true);
    await File(path(pack, 'a.onnx.part')).writeAsBytes(List.filled(1000, 0xee));
    server.ignoreRange = true;
    await downloader.install(pack, consent: DownloadConsent.forPack(pack));
    expect(server.requests.single.range, 'bytes=1000-');
    expect(await File(path(pack, 'a.onnx')).readAsBytes(), a);
    expect(store.installed, {pack.id});
  });

  test('416 verifies the part as it is', () async {
    final pack = packOf([file('a.onnx', a)]);
    final downloader = downloaderFor([pack]);
    await Directory(store.directoryOf(pack.id)).create(recursive: true);
    await File(path(pack, 'a.onnx.part')).writeAsBytes(a.sublist(0, 1000));
    server.forceStatus = HttpStatus.requestedRangeNotSatisfiable;
    await expectLater(
      downloader.install(pack, consent: DownloadConsent.forPack(pack)),
      throwsA(isA<ChecksumMismatch>()),
    );
    expect(exists(pack, 'a.onnx.part'), isFalse);
  });

  test('a complete part and an intact finished file skip the network', () async {
    final pack = packOf([file('a.onnx', a), file('tokens.txt', b)]);
    final downloader = downloaderFor([pack]);
    await Directory(store.directoryOf(pack.id)).create(recursive: true);
    await File(path(pack, 'a.onnx')).writeAsBytes(a);
    await File(path(pack, 'tokens.txt.part')).writeAsBytes(b);
    await downloader.install(pack, consent: DownloadConsent.forPack(pack));
    expect(server.requests, isEmpty);
    expect(store.installed, {pack.id});
  });

  test('a corrupt finished file is downloaded again', () async {
    final pack = packOf([file('a.onnx', a)]);
    final downloader = downloaderFor([pack]);
    await Directory(store.directoryOf(pack.id)).create(recursive: true);
    await File(path(pack, 'a.onnx')).writeAsBytes(_bytes(a.length, 8));
    await downloader.install(pack, consent: DownloadConsent.forPack(pack));
    expect(server.requests, hasLength(1));
    expect(await File(path(pack, 'a.onnx')).readAsBytes(), a);
  });

  test('404 is a DownloadHttpError', () async {
    final pack = packOf([file('missing.onnx', a)]);
    final downloader = downloaderFor([pack]);
    await expectLater(
      downloader.install(pack, consent: DownloadConsent.forPack(pack)),
      throwsA(
        isA<DownloadHttpError>()
            .having((e) => e.status, 'status', 404)
            .having((e) => e.file, 'file', 'missing.onnx'),
      ),
    );
    expect(store.installed, isEmpty);
  });

  test('an idle connection times out and keeps the part', () async {
    server.stall = true;
    final pack = packOf([file('a.onnx', a)]);
    final downloader = downloaderFor([pack], idleTimeout: const Duration(milliseconds: 300));
    await expectLater(
      downloader.install(pack, consent: DownloadConsent.forPack(pack)),
      throwsA(isA<DownloadNetworkError>().having((e) => e.message, 'message', 'timed out')),
    );
  });

  group('URLs', () {
    test('follows redirects to allowed URLs', () async {
      server.redirects['/r'] = '/a.onnx';
      final pack = packOf([file('a.onnx', a, path: '/r')]);
      final downloader = downloaderFor([pack]);
      await downloader.install(pack, consent: DownloadConsent.forPack(pack));
      expect(server.requests.map((r) => r.path), ['/r', '/a.onnx']);
      expect(store.installed, {pack.id});
    });

    test('refuses a redirect to plain http on another host', () async {
      server.redirects['/r'] = 'http://example.com/a.onnx';
      final pack = packOf([file('a.onnx', a, path: '/r')]);
      final downloader = downloaderFor([pack]);
      await expectLater(
        downloader.install(pack, consent: DownloadConsent.forPack(pack)),
        throwsA(
          isA<DownloadUrlRefused>()
              .having((e) => e.scheme, 'scheme', 'http')
              .having((e) => e.host, 'host', 'example.com'),
        ),
      );
      expect(server.requests.single.path, '/r');
      expect(store.installed, isEmpty);
    });

    test('refuses non-https catalog URLs before creating a client', () {
      final pack = packOf([
        const ModelFile(name: 'a.onnx', url: 'http://example.com/a', bytes: 1, sha256: ''),
      ]);
      final downloader = downloaderFor([pack]);
      expect(
        () => downloader.start(pack, consent: DownloadConsent.forPack(pack)),
        throwsA(isA<DownloadUrlRefused>()),
      );
      final withUser = packOf([
        const ModelFile(name: 'a.onnx', url: 'https://u:p@example.com/a', bytes: 1, sha256: ''),
      ], id: 'user');
      expect(
        () => downloader.start(withUser, consent: DownloadConsent.forPack(withUser)),
        throwsA(isA<DownloadUrlRefused>()),
      );
      expect(clients, 0);
    });

    test('rejects path traversal in names before creating a client', () {
      for (final pack in [
        packOf([file('../evil.onnx', a)]),
        packOf([file('a.onnx', a)], id: '../evil'),
        packOf([file('a/b.onnx', a)]),
        packOf([file('.receipt.json', a)]),
        packOf([file('a.onnx', a), file('a.onnx', a)]),
      ]) {
        final downloader = downloaderFor([pack]);
        expect(
          () => downloader.start(pack, consent: DownloadConsent.forPack(pack)),
          throwsArgumentError,
        );
      }
      expect(clients, 0);
      expect(server.requests, isEmpty);
    });
  });

  test('delete cancels a running install and removes the folder', () async {
    server
      ..chunkSize = 4 * 1024
      ..chunkDelay = const Duration(milliseconds: 20);
    final pack = packOf([file('a.onnx', a)]);
    final downloader = downloaderFor([pack], progressInterval: Duration.zero);
    final job = downloader.start(pack, consent: DownloadConsent.forPack(pack));
    await job.progress.first;
    await downloader.delete(pack.id);
    await expectLater(job.done, throwsA(isA<DownloadCancelled>()));
    expect(Directory(store.directoryOf(pack.id)).existsSync(), isFalse);
    expect(store.installed, isEmpty);
  });

  group('archive packs', () {
    late List<int> archiveBytes;
    final encoder = _bytes(200 * 1024, 4);
    final tokens = _bytes(3000, 5);

    setUp(() async {
      final src = await Directory(p.join(data.path, 'src', 'model-2026')).create(recursive: true);
      await File(p.join(src.path, 'encoder.int8.onnx')).writeAsBytes(encoder);
      await File(p.join(src.path, 'tokens.txt')).writeAsBytes(tokens);
      await File(p.join(src.path, 'README.md')).writeAsString('not listed');
      final tar = await Process.run(
        '/usr/bin/tar',
        ['-cjf', 'model.tar.bz2', 'model-2026'],
        workingDirectory: src.parent.path,
        environment: {'COPYFILE_DISABLE': '1'},
      );
      expect(tar.exitCode, 0, reason: '${tar.stderr}');
      archiveBytes = await File(p.join(src.parent.path, 'model.tar.bz2')).readAsBytes();
      server.files['/model.tar.bz2'] = archiveBytes;
    });

    ModelPack archivePack({String? archiveSha, String? tokensSha}) => packOf(
      [
        ModelFile(name: 'encoder.int8.onnx', url: '', bytes: encoder.length, sha256: _sha(encoder)),
        ModelFile(
          name: 'tokens.txt',
          url: '',
          bytes: tokens.length,
          sha256: tokensSha ?? _sha(tokens),
        ),
      ],
      archive: ModelArchive(
        url: server.url('/model.tar.bz2'),
        bytes: archiveBytes.length,
        sha256: archiveSha ?? _sha(archiveBytes),
        folder: 'model-2026',
      ),
    );

    test('extracts only the listed files and cleans up', () async {
      final pack = archivePack();
      final downloader = downloaderFor([pack], progressInterval: Duration.zero);
      expect(
        () => downloader.start(
          pack,
          consent: DownloadConsent(packId: pack.id, bytes: pack.bytes, agreedAt: DateTime(2026)),
        ),
        throwsStateError,
        reason: 'consent covers the archive size',
      );
      final progress = <DownloadProgress>[];
      await downloader.install(
        pack,
        consent: DownloadConsent.forPack(pack),
        onProgress: progress.add,
      );
      expect(progress.last.received, archiveBytes.length);
      expect(progress.every((e) => e.total == archiveBytes.length), isTrue);
      expect(await File(path(pack, 'encoder.int8.onnx')).readAsBytes(), encoder);
      expect(await File(path(pack, 'tokens.txt')).readAsBytes(), tokens);
      expect(exists(pack, 'README.md'), isFalse);
      expect(exists(pack, 'model-2026'), isFalse);
      expect(exists(pack, ModelDownloader.archiveName), isFalse);
      expect(exists(pack, '${ModelDownloader.archiveName}.part'), isFalse);
      expect(exists(pack, ModelDownloader.stagingName), isFalse);
      expect(store.installed, {pack.id});
      expect(await store.verify(pack.id), isTrue);
    });

    test('a wrong archive checksum installs nothing', () async {
      final pack = archivePack(archiveSha: '1' * 64);
      final downloader = downloaderFor([pack]);
      await expectLater(
        downloader.install(pack, consent: DownloadConsent.forPack(pack)),
        throwsA(isA<ChecksumMismatch>().having((e) => e.file, 'file', 'model.tar.bz2')),
      );
      expect(exists(pack, 'encoder.int8.onnx'), isFalse);
      expect(exists(pack, '${ModelDownloader.archiveName}.part'), isFalse);
      expect(store.installed, isEmpty);
    });

    test('an extracted file that differs from the catalog is a mismatch', () async {
      final pack = archivePack(tokensSha: '2' * 64);
      final downloader = downloaderFor([pack]);
      await expectLater(
        downloader.install(pack, consent: DownloadConsent.forPack(pack)),
        throwsA(isA<ChecksumMismatch>().having((e) => e.file, 'file', 'tokens.txt')),
      );
      expect(exists(pack, 'tokens.txt'), isFalse);
      expect(exists(pack, ModelDownloader.stagingName), isFalse);
      expect(store.installed, isEmpty);
    });

    test('a file missing from the archive is an archive error', () async {
      final good = archivePack();
      final pack = packOf([
        ...good.files,
        const ModelFile(name: 'joiner.onnx', url: '', bytes: 1, sha256: ''),
      ], archive: good.archive);
      final downloader = downloaderFor([pack]);
      await expectLater(
        downloader.install(pack, consent: DownloadConsent.forPack(pack)),
        throwsA(isA<ModelArchiveError>()),
      );
      expect(store.installed, isEmpty);
    });

    test('installed archive files skip the download', () async {
      final pack = archivePack();
      final downloader = downloaderFor([pack]);
      await Directory(store.directoryOf(pack.id)).create(recursive: true);
      await File(path(pack, 'encoder.int8.onnx')).writeAsBytes(encoder);
      await File(path(pack, 'tokens.txt')).writeAsBytes(tokens);
      await downloader.install(pack, consent: DownloadConsent.forPack(pack));
      expect(server.requests, isEmpty);
      expect(store.installed, {pack.id});
    });
  });
}

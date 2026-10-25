import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tinglang_native/tinglang_native.dart';

/// Installs the real X-ASR streaming pack from a copy of its release archive
/// served on 127.0.0.1, so the catalog's archive and per-file SHA-256 are
/// checked against the actual published bytes without another download.
/// `TINGLANG_XASR_ARCHIVE=/path/to/...-480ms-...-2026-06-05.tar.bz2`.
void main() {
  final archive = Platform.environment['TINGLANG_XASR_ARCHIVE'];

  test(
    'the X-ASR release archive matches the catalog',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);
      server.listen((request) async {
        request.response.headers.contentLength = File(archive!).lengthSync();
        await request.response.addStream(File(archive).openRead());
        await request.response.close();
      });
      final real = SpeechModels.xasrStreaming.pack!;
      final local = ModelPack(
        id: real.id,
        files: real.files,
        license: real.license,
        archive: ModelArchive(
          url: 'http://127.0.0.1:${server.port}/x.tar.bz2',
          bytes: real.archive!.bytes,
          sha256: real.archive!.sha256,
          folder: real.archive!.folder,
        ),
      );
      final dir = await Directory.systemTemp.createTemp('tinglang-archive-');
      addTearDown(() => dir.delete(recursive: true));
      final store = ModelStore(dir.path, catalog: [local]);
      final downloader = ModelDownloader(store: store, appVersion: 'test');
      await downloader.install(local, consent: DownloadConsent.forPack(local));
      expect(store.installed, {real.id});
      expect(
        Directory(store.directoryOf(real.id))
            .listSync()
            .map((e) => e.uri.pathSegments.last)
            .toSet(),
        {...real.files.map((f) => f.name), ModelStore.receiptName},
        reason: 'only the listed files are kept; archive and staging are gone',
      );
    },
    skip: archive == null ? 'set TINGLANG_XASR_ARCHIVE' : false,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

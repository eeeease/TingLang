import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinglang/core/db/database.dart';
import 'package:tinglang/core/library_store.dart';
import 'package:tinglang/core/live_repository.dart';
import 'package:tinglang/services/app_controller.dart';
import 'package:tinglang/services/link_import.dart';
import 'package:tinglang/services/transcription_controller.dart';
import 'package:tinglang_native/tinglang_native.dart';
import 'package:tinglang_platform_interface/testing.dart';

/// A stand-in for yt-dlp: `-J` prints the page, otherwise it "downloads" a
/// small file where `-o` says and prints its path, like `--print after_move`.
const _fakeTool = r'''#!/bin/sh
for a in "$@"; do last="$a"; done
case "$last" in
  *unsupported*) echo "ERROR: Unsupported URL: $last" >&2; exit 1 ;;
esac
for a in "$@"; do
  if [ "$a" = "-J" ]; then
    case "$last" in
      *live*) echo '{"title":"Live now","is_live":true}' ;;
      *) echo '{"title":"A talk about listening","duration":95.5,"webpage_url":"https://www.youtube.com/watch?v=abc","extractor_key":"Youtube"}' ;;
    esac
    exit 0
  fi
done
out=""; prev=""
for a in "$@"; do
  if [ "$prev" = "-o" ]; then out="$a"; fi
  prev="$a"
done
file=$(echo "$out" | sed 's/%(ext)s/m4a/')
echo "download: 50.0%"
printf 'audio' > "$file"
echo "download:100.0%"
echo "$file"
''';

void main() {
  late Directory dir;
  late TinglangDatabase db;
  late AppController app;
  late TranscriptionController transcription;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('tinglang-links-');
    db = TinglangDatabase.memory();
    final store = LibraryStore(Directory('${dir.path}/library'));
    app = AppController(store, LibraryState());
    final platform =
        TinglangPlatform(probeSource: FakeProbeSource(FakeProbes.macos(const OsVersion(26))))
          ..fileAsr.register(
            BackendFactory(
              BackendCatalog.speechAnalyzerFile,
              () => FakeFileTranscriber(
                BackendCatalog.speechAnalyzerFile.id,
                output: const [
                  TranscriptSegment(startMs: 0, endMs: 900, text: 'Listening is a skill.'),
                ],
              ),
            ),
          )
          ..decoders.register(BackendFactory(BackendCatalog.avAssetReader, FakeMediaDecoder.new));
    transcription = TranscriptionController(
      repository: LiveRepository(db),
      store: store,
      platform: platform,
    );
  });
  tearDown(() async {
    app.dispose();
    await db.close();
    await dir.delete(recursive: true);
  });

  LinkImportService service({Uri? releaseApi}) => LinkImportService(
    app: app,
    transcription: transcription,
    toolsFolder: Directory('${dir.path}/tools'),
    releaseApi: releaseApi,
    allowDownload: (uri) => uri.host == '127.0.0.1',
  );

  Future<void> installFakeTool(LinkImportService links) async {
    await links.toolsFolder.create(recursive: true);
    await links.tool.writeAsString(_fakeTool);
    await Process.run('/bin/chmod', ['755', links.tool.path]);
  }

  group('yt-dlp itself', () {
    late HttpServer server;
    late List<int> binary;
    late String sums;

    setUp(() async {
      binary = utf8.encode('#!/bin/sh\necho 2026.10.26\n');
      sums = '${sha256.convert(binary)}  yt-dlp_macos\n${'0' * 64}  yt-dlp.exe\n';
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final base = 'http://127.0.0.1:${server.port}';
      server.listen((request) async {
        final response = request.response;
        switch (request.uri.path) {
          case '/latest':
            response.write(
              jsonEncode({
                'tag_name': '2026.10.26',
                'assets': [
                  {
                    'name': 'yt-dlp_macos',
                    'size': binary.length,
                    'browser_download_url': '$base/yt-dlp_macos',
                  },
                  {
                    'name': 'SHA2-256SUMS',
                    'size': sums.length,
                    'browser_download_url': '$base/sums',
                  },
                ],
              }),
            );
          case '/yt-dlp_macos':
            response.add(binary);
          case '/sums':
            response.write(sums);
          default:
            response.statusCode = 404;
        }
        await response.close();
      });
    });
    tearDown(() => server.close(force: true));

    test('nothing is downloaded until asked; then it is checked and made runnable', () async {
      final links = service(releaseApi: Uri.parse('http://127.0.0.1:${server.port}/latest'));
      expect(links.installed, isFalse);
      final offer = await links.offer();
      expect(offer.version, '2026.10.26');
      expect(offer.bytes, binary.length);
      expect(links.installed, isFalse, reason: 'asking which version exists downloads nothing');

      await links.install(offer);
      expect(links.installed, isTrue);
      final run = await Process.run(links.tool.path, ['--version']);
      expect('${run.stdout}'.trim(), '2026.10.26');
    });

    test('a download that does not match its checksum is not kept', () async {
      sums = '${'1' * 64}  yt-dlp_macos\n';
      final links = service(releaseApi: Uri.parse('http://127.0.0.1:${server.port}/latest'));
      await expectLater(
        links.install(await links.offer()),
        throwsA(isA<LinkImportFailure>().having((e) => e.problem, 'problem', LinkProblem.tool)),
      );
      expect(links.installed, isFalse);
      expect(File('${links.tool.path}.part').existsSync(), isFalse);
    });

    test('downloads only from the allowed hosts', () async {
      final links = LinkImportService(
        app: app,
        transcription: transcription,
        toolsFolder: Directory('${dir.path}/tools'),
        releaseApi: Uri.parse('http://127.0.0.1:${server.port}/latest'),
      );
      await expectLater(links.offer(), throwsA(isA<LinkImportFailure>()));
    });
  });

  group('a link', () {
    test('only the audio is fetched and transcribed under History, with the link kept', () async {
      final links = service();
      await installFakeTool(links);
      final info = await links.inspect('https://youtu.be/abc');
      expect(info.title, 'A talk about listening');
      expect(info.duration, const Duration(milliseconds: 95500));
      expect(info.site, 'Youtube');

      final job = await links.import(info);
      while (job.status == ImportStatus.copying || job.status == ImportStatus.transcribing) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(job.status, ImportStatus.done, reason: job.error);
      final session = (await transcription.repository.recentSessions()).single;
      expect(session.origin, 'link');
      expect(session.title, 'A talk about listening');
      expect(session.sourceRef, 'https://www.youtube.com/watch?v=abc');
      expect(
        (await transcription.repository.lines(session.id)).single.text,
        'Listening is a skill.',
      );
    });

    test('not a link, a live stream and an unknown site each say why', () async {
      final links = service();
      await installFakeTool(links);
      Matcher fails(LinkProblem problem) =>
          throwsA(isA<LinkImportFailure>().having((e) => e.problem, 'problem', problem));
      await expectLater(links.inspect('just words'), fails(LinkProblem.notALink));
      await expectLater(links.inspect('ftp://example.com/a'), fails(LinkProblem.notALink));
      await expectLater(links.inspect('https://example.com/live'), fails(LinkProblem.live));
      await expectLater(
        links.inspect('https://example.com/unsupported'),
        fails(LinkProblem.unsupported),
      );
    });
  });
}

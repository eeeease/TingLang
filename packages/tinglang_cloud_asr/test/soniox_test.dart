import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:tinglang_cloud_asr/src/providers/soniox.dart';
import 'package:tinglang_cloud_asr/tinglang_cloud_asr.dart';

import 'support/fake_server.dart';
import 'support/ws_peer.dart';

// A made-up key: tests never use real credentials.
const key = 'soniox-test-key-0123456789abcdef';
const creds = {CloudFieldKeys.apiKey: key};

/// A [CloudAsrError] of [kind] whose message and toString never contain the key.
Matcher cloudError(CloudAsrErrorKind kind) => isA<CloudAsrError>()
    .having((e) => e.kind, 'kind', kind)
    .having((e) => e.message, 'message', isNot(contains(key)))
    .having((e) => e.toString(), 'toString', isNot(contains(key)));

Map<String, Object?> tok(String text, int start, int end, {bool fin = true}) => {
  'text': text,
  'start_ms': start,
  'end_ms': end,
  'confidence': 0.9,
  'is_final': fin,
};

void main() {
  group('info', () {
    test('registry, fields, languages, hosts', () {
      final p = CloudAsrProviders.byId('soniox');
      expect(p, isA<SonioxProvider>());
      expect(p!.info.fields.map((f) => f.key), [CloudFieldKeys.apiKey]);
      expect(p.info.fields.single.kind, CloudFieldKind.secret);
      expect(p.info.languages, containsAll(['en', 'zh', 'ja', 'ko', 'es', 'fr', 'de']));
      expect(p.info.live && p.info.file, isTrue);
      expect(p.info.maxFileMs, 240 * 60 * 1000);
      expect(p.hosts(creds), ['api.soniox.com', 'stt-rt.soniox.com']);
    });

    test('no HttpClient exists before a call', () async {
      final n = await countHttpClients(() {
        final p = SonioxProvider();
        p.info;
        p.hosts(creds);
      });
      expect(n, 0);
    });

    test('language hints', () {
      expect(SonioxProvider.languageHint('en'), 'en');
      expect(SonioxProvider.languageHint('en-US'), 'en');
      expect(SonioxProvider.languageHint('en-GB'), 'en');
      expect(SonioxProvider.languageHint('zh-Hans'), 'zh');
      for (final l in ['ja', 'ko', 'es', 'fr', 'de']) {
        expect(SonioxProvider.languageHint(l), l);
      }
      expect(
        () => SonioxProvider.languageHint('xx'),
        throwsA(cloudError(CloudAsrErrorKind.unsupportedLanguage)),
      );
    });
  });

  group('verify', () {
    late FakeServer server;
    var status = 200;
    String? auth;
    setUp(() async {
      status = 200;
      server = await FakeServer.start((request) async {
        auth = request.headers.value(HttpHeaders.authorizationHeader);
        if (status == 200) {
          await replyJson(request, '{"models":[]}');
        } else {
          await replyJson(
            request,
            jsonEncode({
              'status_code': status,
              'error_type': 'x',
              'message': 'Incorrect API key provided: $key',
              'validation_errors': <Object>[],
              'request_id': 'r',
            }),
            status: status,
          );
        }
      });
    });
    tearDown(() => server.close());

    SonioxProvider provider() => SonioxProvider(apiBase: server.http);

    test('lists models with a Bearer key', () async {
      await provider().verify(creds);
      expect(server.requests.single.method, 'GET');
      expect(server.requests.single.uri.path, '/v1/models');
      expect(auth, 'Bearer $key');
    });

    test('maps HTTP errors and never shows the key', () async {
      for (final (s, kind) in [
        (401, CloudAsrErrorKind.unauthorized),
        (402, CloudAsrErrorKind.quotaExceeded),
        (403, CloudAsrErrorKind.unauthorized),
        (429, CloudAsrErrorKind.rateLimited),
        (500, CloudAsrErrorKind.server),
        (503, CloudAsrErrorKind.server),
      ]) {
        status = s;
        await expectLater(provider().verify(creds), throwsA(cloudError(kind)), reason: '$s');
      }
    });

    test('missing key and unreachable service', () async {
      await expectLater(provider().verify({}), throwsA(cloudError(CloudAsrErrorKind.unauthorized)));
      final dead = SonioxProvider(apiBase: await deadUrl('http'));
      await expectLater(dead.verify(creds), throwsA(cloudError(CloudAsrErrorKind.network)));
    });
  });

  group('lines from tokens', () {
    List<String> lines(List<SonioxToken> tokens) {
      final l = TokenLines();
      tokens.forEach(l.addFinal);
      l.close();
      return [for (final line in l.done) line.text];
    }

    SonioxToken t(String text, [int start = 0, int? end]) => SonioxToken(text, start, end ?? start);

    test('a sentence ends at . ? ! before a new capitalised word', () {
      expect(
        lines([
          t('Hello'),
          t(' Mr'),
          t('.'),
          t(' Smith'),
          t('.'),
          t(' How'),
          t(' are'),
          t(' you'),
          t('?'),
        ]),
        ['Hello Mr. Smith.', 'How are you?'],
      );
      expect(lines([t('Wait'), t('...'), t(' then'), t(' go'), t('.')]), ['Wait... then go.']);
      expect(lines([t('Use'), t(' e.g.'), t(' This'), t('.')]), ['Use e.g. This.']);
      expect(lines([t('Pi'), t(' is'), t(' 3'), t('.'), t('14'), t('.')]), ['Pi is 3.14.']);
    });

    test('CJK stops, markers and long pauses end lines', () {
      expect(lines([t('你好'), t('。'), t('谢谢'), t('！')]), ['你好。', '谢谢！']);
      expect(lines([t('好吗'), t('?'), t('我'), t('很好')]), ['好吗?', '我很好']);
      expect(lines([t('今日は'), t('、'), t('元気'), t('です'), t('か')]), ['今日は、元気ですか']);
      expect(lines([t('one'), t('<end>'), t(' two')]), ['one', 'two']);
      expect(lines([t('one', 0, 100), t(' two', 2200, 2400)]), ['one', 'two']);
    });

    test('words join sub-word tokens; punctuation stays with its word', () {
      final line = TokenLine([
        t('Hel', 10, 90),
        t('lo', 110, 160),
        t(',', 160, 170),
        t(' world', 200, 500),
      ]);
      expect(line.toSegment('0').words!.map((w) => '${w.text}@${w.startMs}-${w.endMs}'), [
        'Hello,@10-170',
        'world@200-500',
      ]);
      final zh = TokenLine([t('你', 0, 100), t('好', 100, 200), t('。', 200, 210)]);
      expect(zh.toSegment('0').words!.map((w) => w.text), ['你', '好。']);
    });
  });

  group('stream', () {
    late FakeServer server;
    late Completer<WsPeer> peer;
    String? auth;
    int? reject;

    setUp(() async {
      reject = null;
      peer = Completer<WsPeer>();
      server = await FakeServer.start((request) async {
        auth = request.headers.value(HttpHeaders.authorizationHeader);
        if (reject != null) {
          request.response.statusCode = reject!;
          await request.response.close();
          return;
        }
        peer.complete(await upgrade(request));
      });
    });
    tearDown(() => server.close());

    SonioxProvider provider({Duration keepAlive = const Duration(minutes: 1)}) => SonioxProvider(
      realtimeUrl: server.ws.replace(path: '/transcribe-websocket'),
      keepAliveInterval: keepAlive,
    );

    test('config, partials then finals with stable ids and times, finish', () async {
      final stream = await provider().openStream(
        creds,
        const CloudStreamOptions(language: 'en-GB'),
      );
      final got = Inbox(stream.segments);
      final ws = await peer.future;
      final config = await ws.nextJson();
      expect(auth, 'Bearer $key');
      expect(config, {
        'model': 'stt-rt-v5',
        'audio_format': 'pcm_s16le',
        'sample_rate': 16000,
        'num_channels': 1,
        'language_hints': ['en'],
        'enable_endpoint_detection': true,
      });
      expect(jsonEncode(config), isNot(contains(key)));

      stream.addPcm(pcm(40));
      stream.addPcm(pcm(120));
      expect((await ws.nextBinary()).length, 40 * 32);
      expect((await ws.nextBinary()).length, 120 * 32);

      ws.sendJson({
        'tokens': [tok('Hel', 100, 200, fin: false)],
        'final_audio_proc_ms': 0,
        'total_audio_proc_ms': 200,
      });
      var s = await got.next();
      expect((s.id, s.isFinal, s.text, s.startMs, s.endMs), ('0', false, 'Hel', 100, 200));

      ws.sendJson({
        'tokens': [
          tok('Hello', 100, 300),
          tok(' world', 320, 600),
          tok(' ag', 640, 700, fin: false),
        ],
      });
      s = await got.next();
      expect((s.id, s.isFinal, s.text), ('0', false, 'Hello world ag'));

      ws.sendJson({
        'tokens': [tok('.', 600, 610), tok('<end>', 610, 610)],
      });
      s = await got.next();
      expect((s.id, s.isFinal, s.text, s.startMs, s.endMs), ('0', true, 'Hello world.', 100, 610));
      expect(s.words!.map((w) => '${w.text}@${w.startMs}-${w.endMs}'), [
        'Hello@100-300',
        'world.@320-610',
      ]);

      ws.sendJson({
        'tokens': [tok(' Next', 1000, 1200, fin: false)],
      });
      s = await got.next();
      expect((s.id, s.isFinal, s.text), ('1', false, 'Next'));

      final finishing = stream.finish();
      expect(await ws.nextText(), '', reason: 'an empty text frame ends the audio');
      ws.sendJson({
        'tokens': [tok(' Next', 1000, 1200), tok(' one', 1210, 1400)],
      });
      ws.sendJson({'tokens': <Object>[], 'final_audio_proc_ms': 1400, 'finished': true});
      await ws.close();
      await finishing;
      s = await got.next();
      expect((s.id, s.isFinal, s.text), ('1', false, 'Next one'));
      s = await got.next();
      expect((s.id, s.isFinal, s.text, s.startMs, s.endMs), ('1', true, 'Next one', 1000, 1400));
      await got.done();
      expect(got.errors, isEmpty);
      stream.addPcm(pcm(40)); // ignored after finish
    });

    test('a sentence end splits finals without an endpoint', () async {
      final stream = await provider().openStream(creds, const CloudStreamOptions(language: 'en'));
      final got = Inbox(stream.segments);
      final ws = await peer.future;
      await ws.nextJson();
      ws.sendJson({
        'tokens': [
          tok('Yes', 0, 100),
          tok('.', 100, 110),
          tok(' No', 500, 600),
          tok('.', 600, 610),
        ],
      });
      final first = await got.next();
      expect((first.id, first.isFinal, first.text), ('0', true, 'Yes.'));
      final partial = await got.next();
      expect((partial.id, partial.isFinal, partial.text), ('1', false, 'No.'));
      await stream.cancel();
      await got.done();
    });

    test('server errors end the stream with a mapped error', () async {
      for (final (code, type, kind) in [
        (413, 'max_duration_reached', CloudAsrErrorKind.sessionEnded),
        (401, 'unauthenticated', CloudAsrErrorKind.unauthorized),
        (402, 'organization_balance_exhausted', CloudAsrErrorKind.quotaExceeded),
        (429, 'limit_exceeded', CloudAsrErrorKind.rateLimited),
        (400, 'invalid_request', CloudAsrErrorKind.badRequest),
        (503, 'service_unavailable', CloudAsrErrorKind.server),
      ]) {
        peer = Completer<WsPeer>();
        final stream = await provider().openStream(creds, const CloudStreamOptions(language: 'en'));
        final got = Inbox(stream.segments);
        final ws = await peer.future;
        await ws.nextJson();
        ws.sendJson({
          'tokens': <Object>[],
          'error_code': code,
          'error_type': type,
          'error_message': 'Bad key $key',
        });
        await ws.close();
        expect(await got.error(), cloudError(kind), reason: type);
        await got.done();
      }
    });

    test('idle close is sessionEnded; a refused upgrade throws', () async {
      final stream = await provider().openStream(creds, const CloudStreamOptions(language: 'en'));
      final got = Inbox(stream.segments);
      final ws = await peer.future;
      await ws.nextJson();
      await ws.close(WebSocketStatus.goingAway);
      expect(await got.error(), cloudError(CloudAsrErrorKind.sessionEnded));

      reject = 401;
      await expectLater(
        provider().openStream(creds, const CloudStreamOptions(language: 'en')),
        throwsA(cloudError(CloudAsrErrorKind.unauthorized)),
      );
      final dead = SonioxProvider(realtimeUrl: await deadUrl('ws'));
      await expectLater(
        dead.openStream(creds, const CloudStreamOptions(language: 'en')),
        throwsA(cloudError(CloudAsrErrorKind.network)),
      );
    });

    test('keepalive while no audio is sent', () async {
      final stream = await provider(keepAlive: const Duration(milliseconds: 20))
          .openStream(creds, const CloudStreamOptions(language: 'en'));
      final ws = await peer.future;
      await ws.nextJson();
      expect(await ws.nextJson(), {'type': 'keepalive'});
      await stream.cancel();
    });

    test('cancel drops pending results and closes', () async {
      final stream = await provider().openStream(creds, const CloudStreamOptions(language: 'en'));
      final got = Inbox(stream.segments);
      final ws = await peer.future;
      await ws.nextJson();
      await stream.cancel();
      await got.done();
      expect(got.items, isEmpty);
      expect(got.errors, isEmpty);
      await ws.inbox.done();
    });

    test('unsupported language is refused before connecting', () async {
      await expectLater(
        provider().openStream(creds, const CloudStreamOptions(language: 'xx')),
        throwsA(cloudError(CloudAsrErrorKind.unsupportedLanguage)),
      );
      expect(server.requests, isEmpty);
    });
  });

  group('file', () {
    late FakeServer server;
    final log = <String>[];
    var polls = 0;
    var jobStatus = 'completed';
    int createStatus = 201;
    CloudCancelToken? cancelOnPoll;
    Map<String, Object?>? created;
    String? uploadBody;
    String? uploadType;

    setUp(() async {
      log.clear();
      polls = 0;
      jobStatus = 'completed';
      createStatus = 201;
      cancelOnPoll = null;
      server = await FakeServer.start((request) async {
        final path = request.uri.path;
        log.add('${request.method} $path ${request.headers.value('authorization')}');
        switch ((request.method, path)) {
          case ('POST', '/v1/files'):
            uploadType = request.headers.value(HttpHeaders.contentTypeHeader);
            uploadBody = latin1.decode(await readBytes(request));
            await replyJson(
              request,
              '{"id":"file-1","filename":"tinglang.wav","size":1}',
              status: 201,
            );
          case ('POST', '/v1/transcriptions'):
            created = (jsonDecode(await readText(request)) as Map).cast<String, Object?>();
            if (createStatus != 201) {
              await replyJson(
                request,
                jsonEncode({
                  'status_code': createStatus,
                  'error_type': 'organization_balance_exhausted',
                  'message': 'No credit for $key',
                }),
                status: createStatus,
              );
              return;
            }
            await replyJson(request, '{"id":"tr-1","status":"queued"}', status: 201);
          case ('GET', '/v1/transcriptions/tr-1'):
            polls++;
            cancelOnPoll?.cancel();
            final status = polls == 1 ? 'queued' : (polls == 2 ? 'processing' : jobStatus);
            await replyJson(
              request,
              jsonEncode({
                'id': 'tr-1',
                'status': status,
                if (status == 'error') 'error_type': 'invalid_request',
                if (status == 'error') 'error_message': 'Unreadable audio ($key)',
              }),
            );
          case ('GET', '/v1/transcriptions/tr-1/transcript'):
            await replyJson(
              request,
              jsonEncode({
                'id': 'tr-1',
                'text': 'Hello world. How are you?',
                'tokens': [
                  tok('Hel', 120, 200),
                  tok('lo', 200, 380),
                  tok(' world', 420, 800),
                  tok('.', 800, 810),
                  tok(' How', 1500, 1700),
                  tok(' are', 1720, 1900),
                  tok(' you', 1920, 2100),
                  tok('?', 2100, 2110),
                ],
              }),
            );
          case ('DELETE', _):
            request.response.statusCode = 204;
            await request.response.close();
          default:
            request.response.statusCode = 404;
            await request.response.close();
        }
      });
    });
    tearDown(() => server.close());

    SonioxProvider provider() => SonioxProvider(apiBase: server.http, pollInterval: Duration.zero);

    test('upload, create, poll, transcript, then delete both', () async {
      final progress = <double>[];
      final segments = await provider().transcribeFile(
        creds,
        wavRequest(3000, language: 'zh-Hans'),
        onProgress: progress.add,
      );
      expect(log, [
        'POST /v1/files Bearer $key',
        'POST /v1/transcriptions Bearer $key',
        'GET /v1/transcriptions/tr-1 Bearer $key',
        'GET /v1/transcriptions/tr-1 Bearer $key',
        'GET /v1/transcriptions/tr-1 Bearer $key',
        'GET /v1/transcriptions/tr-1/transcript Bearer $key',
        'DELETE /v1/transcriptions/tr-1 Bearer $key',
        'DELETE /v1/files/file-1 Bearer $key',
      ]);
      expect(uploadType, startsWith('multipart/form-data; boundary='));
      expect(
        uploadBody,
        contains('Content-Disposition: form-data; name="file"; filename="tinglang.wav"'),
      );
      expect(uploadBody, contains('RIFF'));
      expect(created, {
        'model': 'stt-async-v5',
        'file_id': 'file-1',
        'language_hints': ['zh'],
      });
      expect(
        [for (final s in segments) (s.id, s.text, s.startMs, s.endMs, s.isFinal)],
        [('0', 'Hello world.', 120, 810, true), ('1', 'How are you?', 1500, 2110, true)],
      );
      expect(segments.first.words!.map((w) => '${w.text}@${w.startMs}-${w.endMs}'), [
        'Hello@120-380',
        'world.@420-810',
      ]);
      expect(progress, isNotEmpty);
      expect(progress.last, 1);
      for (var i = 1; i < progress.length; i++) {
        expect(progress[i], greaterThanOrEqualTo(progress[i - 1]));
      }
    });

    test('without word timestamps', () async {
      final segments = await provider().transcribeFile(creds, wavRequest(1000, words: false));
      expect(segments.every((s) => s.words == null), isTrue);
    });

    test('a failed job maps its error and still cleans up', () async {
      jobStatus = 'error';
      await expectLater(
        provider().transcribeFile(creds, wavRequest(1000)),
        throwsA(cloudError(CloudAsrErrorKind.badRequest)),
      );
      expect(log.where((l) => l.startsWith('DELETE')), hasLength(2));
    });

    test('payment required on create deletes the upload', () async {
      createStatus = 402;
      await expectLater(
        provider().transcribeFile(creds, wavRequest(1000)),
        throwsA(cloudError(CloudAsrErrorKind.quotaExceeded)),
      );
      expect(log.last, 'DELETE /v1/files/file-1 Bearer $key');
    });

    test('cancel while polling stops and cleans up', () async {
      final token = CloudCancelToken();
      cancelOnPoll = token;
      await expectLater(
        provider().transcribeFile(creds, wavRequest(1000), cancel: token),
        throwsA(cloudError(CloudAsrErrorKind.cancelled)),
      );
      expect(log.where((l) => l.startsWith('DELETE')), hasLength(2));
    });

    test('limits and languages are checked before anything is sent', () async {
      await expectLater(
        provider().transcribeFile(creds, wavRequest(1000, language: 'xx')),
        throwsA(cloudError(CloudAsrErrorKind.unsupportedLanguage)),
      );
      final tooLong = CloudFileRequest(
        wav: wavFromPcm16(pcm(10)),
        durationMs: 241 * 60 * 1000,
        language: 'en',
      );
      await expectLater(
        provider().transcribeFile(creds, tooLong),
        throwsA(cloudError(CloudAsrErrorKind.audioTooLong)),
      );
      final cancelled = CloudCancelToken()..cancel();
      await expectLater(
        provider().transcribeFile(creds, wavRequest(1000), cancel: cancelled),
        throwsA(cloudError(CloudAsrErrorKind.cancelled)),
      );
      expect(server.requests, isEmpty);
    });
  });
}

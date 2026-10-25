import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:tinglang_cloud_asr/src/providers/assemblyai.dart';
import 'package:tinglang_cloud_asr/tinglang_cloud_asr.dart';

import 'support/fake_server.dart';
import 'support/ws_peer.dart';

// A made-up key: tests never use real credentials.
const key = 'aai-test-key-0123456789abcdef0123';
const creds = {CloudFieldKeys.apiKey: key};

Matcher cloudError(CloudAsrErrorKind kind) => isA<CloudAsrError>()
    .having((e) => e.kind, 'kind', kind)
    .having((e) => e.message, 'message', isNot(contains(key)))
    .having((e) => e.toString(), 'toString', isNot(contains(key)));

Map<String, Object?> word(String text, int start, int end, {bool fin = true}) => {
  'text': text,
  'start': start,
  'end': end,
  'confidence': 0.9,
  'word_is_final': fin,
};

Map<String, Object?> turn(
  int order,
  String transcript,
  List<Map<String, Object?>> words, {
  bool end = false,
  bool formatted = false,
}) => {
  'type': 'Turn',
  'turn_order': order,
  'turn_is_formatted': formatted,
  'end_of_turn': end,
  'transcript': transcript,
  'end_of_turn_confidence': end ? 1 : 0,
  'words': words,
  'utterance': end ? transcript : '',
};

void main() {
  group('info', () {
    test('registry, fields, regions, languages', () {
      final p = CloudAsrProviders.byId('assemblyai');
      expect(p, isA<AssemblyAiProvider>());
      final fields = p!.info.fields;
      expect(fields.map((f) => f.key), [CloudFieldKeys.apiKey, CloudFieldKeys.region]);
      expect(fields[1].kind, CloudFieldKind.choice);
      expect(fields[1].choices, ['us', 'eu']);
      expect(fields[1].defaultValue, 'us');
      expect(p.info.languages, containsAll(['en', 'zh', 'ja', 'ko', 'es', 'fr', 'de']));
      expect(p.info.languages, isNot(contains('yue')), reason: 'no file model for Cantonese');
      expect(p.hosts(creds), ['api.assemblyai.com', 'streaming.us.assemblyai.com']);
      expect(p.hosts({...creds, CloudFieldKeys.region: 'us'}), [
        'api.assemblyai.com',
        'streaming.us.assemblyai.com',
      ]);
      expect(p.hosts({...creds, CloudFieldKeys.region: 'eu'}), [
        'api.eu.assemblyai.com',
        'streaming.eu.assemblyai.com',
      ]);
    });

    test('no HttpClient exists before a call; a call creates one', () async {
      expect(
        await countHttpClients(() {
          final p = AssemblyAiProvider();
          p.info;
          p.hosts(creds);
        }),
        0,
      );
      final dead = AssemblyAiProvider(apiBase: await deadUrl('http'));
      expect(
        await countHttpClients(() async {
          await expectLater(dead.verify(creds), throwsA(cloudError(CloudAsrErrorKind.network)));
        }),
        1,
      );
    });

    test('language mapping', () {
      expect(AssemblyAiProvider.fileLanguage('en'), 'en');
      expect(AssemblyAiProvider.fileLanguage('en-US'), 'en_us');
      expect(AssemblyAiProvider.fileLanguage('en-GB'), 'en_uk');
      expect(AssemblyAiProvider.fileLanguage('zh-Hans'), 'zh');
      expect(AssemblyAiProvider.streamingLanguage('en-GB'), 'en');
      expect(AssemblyAiProvider.streamingLanguage('zh-Hans'), 'zh');
      for (final l in ['ja', 'ko', 'es', 'fr', 'de']) {
        expect(AssemblyAiProvider.fileLanguage(l), l);
        expect(AssemblyAiProvider.streamingLanguage(l), l);
      }
      expect(
        () => AssemblyAiProvider.streamingLanguage('pl'),
        throwsA(cloudError(CloudAsrErrorKind.unsupportedLanguage)),
      );
      expect(
        () => AssemblyAiProvider.fileLanguage('xx'),
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
        await replyJson(
          request,
          status == 200 ? '{"transcripts":[]}' : jsonEncode({'error': 'Invalid API key $key'}),
          status: status,
        );
      });
    });
    tearDown(() => server.close());

    test('lists one transcript with the raw key', () async {
      await AssemblyAiProvider(apiBase: server.http).verify(creds);
      final r = server.requests.single;
      expect((r.method, r.uri.path), ('GET', '/v2/transcript'));
      expect(r.uri.queryParameters, {'limit': '1'});
      expect(auth, key, reason: 'no Bearer prefix');
    });

    test('maps HTTP errors and never shows the key', () async {
      for (final (s, kind) in [
        (401, CloudAsrErrorKind.unauthorized),
        (402, CloudAsrErrorKind.quotaExceeded),
        (429, CloudAsrErrorKind.rateLimited),
        (500, CloudAsrErrorKind.server),
        (503, CloudAsrErrorKind.server),
      ]) {
        status = s;
        await expectLater(
          AssemblyAiProvider(apiBase: server.http).verify(creds),
          throwsA(cloudError(kind)),
          reason: '$s',
        );
      }
    });
  });

  group('stream', () {
    late FakeServer server;
    late Completer<WsPeer> peer;
    late Uri connected;
    String? auth;
    int? reject;

    setUp(() async {
      reject = null;
      peer = Completer<WsPeer>();
      server = await FakeServer.start((request) async {
        auth = request.headers.value(HttpHeaders.authorizationHeader);
        connected = request.uri;
        if (reject != null) {
          request.response.statusCode = reject!;
          await request.response.close();
          return;
        }
        peer.complete(await upgrade(request));
      });
    });
    tearDown(() => server.close());

    AssemblyAiProvider provider() => AssemblyAiProvider(
      streamingUrl: server.ws.replace(path: '/v3/ws'),
      readyTimeout: const Duration(seconds: 2),
    );

    /// Opens a stream; the fake server answers with Begin.
    Future<(CloudAsrStream, WsPeer)> open({String language = 'en'}) async {
      final opening = provider().openStream(creds, CloudStreamOptions(language: language));
      final ws = await peer.future;
      ws.sendJson({'type': 'Begin', 'id': 'session-1', 'expires_at': 1});
      return (await opening, ws);
    }

    test('connects with the documented query, re-chunks audio, partials then finals', () async {
      final (stream, ws) = await open(language: 'ja');
      expect(connected.path, '/v3/ws');
      expect(connected.queryParameters, {
        'sample_rate': '16000',
        'encoding': 'pcm_s16le',
        'speech_model': 'universal-3-6-pro',
        'language_codes': '["ja"]',
      });
      expect(auth, key);
      expect(connected.toString(), isNot(contains(key)));
      final got = Inbox(stream.segments);

      // 40 ms chunks become 100 ms frames (the service wants 50–1000 ms).
      for (var i = 0; i < 5; i++) {
        stream.addPcm(pcm(40));
      }
      expect((await ws.nextBinary()).length, 3200);
      expect((await ws.nextBinary()).length, 3200);

      ws.sendJson({'type': 'SpeechStarted', 'timestamp': 1200, 'confidence': 0.9});
      ws.sendJson(turn(0, '', [word('My', 1216, 1627, fin: false)]));
      var s = await got.next();
      expect((s.id, s.isFinal, s.text, s.startMs, s.endMs), ('0', false, 'My', 1216, 1627));
      ws.sendJson(turn(0, 'My', [word('My', 1216, 1627), word('name', 1668, 2490, fin: false)]));
      s = await got.next();
      expect((s.id, s.isFinal, s.text), ('0', false, 'My name'));
      ws.sendJson(
        turn(
          0,
          'My name is Sonny.',
          [
            word('My', 1216, 1635),
            word('name', 1676, 2515),
            word('is', 2556, 2975),
            word('Sonny.', 3016, 4155),
          ],
          end: true,
          formatted: true,
        ),
      );
      s = await got.next();
      expect(
        (s.id, s.isFinal, s.text, s.startMs, s.endMs),
        ('0', true, 'My name is Sonny.', 1216, 4155),
      );
      expect(s.words!.map((w) => w.text), ['My', 'name', 'is', 'Sonny.']);
      // A late copy of a finished turn is ignored.
      ws.sendJson(
        turn(0, 'My name is Sonny.', [word('My', 1216, 1635)], end: true, formatted: true),
      );
      ws.sendJson(turn(1, '', [word('Hi', 5000, 5200, fin: false)]));
      s = await got.next();
      expect((s.id, s.isFinal, s.text), ('1', false, 'Hi'));

      stream.addPcm(pcm(10)); // 10 ms left over: padded to 50 ms at the end
      final finishing = stream.finish();
      expect((await ws.nextBinary()).length, 1600);
      expect(await ws.nextJson(), {'type': 'ForceEndpoint'});
      expect(await ws.nextJson(), {'type': 'Terminate'});
      ws.sendJson(turn(1, 'Hi.', [word('Hi.', 5000, 5200)], end: true, formatted: true));
      ws.sendJson({
        'type': 'Termination',
        'audio_duration_seconds': 6,
        'session_duration_seconds': 6,
      });
      await ws.close();
      await finishing;
      s = await got.next();
      expect((s.id, s.isFinal, s.text), ('1', true, 'Hi.'));
      await got.done();
      expect(got.errors, isEmpty);
    });

    test('refusals during the handshake throw from openStream', () async {
      for (final (code, text, kind) in [
        (1008, 'Unauthorized Connection: Invalid API key', CloudAsrErrorKind.unauthorized),
        (
          1008,
          'Unauthorized Connection: Too many concurrent sessions',
          CloudAsrErrorKind.rateLimited,
        ),
        (1008, 'Unauthorized Connection: Insufficient funds', CloudAsrErrorKind.quotaExceeded),
        (3005, 'Session Cancelled: An error occurred', CloudAsrErrorKind.server),
      ]) {
        peer = Completer<WsPeer>();
        final opening = provider().openStream(creds, const CloudStreamOptions(language: 'en'));
        final ws = await peer.future;
        ws.sendJson({'type': 'Error', 'error_code': code, 'error': '$text ($key)'});
        await ws.close(code, 'See Error message for details.');
        await expectLater(opening, throwsA(cloudError(kind)), reason: text);
      }
      // Closed with only a close code and reason.
      peer = Completer<WsPeer>();
      final opening = provider().openStream(creds, const CloudStreamOptions(language: 'en'));
      await (await peer.future).close(1008, 'Unauthorized Connection: Invalid API key');
      await expectLater(opening, throwsA(cloudError(CloudAsrErrorKind.unauthorized)));

      reject = 401;
      await expectLater(
        provider().openStream(creds, const CloudStreamOptions(language: 'en')),
        throwsA(cloudError(CloudAsrErrorKind.unauthorized)),
      );
    });

    test('the session time limit is sessionEnded', () async {
      final (stream, ws) = await open();
      final got = Inbox(stream.segments);
      ws.sendJson({
        'type': 'Error',
        'error_code': 3008,
        'error': 'Session Expired: Maximum session duration exceeded',
      });
      await ws.close(3008);
      final e = await got.error();
      expect(e, cloudError(CloudAsrErrorKind.sessionEnded));
      expect((e as CloudAsrError).retryable, isTrue);
      await got.done();
    });

    test('cancel closes without results', () async {
      final (stream, ws) = await open();
      final got = Inbox(stream.segments);
      await stream.cancel();
      await got.done();
      expect(got.items, isEmpty);
      await ws.inbox.done();
    });

    test('unsupported language is refused before connecting', () async {
      await expectLater(
        provider().openStream(creds, const CloudStreamOptions(language: 'pl')),
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
    var uploadStatus = 200;
    CloudCancelToken? cancelOnPoll;
    Map<String, Object?>? created;
    List<int>? uploaded;
    String? uploadType;

    setUp(() async {
      log.clear();
      polls = 0;
      jobStatus = 'completed';
      uploadStatus = 200;
      cancelOnPoll = null;
      server = await FakeServer.start((request) async {
        final path = request.uri.path;
        log.add('${request.method} $path ${request.headers.value('authorization')}');
        switch ((request.method, path)) {
          case ('POST', '/v2/upload'):
            uploadType = request.headers.value(HttpHeaders.contentTypeHeader);
            uploaded = await readBytes(request);
            if (uploadStatus != 200) {
              await replyJson(
                request,
                jsonEncode({'error': 'Too many requests for $key'}),
                status: uploadStatus,
              );
              return;
            }
            await replyJson(request, '{"upload_url":"https://cdn.example/upload/abc"}');
          case ('POST', '/v2/transcript'):
            created = (jsonDecode(await readText(request)) as Map).cast<String, Object?>();
            await replyJson(request, '{"id":"t-1","status":"queued"}');
          case ('GET', '/v2/transcript/t-1'):
            polls++;
            cancelOnPoll?.cancel();
            final status = polls == 1 ? 'processing' : jobStatus;
            await replyJson(
              request,
              jsonEncode({
                'id': 't-1',
                'status': status,
                if (status == 'error') 'error': 'File does not appear to contain audio ($key)',
              }),
            );
          case ('GET', '/v2/transcript/t-1/sentences'):
            await replyJson(
              request,
              jsonEncode({
                'id': 't-1',
                'confidence': 0.9,
                'audio_duration': 3,
                'sentences': [
                  {
                    'text': 'Smoke from fires.',
                    'start': 250,
                    'end': 1650,
                    'confidence': 0.9,
                    'speaker': null,
                    'words': [
                      {
                        'text': 'Smoke',
                        'start': 250,
                        'end': 650,
                        'confidence': 0.9,
                        'speaker': null,
                      },
                      {'text': 'from', 'start': 730, 'end': 1022, 'confidence': 1, 'speaker': null},
                      {
                        'text': 'fires.',
                        'start': 1076,
                        'end': 1650,
                        'confidence': 1,
                        'speaker': null,
                      },
                    ],
                  },
                  {
                    'text': 'Skies are gray.',
                    'start': 2000,
                    'end': 2900,
                    'confidence': 0.9,
                    'speaker': null,
                    'words': <Object>[],
                  },
                ],
              }),
            );
          case ('DELETE', '/v2/transcript/t-1'):
            await replyJson(request, '{"id":"t-1","status":"completed","text":"Deleted by user."}');
          default:
            await replyJson(request, '{"error":"not found"}', status: 404);
        }
      });
    });
    tearDown(() => server.close());

    AssemblyAiProvider provider() =>
        AssemblyAiProvider(apiBase: server.http, pollInterval: Duration.zero);

    test('upload, create, poll, sentences, then delete', () async {
      final progress = <double>[];
      final request = wavRequest(3000, language: 'en-GB');
      final segments = await provider().transcribeFile(creds, request, onProgress: progress.add);
      expect(log, [
        'POST /v2/upload $key',
        'POST /v2/transcript $key',
        'GET /v2/transcript/t-1 $key',
        'GET /v2/transcript/t-1 $key',
        'GET /v2/transcript/t-1/sentences $key',
        'DELETE /v2/transcript/t-1 $key',
      ]);
      expect(uploadType, 'application/octet-stream');
      expect(uploaded, request.wav);
      expect(created, {
        'audio_url': 'https://cdn.example/upload/abc',
        'speech_models': ['universal-3-5-pro', 'universal-2'],
        'language_code': 'en_uk',
        'punctuate': true,
        'format_text': true,
      });
      expect(
        [for (final s in segments) (s.id, s.text, s.startMs, s.endMs, s.isFinal)],
        [('0', 'Smoke from fires.', 250, 1650, true), ('1', 'Skies are gray.', 2000, 2900, true)],
      );
      expect(segments.first.words!.map((w) => '${w.text}@${w.startMs}-${w.endMs}'), [
        'Smoke@250-650',
        'from@730-1022',
        'fires.@1076-1650',
      ]);
      expect(progress.last, 1);
    });

    test('a failed job maps its error and still deletes the transcript', () async {
      jobStatus = 'error';
      await expectLater(
        provider().transcribeFile(creds, wavRequest(1000)),
        throwsA(cloudError(CloudAsrErrorKind.badRequest)),
      );
      expect(log.last, 'DELETE /v2/transcript/t-1 $key');
    });

    test('rate limit on upload', () async {
      uploadStatus = 429;
      await expectLater(
        provider().transcribeFile(creds, wavRequest(1000)),
        throwsA(cloudError(CloudAsrErrorKind.rateLimited)),
      );
      expect(log, ['POST /v2/upload $key']);
    });

    test('cancel while polling stops and deletes', () async {
      final token = CloudCancelToken();
      cancelOnPoll = token;
      await expectLater(
        provider().transcribeFile(creds, wavRequest(1000), cancel: token),
        throwsA(cloudError(CloudAsrErrorKind.cancelled)),
      );
      expect(log.last, 'DELETE /v2/transcript/t-1 $key');
    });

    test('EU region uses the EU host; network failure', () async {
      final p = AssemblyAiProvider();
      expect(p.hosts({...creds, CloudFieldKeys.region: 'eu'}).first, 'api.eu.assemblyai.com');
      final dead = AssemblyAiProvider(apiBase: await deadUrl('http'));
      await expectLater(
        dead.transcribeFile(creds, wavRequest(1000)),
        throwsA(cloudError(CloudAsrErrorKind.network)),
      );
    });
  });
}

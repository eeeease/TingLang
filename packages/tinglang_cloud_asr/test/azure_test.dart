import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:tinglang_cloud_asr/src/providers/azure.dart';
import 'package:tinglang_cloud_asr/tinglang_cloud_asr.dart';

import 'support/fake_server.dart';
import 'support/ws_peer.dart';

// A made-up key: tests never use real credentials.
const key = 'azure-test-key-0123456789abcdef01';
const creds = {CloudFieldKeys.apiKey: key, CloudFieldKeys.region: 'westeurope'};

Matcher cloudError(CloudAsrErrorKind kind) => isA<CloudAsrError>()
    .having((e) => e.kind, 'kind', kind)
    .having((e) => e.message, 'message', isNot(contains(key)))
    .having((e) => e.toString(), 'toString', isNot(contains(key)));

/// A protocol message as the fake service reads it.
typedef Msg = ({Map<String, String> headers, Uint8List body});

/// Parses a client message independently of the adapter: text messages split
/// at the first blank line; binary ones start with a big-endian header length.
Msg parseClient(Object? data) {
  if (data is String) {
    final split = data.indexOf('\r\n\r\n');
    return (
      headers: _headers(data.substring(0, split)),
      body: utf8.encode(data.substring(split + 4)),
    );
  }
  final bytes = Uint8List.fromList(data! as List<int>);
  final len = (bytes[0] << 8) | bytes[1];
  return (
    headers: _headers(ascii.decode(bytes.sublist(2, 2 + len))),
    body: Uint8List.sublistView(bytes, 2 + len),
  );
}

Map<String, String> _headers(String head) => {
  for (final line in head.split('\r\n'))
    if (line.contains(':'))
      line.substring(0, line.indexOf(':')).toLowerCase(): line
          .substring(line.indexOf(':') + 1)
          .trim(),
};

/// A service text message.
String serviceMessage(String path, Object body, {String requestId = 'R'}) =>
    'X-RequestId:$requestId\r\nContent-Type:application/json; charset=utf-8\r\nPath:$path\r\n\r\n'
    '${jsonEncode(body)}';

void main() {
  group('info and region', () {
    test('registry, fields, languages, hosts', () {
      final p = CloudAsrProviders.byId('azure');
      expect(p, isA<AzureSpeechProvider>());
      expect(p!.info.fields.map((f) => (f.key, f.kind)), [
        (CloudFieldKeys.apiKey, CloudFieldKind.secret),
        (CloudFieldKeys.region, CloudFieldKind.text),
      ]);
      expect(p.info.languages, containsAll(['en', 'zh', 'ja', 'ko', 'es', 'fr', 'de']));
      expect(p.info.maxFileMs, 2 * 60 * 60 * 1000);
      expect(p.hosts(creds), [
        'westeurope.api.cognitive.microsoft.com',
        'westeurope.stt.speech.microsoft.com',
      ]);
    });

    test('no HttpClient exists before a call', () async {
      final n = await countHttpClients(() {
        final p = AzureSpeechProvider();
        p.info;
        p.hosts(creds);
      });
      expect(n, 0);
    });

    test('region must be a plain region name', () {
      String region(String r) => AzureSpeechProvider.region({...creds, CloudFieldKeys.region: r});
      expect(region('eastus'), 'eastus');
      expect(region(' East US '), 'eastus');
      expect(region('westus3'), 'westus3');
      for (final bad in [
        'evil.com',
        'eastus.attacker.net',
        'eastus/../x',
        'eastus:443',
        'user@eastus',
        'east-us',
        'east_us',
        'e',
        '3eastus',
        'eastus?x=1',
        'eastus#',
        'usgovvirginia',
        'chinaeast2',
      ]) {
        expect(() => region(bad), throwsA(cloudError(CloudAsrErrorKind.unauthorized)), reason: bad);
        expect(AzureSpeechProvider().hosts({...creds, CloudFieldKeys.region: bad}), isEmpty);
      }
      expect(
        () => AzureSpeechProvider.region({CloudFieldKeys.apiKey: key}),
        throwsA(cloudError(CloudAsrErrorKind.unauthorized)),
      );
    });

    test('locales', () {
      expect(AzureSpeechProvider.locale('en'), 'en-US');
      expect(AzureSpeechProvider.locale('en-US'), 'en-US');
      expect(AzureSpeechProvider.locale('en-GB'), 'en-GB');
      expect(AzureSpeechProvider.locale('en_gb'), 'en-GB');
      expect(AzureSpeechProvider.locale('zh-Hans'), 'zh-CN');
      expect(AzureSpeechProvider.locale('ja'), 'ja-JP');
      expect(AzureSpeechProvider.locale('ko'), 'ko-KR');
      expect(AzureSpeechProvider.locale('es'), 'es-ES');
      expect(AzureSpeechProvider.locale('es-MX'), 'es-MX');
      expect(AzureSpeechProvider.locale('fr'), 'fr-FR');
      expect(AzureSpeechProvider.locale('de'), 'de-DE');
      expect(
        () => AzureSpeechProvider.locale('xx'),
        throwsA(cloudError(CloudAsrErrorKind.unsupportedLanguage)),
      );
    });
  });

  group('verify', () {
    late FakeServer server;
    var status = 200;
    String? subscriptionKey;
    setUp(() async {
      status = 200;
      server = await FakeServer.start((request) async {
        subscriptionKey = request.headers.value('Ocp-Apim-Subscription-Key');
        if (status == 200) {
          request.response.write('eyJ.token.value');
          await request.response.close();
          return;
        }
        await replyJson(
          request,
          jsonEncode({
            'error': {
              'code': '$status',
              'message': status == 403
                  ? 'Out of call volume quota for $key. Quota will be replenished in 2 days.'
                  : 'Access denied due to invalid subscription key $key or wrong API endpoint.',
            },
          }),
          status: status,
        );
      });
    });
    tearDown(() => server.close());

    test('exchanges the key for a token and discards it', () async {
      await AzureSpeechProvider(restBase: server.http).verify(creds);
      final r = server.requests.single;
      expect((r.method, r.uri.path), ('POST', '/sts/v1.0/issueToken'));
      expect(subscriptionKey, key);
    });

    test('maps errors and never shows the key', () async {
      for (final (s, kind) in [
        (401, CloudAsrErrorKind.unauthorized),
        (403, CloudAsrErrorKind.quotaExceeded),
        (429, CloudAsrErrorKind.rateLimited),
        (500, CloudAsrErrorKind.server),
      ]) {
        status = s;
        await expectLater(
          AzureSpeechProvider(restBase: server.http).verify(creds),
          throwsA(cloudError(kind)),
          reason: '$s',
        );
      }
      final dead = AzureSpeechProvider(restBase: await deadUrl('http'));
      await expectLater(dead.verify(creds), throwsA(cloudError(CloudAsrErrorKind.network)));
      // A bad region never reaches the network.
      await expectLater(
        AzureSpeechProvider(restBase: server.http).verify({...creds, CloudFieldKeys.region: 'x.y'}),
        throwsA(cloudError(CloudAsrErrorKind.unauthorized)),
      );
    });
  });

  group('file (fast transcription)', () {
    late FakeServer server;
    var status = 200;
    Map<String, Object?>? errorBody;
    String? body;
    String? contentType;
    Uri? called;
    CloudCancelToken? cancelOnRequest;

    setUp(() async {
      status = 200;
      errorBody = null;
      cancelOnRequest = null;
      server = await FakeServer.start((request) async {
        called = request.uri;
        contentType = request.headers.value(HttpHeaders.contentTypeHeader);
        body = latin1.decode(await readBytes(request));
        if (cancelOnRequest != null) {
          cancelOnRequest!.cancel();
          await Future<void>.delayed(const Duration(milliseconds: 200));
        }
        if (status != 200) {
          await replyJson(request, jsonEncode(errorBody), status: status);
          return;
        }
        await replyJson(
          request,
          jsonEncode({
            'durationMilliseconds': 4000,
            'combinedPhrases': [
              {'text': 'Good afternoon. How can I help?'},
            ],
            'phrases': [
              {
                'offsetMilliseconds': 960,
                'durationMilliseconds': 640,
                'text': 'Good afternoon.',
                'words': [
                  {'text': 'Good', 'offsetMilliseconds': 960, 'durationMilliseconds': 240},
                  {'text': 'afternoon.', 'offsetMilliseconds': 1200, 'durationMilliseconds': 400},
                ],
                'locale': 'en-GB',
                'confidence': 0.93,
              },
              {
                'offsetMilliseconds': 2000,
                'durationMilliseconds': 1500,
                'text': 'How can I help?',
                'words': [
                  {'text': 'How', 'offsetMilliseconds': 2000, 'durationMilliseconds': 300},
                ],
                'locale': 'en-GB',
                'confidence': 0.9,
              },
            ],
          }),
        );
      });
    });
    tearDown(() => server.close());

    AzureSpeechProvider provider() => AzureSpeechProvider(restBase: server.http);

    test('one multipart request: audio and definition; phrases become segments', () async {
      final progress = <double>[];
      final segments = await provider().transcribeFile(
        creds,
        wavRequest(4000, language: 'en-GB'),
        onProgress: progress.add,
      );
      expect(server.requests, hasLength(1));
      expect(called!.path, '/speechtotext/transcriptions:transcribe');
      expect(called!.queryParameters, {'api-version': '2025-10-15'});
      expect(server.requests.single.headers.value('Ocp-Apim-Subscription-Key'), key);
      expect(contentType, startsWith('multipart/form-data; boundary='));
      expect(
        body,
        contains('Content-Disposition: form-data; name="audio"; filename="tinglang.wav"'),
      );
      expect(body, contains('RIFF'));
      expect(body, contains('Content-Disposition: form-data; name="definition"'));
      expect(body, contains('{"locales":["en-GB"],"profanityFilterMode":"None"}'));
      expect(
        [for (final s in segments) (s.id, s.text, s.startMs, s.endMs, s.language)],
        [
          ('0', 'Good afternoon.', 960, 1600, 'en-GB'),
          ('1', 'How can I help?', 2000, 3500, 'en-GB'),
        ],
      );
      expect(segments.first.words!.map((w) => '${w.text}@${w.startMs}-${w.endMs}'), [
        'Good@960-1200',
        'afternoon.@1200-1600',
      ]);
      expect(progress.last, 1);
    });

    test('maps error codes and never shows the key', () async {
      for (final (s, code, kind) in [
        (400, 'AudioLengthLimitExceeded', CloudAsrErrorKind.audioTooLong),
        (400, 'InvalidLocale', CloudAsrErrorKind.unsupportedLanguage),
        (400, 'InvalidAudioFormat', CloudAsrErrorKind.badRequest),
        (401, null, CloudAsrErrorKind.unauthorized),
        (429, null, CloudAsrErrorKind.rateLimited),
        (503, null, CloudAsrErrorKind.server),
      ]) {
        status = s;
        errorBody = {
          'error': {
            'code': 'InvalidRequest',
            'message': 'Request failed for key $key',
            if (code != null) 'innerError': {'code': code, 'message': 'Detail for $key'},
          },
        };
        await expectLater(
          provider().transcribeFile(creds, wavRequest(1000)),
          throwsA(cloudError(kind)),
          reason: '$s $code',
        );
      }
    });

    test('cancel aborts the request', () async {
      final token = CloudCancelToken();
      cancelOnRequest = token;
      await expectLater(
        provider().transcribeFile(creds, wavRequest(1000), cancel: token),
        throwsA(cloudError(CloudAsrErrorKind.cancelled)),
      );
    });

    test('limits, language and region are checked before sending', () async {
      await expectLater(
        provider().transcribeFile(
          creds,
          CloudFileRequest(
            wav: wavFromPcm16(pcm(10)),
            durationMs: 3 * 60 * 60 * 1000,
            language: 'en',
          ),
        ),
        throwsA(cloudError(CloudAsrErrorKind.audioTooLong)),
      );
      await expectLater(
        provider().transcribeFile(creds, wavRequest(1000, language: 'xx')),
        throwsA(cloudError(CloudAsrErrorKind.unsupportedLanguage)),
      );
      await expectLater(
        provider().transcribeFile({...creds, CloudFieldKeys.region: 'a.b'}, wavRequest(1000)),
        throwsA(cloudError(CloudAsrErrorKind.unauthorized)),
      );
      expect(server.requests, isEmpty);
    });
  });

  group('live (Speech service WebSocket protocol)', () {
    late FakeServer server;
    late Completer<WsPeer> peer;
    late HttpHeaders upgradeHeaders;
    late Uri connected;
    int? reject;

    setUp(() async {
      reject = null;
      peer = Completer<WsPeer>();
      server = await FakeServer.start((request) async {
        upgradeHeaders = request.headers;
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

    AzureSpeechProvider provider() => AzureSpeechProvider(
      speechBase: server.ws,
      now: () => DateTime.utc(2026, 10, 25, 1, 2, 3, 45),
    );

    test('config, WAV header, framed audio, hypotheses then phrases, end of audio', () async {
      final stream = await provider().openStream(
        creds,
        const CloudStreamOptions(language: 'en-GB'),
      );
      final got = Inbox(stream.segments);
      final ws = await peer.future;
      expect(connected.path, '/speech/recognition/conversation/cognitiveservices/v1');
      expect(connected.queryParameters, {
        'language': 'en-GB',
        'format': 'detailed',
        'profanity': 'raw',
        'wordLevelTimestamps': 'true',
      });
      expect(connected.toString(), isNot(contains(key)));
      expect(upgradeHeaders.value('Ocp-Apim-Subscription-Key'), key);
      expect(upgradeHeaders.value('X-ConnectionId'), matches(RegExp(r'^[0-9A-F]{32}$')));

      final config = parseClient(await ws.inbox.next());
      expect(config.headers['path'], 'speech.config');
      expect(config.headers['content-type'], 'application/json');
      expect(config.headers['x-timestamp'], '2026-10-25T01:02:03.045Z');
      final requestId = config.headers['x-requestid']!;
      expect(requestId, matches(RegExp(r'^[0-9A-F]{32}$')));
      expect(
        jsonDecode(utf8.decode(config.body)),
        containsPair('context', isA<Map<String, Object?>>()),
      );

      final header = parseClient(await ws.inbox.next());
      expect(header.headers['path'], 'audio');
      expect(header.headers['x-requestid'], requestId);
      expect(header.headers['content-type'], 'audio/x-wav');
      expect(String.fromCharCodes(header.body.sublist(0, 4)), 'RIFF');
      expect(ByteData.sublistView(header.body).getUint32(24, Endian.little), 16000);

      stream.addPcm(pcm(100));
      final audio = parseClient(await ws.inbox.next());
      expect(
        (audio.headers['path'], audio.headers['x-requestid'], audio.body.length),
        ('audio', requestId, 3200),
      );
      expect(audio.headers.containsKey('content-type'), isFalse);

      ws.send(
        serviceMessage('turn.start', {
          'context': {'serviceTag': 'tag'},
        }),
      );
      ws.send(serviceMessage('speech.startDetected', {'Offset': 5000000}));
      ws.send(
        serviceMessage('speech.hypothesis', {
          'Text': 'good',
          'Offset': 9600000,
          'Duration': 2400000,
        }),
      );
      var s = await got.next();
      expect((s.id, s.isFinal, s.text, s.startMs, s.endMs), ('0', false, 'good', 960, 1200));
      ws.send(
        serviceMessage('speech.hypothesis', {
          'Text': 'good afternoon',
          'Offset': '9600000',
          'Duration': '6400000',
        }),
      );
      s = await got.next();
      expect(
        (s.id, s.isFinal, s.text, s.startMs, s.endMs),
        ('0', false, 'good afternoon', 960, 1600),
      );
      ws.send(
        serviceMessage('speech.phrase', {
          'RecognitionStatus': 'Success',
          'Offset': 9600000,
          'Duration': 6400000,
          'DisplayText': 'Good afternoon.',
          'NBest': [
            {
              'Confidence': 0.95,
              'Lexical': 'good afternoon',
              'Display': 'Good afternoon.',
              'Words': [
                {'Word': 'good', 'Offset': 9600000, 'Duration': 2400000},
                {'Word': 'afternoon', 'Offset': 12000000, 'Duration': 4000000},
              ],
            },
          ],
        }),
      );
      s = await got.next();
      expect(
        (s.id, s.isFinal, s.text, s.startMs, s.endMs),
        ('0', true, 'Good afternoon.', 960, 1600),
      );
      expect(s.words!.map((w) => '${w.text}@${w.startMs}-${w.endMs}'), [
        'good@960-1200',
        'afternoon@1200-1600',
      ]);
      ws.send(
        serviceMessage('speech.phrase', {
          'RecognitionStatus': 'NoMatch',
          'Offset': 0,
          'Duration': 0,
        }),
      );
      ws.send(
        serviceMessage('speech.hypothesis', {
          'Text': 'how',
          'Offset': 20000000,
          'Duration': 3000000,
        }),
      );
      s = await got.next();
      expect((s.id, s.isFinal, s.text), ('1', false, 'how'));

      final finishing = stream.finish();
      final end = parseClient(await ws.inbox.next());
      expect(
        (end.headers['path'], end.headers['x-requestid'], end.body.length),
        ('audio', requestId, 0),
      );
      ws.send(
        serviceMessage('speech.phrase', {
          'RecognitionStatus': 'Success',
          'Offset': 20000000,
          'Duration': 10000000,
          'NBest': [
            {'Confidence': 0.9, 'Display': 'How can I help?'},
          ],
        }),
      );
      ws.send(serviceMessage('speech.endDetected', {'Offset': 30000000}));
      ws.send(serviceMessage('turn.end', {}));
      await finishing;
      s = await got.next();
      expect(
        (s.id, s.isFinal, s.text, s.startMs, s.endMs),
        ('1', true, 'How can I help?', 2000, 3000),
      );
      expect(s.words, isNull);
      await got.done();
      expect(got.errors, isEmpty);
      await ws.inbox.done();
    });

    test('a turn.end or close before finish is sessionEnded', () async {
      var stream = await provider().openStream(creds, const CloudStreamOptions(language: 'en'));
      var got = Inbox(stream.segments);
      var ws = await peer.future;
      ws.send(serviceMessage('turn.end', {}));
      expect(await got.error(), cloudError(CloudAsrErrorKind.sessionEnded));

      peer = Completer<WsPeer>();
      stream = await provider().openStream(creds, const CloudStreamOptions(language: 'en'));
      got = Inbox(stream.segments);
      ws = await peer.future;
      await ws.close(WebSocketStatus.normalClosure, 'Exceeded maximum connection time');
      expect(await got.error(), cloudError(CloudAsrErrorKind.sessionEnded));
    });

    test('close codes and failure statuses are mapped', () async {
      for (final (code, reason, kind) in [
        (1007, 'Quota exceeded.', CloudAsrErrorKind.quotaExceeded),
        (1007, 'Too many concurrent requests', CloudAsrErrorKind.rateLimited),
        (1007, 'Invalid audio header', CloudAsrErrorKind.badRequest),
        (1008, 'Policy violation for $key', CloudAsrErrorKind.unauthorized),
        (1011, 'Internal error', CloudAsrErrorKind.server),
      ]) {
        peer = Completer<WsPeer>();
        final stream = await provider().openStream(creds, const CloudStreamOptions(language: 'en'));
        final got = Inbox(stream.segments);
        await (await peer.future).close(code, reason);
        expect(await got.error(), cloudError(kind), reason: reason);
      }
      peer = Completer<WsPeer>();
      final stream = await provider().openStream(creds, const CloudStreamOptions(language: 'en'));
      final got = Inbox(stream.segments);
      (await peer.future).send(
        serviceMessage('speech.phrase', {'RecognitionStatus': 'TooManyRequests'}),
      );
      expect(await got.error(), cloudError(CloudAsrErrorKind.rateLimited));
    });

    test('a refused upgrade throws from openStream', () async {
      for (final (status, kind) in [
        (401, CloudAsrErrorKind.unauthorized),
        (403, CloudAsrErrorKind.unauthorized),
        (429, CloudAsrErrorKind.rateLimited),
        (500, CloudAsrErrorKind.server),
      ]) {
        reject = status;
        await expectLater(
          provider().openStream(creds, const CloudStreamOptions(language: 'en')),
          throwsA(cloudError(kind)),
          reason: '$status',
        );
      }
    });

    test('cancel closes at once', () async {
      final stream = await provider().openStream(creds, const CloudStreamOptions(language: 'en'));
      final got = Inbox(stream.segments);
      final ws = await peer.future;
      await stream.cancel();
      await got.done();
      expect(got.items, isEmpty);
      await ws.inbox.done();
    });
  });
}

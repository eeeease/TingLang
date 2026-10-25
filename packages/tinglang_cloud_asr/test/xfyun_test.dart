import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:tinglang_cloud_asr/src/providers/xfyun.dart';
import 'package:tinglang_cloud_asr/tinglang_cloud_asr.dart';

import 'support/cn_fakes.dart';
import 'support/fake_server.dart';

const _appId = 'a1b2c3d4';
const _apiKey = 'testApiKey0000000000000000000000';
const _apiSecret = 'testApiSecret000';
const _creds = {
  CloudFieldKeys.appId: _appId,
  CloudFieldKeys.apiKey: _apiKey,
  CloudFieldKeys.apiSecret: _apiSecret,
};
const _secrets = [_apiKey, _apiSecret];
// 2025-09-04T15:38:07+0800
final _now = DateTime.utc(2025, 9, 4, 7, 38, 7);

XfyunAsr _provider(FakeServer server) => XfyunAsr(
  liveBaseUrl: server.ws,
  fileBaseUrl: server.http,
  now: () => _now,
  random: Random(11),
  pollInterval: const Duration(milliseconds: 10),
  connectTimeout: const Duration(seconds: 5),
);

/// A `ws` token: word [w] with [wp] at frames [wb]–[we] from the sentence start.
Map<String, Object?> _w(String w, int wb, int we, [String wp = 'n']) => {
  'cw': [
    {'w': w, 'wp': wp},
  ],
  'wb': wb,
  'we': we,
};

Map<String, Object?> _st(int bg, int ed, String type, List<Map<String, Object?>> ws) => {
  'bg': '$bg',
  'ed': '$ed',
  'type': type,
  'rt': [
    {'ws': ws},
  ],
};

Map<String, Object?> _result(Map<String, Object?> st, {bool last = false, int seg = 0}) => {
  'msg_type': 'result',
  'res_type': 'asr',
  'data': {
    'seg_id': seg,
    'cn': {'st': st},
    'ls': last,
  },
};

void main() {
  group('signatures', () {
    test('the base string follows the 实时语音转写大模型 example', () {
      // https://www.xfyun.cn/doc/spark/asr_llm/rtasr_llm.html, signature 生成:
      // accessKeyId=XXX&appId=XXX&lang=cn&utc=2025-03-24T00%3A01%3A19%2B0800&uuid=…
      final params = {
        'utc': '2025-03-24T00:01:19+0800',
        'uuid': 'edf53e32-6533-4d6a-acd3-fe4df14ee332',
        'lang': 'cn',
        'appId': 'XXX',
        'accessKeyId': 'XXX',
        'pd': '',
      };
      expect(
        XfyunAsr.baseString(params),
        'accessKeyId=XXX&appId=XXX&lang=cn&utc=2025-03-24T00%3A01%3A19%2B0800'
        '&uuid=edf53e32-6533-4d6a-acd3-fe4df14ee332',
      );
      // The documentation prints no reproducible signature; this one was
      // computed independently (Python hmac/sha1/base64) for the test secret.
      expect(XfyunAsr.sign(params, _apiSecret), 'hhBvGrKdkvD2uX+S0fdP2JJTXMQ=');
    });

    test('the base string follows the 录音文件转写大模型 upload example', () {
      // https://www.xfyun.cn/doc/spark/asr_llm/Ifasr_llm.html, 4.1.5 请求示例.
      final params = {
        'signatureRandom': 'a0289d60-26b3-4601-ad18-d2179dc95fd2',
        'language': 'en',
        'fileSize': '397144',
        'fileName': '1分钟音频.mp3',
        'duration': '56352',
        'dateTime': '2018-04-13T20:22:53+0800',
        'accessKeyId': 'testaccesskeyid',
      };
      expect(
        XfyunAsr.baseString(params),
        'accessKeyId=testaccesskeyid&dateTime=2018-04-13T20%3A22%3A53%2B0800&duration=56352'
        '&fileName=1%E5%88%86%E9%92%9F%E9%9F%B3%E9%A2%91.mp3&fileSize=397144&language=en'
        '&signatureRandom=a0289d60-26b3-4601-ad18-d2179dc95fd2',
      );
      expect(XfyunAsr.sign(params, _apiSecret), 'rmmJhY83SnQ9/vKVAoY9vFdn6Mg=');
    });

    test('times are written in Beijing time', () {
      expect(XfyunAsr.beijingTime(_now), '2025-09-04T15:38:07+0800');
      expect(XfyunAsr.beijingTime(DateTime.utc(2025, 12, 31, 20)), '2026-01-01T04:00:00+0800');
    });
  });

  test('languages map to the two language modes', () {
    expect(XfyunAsr.languageFor('en-GB'), (mode: 'autodialect', code: null));
    expect(XfyunAsr.languageFor('en-US'), (mode: 'autodialect', code: null));
    expect(XfyunAsr.languageFor('zh-Hans'), (mode: 'autodialect', code: null));
    for (final c in ['ja', 'ko', 'es', 'fr', 'de']) {
      expect(XfyunAsr.languageFor(c), (mode: 'autominor', code: c));
    }
    expect(
      () => XfyunAsr.languageFor('sw'),
      throwsA(cloudError(CloudAsrErrorKind.unsupportedLanguage)),
    );
    final p = XfyunAsr();
    expect(p.info.id, 'xfyun');
    expect([for (final f in p.info.fields) f.key], ['appId', 'apiKey', 'apiSecret']);
    expect(p.info.fields.first.kind, CloudFieldKind.text);
    expect(p.info.maxFileMs, 5 * 60 * 60 * 1000);
    expect(p.info.maxFileBytes, 500 * 1000 * 1000);
    expect(p.hosts(_creds), ['office-api-ast-dx.iflyaisol.com', 'office-api-ist-dx.iflyaisol.com']);
    expect(CloudAsrProviders.byId('xfyun'), isA<XfyunAsr>());
  });

  test('sentences join Latin words with spaces and CJK without', () {
    final orderResult = jsonEncode({
      'lattice': [
        {
          'json_1best': jsonEncode({
            'st': _st(880, 2400, '0', [
              _w('Hello', 2, 40),
              _w(',', 40, 40, 'p'),
              _w('über', 41, 80),
              _w('café', 81, 150),
              _w('.', 150, 150, 'p'),
              _w('', 150, 150, 'g'),
            ]),
          }),
        },
        {
          'json_1best': {
            'st': _st(2600, 3640, '0', [
              _w('喂', 1, 30, 's'),
              _w('你好', 31, 90),
              _w('｡', 90, 90, 'p'),
            ]),
          },
        },
        {
          'json_1best': jsonEncode({'st': _st(4000, 4100, '0', <Map<String, Object?>>[])}),
        },
      ],
    });
    final segments = XfyunAsr.parseOrderResult(orderResult);
    expect(
      [for (final s in segments) (s.id, s.text, s.startMs, s.endMs)],
      [('0', 'Hello, über café.', 880, 2400), ('1', '喂你好｡', 2600, 3640)],
    );
    expect(segments[0].words!.map((w) => (w.text, w.startMs, w.endMs)), [
      ('Hello', 900, 1280),
      ('über', 1290, 1680),
      ('café', 1690, 2380),
    ]);
    expect(segments[1].words!.map((w) => w.text), ['喂', '你好']);
    expect(XfyunAsr.parseOrderResult(orderResult, words: false).first.words, isNull);
  });

  group('live', () {
    late FakeServer server;
    late List<Object> received;
    late Map<String, Object?> handshake;
    late void Function(WebSocket ws, Object message) onMessage;

    setUp(() async {
      received = [];
      handshake = {
        'msg_type': 'action',
        'data': {'action': 'started', 'sessionId': 'sess-1'},
      };
      onMessage = (_, _) {};
      server = await FakeServer.start((request) async {
        final ws = await WebSocketTransformer.upgrade(request);
        sendJson(ws, handshake);
        ws.listen((m) {
          received.add(m as Object);
          onMessage(ws, m);
        });
      });
    });
    tearDown(() => server.close());

    test('the URL carries the documented parameters and a valid signature', () async {
      final stream = await _provider(server)
          .openStream(_creds, const CloudStreamOptions(language: 'ja'));
      await stream.cancel();
      final uri = server.requests.single.uri;
      expect(uri.path, '/ast/communicate/v1');
      final q = uri.queryParameters;
      expect(q['appId'], _appId);
      expect(q['accessKeyId'], _apiKey);
      expect(q['utc'], '2025-09-04T15:38:07+0800');
      expect(q['lang'], 'autominor');
      expect(q['recognized_language'], 'ja');
      expect(q['audio_encode'], 'pcm_s16le');
      expect(q['samplerate'], '16000');
      expect(q['uuid'], matches(RegExp(r'^[0-9a-f]{32}$')));
      final signed = Map.of(q)..remove('signature');
      expect(q['signature'], XfyunAsr.sign(signed, _apiSecret));
      expect(uri.query, contains('utc=2025-09-04T15%3A38%3A07%2B0800'));
      expect(uri.query, isNot(contains(_apiSecret)));
    });

    test('partials and finals share an id per sentence; end carries the session id', () async {
      onMessage = (ws, m) {
        if (m is List<int> && received.whereType<List<int>>().length == 1) {
          sendJson(ws, _result(_st(820, 0, '1', [_w('Hello', 0, 0)])));
          sendJson(
            ws,
            _result(
              _st(820, 2000, '0', [
                _w('Hello', 5, 40),
                _w('world', 41, 110),
                _w('.', 110, 110, 'p'),
              ]),
            ),
          );
          sendJson(ws, _result(_st(2300, 0, '1', [_w('How', 0, 0)])));
        }
        if (m is String && (jsonDecode(m) as Map)['end'] == true) {
          sendJson(
            ws,
            _result(_st(2300, 3100, '0', [_w('How', 1, 30), _w('are', 31, 50), _w('you', 51, 80)])),
          );
          sendJson(ws, {
            'msg_type': 'result',
            'res_type': 'asr',
            'data': {'seg_id': 9, 'ls': true},
          });
          ws.close();
        }
      };
      final stream = await _provider(server)
          .openStream(_creds, const CloudStreamOptions(language: 'en'));
      final drained = drain(stream);
      stream.addPcm(silence(100));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await stream.finish();
      final (segments, error) = await drained;
      expect(error, isNull);
      expect(
        [for (final s in segments) (s.id, s.isFinal, s.text, s.startMs, s.endMs)],
        [
          ('0', false, 'Hello', 820, 820),
          ('0', true, 'Hello world.', 820, 2000),
          ('1', false, 'How', 2300, 2300),
          ('1', true, 'How are you', 2300, 3100),
        ],
      );
      expect(segments[1].words!.map((w) => (w.text, w.startMs, w.endMs)), [
        ('Hello', 870, 1220),
        ('world', 1230, 1920),
      ]);
      expect(segments[0].words, isNull);
      // 100 ms → two 40 ms frames and the 20 ms rest at finish.
      expect([for (final f in received.whereType<List<int>>()) f.length], [1280, 1280, 640]);
      expect(jsonDecode(received.last as String), {'end': true, 'sessionId': 'sess-1'});
    });

    test('the older top-level message shape is read too', () async {
      handshake = {
        'action': 'started',
        'code': '0',
        'data': '',
        'desc': 'success',
        'sid': 'rta0001',
      };
      onMessage = (ws, m) {
        if (m is String) {
          sendJson(ws, {
            'action': 'result',
            'code': '0',
            'data': jsonEncode({
              'cn': {
                'st': _st(0, 900, '0', [_w('你', 2, 30), _w('好', 31, 80)]),
              },
              'seg_id': 0,
            }),
            'desc': 'success',
            'sid': 'rta0001',
          });
          ws.close();
        }
      };
      final stream = await _provider(server)
          .openStream(_creds, const CloudStreamOptions(language: 'zh-Hans'));
      final drained = drain(stream);
      await stream.finish();
      final (segments, error) = await drained;
      expect(error, isNull);
      expect(segments.single.text, '你好');
      expect(jsonDecode(received.last as String), {'end': true, 'sessionId': 'rta0001'});
    });

    test('server error frames end the stream with the mapped kind', () async {
      for (final (frame, kind) in [
        (
          {
            'msg_type': 'action',
            'data': {'action': 'error', 'code': '37005', 'desc': 'no audio'},
          },
          CloudAsrErrorKind.sessionEnded,
        ),
        (
          {'action': 'error', 'code': '37007', 'desc': 'max duration'},
          CloudAsrErrorKind.sessionEnded,
        ),
        ({'action': 'error', 'code': '100001', 'desc': 'too fast'}, CloudAsrErrorKind.rateLimited),
        (
          {
            'msg_type': 'result',
            'res_type': 'frc',
            'data': {'desc': '功能异常', 'normal': false},
          },
          CloudAsrErrorKind.server,
        ),
      ]) {
        onMessage = (ws, m) {
          if (m is List<int>) sendJson(ws, frame);
        };
        final stream = await _provider(server)
            .openStream(_creds, const CloudStreamOptions(language: 'en'));
        final drained = drain(stream);
        stream.addPcm(silence(40));
        final (_, error) = await drained;
        expect(error, cloudError(kind, secrets: _secrets), reason: '$frame');
      }
    });

    test('handshake refusals', () async {
      for (final (frame, kind) in [
        (
          {
            'msg_type': 'action',
            'data': {'action': 'error', 'code': '35001', 'desc': 'auth failed for $_apiKey'},
          },
          CloudAsrErrorKind.unauthorized,
        ),
        ({'action': 'error', 'code': '35002', 'desc': '用量不足'}, CloudAsrErrorKind.quotaExceeded),
        ({'action': 'error', 'code': '35006', 'desc': 'full'}, CloudAsrErrorKind.rateLimited),
        (
          {'action': 'error', 'code': '100019', 'desc': 'language'},
          CloudAsrErrorKind.unsupportedLanguage,
        ),
        ({'action': 'error', 'code': '35014', 'desc': 'time'}, CloudAsrErrorKind.badRequest),
        (
          {'action': 'error', 'code': '10110', 'desc': 'no license'},
          CloudAsrErrorKind.quotaExceeded,
        ),
      ]) {
        handshake = frame;
        await expectLater(
          _provider(server).openStream(_creds, const CloudStreamOptions(language: 'en')),
          throwsA(cloudError(kind, secrets: _secrets)),
          reason: '$frame',
        );
      }
    });

    test('verify sends neither audio nor an end message', () async {
      await _provider(server).verify(_creds);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(server.requests, hasLength(1));
      expect(received, isEmpty);
    });

    test('an HTTP refusal of the upgrade keeps its status', () async {
      final refusing = await FakeServer.start((r) => replyJson(r, 'denied', status: 403));
      addTearDown(refusing.close);
      await expectLater(
        _provider(refusing).verify(_creds),
        throwsA(
          cloudError(
            CloudAsrErrorKind.unauthorized,
            secrets: _secrets,
          ).having((e) => e.statusCode, 'status', 403),
        ),
      );
    });
  });

  group('file', () {
    final wav = countingWav(1200);
    late FakeServer server;
    late List<String> log;
    late Map<String, String> uploadQuery;
    late Uint8List uploaded;
    var polls = 0;
    late Future<bool> Function(HttpRequest request) override;

    final orderResult = jsonEncode({
      'lattice': [
        {
          'json_1best': jsonEncode({
            'st': {
              ..._st(100, 1100, '0', [
                _w('Nice', 1, 30),
                _w('to', 31, 45),
                _w('meet', 46, 70),
                _w('you', 71, 99),
                _w('.', 99, 99, 'p'),
              ]),
              'rl': '0',
            },
          }),
        },
      ],
    });

    setUp(() async {
      log = [];
      polls = 0;
      override = (_) async => false;
      server = await FakeServer.start((request) async {
        log.add('${request.method} ${request.uri.path}');
        if (await override(request)) return;
        final q = request.uri.queryParameters;
        final signature = request.headers.value('signature');
        expect(signature, XfyunAsr.sign(q, _apiSecret));
        switch (request.uri.path) {
          case '/v2/upload':
            uploadQuery = q;
            expect(request.headers.contentType?.mimeType, 'application/octet-stream');
            uploaded = await readBody(request);
            await replyJson(
              request,
              '{"descInfo":"success","code":"000000","content":{"orderId":"DKHJQ1","taskEstimateTime":200}}',
            );
          case '/v2/getResult':
            expect(q['orderId'], 'DKHJQ1');
            expect(q['signatureRandom'], uploadQuery['signatureRandom']);
            expect(q['resultType'], 'transfer');
            expect(utf8.decode(await readBody(request)), '{}');
            polls++;
            if (polls == 1) {
              await replyJson(
                request,
                '{"code":"000000","descInfo":"success","content":{"orderInfo":{"orderId":"DKHJQ1","failType":0,"status":3,"originalDuration":1200},"orderResult":"","taskEstimateTime":200}}',
              );
            } else if (polls == 2) {
              await replyJson(request, '{"code":"100013","descInfo":"order not finished"}');
            } else {
              await replyJson(
                request,
                jsonEncode({
                  'code': '000000',
                  'descInfo': 'success',
                  'content': {
                    'orderInfo': {
                      'orderId': 'DKHJQ1',
                      'failType': 0,
                      'status': 4,
                      'originalDuration': 1200,
                    },
                    'orderResult': orderResult,
                  },
                }),
              );
            }
          default:
            await replyJson(request, '{"code":"1000000"}', status: 404);
        }
      });
    });
    tearDown(() => server.close());

    test('upload → poll (processing, not finished, done) → timed sentences and words', () async {
      final progress = <double>[];
      final segments = await _provider(server).transcribeFile(
        _creds,
        CloudFileRequest(wav: wav, durationMs: 1200, language: 'en-US'),
        onProgress: progress.add,
      );
      expect(log, [
        'POST /v2/upload',
        'POST /v2/getResult',
        'POST /v2/getResult',
        'POST /v2/getResult',
      ]);
      expect(uploaded, wav);
      expect(uploadQuery['appId'], _appId);
      expect(uploadQuery['accessKeyId'], _apiKey);
      expect(uploadQuery['dateTime'], '2025-09-04T15:38:07+0800');
      expect(uploadQuery['signatureRandom'], matches(RegExp(r'^[A-Za-z0-9]{16}$')));
      expect(uploadQuery['fileSize'], '${wav.length}');
      expect(uploadQuery['fileName'], 'tinglang.wav');
      expect(uploadQuery['language'], 'autodialect');
      expect(uploadQuery['durationCheckDisable'], 'true');
      expect(
        [for (final s in segments) (s.text, s.startMs, s.endMs)],
        [('Nice to meet you.', 100, 1100)],
      );
      expect(segments.single.words!.map((w) => (w.text, w.startMs, w.endMs)), [
        ('Nice', 110, 400),
        ('to', 410, 550),
        ('meet', 560, 800),
        ('you', 810, 1090),
      ]);
      expect(progress.last, 1.0);
      expect(progress, orderedEquals([...progress]..sort()));
    });

    test('a file in another language uses the multilingual mode', () async {
      await _provider(server)
          .transcribeFile(_creds, CloudFileRequest(wav: wav, durationMs: 1200, language: 'fr'));
      expect(uploadQuery['language'], 'autominor');
    });

    test('codes map to kinds without credentials', () async {
      for (final (body, kind) in [
        (
          '{"code":"000002","descInfo":"accessKeyId $_apiKey not exist"}',
          CloudAsrErrorKind.unauthorized,
        ),
        ('{"code":"100009","descInfo":"signature check failed"}', CloudAsrErrorKind.unauthorized),
        ('{"code":"100007","descInfo":"no permission"}', CloudAsrErrorKind.quotaExceeded),
        ('{"code":100012,"descInfo":"too frequent"}', CloudAsrErrorKind.rateLimited),
        ('{"code":"100008","descInfo":"time"}', CloudAsrErrorKind.badRequest),
        ('{"code":"999999","descInfo":"unknown"}', CloudAsrErrorKind.server),
      ]) {
        override = (request) async {
          await readBody(request);
          await replyJson(request, body);
          return true;
        };
        await expectLater(
          _provider(server)
              .transcribeFile(_creds, CloudFileRequest(wav: wav, durationMs: 1200, language: 'en')),
          throwsA(cloudError(kind, secrets: _secrets)),
          reason: body,
        );
      }
    });

    test('failed orders: too long is audioTooLong, a silent file is empty', () async {
      for (final (failType, expected) in [
        (4, CloudAsrErrorKind.audioTooLong),
        (2, CloudAsrErrorKind.badRequest),
        (6, null),
      ]) {
        override = (request) async {
          if (request.uri.path != '/v2/getResult') return false;
          await readBody(request);
          await replyJson(
            request,
            '{"code":"000000","content":{"orderInfo":{"orderId":"DKHJQ1","failType":$failType,"status":-1}}}',
          );
          return true;
        };
        final call = _provider(server)
            .transcribeFile(_creds, CloudFileRequest(wav: wav, durationMs: 1200, language: 'en'));
        if (expected == null) {
          expect(await call, isEmpty);
        } else {
          await expectLater(call, throwsA(cloudError(expected)), reason: 'failType $failType');
        }
      }
    });

    test('an HTTP failure without a body code is mapped by status', () async {
      override = (request) async {
        await readBody(request);
        request.response
          ..statusCode = 502
          ..write('bad gateway');
        await request.response.close();
        return true;
      };
      await expectLater(
        _provider(server)
            .transcribeFile(_creds, CloudFileRequest(wav: wav, durationMs: 1200, language: 'en')),
        throwsA(cloudError(CloudAsrErrorKind.server).having((e) => e.statusCode, 'status', 502)),
      );
    });

    test('cancel while polling stops at once', () async {
      override = (request) async {
        if (request.uri.path != '/v2/getResult') return false;
        await readBody(request);
        await replyJson(request, '{"code":"100013","descInfo":"order not finished"}');
        return true;
      };
      final token = CloudCancelToken();
      final call = _provider(server).transcribeFile(
        _creds,
        CloudFileRequest(wav: wav, durationMs: 1200, language: 'en'),
        cancel: token,
      );
      await Future<void>.delayed(const Duration(milliseconds: 120));
      token.cancel();
      await expectLater(call, throwsA(cloudError(CloudAsrErrorKind.cancelled)));
    });

    test('a network failure is a network error', () async {
      final port = await closedPort();
      final p = XfyunAsr(fileBaseUrl: Uri.parse('http://127.0.0.1:$port'));
      await expectLater(
        p.transcribeFile(_creds, CloudFileRequest(wav: wav, durationMs: 1200, language: 'en')),
        throwsA(cloudError(CloudAsrErrorKind.network, secrets: _secrets)),
      );
    });

    test('missing credentials name the field only', () async {
      await expectLater(
        XfyunAsr().transcribeFile({
          CloudFieldKeys.appId: _appId,
          CloudFieldKeys.apiKey: _apiKey,
        }, CloudFileRequest(wav: wav, durationMs: 1200, language: 'en')),
        throwsA(cloudError(CloudAsrErrorKind.unauthorized, secrets: _secrets)),
      );
    });
  });
}

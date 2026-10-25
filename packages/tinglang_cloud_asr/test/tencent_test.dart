import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:tinglang_cloud_asr/src/providers/tencent.dart';
import 'package:tinglang_cloud_asr/tinglang_cloud_asr.dart';

import 'support/cn_fakes.dart';
import 'support/fake_server.dart';

const _appId = '1259228442';
const _secretId = 'AKIDtestSecretId0000000000000000';
const _secretKey = 'testSecretKey00000000000000000000';
const _creds = {
  CloudFieldKeys.appId: _appId,
  CloudFieldKeys.secretId: _secretId,
  CloudFieldKeys.secretKey: _secretKey,
};
const _secrets = [_secretId, _secretKey];
final _now = DateTime.fromMillisecondsSinceEpoch(1673408372000, isUtc: true);

TencentCloudAsr _provider(FakeServer server) => TencentCloudAsr(
  liveBaseUrl: server.ws,
  fileBaseUrl: server.http,
  now: () => _now,
  random: Random(7),
  connectTimeout: const Duration(seconds: 5),
);

Map<String, Object?> _result(
  int index,
  int slice,
  String text,
  int start,
  int end, [
  Object? words,
]) => {
  'code': 0,
  'message': 'success',
  'voice_id': 'v',
  'message_id': 'v_$index',
  'result': {
    'slice_type': slice,
    'index': index,
    'start_time': start,
    'end_time': end,
    'voice_text_str': text,
    'word_size': 0,
    'word_list': ?words,
  },
  'final': 0,
};

void main() {
  group('signatures', () {
    test('the live signature matches the example in the 实时语音识别 documentation', () {
      // https://cloud.tencent.com/document/product/1093/48982 (signature 生成):
      // the documentation's own masked values reproduce its printed result.
      final signature = TencentCloudAsr.signLive('asr.cloud.tencent.com/asr/v2/125922***', {
        'engine_model_type': '16k_zh',
        'expired': '1673494772',
        'needvad': '1',
        'nonce': '1673408372',
        'secretid': '*****Qq1zhZMN8dv0******',
        'timestamp': '1673408372',
        'voice_format': '1',
        'voice_id': 'c64385ee-3e5c-4fc5-bbfd-7c71addb35b0',
      }, '*****SkqpeHgqmSz*****');
      expect(signature, 'G8jDQBRg1JfeBi/YnTjyjekxfDA=');
    });

    test('the flash signature signs POST + host + path + sorted query', () {
      // The 录音文件识别极速版 page (https://cloud.tencent.com/document/product/1093/52097,
      // 4.5) prints vLBmoXJ8Oi4YMEuNhpIyrOo+deM= for its example, but that value does
      // not reproduce from the example text itself. Expected value computed
      // independently (Python hmac/sha1/base64) from the documented string:
      // POSTasr.cloud.tencent.com/asr/flash/v1/125922***?engine_type=16k_zh_beta&…
      final signature = TencentCloudAsr.signFlash('asr.cloud.tencent.com/asr/flash/v1/125922***', {
        'secretid': '*****Qq1zhZMN8dv0******',
        'word_info': '1',
        'voice_format': 'wav',
        'timestamp': '1673426168',
        'speaker_diarization': '0',
        'reinforce_hotword': '0',
        'hotword_id': '584f4d0060d811ed85da525400aec391',
        'first_channel_only': '1',
        'filter_punc': '0',
        'extra_punc': '0',
        'engine_type': '16k_zh_beta',
      }, '*****SkqpeHgqmSz*****');
      expect(signature, '9LIDnkK30FR5oMqBCrVmvH7t0i4=');
    });
  });

  test('languages map to the 16 kHz general engines', () {
    expect(TencentCloudAsr.engineFor('en'), '16k_en');
    expect(TencentCloudAsr.engineFor('en-US'), '16k_en');
    expect(TencentCloudAsr.engineFor('en-GB'), '16k_en');
    expect(TencentCloudAsr.engineFor('zh-Hans'), '16k_zh');
    expect(TencentCloudAsr.engineFor('ja'), '16k_ja');
    expect(TencentCloudAsr.engineFor('ko'), '16k_ko');
    expect(TencentCloudAsr.engineFor('es'), '16k_es');
    expect(TencentCloudAsr.engineFor('fr'), '16k_fr');
    expect(TencentCloudAsr.engineFor('de'), '16k_de');
    expect(
      () => TencentCloudAsr.engineFor('it'),
      throwsA(cloudError(CloudAsrErrorKind.unsupportedLanguage)),
    );
    final info = TencentCloudAsr().info;
    expect(info.id, 'tencent');
    expect(info.languages, {'en', 'zh', 'ja', 'ko', 'es', 'fr', 'de'});
    expect(info.maxFileBytes, 100 * 1000 * 1000);
    expect(info.maxFileMs, 2 * 60 * 60 * 1000);
    expect([for (final f in info.fields) f.key], ['appId', 'secretId', 'secretKey']);
    expect(TencentCloudAsr().hosts(_creds), ['asr.cloud.tencent.com']);
    expect(CloudAsrProviders.byId('tencent'), isA<TencentCloudAsr>());
  });

  test('missing or malformed credentials fail without echoing values', () async {
    final p = TencentCloudAsr();
    await expectLater(
      p.verify({CloudFieldKeys.appId: _appId, CloudFieldKeys.secretId: _secretId}),
      throwsA(cloudError(CloudAsrErrorKind.unauthorized, secrets: _secrets)),
    );
    await expectLater(
      p.verify({..._creds, CloudFieldKeys.appId: 'app/../$_secretKey'}),
      throwsA(cloudError(CloudAsrErrorKind.unauthorized, secrets: _secrets)),
    );
  });

  group('live', () {
    late FakeServer server;
    late List<Object> received;
    late void Function(WebSocket ws, Object message) onMessage;
    final handshake = {'code': 0, 'message': 'success', 'voice_id': 'v'};

    setUp(() async {
      received = [];
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

    test('the URL is signed as documented', () async {
      final stream = await _provider(server)
          .openStream(_creds, const CloudStreamOptions(language: 'en-GB'));
      await stream.cancel();
      final uri = server.requests.single.uri;
      expect(uri.path, '/asr/v2/$_appId');
      final q = uri.queryParameters;
      expect(q['secretid'], _secretId);
      expect(q['engine_model_type'], '16k_en');
      expect(q['voice_format'], '1');
      expect(q['needvad'], '1');
      expect(q['word_info'], '1');
      expect(q['timestamp'], '1673408372');
      expect(q['expired'], '${1673408372 + 86400}');
      expect(int.parse(q['nonce']!), greaterThan(0));
      expect(q['voice_id'], matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-')));
      final signed = Map.of(q)..remove('signature');
      expect(
        q['signature'],
        TencentCloudAsr.signLive('127.0.0.1:${server.port}/asr/v2/$_appId', signed, _secretKey),
      );
      // The signature is percent-encoded in the raw query (+, / and = included).
      expect(uri.query, endsWith('signature=${Uri.encodeQueryComponent(q['signature']!)}'));
      expect(uri.query, isNot(contains(_secretKey)));
    });

    test(
      'partials then finals share ids, carry stream times, and finish waits for final',
      () async {
        onMessage = (ws, m) {
          if (m is List<int> && received.whereType<List<int>>().length == 1) {
            sendJson(ws, _result(0, 0, '', 120, 120));
            sendJson(ws, _result(0, 1, 'hello', 120, 600));
            sendJson(
              ws,
              _result(0, 2, 'Hello world.', 120, 980, [
                {'word': 'Hello', 'start_time': 120, 'end_time': 480, 'stable_flag': 1},
                {'word': 'world', 'start_time': 480, 'end_time': 980, 'stable_flag': 1},
              ]),
            );
            sendJson(ws, _result(1, 1, 'how', 1500, 1700));
          }
          if (m is String && (jsonDecode(m) as Map)['type'] == 'end') {
            sendJson(ws, _result(1, 2, 'How are you?', 1500, 2300));
            sendJson(ws, {...handshake, 'final': 1});
            ws.close();
          }
        };
        final stream = await _provider(server)
            .openStream(_creds, const CloudStreamOptions(language: 'en'));
        final drained = drain(stream);
        stream.addPcm(silence(120));
        stream.addPcm(silence(120));
        stream.addPcm(silence(40));
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await stream.finish();
        final (segments, error) = await drained;
        expect(error, isNull);
        expect(
          [for (final s in segments) (s.id, s.isFinal, s.text, s.startMs, s.endMs)],
          [
            ('0', false, 'hello', 120, 600),
            ('0', true, 'Hello world.', 120, 980),
            ('1', false, 'how', 1500, 1700),
            ('1', true, 'How are you?', 1500, 2300),
          ],
        );
        expect(segments[1].words!.map((w) => (w.text, w.startMs, w.endMs)), [
          ('Hello', 120, 480),
          ('world', 480, 980),
        ]);
        // 280 ms re-chunked into 200 ms frames; the rest is flushed before the end message.
        final frames = received.whereType<List<int>>().toList();
        expect([for (final f in frames) f.length], [6400, 2560]);
        expect(received.last, '{"type":"end"}');
      },
    );

    test('a server error frame ends the stream with the mapped kind', () async {
      onMessage = (ws, m) {
        if (m is List<int>) {
          sendJson(ws, {'code': 4008, 'message': 'no audio for 15s', 'voice_id': 'v'});
          ws.close();
        }
      };
      final stream = await _provider(server)
          .openStream(_creds, const CloudStreamOptions(language: 'zh-Hans'));
      final drained = drain(stream);
      stream.addPcm(silence(200));
      final (segments, error) = await drained;
      expect(segments, isEmpty);
      expect(error, cloudError(CloudAsrErrorKind.sessionEnded, secrets: _secrets));
      expect((error! as CloudAsrError).retryable, isTrue);
    });

    test('words outside their sentence are dropped, not shifted', () async {
      onMessage = (ws, m) {
        if (m is String) {
          sendJson(
            ws,
            _result(3, 2, 'later', 9000, 9600, [
              {'word': 'later', 'start_time': 0, 'end_time': 600},
            ]),
          );
          sendJson(ws, {...handshake, 'final': 1});
          ws.close();
        }
      };
      final stream = await _provider(server)
          .openStream(_creds, const CloudStreamOptions(language: 'en'));
      final drained = drain(stream);
      await stream.finish();
      final (segments, _) = await drained;
      expect(segments.single.words, isNull);
      expect(segments.single.startMs, 9000);
    });

    test('cancel closes at once without the end message', () async {
      final stream = await _provider(server)
          .openStream(_creds, const CloudStreamOptions(language: 'en'));
      final drained = drain(stream);
      stream.addPcm(silence(200));
      await stream.cancel();
      final (segments, error) = await drained;
      expect(segments, isEmpty);
      expect(error, isNull);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(received.whereType<String>(), isEmpty);
    });

    test('verify opens a session and sends no audio', () async {
      await _provider(server).verify(_creds);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(server.requests, hasLength(1));
      expect(received.whereType<List<int>>(), isEmpty);
    });
  });

  group('live handshake errors', () {
    Future<Object?> openWith(FutureOr<void> Function(HttpRequest) handler) async {
      final server = await FakeServer.start(handler);
      try {
        await _provider(server).openStream(_creds, const CloudStreamOptions(language: 'en'));
        return null;
      } on Object catch (e) {
        return e;
      } finally {
        await server.close();
      }
    }

    test('a refused signature is unauthorized and the reply is redacted', () async {
      final error = await openWith((request) async {
        final ws = await WebSocketTransformer.upgrade(request);
        sendJson(ws, {'code': 4002, 'message': 'signature mismatch for secretid $_secretId'});
        await ws.close();
      });
      expect(error, cloudError(CloudAsrErrorKind.unauthorized, secrets: _secrets));
      expect((error! as CloudAsrError).providerCode, '4002');
    });

    test('quota and concurrency codes', () async {
      for (final (code, kind) in [
        (4003, CloudAsrErrorKind.quotaExceeded),
        (4004, CloudAsrErrorKind.quotaExceeded),
        (4005, CloudAsrErrorKind.quotaExceeded),
        (4006, CloudAsrErrorKind.rateLimited),
        (5000, CloudAsrErrorKind.server),
      ]) {
        final error = await openWith((request) async {
          final ws = await WebSocketTransformer.upgrade(request);
          sendJson(ws, {'code': code, 'message': 'x'});
          await ws.close();
        });
        expect(error, cloudError(kind), reason: '$code');
      }
    });

    test('an HTTP 403 on the upgrade is unauthorized with the status', () async {
      final error = await openWith(
        (request) => replyJson(request, '{"error":"forbidden"}', status: 403),
      );
      expect(error, cloudError(CloudAsrErrorKind.unauthorized, secrets: _secrets));
      expect((error! as CloudAsrError).statusCode, 403);
    });

    test('an unreachable service is a network error without the URL', () async {
      final port = await closedPort();
      final p = TencentCloudAsr(
        liveBaseUrl: Uri.parse('ws://127.0.0.1:$port'),
        connectTimeout: const Duration(seconds: 2),
      );
      await expectLater(
        p.openStream(_creds, const CloudStreamOptions(language: 'en')),
        throwsA(
          cloudError(
            CloudAsrErrorKind.network,
            secrets: [..._secrets, 'signature', '127.0.0.1:$port/'],
          ),
        ),
      );
    });
  });

  group('file (录音文件识别极速版)', () {
    final wav = countingWav(1500);
    const flash = {
      'request_id': 'r',
      'code': 0,
      'message': '',
      'audio_duration': 1500,
      'flash_result': [
        {
          'text': 'Good morning. How are you?',
          'channel_id': 0,
          'sentence_list': [
            {
              'text': 'Good morning.',
              'start_time': 0,
              'end_time': 820,
              'speaker_id': 0,
              'word_list': [
                {'word': 'Good', 'start_time': 0, 'end_time': 300, 'stable_flag': 1},
                {'word': 'morning', 'start_time': 300, 'end_time': 820, 'stable_flag': 1},
              ],
            },
            {
              'text': 'How are you?',
              'start_time': 900,
              'end_time': 1500,
              'speaker_id': 0,
              'word_list': [
                {'word': 'How', 'start_time': 900, 'end_time': 1100, 'stable_flag': 1},
                {'word': 'are', 'start_time': 1100, 'end_time': 1250, 'stable_flag': 1},
                {'word': 'you', 'start_time': 1250, 'end_time': 1500, 'stable_flag': 1},
              ],
            },
          ],
        },
      ],
    };

    test('one signed POST of the WAV returns timed sentences and words', () async {
      late Uint8List body;
      late HttpHeaders headers;
      final server = await FakeServer.start((request) async {
        headers = request.headers;
        body = await readBody(request);
        await replyJson(request, jsonEncode(flash));
      });
      addTearDown(server.close);
      final progress = <double>[];
      final segments = await _provider(server).transcribeFile(
        _creds,
        CloudFileRequest(wav: wav, durationMs: 1500, language: 'en-US'),
        onProgress: progress.add,
      );
      final request = server.requests.single;
      expect(request.method, 'POST');
      expect(request.uri.path, '/asr/flash/v1/$_appId');
      final q = request.uri.queryParameters;
      expect(q['engine_type'], '16k_en');
      expect(q['voice_format'], 'wav');
      expect(q['word_info'], '1');
      expect(q['secretid'], _secretId);
      expect(q['timestamp'], '1673408372');
      expect(q.containsKey('appid'), isFalse);
      expect(
        headers.value(HttpHeaders.authorizationHeader),
        TencentCloudAsr.signFlash('127.0.0.1:${server.port}/asr/flash/v1/$_appId', q, _secretKey),
      );
      expect(headers.contentType?.mimeType, 'application/octet-stream');
      expect(body, wav);
      expect(
        [for (final s in segments) (s.id, s.text, s.startMs, s.endMs, s.isFinal)],
        [('0', 'Good morning.', 0, 820, true), ('1', 'How are you?', 900, 1500, true)],
      );
      expect(segments[1].words!.map((w) => (w.text, w.startMs, w.endMs)), [
        ('How', 900, 1100),
        ('are', 1100, 1250),
        ('you', 1250, 1500),
      ]);
      expect(progress.last, 1.0);
      expect(progress, orderedEquals([...progress]..sort()));
    });

    test('service codes and HTTP failures map to kinds', () async {
      for (final (status, reply, kind) in [
        (200, '{"code":4002,"message":"auth failed $_secretKey"}', CloudAsrErrorKind.unauthorized),
        (200, '{"code":4004,"message":"no resource"}', CloudAsrErrorKind.quotaExceeded),
        (200, '{"code":4006,"message":"too many"}', CloudAsrErrorKind.rateLimited),
        (200, '{"code":4011,"message":"too large"}', CloudAsrErrorKind.audioTooLong),
        (200, '{"code":5003,"message":"timeout"}', CloudAsrErrorKind.server),
        (502, 'bad gateway', CloudAsrErrorKind.server),
        (429, 'slow down', CloudAsrErrorKind.rateLimited),
      ]) {
        final server = await FakeServer.start((request) async {
          await readBody(request);
          request.response.statusCode = status;
          request.response.write(reply);
          await request.response.close();
        });
        await expectLater(
          _provider(server)
              .transcribeFile(_creds, CloudFileRequest(wav: wav, durationMs: 1500, language: 'en')),
          throwsA(cloudError(kind, secrets: _secrets)),
          reason: reply,
        );
        await server.close();
      }
    });

    test('files over the documented limits are refused before upload', () async {
      await expectLater(
        TencentCloudAsr().transcribeFile(
          _creds,
          CloudFileRequest(wav: wav, durationMs: 2 * 60 * 60 * 1000 + 1, language: 'en'),
        ),
        throwsA(cloudError(CloudAsrErrorKind.audioTooLong)),
      );
    });

    test('a network failure is a network error', () async {
      final port = await closedPort();
      final p = TencentCloudAsr(fileBaseUrl: Uri.parse('http://127.0.0.1:$port'));
      await expectLater(
        p.transcribeFile(_creds, CloudFileRequest(wav: wav, durationMs: 1500, language: 'en')),
        throwsA(cloudError(CloudAsrErrorKind.network, secrets: _secrets)),
      );
    });

    test('cancel stops a request in flight', () async {
      final server = await FakeServer.start((request) async {
        await readBody(request);
        await Future<void>.delayed(const Duration(seconds: 5));
        await replyJson(request, jsonEncode(flash));
      });
      addTearDown(server.close);
      final token = CloudCancelToken();
      final watch = Stopwatch()..start();
      final call = _provider(server).transcribeFile(
        _creds,
        CloudFileRequest(wav: wav, durationMs: 1500, language: 'en'),
        cancel: token,
      );
      await Future<void>.delayed(const Duration(milliseconds: 200));
      token.cancel();
      await expectLater(call, throwsA(cloudError(CloudAsrErrorKind.cancelled)));
      expect(watch.elapsed, lessThan(const Duration(seconds: 3)));
      final pre = CloudCancelToken()..cancel();
      await expectLater(
        _provider(server).transcribeFile(
          _creds,
          CloudFileRequest(wav: wav, durationMs: 1500, language: 'en'),
          cancel: pre,
        ),
        throwsA(cloudError(CloudAsrErrorKind.cancelled)),
      );
    });
  });
}

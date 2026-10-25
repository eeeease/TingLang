import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:tinglang_cloud_asr/src/providers/dashscope.dart';
import 'package:tinglang_cloud_asr/tinglang_cloud_asr.dart';

import 'support/cn_fakes.dart';
import 'support/fake_server.dart';

const _key = 'sk-test0000000000000000000000000000';
const _creds = {CloudFieldKeys.apiKey: _key, CloudFieldKeys.region: 'cn'};
const _secrets = [_key];

DashScopeAsr _provider(FakeServer server) => DashScopeAsr(
  httpBaseUrl: server.http,
  wsBaseUrl: server.ws,
  random: Random(3),
  pollInterval: const Duration(milliseconds: 10),
  connectTimeout: const Duration(seconds: 5),
);

Map<String, Object?> _event(String event, [Map<String, Object?> payload = const {}]) => {
  'header': {'task_id': 't', 'event': event, 'attributes': <String, Object?>{}},
  'payload': payload,
};

Map<String, Object?> _sentence(
  int id,
  String text,
  int begin,
  int? end, {
  bool isFinal = false,
  bool beginning = false,
  List<Map<String, Object?>> words = const [],
}) => _event('result-generated', {
  'output': {
    'sentence': {
      'begin_time': begin,
      'end_time': end,
      'text': text,
      'heartbeat': false,
      'sentence_begin': beginning,
      'sentence_end': isFinal,
      'sentence_id': id,
      'words': words,
    },
  },
  'usage': isFinal ? {'duration': 3} : null,
});

void main() {
  test('info, regions, hosts and language hints', () {
    final p = DashScopeAsr();
    expect(p.info.id, 'dashscope');
    expect([for (final f in p.info.fields) f.key], ['apiKey', 'region']);
    final region = p.info.fields[1];
    expect(region.kind, CloudFieldKind.choice);
    expect(region.choices, ['cn', 'intl']);
    expect(region.defaultValue, 'cn');
    expect(p.hosts(_creds).first, 'dashscope.aliyuncs.com');
    expect(p.hosts({CloudFieldKeys.apiKey: _key}).first, 'dashscope.aliyuncs.com');
    expect(
      p.hosts({..._creds, CloudFieldKeys.region: 'intl'}).first,
      'dashscope-intl.aliyuncs.com',
    );
    expect(
      () => p.hosts({..._creds, CloudFieldKeys.region: 'mars'}),
      throwsA(cloudError(CloudAsrErrorKind.badRequest)),
    );
    expect(p.liveModel, 'fun-asr-realtime');
    expect(p.fileModel, 'fun-asr');
    for (final (tag, hint) in [
      ('en', 'en'),
      ('en-US', 'en'),
      ('en-GB', 'en'),
      ('zh-Hans', 'zh'),
      ('ja', 'ja'),
      ('ko', 'ko'),
      ('es', 'es'),
      ('fr', 'fr'),
      ('de', 'de'),
    ]) {
      expect(DashScopeAsr.languageHint(tag), hint);
    }
    expect(
      () => DashScopeAsr.languageHint('xx'),
      throwsA(cloudError(CloudAsrErrorKind.unsupportedLanguage)),
    );
    expect(p.info.languages, {'en', 'zh', 'ja', 'ko', 'es', 'fr', 'de'});
    expect(CloudAsrProviders.byId('dashscope'), isA<DashScopeAsr>());
  });

  group('live', () {
    late FakeServer server;
    late List<Object> received;
    late void Function(WebSocket ws, Object message) onMessage;

    setUp(() async {
      received = [];
      onMessage = (ws, m) {
        if (m is String && m.contains('"run-task"')) sendJson(ws, _event('task-started'));
      };
      server = await FakeServer.start((request) async {
        final ws = await WebSocketTransformer.upgrade(request);
        ws.listen((m) {
          received.add(m as Object);
          onMessage(ws, m);
        });
      });
    });
    tearDown(() => server.close());

    test(
      'run-task, partials and finals by sentence id, finish-task waits for task-finished',
      () async {
        onMessage = (ws, m) {
          if (m is String && m.contains('"run-task"')) sendJson(ws, _event('task-started'));
          if (m is List<int> && received.whereType<List<int>>().length == 1) {
            sendJson(ws, _sentence(1, '', 170, null, beginning: true));
            sendJson(
              ws,
              _sentence(
                1,
                'good',
                170,
                null,
                words: [
                  {'begin_time': 170, 'end_time': 420, 'text': 'good', 'punctuation': ''},
                ],
              ),
            );
            sendJson(
              ws,
              _sentence(
                1,
                'Good morning.',
                170,
                920,
                isFinal: true,
                words: [
                  {'begin_time': 170, 'end_time': 420, 'text': 'Good ', 'punctuation': ''},
                  {'begin_time': 420, 'end_time': 920, 'text': 'morning', 'punctuation': '.'},
                ],
              ),
            );
            sendJson(ws, {
              ..._event('result-generated', {
                'output': {
                  'sentence': {'heartbeat': true, 'sentence_id': 0, 'text': '', 'begin_time': 0},
                },
              }),
            });
          }
          if (m is String && m.contains('"finish-task"')) {
            sendJson(ws, _sentence(2, 'Bye.', 1200, 1500, isFinal: true));
            sendJson(ws, _event('task-finished', {'output': <String, Object?>{}, 'usage': null}));
          }
        };
        final stream = await _provider(server)
            .openStream(_creds, const CloudStreamOptions(language: 'en-US'));
        final drained = drain(stream);
        stream.addPcm(silence(80));
        stream.addPcm(silence(80));
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await stream.finish();
        final (segments, error) = await drained;
        expect(error, isNull);
        expect(
          [for (final s in segments) (s.id, s.isFinal, s.text, s.startMs, s.endMs)],
          [
            ('1', false, 'good', 170, 420),
            ('1', true, 'Good morning.', 170, 920),
            ('2', true, 'Bye.', 1200, 1500),
          ],
        );
        expect(segments[1].words!.map((w) => (w.text, w.startMs, w.endMs)), [
          ('Good', 170, 420),
          ('morning', 420, 920),
        ]);

        final upgrade = server.requests.single;
        expect(upgrade.uri.path, '/api-ws/v1/inference');
        expect(upgrade.headers.value(HttpHeaders.authorizationHeader), 'Bearer $_key');
        expect(upgrade.uri.query, isEmpty);
        final run = jsonDecode(received.first as String) as Map<String, Object?>;
        final header = run['header']! as Map<String, Object?>;
        final payload = run['payload']! as Map<String, Object?>;
        expect(header['action'], 'run-task');
        expect(header['streaming'], 'duplex');
        expect(payload['model'], 'fun-asr-realtime');
        expect(payload['task_group'], 'audio');
        expect(payload['task'], 'asr');
        expect(payload['function'], 'recognition');
        expect(payload['parameters'], {
          'format': 'pcm',
          'sample_rate': 16000,
          'language_hints': ['en'],
        });
        expect(payload['input'], <String, Object?>{});
        // 160 ms → one 100 ms frame plus the 60 ms remainder at finish.
        expect([for (final f in received.whereType<List<int>>()) f.length], [3200, 1920]);
        final finish = jsonDecode(received.last as String) as Map<String, Object?>;
        expect((finish['header']! as Map)['action'], 'finish-task');
        expect((finish['header']! as Map)['task_id'], header['task_id']);
      },
    );

    test('task-failed during a session ends the stream with the mapped kind', () async {
      onMessage = (ws, m) {
        if (m is String && m.contains('"run-task"')) sendJson(ws, _event('task-started'));
        if (m is List<int>) {
          sendJson(ws, {
            'header': {
              'task_id': 't',
              'event': 'task-failed',
              'error_code': 'CLIENT_ERROR',
              'error_message': 'request timeout after 23 seconds.',
            },
            'payload': <String, Object?>{},
          });
          ws.close();
        }
      };
      final stream = await _provider(server)
          .openStream(_creds, const CloudStreamOptions(language: 'zh-Hans'));
      final drained = drain(stream);
      stream.addPcm(silence(100));
      final (_, error) = await drained;
      expect(error, cloudError(CloudAsrErrorKind.sessionEnded, secrets: _secrets));
      expect((error! as CloudAsrError).providerCode, 'CLIENT_ERROR');
    });

    test('task-failed instead of task-started fails openStream', () async {
      for (final (code, kind) in [
        ('InvalidApiKey', CloudAsrErrorKind.unauthorized),
        ('Arrearage', CloudAsrErrorKind.quotaExceeded),
        ('Throttling.RateQuota', CloudAsrErrorKind.rateLimited),
        ('InvalidParameter', CloudAsrErrorKind.badRequest),
        ('InternalError.Algo', CloudAsrErrorKind.server),
      ]) {
        onMessage = (ws, m) {
          sendJson(ws, {
            'header': {'event': 'task-failed', 'error_code': code, 'error_message': 'bad $_key'},
            'payload': <String, Object?>{},
          });
          ws.close();
        };
        await expectLater(
          _provider(server).openStream(_creds, const CloudStreamOptions(language: 'en')),
          throwsA(cloudError(kind, secrets: _secrets)),
          reason: code,
        );
      }
    });

    test('a 401 on the upgrade is unauthorized', () async {
      final refusing = await FakeServer.start(
        (request) => replyJson(
          request,
          '{"code":"InvalidApiKey","message":"Invalid API-key provided."}',
          status: 401,
        ),
      );
      addTearDown(refusing.close);
      await expectLater(
        _provider(refusing).openStream(_creds, const CloudStreamOptions(language: 'en')),
        throwsA(
          cloudError(
            CloudAsrErrorKind.unauthorized,
            secrets: _secrets,
          ).having((e) => e.statusCode, 'status', 401),
        ),
      );
    });

    test('a socket closed by the service without a message is a session end', () async {
      onMessage = (ws, m) {
        if (m is String && m.contains('"run-task"')) sendJson(ws, _event('task-started'));
        if (m is List<int>) ws.close(WebSocketStatus.normalClosure);
      };
      final stream = await _provider(server)
          .openStream(_creds, const CloudStreamOptions(language: 'en'));
      final drained = drain(stream);
      stream.addPcm(silence(100));
      final (_, error) = await drained;
      expect(error, cloudError(CloudAsrErrorKind.sessionEnded));
    });
  });

  group('file', () {
    final wav = countingWav(2000);
    late FakeServer server;
    late List<String> log;
    late Map<String, Object?> submitted;
    late Uint8List uploaded;
    var polls = 0;
    late Future<bool> Function(HttpRequest request) override;

    Map<String, Object?> policy() => {
      'request_id': 'r',
      'data': {
        'policy': 'eyJleHBpcmF0aW9uIjoiMjAyNi0xMC0yNVQwMDowMDowMFoifQ==',
        'signature': 'OssSignature0=',
        'upload_dir': 'dashscope-instant/abc/2026-10-25/xyz',
        'upload_host': '${server.http}/oss',
        'expire_in_seconds': 300,
        'max_file_size_mb': 100,
        'capacity_limit_mb': 999999999,
        'oss_access_key_id': 'LTAIoss',
        'x_oss_object_acl': 'private',
        'x_oss_forbid_overwrite': 'true',
      },
    };

    const transcription = {
      'file_url': 'oss://x',
      'properties': {
        'audio_format': 'pcm_s16le',
        'channels': [0],
        'original_sampling_rate': 16000,
      },
      'transcripts': [
        {
          'channel_id': 0,
          'text': 'Hello world, this is a test.',
          'sentences': [
            {
              'begin_time': 100,
              'end_time': 1200,
              'text': 'Hello world, this is a test.',
              'sentence_id': 1,
              'words': [
                {'begin_time': 100, 'end_time': 596, 'text': 'Hello ', 'punctuation': ''},
                {'begin_time': 596, 'end_time': 844, 'text': 'world', 'punctuation': ', '},
              ],
            },
            {
              'begin_time': 1300,
              'end_time': 1900,
              'text': 'Second.',
              'sentence_id': 2,
              'words': <Object>[],
            },
          ],
        },
      ],
    };

    setUp(() async {
      log = [];
      polls = 0;
      override = (_) async => false;
      server = await FakeServer.start((request) async {
        final path = request.uri.path;
        log.add('${request.method} $path');
        if (await override(request)) return;
        switch ((request.method, path)) {
          case ('GET', '/api/v1/uploads'):
            expect(request.uri.queryParameters, {'action': 'getPolicy', 'model': 'fun-asr'});
            expect(request.headers.value(HttpHeaders.authorizationHeader), 'Bearer $_key');
            await replyJson(request, jsonEncode(policy()));
          case ('POST', '/oss'):
            expect(request.headers.value(HttpHeaders.authorizationHeader), isNull);
            uploaded = await readBody(request);
            request.response.statusCode = 200;
            await request.response.close();
          case ('POST', '/api/v1/services/audio/asr/transcription'):
            expect(request.headers.value('X-DashScope-Async'), 'enable');
            expect(request.headers.value('X-DashScope-OssResourceResolve'), 'enable');
            expect(request.headers.value(HttpHeaders.authorizationHeader), 'Bearer $_key');
            submitted = jsonDecode(utf8.decode(await readBody(request))) as Map<String, Object?>;
            await replyJson(
              request,
              '{"output":{"task_status":"PENDING","task_id":"task-1"},"request_id":"r"}',
            );
          case ('GET', '/api/v1/tasks/task-1'):
            polls++;
            final status = polls < 2 ? 'PENDING' : (polls < 3 ? 'RUNNING' : 'SUCCEEDED');
            await replyJson(
              request,
              jsonEncode({
                'output': {
                  'task_id': 'task-1',
                  'task_status': status,
                  if (status == 'SUCCEEDED')
                    'results': [
                      {
                        'file_url': 'oss://x',
                        'transcription_url': '${server.http}/result.json?Expires=1&Signature=s',
                        'subtask_status': 'SUCCEEDED',
                      },
                    ],
                },
              }),
            );
          case ('GET', '/result.json'):
            expect(request.headers.value(HttpHeaders.authorizationHeader), isNull);
            await replyJson(request, jsonEncode(transcription));
          default:
            await replyJson(request, '{"code":"NotFound"}', status: 404);
        }
      });
    });
    tearDown(() => server.close());

    test('policy → OSS form upload → task → poll → result, with times and words', () async {
      final progress = <double>[];
      final segments = await _provider(server).transcribeFile(
        _creds,
        CloudFileRequest(wav: wav, durationMs: 2000, language: 'en-GB'),
        onProgress: progress.add,
      );
      expect(log, [
        'GET /api/v1/uploads',
        'POST /oss',
        'POST /api/v1/services/audio/asr/transcription',
        'GET /api/v1/tasks/task-1',
        'GET /api/v1/tasks/task-1',
        'GET /api/v1/tasks/task-1',
        'GET /result.json',
      ]);
      // The multipart form: policy fields first, the file last and intact.
      final text = latin1.decode(uploaded);
      final names = RegExp(r'; name="([^"]+)"').allMatches(text).map((m) => m.group(1)).toList();
      expect(names, [
        'OSSAccessKeyId',
        'Signature',
        'policy',
        'x-oss-object-acl',
        'x-oss-forbid-overwrite',
        'key',
        'success_action_status',
        'file',
      ]);
      final key = RegExp(r'name="key"\r\n\r\n([^\r]+)\r\n').firstMatch(text)!.group(1)!;
      expect(key, startsWith('dashscope-instant/abc/2026-10-25/xyz/tinglang-'));
      expect(key, endsWith('.wav'));
      final fileStart = text.indexOf('\r\n\r\n', text.indexOf('name="file"')) + 4;
      expect(uploaded.sublist(fileStart, fileStart + wav.length), wav);
      expect(text.substring(fileStart + wav.length), startsWith('\r\n--'));
      expect(submitted, {
        'model': 'fun-asr',
        'input': {
          'file_urls': ['oss://$key'],
        },
        'parameters': {
          'channel_id': [0],
          'language_hints': ['en'],
        },
      });
      expect(
        [for (final s in segments) (s.id, s.text, s.startMs, s.endMs)],
        [('0', 'Hello world, this is a test.', 100, 1200), ('1', 'Second.', 1300, 1900)],
      );
      expect(segments[0].words!.map((w) => (w.text, w.startMs, w.endMs)), [
        ('Hello', 100, 596),
        ('world', 596, 844),
      ]);
      expect(segments[1].words, isNull);
      expect(progress.last, 1.0);
      expect(progress, orderedEquals([...progress]..sort()));
    });

    test('verify asks for an upload policy and nothing else', () async {
      await _provider(server).verify(_creds);
      expect(log, ['GET /api/v1/uploads']);
    });

    test('HTTP error codes map to kinds without the key', () async {
      for (final (status, body, kind) in [
        (
          401,
          '{"code":"InvalidApiKey","message":"Invalid API-key provided: $_key"}',
          CloudAsrErrorKind.unauthorized,
        ),
        (
          400,
          '{"code":"Arrearage","message":"Access denied, please make sure your account is in good standing."}',
          CloudAsrErrorKind.quotaExceeded,
        ),
        (
          403,
          '{"code":"AccessDenied.Unpurchased","message":"Access to model denied."}',
          CloudAsrErrorKind.quotaExceeded,
        ),
        (
          403,
          '{"code":"AllocationQuota.FreeTierOnly","message":"free tier exhausted"}',
          CloudAsrErrorKind.quotaExceeded,
        ),
        (
          429,
          '{"code":"Throttling.RateQuota","message":"Requests rate limit exceeded"}',
          CloudAsrErrorKind.rateLimited,
        ),
        (500, '{"code":"InternalError","message":"oops"}', CloudAsrErrorKind.server),
        (503, 'gateway', CloudAsrErrorKind.server),
      ]) {
        override = (request) async {
          await replyJson(request, body, status: status);
          return true;
        };
        await expectLater(
          _provider(server).verify(_creds),
          throwsA(
            cloudError(kind, secrets: _secrets).having((e) => e.statusCode, 'status', status),
          ),
          reason: body,
        );
      }
    });

    test('a failed subtask maps its code; no speech is an empty result', () async {
      for (final (code, expected) in [
        ('FILE_DOWNLOAD_FAILED', CloudAsrErrorKind.badRequest),
        ('AUDIO_DURATION_TOO_LONG', CloudAsrErrorKind.audioTooLong),
        ('SUCCESS_WITH_NO_VALID_FRAGMENT', null),
      ]) {
        override = (request) async {
          if (request.uri.path.startsWith('/api/v1/tasks/')) {
            await replyJson(
              request,
              jsonEncode({
                'output': {
                  'task_status': 'SUCCEEDED',
                  'results': [
                    {
                      'file_url': 'oss://x',
                      'code': code,
                      'message': code,
                      'subtask_status': 'FAILED',
                    },
                  ],
                },
              }),
            );
            return true;
          }
          return false;
        };
        final call = _provider(server)
            .transcribeFile(_creds, CloudFileRequest(wav: wav, durationMs: 2000, language: 'en'));
        if (expected == null) {
          expect(await call, isEmpty);
        } else {
          await expectLater(call, throwsA(cloudError(expected)), reason: code);
        }
      }
    });

    test('a FAILED task is reported with its code', () async {
      override = (request) async {
        if (request.uri.path.startsWith('/api/v1/tasks/')) {
          await replyJson(
            request,
            '{"output":{"task_status":"FAILED","code":"InvalidFile.DownloadFailed","message":"download failed"}}',
          );
          return true;
        }
        return false;
      };
      await expectLater(
        _provider(server)
            .transcribeFile(_creds, CloudFileRequest(wav: wav, durationMs: 2000, language: 'en')),
        throwsA(
          cloudError(CloudAsrErrorKind.badRequest)
              .having((e) => e.providerCode, 'code', 'InvalidFile.DownloadFailed'),
        ),
      );
    });

    test('an upload host outside Alibaba Cloud is refused before any audio leaves', () async {
      override = (request) async {
        if (request.uri.path == '/api/v1/uploads') {
          final p = policy();
          (p['data']! as Map<String, Object?>)['upload_host'] = 'https://evil.example.com/oss';
          await replyJson(request, jsonEncode(p));
          return true;
        }
        return false;
      };
      await expectLater(
        _provider(server)
            .transcribeFile(_creds, CloudFileRequest(wav: wav, durationMs: 2000, language: 'en')),
        throwsA(cloudError(CloudAsrErrorKind.protocol)),
      );
      expect(log, ['GET /api/v1/uploads']);
    });

    test('an OSS refusal is reported from its XML', () async {
      override = (request) async {
        if (request.uri.path == '/oss') {
          await readBody(request);
          request.response
            ..statusCode = 403
            ..write(
              '<?xml version="1.0"?><Error><Code>AccessDenied</Code><Message>Invalid according to Policy: Policy expired.</Message></Error>',
            );
          await request.response.close();
          return true;
        }
        return false;
      };
      await expectLater(
        _provider(server)
            .transcribeFile(_creds, CloudFileRequest(wav: wav, durationMs: 2000, language: 'en')),
        throwsA(
          cloudError(
            CloudAsrErrorKind.server,
            secrets: [..._secrets, 'LTAIoss', 'OssSignature0='],
          ).having((e) => e.message, 'message', contains('Policy expired')),
        ),
      );
    });

    test('cancel while polling stops with cancelled', () async {
      override = (request) async {
        if (request.uri.path.startsWith('/api/v1/tasks/')) {
          await replyJson(request, '{"output":{"task_status":"RUNNING"}}');
          return true;
        }
        return false;
      };
      final token = CloudCancelToken();
      final call = _provider(server).transcribeFile(
        _creds,
        CloudFileRequest(wav: wav, durationMs: 2000, language: 'en'),
        cancel: token,
      );
      await Future<void>.delayed(const Duration(milliseconds: 150));
      token.cancel();
      await expectLater(call, throwsA(cloudError(CloudAsrErrorKind.cancelled)));
      final polled = log.where((l) => l.contains('/tasks/')).length;
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(log.where((l) => l.contains('/tasks/')).length, polled);
    });

    test('an unreachable service is a network error', () async {
      final port = await closedPort();
      final p = DashScopeAsr(httpBaseUrl: Uri.parse('http://127.0.0.1:$port'));
      await expectLater(
        p.verify(_creds),
        throwsA(cloudError(CloudAsrErrorKind.network, secrets: _secrets)),
      );
    });
  });

  test('a missing key is unauthorized', () async {
    await expectLater(
      DashScopeAsr().verify({CloudFieldKeys.region: 'cn'}),
      throwsA(cloudError(CloudAsrErrorKind.unauthorized)),
    );
  });
}

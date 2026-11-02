import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tinglang/core/providers/llm_client.dart';

/// A local OpenAI-compatible server that rejects `json_schema` (as several
/// compatible servers do) and answers in a ``` fence.
Future<(HttpServer, List<Map<String, Object?>>, List<String?>)> _server() async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final bodies = <Map<String, Object?>>[];
  final auth = <String?>[];
  server.listen((request) async {
    auth.add(request.headers.value(HttpHeaders.authorizationHeader));
    final response = request.response..headers.contentType = ContentType.json;
    if (request.uri.path == '/v1/models') {
      if (request.headers.value(HttpHeaders.authorizationHeader) != 'Bearer sk-good') {
        response.statusCode = 401;
        response.write(
          jsonEncode({
            'error': {'message': 'Invalid API key'},
          }),
        );
      } else {
        response.write(
          jsonEncode({
            'data': [
              {'id': 'model-b'},
              {'id': 'model-a'},
            ],
          }),
        );
      }
    } else if (request.uri.path == '/v1/chat/completions') {
      final body = jsonDecode(await utf8.decodeStream(request)) as Map<String, Object?>;
      bodies.add(body);
      final format = (body['response_format'] as Map?)?['type'];
      if (request.headers.value(HttpHeaders.authorizationHeader) != 'Bearer sk-good') {
        response.statusCode = 401;
        response.write(
          jsonEncode({
            'error': {'message': 'Invalid API key'},
          }),
        );
      } else if (format == 'json_schema') {
        response.statusCode = 400;
        response.write(
          jsonEncode({
            'error': {'message': 'response_format json_schema is not supported'},
          }),
        );
      } else {
        response.write(
          jsonEncode({
            'id': 'chatcmpl-1',
            'object': 'chat.completion',
            'created': 1,
            'model': 'model-a',
            'choices': [
              {
                'index': 0,
                'message': {
                  'role': 'assistant',
                  'content': 'Sure!\n```json\n{"title": "ok", "n": 2}\n```',
                },
                'finish_reason': 'stop',
              },
            ],
            'usage': {'prompt_tokens': 30, 'completion_tokens': 7, 'total_tokens': 37},
          }),
        );
      }
    } else {
      response.statusCode = 404;
    }
    await response.close();
  });
  return (server, bodies, auth);
}

void main() {
  test('falls back from json_schema to json_object and strips fences', () async {
    final (server, bodies, auth) = await _server();
    addTearDown(() => server.close(force: true));
    final client = LlmClient(
      baseUrl: 'http://127.0.0.1:${server.port}/v1/',
      model: 'model-a',
      apiKey: 'sk-good',
    );
    final reply = await client.completeJson(
      system: 's',
      user: 'u',
      schemaName: 'x',
      schema: const {'type': 'object'},
    );
    expect(reply, {'title': 'ok', 'n': 2});
    expect(bodies.map((b) => (b['response_format'] as Map?)?['type']), [
      'json_schema',
      'json_object',
    ]);
    expect(client.jsonMode, JsonMode.jsonObject);
    // With only json_object enforced, the schema travels in the system prompt;
    // every message goes out as plain text.
    final messages = (bodies.last['messages']! as List).cast<Map<String, Object?>>();
    expect(messages.first['role'], 'system');
    expect(messages.first['content'], 's\n\n${schemaInstructions(const {'type': 'object'})}');
    expect(messages.last, {'role': 'user', 'content': 'u'});
    expect(client.usage.calls, 1);
    expect(client.usage.inputTokens, 30);
    expect(client.usage.outputTokens, 7);
    // The fallback is remembered: the next call goes straight to json_object.
    await client.completeJson(
      system: 's',
      user: 'u',
      schemaName: 'x',
      schema: const {'type': 'object'},
    );
    expect((bodies.last['response_format'] as Map?)?['type'], 'json_object');
    expect(auth.every((a) => a == 'Bearer sk-good'), isTrue);
    expect(await client.models(), ['model-a', 'model-b']);
    client.close();
  });

  test('errors carry the status but never the key', () async {
    final (server, _, _) = await _server();
    addTearDown(() => server.close(force: true));
    final client = LlmClient(
      baseUrl: 'http://127.0.0.1:${server.port}/v1',
      model: 'm',
      apiKey: 'sk-bad-SECRET',
    );
    try {
      await client.models();
      fail('expected an error');
    } on LlmException catch (e) {
      expect(e.unauthorized, isTrue);
      expect('$e', contains('Invalid API key'));
      expect('$e', isNot(contains('SECRET')));
    }
    client.close();
  });

  test('a model listed without json_schema starts at json_object', () async {
    final (server, bodies, _) = await _server();
    addTearDown(() => server.close(force: true));
    final client = LlmClient(
      baseUrl: 'http://127.0.0.1:${server.port}/v1',
      model: 'model-a',
      apiKey: 'sk-good',
      jsonMode: JsonMode.jsonObject,
    );
    await client.completeJson(
      system: 's',
      user: 'u',
      schemaName: 'x',
      schema: const {'type': 'object'},
    );
    expect(bodies.single['response_format'], {'type': 'json_object'});
    client.close();
  });

  test('chat errors carry the status and stop; a key never shows', () async {
    final (server, _, _) = await _server();
    addTearDown(() => server.close(force: true));
    final client = LlmClient(
      baseUrl: 'http://127.0.0.1:${server.port}/v1',
      model: 'model-a',
      apiKey: 'sk-bad-SECRET',
    );
    await expectLater(
      client.completeJson(system: 's', user: 'u', schemaName: 'x', schema: const {}),
      throwsA(
        isA<LlmException>()
            .having((e) => e.unauthorized, 'unauthorized', isTrue)
            .having((e) => '$e', 'text', isNot(contains('SECRET'))),
      ),
    );
    client.close();
  });

  test('unreachable servers and bad URLs fail cleanly', () async {
    final unreachable = LlmClient(baseUrl: 'http://127.0.0.1:9/v1', model: 'm');
    await expectLater(unreachable.models(), throwsA(isA<LlmException>()));
    await expectLater(
      unreachable.completeJson(system: 's', user: 'u', schemaName: 'x', schema: const {}),
      throwsA(isA<LlmException>().having((e) => e.status, 'status', isNull)),
    );
    final bad = LlmClient(baseUrl: 'ftp://example.com', model: 'm');
    await expectLater(bad.models(), throwsA(isA<LlmException>()));
    await expectLater(
      bad.completeJson(system: 's', user: 'u', schemaName: 'x', schema: const {}),
      throwsA(isA<LlmException>()),
    );
  });

  test('parseJsonObject tolerates chatter and rejects non-objects', () {
    expect(parseJsonObject('{"a":1}'), {'a': 1});
    expect(parseJsonObject('Here you go: {"a": {"b": 2}} hope it helps'), {
      'a': {'b': 2},
    });
    expect(() => parseJsonObject('[1,2]'), throwsA(isA<LlmException>()));
    expect(() => parseJsonObject('no json'), throwsA(isA<LlmException>()));
  });
}

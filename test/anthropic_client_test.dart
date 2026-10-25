import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tinglang/core/providers/catalog.dart';
import 'package:tinglang/core/providers/llm_client.dart';

/// A local stand-in for the Messages API. [reply] decides each answer.
Future<(HttpServer, List<HttpHeaders>, List<Map<String, Object?>>)> _server(
  (int, Map<String, Object?>) Function(Map<String, Object?> body, int call) reply,
) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final headers = <HttpHeaders>[];
  final bodies = <Map<String, Object?>>[];
  server.listen((request) async {
    headers.add(request.headers);
    final response = request.response..headers.contentType = ContentType.json;
    if (request.uri.path == '/v1/models') {
      response.write(
        jsonEncode({
          'data': [
            {'id': 'claude-opus-5-5', 'type': 'model'},
          ],
        }),
      );
    } else {
      final body = jsonDecode(await utf8.decodeStream(request)) as Map<String, Object?>;
      bodies.add(body);
      final (status, json) = reply(body, bodies.length);
      response
        ..statusCode = status
        ..write(jsonEncode(json));
    }
    await response.close();
  });
  return (server, headers, bodies);
}

Map<String, Object?> _message(String text, {String stop = 'end_turn'}) => {
  'type': 'message',
  'role': 'assistant',
  'content': [
    {'type': 'thinking', 'thinking': ''},
    {'type': 'text', 'text': text},
  ],
  'stop_reason': stop,
  'usage': {'input_tokens': 1200, 'output_tokens': 800},
};

void main() {
  const schema = {
    'type': 'object',
    'properties': {
      'title': {'type': 'string'},
    },
    'required': ['title'],
    'additionalProperties': false,
  };

  test('Messages API: x-api-key, version header, structured output, usage', () async {
    final (server, headers, bodies) = await _server((_, _) => (200, _message('{"title":"ok"}')));
    addTearDown(() => server.close(force: true));
    final client = LlmClient(
      baseUrl: 'http://127.0.0.1:${server.port}/v1',
      model: 'claude-opus-5-5',
      apiKey: 'sk-ant-test',
      protocol: LlmProtocol.anthropic,
    );
    expect(await client.models(), ['claude-opus-5-5']);
    final reply = await client.completeJson(
      system: 'sys',
      user: 'hi',
      schemaName: 'x',
      schema: schema,
    );
    expect(reply, {'title': 'ok'});
    expect(headers.every((h) => h.value('x-api-key') == 'sk-ant-test'), isTrue);
    expect(
      headers.every((h) => h.value('authorization') == null),
      isTrue,
      reason: 'key only in x-api-key',
    );
    expect(headers.every((h) => h.value('anthropic-version') == '2023-06-01'), isTrue);
    final body = bodies.single;
    expect(body['system'], 'sys');
    expect(body['max_tokens'], AnthropicClient.maxTokens);
    expect(body['output_config'], {
      'format': {'type': 'json_schema', 'schema': schema},
    });
    // Fallbacks only on the real Claude API host.
    expect(body.containsKey('fallbacks'), isFalse);
    expect(client.usage.inputTokens, 1200);
    expect(client.usage.outputTokens, 800);
    client.close();
  });

  test('refusals and cut-off replies are reported as such', () async {
    final (server, _, _) = await _server(
      (_, call) => call == 1
          ? (
              200,
              {
                ..._message(''),
                'content': <Object?>[],
                'stop_reason': 'refusal',
                'stop_details': {'category': 'cyber'},
              },
            )
          : (200, _message('{"title": "partial', stop: 'max_tokens')),
    );
    addTearDown(() => server.close(force: true));
    final client = AnthropicClient(
      baseUrl: 'http://127.0.0.1:${server.port}/v1',
      model: 'claude-opus-5-5',
      apiKey: 'k',
    );
    await expectLater(
      client.completeJson(system: 's', user: 'u', schemaName: 'x', schema: schema),
      throwsA(isA<LlmException>().having((e) => e.refused, 'refused', isTrue)),
    );
    await expectLater(
      client.completeJson(system: 's', user: 'u', schemaName: 'x', schema: schema),
      throwsA(isA<LlmException>().having((e) => e.truncated, 'truncated', isTrue)),
    );
    client.close();
  });

  test('errors carry the API message and status, never the key', () async {
    final (server, _, _) = await _server(
      (_, _) => (
        401,
        {
          'type': 'error',
          'error': {'type': 'authentication_error', 'message': 'invalid x-api-key'},
        },
      ),
    );
    addTearDown(() => server.close(force: true));
    final client = AnthropicClient(
      baseUrl: 'http://127.0.0.1:${server.port}/v1',
      model: 'm',
      apiKey: 'sk-ant-SECRET',
    );
    try {
      await client.completeJson(system: 's', user: 'u', schemaName: 'x', schema: schema);
      fail('expected an error');
    } on LlmException catch (e) {
      expect(e.unauthorized, isTrue);
      expect('$e', contains('invalid x-api-key'));
      expect('$e', isNot(contains('SECRET')));
    }
    client.close();
  });

  group('catalog', () {
    final catalog = ProviderCatalog.fromJson(
      File('assets/providers/catalog.v1.json').readAsStringSync(),
    );

    test('presets carry protocol, base URL and a listed default model', () {
      final anthropic = catalog.preset('anthropic');
      expect(anthropic.protocol, LlmProtocol.anthropic);
      expect(anthropic.baseUrl, 'https://api.anthropic.com/v1');
      expect(anthropic.model, 'claude-opus-5-5');
      expect(catalog.preset('litellm').baseUrl, 'http://localhost:4000/v1');
      expect(catalog.preset('litellm').needsKey, isFalse);
      expect(catalog.preset('nonexistent').id, 'custom');
      expect(catalog.presets.last.id, 'custom');
      for (final p in catalog.presets) {
        if (p.model.isNotEmpty) expect(catalog.model(p.id, p.model), isNotNull, reason: p.id);
        if (p.id != 'anthropic') expect(p.protocol, LlmProtocol.openai, reason: p.id);
      }
    });

    test('prices and cost', () {
      final opus = catalog.model('anthropic', 'claude-opus-5-5')!;
      expect(opus.inputPerMTok, 4);
      expect(opus.outputPerMTok, 20);
      expect(opus.context, 1000000);
      expect(opus.jsonSchema, isTrue);
      expect(opus.cost(1000000, 100000), closeTo(6, 1e-9));
      final estimate = CostEstimate.forCourse(
        windows: 3,
        clips: 1,
        transcriptChars: 1600,
        model: opus,
      );
      expect(estimate.calls, 2);
      expect(estimate.usd, closeTo(opus.cost(estimate.inputTokens, estimate.outputTokens), 1e-12));
      expect(CostEstimate.forCourse(windows: 1, clips: 1, transcriptChars: 100).usd, isNull);
    });

    test('formatting', () {
      expect(formatUsd(4), r'$4');
      expect(formatUsd(0.28), r'$0.28');
      expect(formatUsd(0.0123), r'$0.012');
      expect(formatTokens(1000000), '1M');
      expect(formatTokens(200000), '200K');
      expect(formatTokens(1234), '1.2K');
    });
  });
}

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tinglang/core/providers/llm_client.dart';

import 'cloud_fakes.dart';

/// The LLM gateway (docs/CLOUD.md §7.4) is OpenAI-compatible, so the app's
/// existing client must read the contract's examples as they are.
void main() {
  late LocalServer server;
  setUp(() async => server = await LocalServer.start());
  tearDown(() => server.close());

  test('the BYOK OpenAI-compatible client works against the gateway contract', () async {
    server.handler = (r) => switch (r.uri.path) {
      '/v1/llm/models' => (200, contractExample('listLlmModels/response.200.json')),
      '/v1/llm/chat/completions' => (
        200,
        contractExample('createLlmChatCompletion/response.200.json'),
      ),
      _ => (404, null),
    };
    final client = LlmClient(
      baseUrl: '${server.origin}/v1/llm',
      model: 'tinglang-course-standard',
      apiKey: 'account-access-token',
    );
    addTearDown(client.close);

    expect(await client.models(), ['tinglang-course-standard']);
    final reply = await client.completeJson(
      system: 'Reply with JSON only.',
      user: '<transcript>…</transcript>',
      schemaName: 'clip_plan',
      schema: const {'type': 'object'},
    );
    expect(reply, {'clips': <Object?>[]});

    final chat = server.requests.last;
    expect(chat.header('authorization'), 'Bearer account-access-token');
    final body = jsonDecode(chat.body) as Map<String, Object?>;
    // The request carries what the contract's schema requires.
    expect(body['model'], 'tinglang-course-standard');
    expect((body['messages']! as List<Object?>).length, 2);
  });

  test('a gateway refusal surfaces with its status', () async {
    server.handler = (_) => (402, contractExample('createLlmChatCompletion/response.402.json'));
    final client = LlmClient(baseUrl: '${server.origin}/v1/llm', model: 'm', apiKey: 't');
    addTearDown(client.close);
    await expectLater(
      client.completeJson(system: 's', user: 'u', schemaName: 'n', schema: const {}),
      throwsA(isA<LlmException>().having((e) => e.status, 'status', 402)),
    );
  });
}

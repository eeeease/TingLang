import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:anthropic_sdk_dart/anthropic_sdk_dart.dart' as claude_sdk;
import 'package:genkit/genkit.dart'
    show GenkitException, GenkitPlugin, Model;
import 'package:genkit/lite.dart' as genkit;
import 'package:genkit_anthropic/genkit_anthropic.dart';
import 'package:genkit_openai/genkit_openai.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:openai_dart/openai_dart.dart' as openai_sdk;
import 'package:schemantic/schemantic.dart';

/// A failed LLM call. Messages never contain the API key or the prompt.
class LlmException implements Exception {
  const LlmException(this.message, {this.status, this.refused = false, this.truncated = false});
  final String message;
  final int? status;

  /// The model declined (Anthropic `stop_reason: refusal`).
  final bool refused;

  /// The reply hit the output limit and is incomplete.
  final bool truncated;
  bool get unauthorized => status == 401 || status == 403;
  @override
  String toString() => status == null ? message : '$message (HTTP $status)';
}

/// A cloud provider has no API key saved (or the Keychain gave none back):
/// nothing is sent, since every call would be refused.
class MissingApiKey implements Exception {
  const MissingApiKey(this.provider);

  /// The provider's label, for the message.
  final String provider;
  @override
  String toString() => 'No API key for $provider';
}

/// The wire protocol a provider speaks.
enum LlmProtocol {
  /// OpenAI Chat Completions: OpenAI, DeepSeek, Qwen, Kimi, GLM, Gemini,
  /// OpenRouter, LiteLLM Proxy, Ollama, LM Studio and most others.
  openai,

  /// Anthropic Messages API (Claude).
  anthropic;

  static LlmProtocol parse(String? name) => name == 'anthropic' ? anthropic : openai;
}

/// Tokens reported by the provider, summed over a client's calls.
class LlmUsage {
  int inputTokens = 0, outputTokens = 0, calls = 0;

  /// Claude prompt caching: input tokens written to and read from the cache
  /// (not part of [inputTokens]).
  int cacheWriteTokens = 0, cacheReadTokens = 0;
}

/// How a reply is held to its JSON schema, strongest first. A server that
/// rejects one steps the client down to the next for the rest of its calls.
enum JsonMode {
  /// The provider enforces the schema (`json_schema`, Anthropic structured
  /// outputs).
  schema,

  /// The schema goes in the prompt; the provider only guarantees JSON
  /// (`json_object`).
  jsonObject,

  /// The schema goes in the prompt and nothing is enforced.
  prompt,
}

/// One provider endpoint that answers JSON prompts, through Genkit's model
/// plugins (`genkit_openai` for OpenAI-compatible servers, `genkit_anthropic`
/// for Claude). The key goes in the provider's auth header and nowhere else.
class LlmClient {
  LlmClient({
    required String baseUrl,
    required this.model,
    this._apiKey,
    this.protocol = LlmProtocol.openai,
    HttpClient? http,
    this.timeout = const Duration(minutes: 5),
    JsonMode jsonMode = JsonMode.schema,
    this.effort,
  }) : baseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl,
       _http = http ?? (HttpClient()..connectionTimeout = const Duration(seconds: 10)),
       _mode = protocol == LlmProtocol.anthropic ? JsonMode.schema : jsonMode;

  final String baseUrl, model;
  final LlmProtocol protocol;
  final String? _apiKey;
  final HttpClient _http;

  /// Per request. Reasoning models can take minutes on a long JSON reply.
  final Duration timeout;

  /// Claude's `output_config.effort` (`low`…`max`); the model's default when
  /// null.
  final String? effort;
  final usage = LlmUsage();
  JsonMode _mode;

  /// The structured-output mode the next call uses.
  JsonMode get jsonMode => _mode;

  /// Claude's reply limit; non-streaming requests stay well under HTTP
  /// timeouts at this size.
  static const anthropicMaxTokens = 16000;

  Uri _url(String path) {
    final Uri uri;
    try {
      uri = Uri.parse('$baseUrl$path');
    } on FormatException {
      throw const LlmException('Invalid base URL');
    }
    if (uri.scheme != 'http' && uri.scheme != 'https' || uri.host.isEmpty) {
      throw const LlmException('Base URL must start with http:// or https://');
    }
    return uri;
  }

  late final Model<dynamic> _model = _plugin().model(model);

  GenkitPlugin _plugin() {
    _url('');
    final io = IOClient(_http);
    // Local servers (Ollama, LM Studio) take any key.
    final key = _apiKey == null || _apiKey.isEmpty ? 'none' : _apiKey;
    return switch (protocol) {
      LlmProtocol.openai => openAI(
        name: 'tinglang',
        apiKey: key,
        baseUrl: baseUrl,
        httpClient: RewriteJsonBody(io, '/chat/completions', plainTextMessages),
      ),
      // The SDK adds `/v1/messages` itself; presets store the `/v1` base.
      LlmProtocol.anthropic => anthropic(
        apiKey: key,
        baseUrl: baseUrl.replaceFirst(RegExp(r'/v1$'), ''),
        httpClient: RewriteJsonBody(io, '/messages', cacheSystemPrompt, onReply: _countCache),
      ),
    };
  }

  void _countCache(Map<String, Object?> reply) {
    final used = reply['usage'];
    if (used is! Map) return;
    usage.cacheWriteTokens += (used['cache_creation_input_tokens'] as num?)?.toInt() ?? 0;
    usage.cacheReadTokens += (used['cache_read_input_tokens'] as num?)?.toInt() ?? 0;
  }

  /// One request whose reply must be a JSON object matching [schema].
  Future<Map<String, Object?>> completeJson({
    required String system,
    required String user,
    required String schemaName,
    required Map<String, Object?> schema,
  }) async {
    final output = SchemanticType.from<Map<String, Object?>>(
      jsonSchema: schema,
      parse: (json) => json is Map<String, Object?> ? json : const {},
    );
    while (true) {
      final mode = _mode;
      final genkit.GenerateResult<Map<String, Object?>> result;
      try {
        result = await genkit
            .generate<Map<String, Object?>, dynamic>(
              model: _model,
              // Without native enforcement the schema goes in the prompt,
              // on one line: an indented schema costs several times the tokens.
              system: mode == JsonMode.schema ? system : '$system\n\n${schemaInstructions(schema)}',
              prompt: user,
              config: switch (protocol) {
                LlmProtocol.anthropic => AnthropicOptions(
                  maxTokens: anthropicMaxTokens,
                  outputConfig: effort == null ? null : AnthropicOutputConfig(effort: effort),
                ),
                LlmProtocol.openai => OpenAIChatOptions(jsonMode: mode == JsonMode.jsonObject),
              },
              outputSchema: mode == JsonMode.schema ? output : null,
            )
            .timeout(timeout);
      } on TimeoutException {
        throw const LlmException('The provider did not answer in time');
      } on GenkitException catch (e) {
        throw _failure(e);
      }
      final reason = result.finishReason.value;
      if (reason == 'failed' || reason == 'aborted') {
        final failure = _failure(result.cause);
        final next = _stepDown(failure);
        if (next != null) {
          _mode = next;
          continue;
        }
        throw failure;
      }
      usage.calls++;
      usage.inputTokens += result.usage?.inputTokens ?? 0;
      usage.outputTokens += result.usage?.outputTokens ?? 0;
      if (reason == 'blocked') {
        final why = result.finishMessage;
        throw LlmException(
          'The model declined this request${why == null || why.isEmpty ? '' : ' ($why)'}',
          refused: true,
        );
      }
      if (reason == 'length') {
        throw const LlmException('The reply was cut off at the output limit', truncated: true);
      }
      final text = result.text;
      if (text.trim().isEmpty) throw const LlmException('The reply had no text');
      return parseJsonObject(text);
    }
  }

  /// The weaker mode to retry in when the server rejected the output format.
  JsonMode? _stepDown(LlmException failure) {
    if (protocol != LlmProtocol.openai || _mode == JsonMode.prompt) return null;
    if (failure.status != 400 && failure.status != 422) return null;
    final text = failure.message.toLowerCase();
    if (!text.contains('response_format') && !text.contains('json') && !text.contains('schema')) {
      return null;
    }
    return JsonMode.values[_mode.index + 1];
  }

  /// The provider's own message and HTTP status, from whichever layer failed.
  static LlmException _failure(Object? error) {
    Object? e = error;
    while (e is GenkitException && e.cause != null) {
      e = e.cause;
    }
    return switch (e) {
      openai_sdk.ApiException() => LlmException(e.message, status: e.statusCode),
      claude_sdk.ApiException() => LlmException(e.message, status: e.statusCode),
      LlmException() => e,
      SocketException() => LlmException(
        'Cannot reach the provider: ${e.osError?.message ?? e.message}',
      ),
      HandshakeException() => const LlmException('TLS handshake with the provider failed'),
      TimeoutException() => const LlmException('The provider did not answer in time'),
      GenkitException() => LlmException(e.message),
      _ => LlmException('$e'.replaceFirst(RegExp(r'^\w*(Exception|Error): '), '')),
    };
  }

  /// "Test connection": lists model ids (also proves the key works).
  Future<List<String>> models() async {
    final uri = _url('/models');
    final String body;
    final int status;
    try {
      final request = await _http.getUrl(uri).timeout(timeout);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final key = _apiKey;
      if (protocol == LlmProtocol.anthropic) {
        request.headers.set('anthropic-version', '2023-06-01');
        if (key != null && key.isNotEmpty) request.headers.set('x-api-key', key);
      } else if (key != null && key.isNotEmpty) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $key');
      }
      final response = await request.close().timeout(timeout);
      body = await response.transform(utf8.decoder).join().timeout(timeout);
      status = response.statusCode;
    } on TimeoutException {
      throw const LlmException('The provider did not answer in time');
    } on SocketException catch (e) {
      throw LlmException('Cannot reach ${uri.host}: ${e.osError?.message ?? e.message}');
    } on HandshakeException {
      throw LlmException('TLS handshake with ${uri.host} failed');
    } on HttpException catch (e) {
      throw LlmException('HTTP error: ${e.message}');
    }
    Object? json;
    try {
      json = jsonDecode(body);
    } on FormatException {
      json = null;
    }
    if (status != 200) throw LlmException(_errorText(json, body), status: status);
    final data = json is Map ? json['data'] : null;
    if (data is! List) throw const LlmException('The provider returned malformed JSON');
    return [
      for (final m in data)
        if (m is Map && m['id'] is String) m['id'] as String,
    ]..sort();
  }

  static String _errorText(Object? json, String body) {
    if (json is Map) {
      final error = json['error'];
      if (error is Map && error['message'] is String) return error['message'] as String;
      if (error is String) return error;
      if (json['message'] is String) return json['message'] as String;
    }
    return body.length > 200 ? '${body.substring(0, 200)}…' : body;
  }

  void close() => _http.close(force: true);
}

/// Rewrites the JSON body of requests to [path] on their way out; the
/// providers' SDKs give no say over these details.
class RewriteJsonBody extends http.BaseClient {
  RewriteJsonBody(this._inner, this.path, this.rewrite, {this.onReply});
  final http.Client _inner;

  /// Requests whose URL path ends with this are rewritten.
  final String path;
  final void Function(Map<String, Object?> body) rewrite;

  /// Sees each successful JSON reply to those requests (for figures the
  /// SDK does not pass on).
  final void Function(Map<String, Object?> reply)? onReply;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (request is! http.Request || !request.url.path.endsWith(path)) {
      return _inner.send(request);
    }
    final Object? body;
    try {
      body = jsonDecode(request.body);
    } on FormatException {
      return _inner.send(request);
    }
    if (body is! Map<String, Object?>) return _inner.send(request);
    rewrite(body);
    final rewritten = http.Request(request.method, request.url)
      ..headers.addAll(request.headers)
      ..followRedirects = request.followRedirects
      ..maxRedirects = request.maxRedirects
      ..persistentConnection = request.persistentConnection
      ..bodyBytes = utf8.encode(jsonEncode(body));
    final reply = onReply;
    if (reply == null) return _inner.send(rewritten);
    return _inner.send(rewritten).then((response) async {
      if (response.statusCode != 200) return response;
      final bytes = await response.stream.toBytes();
      try {
        final json = jsonDecode(utf8.decode(bytes));
        if (json is Map<String, Object?>) reply(json);
      } on FormatException {
        // Not JSON (a stream): nothing to read.
      }
      return http.StreamedResponse(
        Stream.value(bytes),
        response.statusCode,
        contentLength: bytes.length,
        request: response.request,
        headers: response.headers,
        isRedirect: response.isRedirect,
        persistentConnection: response.persistentConnection,
        reasonPhrase: response.reasonPhrase,
      );
    });
  }

  @override
  void close() => _inner.close();
}

/// Chat Completions messages whose content is only text go as a plain
/// string. Genkit always sends a list of parts, which OpenAI accepts but
/// several compatible servers do not.
void plainTextMessages(Map<String, Object?> body) {
  final messages = body['messages'];
  if (messages is! List) return;
  for (final m in messages) {
    final content = m is Map ? m['content'] : null;
    if (content is List &&
        content.every((p) => p is Map && p['type'] == 'text' && p['text'] is String)) {
      m['content'] = content.map((p) => (p as Map)['text']).join('\n');
    }
  }
}

/// Marks Claude's system prompt for prompt caching. Course prompts put the
/// rules every clip shares there, so after the first clip they are read
/// from the cache at a tenth of the input price (prefixes shorter than the
/// model's minimum are simply not cached).
void cacheSystemPrompt(Map<String, Object?> body) {
  final system = body['system'];
  if (system is String && system.isNotEmpty) {
    body['system'] = [
      {
        'type': 'text',
        'text': system,
        'cache_control': {'type': 'ephemeral'},
      },
    ];
  } else if (system is List && system.isNotEmpty && system.last is Map) {
    (system.last as Map).putIfAbsent('cache_control', () => {'type': 'ephemeral'});
  }
}

/// The schema as prompt text, for servers that enforce none.
String schemaInstructions(Map<String, Object?> schema) =>
    'Reply with one JSON object that matches this JSON schema, and nothing else:\n'
    '${jsonEncode(schema)}';

/// Extracts the JSON object from a model reply (``` fences and chatter
/// around it are tolerated).
Map<String, Object?> parseJsonObject(String content) {
  var text = content.trim();
  final fence = RegExp(r'```(?:json)?\s*([\s\S]*?)```').firstMatch(text);
  if (fence != null) text = fence.group(1)!.trim();
  final start = text.indexOf('{'), end = text.lastIndexOf('}');
  if (start < 0 || end <= start) throw const LlmException('The reply was not a JSON object');
  try {
    final json = jsonDecode(text.substring(start, end + 1));
    if (json is Map<String, Object?>) return json;
  } on FormatException {
    // Reported below.
  }
  throw const LlmException('The reply was not a JSON object');
}

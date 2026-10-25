import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
}

/// One provider endpoint that answers JSON prompts. Uses `dart:io` only; the
/// key goes in the provider's auth header and nowhere else.
abstract class LlmClient {
  LlmClient._(String baseUrl, this.model, this._apiKey, HttpClient? http, this.timeout)
    : baseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl,
      _http = http ?? (HttpClient()..connectionTimeout = const Duration(seconds: 10));

  /// The client for [protocol].
  factory LlmClient({
    required String baseUrl,
    required String model,
    String? apiKey,
    LlmProtocol protocol = LlmProtocol.openai,
    HttpClient? http,
    Duration timeout = const Duration(minutes: 5),
  }) => switch (protocol) {
    LlmProtocol.openai => OpenAiCompatibleClient(
      baseUrl: baseUrl,
      model: model,
      apiKey: apiKey,
      http: http,
      timeout: timeout,
    ),
    LlmProtocol.anthropic => AnthropicClient(
      baseUrl: baseUrl,
      model: model,
      apiKey: apiKey,
      http: http,
      timeout: timeout,
    ),
  };

  final String baseUrl, model;
  final String? _apiKey;
  final HttpClient _http;

  /// Per request. Reasoning models can take minutes on a long JSON reply.
  final Duration timeout;
  final usage = LlmUsage();

  void _auth(HttpClientRequest request, String key);

  Future<(int, String)> _send(
    String method,
    String path, [
    Map<String, Object?>? body,
    Map<String, String>? headers,
  ]) async {
    final Uri uri;
    try {
      uri = Uri.parse('$baseUrl$path');
    } on FormatException {
      throw const LlmException('Invalid base URL');
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      throw const LlmException('Base URL must start with http:// or https://');
    }
    try {
      final request = await _http.openUrl(method, uri).timeout(timeout);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final key = _apiKey;
      if (key != null && key.isNotEmpty) _auth(request, key);
      headers?.forEach(request.headers.set);
      if (body != null) {
        request.headers.contentType = ContentType.json;
        request.add(utf8.encode(jsonEncode(body)));
      }
      final response = await request.close().timeout(timeout);
      final text = await response.transform(utf8.decoder).join().timeout(timeout);
      return (response.statusCode, text);
    } on TimeoutException {
      throw const LlmException('The provider did not answer in time');
    } on SocketException catch (e) {
      throw LlmException('Cannot reach ${uri.host}: ${e.osError?.message ?? e.message}');
    } on HandshakeException {
      throw LlmException('TLS handshake with ${uri.host} failed');
    } on HttpException catch (e) {
      throw LlmException('HTTP error: ${e.message}');
    }
  }

  static String _errorText(String body) {
    try {
      final json = jsonDecode(body);
      if (json is Map) {
        final error = json['error'];
        if (error is Map && error['message'] is String) return error['message'] as String;
        if (error is String) return error;
        if (json['message'] is String) return json['message'] as String;
      }
    } on FormatException {
      // Not JSON; fall through.
    }
    return body.length > 200 ? '${body.substring(0, 200)}…' : body;
  }

  static Map<Object?, Object?> _json(String body) {
    try {
      final json = jsonDecode(body);
      if (json is Map) return json;
    } on FormatException {
      // Reported below.
    }
    throw const LlmException('The provider returned malformed JSON');
  }

  /// "Test connection": lists model ids (also proves the key works).
  Future<List<String>> models() async {
    final (status, body) = await _send('GET', '/models');
    if (status != 200) throw LlmException(_errorText(body), status: status);
    final data = _json(body)['data'];
    return [
      if (data is List)
        for (final m in data)
          if (m is Map && m['id'] is String) m['id'] as String,
    ]..sort();
  }

  /// One request whose reply must be a JSON object matching [schema].
  Future<Map<String, Object?>> completeJson({
    required String system,
    required String user,
    required String schemaName,
    required Map<String, Object?> schema,
  });

  void close() => _http.close(force: true);
}

/// OpenAI-compatible Chat Completions. `response_format: json_schema` falls
/// back to `json_object`, then to none, when a server rejects it.
class OpenAiCompatibleClient extends LlmClient {
  OpenAiCompatibleClient({
    required String baseUrl,
    required String model,
    String? apiKey,
    HttpClient? http,
    Duration timeout = const Duration(minutes: 5),
  }) : super._(baseUrl, model, apiKey, http, timeout);

  static const _formats = ['json_schema', 'json_object', 'none'];
  int _format = 0;

  @override
  void _auth(HttpClientRequest request, String key) =>
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $key');

  @override
  Future<Map<String, Object?>> completeJson({
    required String system,
    required String user,
    required String schemaName,
    required Map<String, Object?> schema,
  }) async {
    while (true) {
      final format = _formats[_format];
      final (status, body) = await _send('POST', '/chat/completions', {
        'model': model,
        'messages': [
          {'role': 'system', 'content': system},
          {'role': 'user', 'content': user},
        ],
        if (format == 'json_schema')
          'response_format': {
            'type': 'json_schema',
            'json_schema': {'name': schemaName, 'schema': schema},
          },
        if (format == 'json_object') 'response_format': {'type': 'json_object'},
      });
      if ((status == 400 || status == 422) && _format < _formats.length - 1) {
        final error = LlmClient._errorText(body).toLowerCase();
        if (error.contains('response_format') ||
            error.contains('json') ||
            error.contains('schema')) {
          _format++;
          continue;
        }
      }
      if (status != 200) throw LlmException(LlmClient._errorText(body), status: status);
      final json = LlmClient._json(body);
      final used = json['usage'];
      usage.calls++;
      if (used is Map) {
        usage.inputTokens += (used['prompt_tokens'] as num?)?.toInt() ?? 0;
        usage.outputTokens += (used['completion_tokens'] as num?)?.toInt() ?? 0;
      }
      final choices = json['choices'];
      final choice = choices is List && choices.isNotEmpty && choices.first is Map
          ? choices.first as Map
          : null;
      final message = choice?['message'];
      final content = message is Map ? message['content'] : null;
      if (content is! String) throw const LlmException('The reply had no message content');
      if (choice?['finish_reason'] == 'length') {
        throw const LlmException('The reply was cut off at the output limit', truncated: true);
      }
      return parseJsonObject(content);
    }
  }
}

/// Anthropic Messages API with structured outputs (`output_config.format`).
/// On the Claude API, models that support it get server-side refusal
/// fallbacks (`fallbacks: "default"`), dropped if the server rejects them.
class AnthropicClient extends LlmClient {
  AnthropicClient({
    required String baseUrl,
    required String model,
    String? apiKey,
    HttpClient? http,
    Duration timeout = const Duration(minutes: 5),
  }) : super._(baseUrl, model, apiKey, http, timeout);

  static const version = '2023-06-01';
  static const fallbackBeta = 'server-side-fallback-2026-07-01';
  static const _fallbackModels = {
    'claude-opus-5-5',
    'claude-opus-5',
    'claude-fable-5-1',
    'claude-sonnet-5-5',
  };

  late bool _fallbacks =
      _fallbackModels.contains(model) && (Uri.tryParse(baseUrl)?.host ?? '') == 'api.anthropic.com';

  /// Non-streaming requests stay well under HTTP timeouts at this size.
  static const maxTokens = 16000;

  @override
  void _auth(HttpClientRequest request, String key) => request.headers.set('x-api-key', key);

  @override
  Future<(int, String)> _send(
    String method,
    String path, [
    Map<String, Object?>? body,
    Map<String, String>? headers,
  ]) => super._send(method, path, body, {'anthropic-version': version, ...?headers});

  @override
  Future<Map<String, Object?>> completeJson({
    required String system,
    required String user,
    required String schemaName,
    required Map<String, Object?> schema,
  }) async {
    while (true) {
      final fallbacks = _fallbacks;
      final (status, body) = await _send('POST', '/messages', {
        'model': model,
        'max_tokens': maxTokens,
        'system': system,
        'messages': [
          {'role': 'user', 'content': user},
        ],
        'output_config': {
          'format': {'type': 'json_schema', 'schema': schema},
        },
        if (fallbacks) 'fallbacks': 'default',
      }, fallbacks ? {'anthropic-beta': fallbackBeta} : null);
      if (status == 400 &&
          fallbacks &&
          LlmClient._errorText(body).toLowerCase().contains('fallback')) {
        _fallbacks = false;
        continue;
      }
      if (status != 200) throw LlmException(LlmClient._errorText(body), status: status);
      final json = LlmClient._json(body);
      final used = json['usage'];
      usage.calls++;
      if (used is Map) {
        usage.inputTokens += (used['input_tokens'] as num?)?.toInt() ?? 0;
        usage.outputTokens += (used['output_tokens'] as num?)?.toInt() ?? 0;
      }
      final stop = json['stop_reason'];
      if (stop == 'refusal') {
        final details = json['stop_details'];
        final category = details is Map ? details['category'] : null;
        throw LlmException(
          'The model declined this request${category is String ? ' ($category)' : ''}',
          refused: true,
        );
      }
      if (stop == 'max_tokens') {
        throw const LlmException('The reply was cut off at the output limit', truncated: true);
      }
      final content = json['content'];
      final text = [
        if (content is List)
          for (final block in content)
            if (block is Map && block['type'] == 'text' && block['text'] is String)
              block['text'] as String,
      ].join();
      if (text.isEmpty) throw const LlmException('The reply had no text');
      return parseJsonObject(text);
    }
  }
}

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

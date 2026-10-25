import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'errors.dart';
import 'models.dart';

/// One HTTP exchange's outcome.
class HttpReply {
  const HttpReply(this.status, this.headers, this.body);
  final int status;
  final HttpHeaders headers;
  final String body;

  bool get ok => status >= 200 && status < 300;

  /// Seconds or an HTTP date, as in RFC 9110.
  Duration? get retryAfter {
    final value = headers.value(HttpHeaders.retryAfterHeader);
    if (value == null) return null;
    final seconds = int.tryParse(value.trim());
    if (seconds != null) return Duration(seconds: seconds < 0 ? 0 : seconds);
    try {
      final at = HttpDate.parse(value);
      final wait = at.difference(DateTime.now());
      return wait.isNegative ? Duration.zero : wait;
    } on FormatException {
      return null;
    } on HttpException {
      return null;
    }
  }

  Object? json() {
    try {
      return jsonDecode(body);
    } on FormatException {
      throw ApiBadResponse('The server did not answer with JSON', status: status);
    }
  }

  /// The problem this reply carries, or a generic one built from the status.
  ApiProblemException problem() {
    Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      decoded = null;
    }
    ApiProblem problem;
    try {
      problem = ApiProblem.fromJson(decoded);
    } on ApiBadResponse {
      problem = ApiProblem(status: status, code: _codeFor(status));
    }
    return ApiProblemException(problem, retryAfter: retryAfter);
  }

  static String _codeFor(int status) => switch (status) {
    401 => 'unauthorized',
    402 => 'entitlement_required',
    403 => 'forbidden',
    404 => 'not_found',
    409 => 'conflict',
    410 => 'upload_expired',
    413 => 'upload_too_large',
    426 => 'client_too_old',
    429 => 'rate_limited',
    503 => 'server_unavailable',
    _ => 'http_$status',
  };
}

/// `dart:io` only. Maps transport failures to [ApiUnreachable]; never puts
/// headers or bodies into messages.
class HttpTransport {
  HttpTransport({HttpClient? http, this.userAgent, this.timeout = const Duration(seconds: 30)})
    : _http = http ?? (HttpClient()..connectionTimeout = const Duration(seconds: 10));

  final HttpClient _http;
  final String? userAgent;
  final Duration timeout;

  Future<HttpReply> send(
    String method,
    Uri uri, {
    Map<String, String> headers = const {},
    List<int>? body,
    Stream<List<int>>? stream,
    int? contentLength,
  }) async {
    try {
      final request = await _http.openUrl(method, uri).timeout(timeout);
      request.followRedirects = false;
      if (userAgent != null) request.headers.set(HttpHeaders.userAgentHeader, userAgent!);
      headers.forEach(request.headers.set);
      if (body != null) {
        request.contentLength = body.length;
        request.add(body);
      } else if (stream != null) {
        if (contentLength != null) request.contentLength = contentLength;
        await request.addStream(stream);
      }
      final response = await request.close().timeout(timeout);
      final text = await response.transform(utf8.decoder).join().timeout(timeout);
      return HttpReply(response.statusCode, response.headers, text);
    } on TimeoutException {
      throw ApiUnreachable('${uri.host} did not answer in time');
    } on SocketException {
      throw ApiUnreachable('Cannot reach ${uri.host}');
    } on HandshakeException {
      throw ApiUnreachable('Secure connection to ${uri.host} failed');
    } on HttpException {
      throw ApiUnreachable('Connection to ${uri.host} failed');
    }
  }

  void close() => _http.close(force: true);
}

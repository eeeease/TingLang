import 'dart:async';
import 'dart:io';

/// A loopback HTTP server for adapter tests. [handler] answers every
/// request; WebSocket tests upgrade inside it with
/// `WebSocketTransformer.upgrade`. Adapters take base URLs, so tests point
/// them at [http] / [ws] and no request leaves this Mac.
final class FakeServer {
  FakeServer._(this._server);
  final HttpServer _server;

  /// Requests in arrival order (method, path with query, headers as read).
  final requests = <HttpRequest>[];

  static Future<FakeServer> start(FutureOr<void> Function(HttpRequest request) handler) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final fake = FakeServer._(server);
    server.listen((request) async {
      fake.requests.add(request);
      try {
        await handler(request);
      } on Object catch (e) {
        try {
          request.response
            ..statusCode = 500
            ..write('fake server: $e');
          await request.response.close();
        } on Object {
          // Already upgraded or closed.
        }
      }
    });
    return fake;
  }

  int get port => _server.port;
  Uri get http => Uri.parse('http://127.0.0.1:$port');
  Uri get ws => Uri.parse('ws://127.0.0.1:$port');

  Future<void> close() => _server.close(force: true);
}

/// Replies with [status] and a JSON [body] string.
Future<void> replyJson(HttpRequest request, String body, {int status = 200}) async {
  request.response
    ..statusCode = status
    ..headers.contentType = ContentType.json
    ..write(body);
  await request.response.close();
}

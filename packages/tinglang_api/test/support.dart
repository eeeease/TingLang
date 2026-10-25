import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// One request a [LocalServer] received.
class Seen {
  Seen(this.method, this.uri, this.headers, this.body);
  final String method;
  final Uri uri;
  final HttpHeaders headers;
  final String body;
  String? header(String name) => headers.value(name);
}

/// A reply the handler wants to send.
class Reply {
  const Reply(this.status, [this.body, this.headers = const {}, this.contentType]);
  Reply.json(Object? json, {int status = 200, Map<String, String> headers = const {}})
    : this(status, jsonEncode(json), headers, 'application/json');
  Reply.problem(Map<String, Object?> problem, {Map<String, String> headers = const {}})
    : this(problem['status']! as int, jsonEncode(problem), headers, 'application/problem+json');
  final int status;
  final String? body;
  final Map<String, String> headers;
  final String? contentType;
}

/// An HTTP server on 127.0.0.1 that records requests and answers through
/// [handler].
class LocalServer {
  LocalServer._(this._server) {
    _server.listen((request) async {
      final body = await utf8.decoder.bind(request).join();
      final seen = Seen(request.method, request.uri, request.headers, body);
      requests.add(seen);
      final reply = handler(seen);
      request.response.statusCode = reply.status;
      if (reply.contentType != null) {
        request.response.headers.set(HttpHeaders.contentTypeHeader, reply.contentType!);
      }
      reply.headers.forEach(request.response.headers.set);
      if (reply.body != null) request.response.write(reply.body);
      await request.response.close();
    });
  }

  static Future<LocalServer> start() async =>
      LocalServer._(await HttpServer.bind(InternetAddress.loopbackIPv4, 0));

  final HttpServer _server;
  final requests = <Seen>[];
  Reply Function(Seen request) handler = (_) => const Reply(404);

  String get origin => 'http://127.0.0.1:${_server.port}';
  Future<void> close() => _server.close(force: true);
}

Map<String, Object?> example(String path) =>
    jsonDecode(File('../../api/examples/$path').readAsStringSync()) as Map<String, Object?>;

/// A port nothing listens on.
Future<int> deadPort() async {
  final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = socket.port;
  await socket.close();
  return port;
}

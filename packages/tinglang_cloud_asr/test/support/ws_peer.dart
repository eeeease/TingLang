import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:tinglang_cloud_asr/tinglang_cloud_asr.dart';

/// Collects a stream's events so a test can await them one by one.
final class Inbox<T> {
  Inbox(Stream<T> stream) {
    stream.listen(
      (event) {
        items.add(event);
        _wake();
      },
      onError: (Object e) {
        errors.add(e);
        _wake();
      },
      onDone: () {
        isDone = true;
        _wake();
      },
    );
  }

  final items = <T>[];
  final errors = <Object>[];
  bool isDone = false;
  int _read = 0;
  Completer<void>? _waiter;

  void _wake() {
    final w = _waiter;
    _waiter = null;
    w?.complete();
  }

  Future<void> _waitUntil(bool Function() ready, Duration timeout) async {
    final deadline = DateTime.now().add(timeout);
    while (!ready()) {
      final left = deadline.difference(DateTime.now());
      if (left <= Duration.zero) throw TimeoutException('Inbox: nothing arrived', timeout);
      final w = _waiter ??= Completer<void>();
      try {
        await w.future.timeout(left);
      } on TimeoutException {
        // Re-check, then give up at the deadline.
      }
    }
  }

  /// The next event not yet read.
  Future<T> next({Duration timeout = const Duration(seconds: 5)}) async {
    await _waitUntil(() => items.length > _read || isDone, timeout);
    if (items.length <= _read) throw StateError('Inbox: stream closed');
    return items[_read++];
  }

  /// Waits until the stream is done.
  Future<void> done({Duration timeout = const Duration(seconds: 5)}) =>
      _waitUntil(() => isDone, timeout);

  /// Waits for the first error.
  Future<Object> error({Duration timeout = const Duration(seconds: 5)}) async {
    await _waitUntil(() => errors.isNotEmpty || isDone, timeout);
    if (errors.isEmpty) throw StateError('Inbox: closed without an error');
    return errors.first;
  }
}

/// The server side of one WebSocket in a test.
final class WsPeer {
  WsPeer(this.socket) : inbox = Inbox<Object?>(socket.cast<Object?>());
  final WebSocket socket;
  final Inbox<Object?> inbox;

  Future<String> nextText() async {
    final m = await inbox.next();
    if (m is! String) throw StateError('expected a text message, got ${m.runtimeType}');
    return m;
  }

  Future<Uint8List> nextBinary() async {
    final m = await inbox.next();
    if (m is! List<int>) throw StateError('expected a binary message, got ${m.runtimeType}');
    return Uint8List.fromList(m);
  }

  /// The next text message, decoded as a JSON object.
  Future<Map<String, Object?>> nextJson() async =>
      (jsonDecode(await nextText()) as Map).cast<String, Object?>();

  void send(Object data) => socket.add(data);
  void sendJson(Object json) => socket.add(jsonEncode(json));
  Future<void> close([int? code, String? reason]) => socket.close(code, reason);
}

/// Upgrades [request] (inside a `FakeServer` handler) to a WebSocket.
Future<WsPeer> upgrade(HttpRequest request) async =>
    WsPeer(await WebSocketTransformer.upgrade(request));

/// Reads a request body as bytes.
Future<Uint8List> readBytes(HttpRequest request) async {
  final b = BytesBuilder(copy: false);
  await for (final chunk in request) {
    b.add(chunk);
  }
  return b.takeBytes();
}

/// Reads a request body as text.
Future<String> readText(HttpRequest request) async => utf8.decode(await readBytes(request));

/// [ms] milliseconds of 16 kHz mono PCM16 silence.
Uint8List pcm(int ms) => Uint8List(ms * 32);

/// A WAV of [ms] milliseconds for file tests.
CloudFileRequest wavRequest(int ms, {String language = 'en', bool words = true}) =>
    CloudFileRequest(
      wav: wavFromPcm16(pcm(ms)),
      durationMs: ms,
      language: language,
      wordTimestamps: words,
    );

/// A loopback URL nothing listens on.
Future<Uri> deadUrl(String scheme) async {
  final s = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = s.port;
  await s.close();
  return Uri.parse('$scheme://127.0.0.1:$port');
}

/// Counts [HttpClient]s created while [body] runs.
Future<int> countHttpClients(FutureOr<void> Function() body) async {
  final overrides = _Counting();
  await HttpOverrides.runWithHttpOverrides(() async => body(), overrides);
  return overrides.count;
}

final class _Counting extends HttpOverrides {
  int count = 0;
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    count++;
    return super.createHttpClient(context);
  }
}

/// Plumbing shared by the mainland China adapters (Tencent Cloud, DashScope,
/// iFlytek): HTTP and WebSocket calls whose failures become [CloudAsrError]s
/// without URLs or credentials, PCM re-framing, lenient JSON readers and the
/// live-stream state machine. Internal to this package.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:meta/meta.dart';

import '../provider.dart';

// ---------------------------------------------------------------------------
// Errors

/// Replaces every credential value (4 characters or more) in [text] with
/// `***`, and clips it to a length that fits an error line.
String redact(String text, CloudCredentials credentials) {
  var out = text;
  for (final value in credentials.values) {
    final v = value.trim();
    if (v.length >= 4) out = out.replaceAll(v, '***');
  }
  out = out.trim();
  return out.length <= 300 ? out : '${out.substring(0, 300)}…';
}

/// An error carrying the service's own [message] (redacted) or [fallback]
/// when the service sent none.
CloudAsrError serviceError(
  CloudAsrErrorKind kind,
  String? message,
  CloudCredentials credentials, {
  required String fallback,
  int? statusCode,
  String? providerCode,
}) {
  final text = redact(message ?? '', credentials);
  return CloudAsrError(
    kind,
    text.isEmpty ? fallback : text,
    statusCode: statusCode,
    providerCode: providerCode == null ? null : redact(providerCode, credentials),
  );
}

/// The kind an HTTP status maps to when the body says nothing more specific.
CloudAsrErrorKind kindForHttpStatus(int status) => switch (status) {
  401 || 403 => CloudAsrErrorKind.unauthorized,
  402 => CloudAsrErrorKind.quotaExceeded,
  408 => CloudAsrErrorKind.network,
  413 => CloudAsrErrorKind.audioTooLong,
  429 => CloudAsrErrorKind.rateLimited,
  >= 500 => CloudAsrErrorKind.server,
  _ => CloudAsrErrorKind.badRequest,
};

const cancelledError = CloudAsrError(CloudAsrErrorKind.cancelled, 'Cancelled.');

/// A transport failure as a [CloudAsrError]. Exception texts are not used:
/// `HttpException` and `WebSocketException` messages contain the URL, which
/// carries signatures and key ids for some services.
CloudAsrError transportError(String service, Object error) {
  if (error is TimeoutException) {
    return CloudAsrError(CloudAsrErrorKind.network, '$service did not answer in time.');
  }
  if (error is SocketException) {
    final os = error.osError?.message.trim();
    return CloudAsrError(
      CloudAsrErrorKind.network,
      'Could not reach $service${os == null || os.isEmpty ? '' : ' ($os)'}.',
    );
  }
  if (error is TlsException) {
    return CloudAsrError(CloudAsrErrorKind.network, 'Secure connection to $service failed.');
  }
  return CloudAsrError(CloudAsrErrorKind.network, 'The connection to $service failed.');
}

// ---------------------------------------------------------------------------
// HTTP

/// One HTTP reply: status and body text (UTF-8, malformed bytes replaced).
@immutable
final class HttpReply {
  const HttpReply(this.statusCode, this.body);
  final int statusCode;
  final String body;
  bool get ok => statusCode >= 200 && statusCode < 300;
}

const _uploadChunk = 256 * 1024;
const _maxBody = 64 * 1024 * 1024;

/// One HTTP exchange on a fresh [HttpClient] that is closed afterwards.
/// [body] parts are written in order, in chunks, reporting [onUpload]
/// (0–1 of the bytes written). [cancel] aborts the request at once.
Future<HttpReply> httpCall(
  String service,
  String method,
  Uri uri, {
  Map<String, String> headers = const {},
  List<Uint8List> body = const [],
  void Function(double fraction)? onUpload,
  CloudCancelToken? cancel,
  Duration connectTimeout = const Duration(seconds: 15),
  Duration responseTimeout = const Duration(seconds: 60),
}) async {
  cancel?.check();
  final client = HttpClient()..connectionTimeout = connectTimeout;
  HttpClientRequest? request;
  final cancelled = cancel?.whenCancelled.then((_) {
    request?.abort();
    client.close(force: true);
  });
  unawaited(cancelled);
  try {
    final req = request = await client.openUrl(method, uri).timeout(connectTimeout);
    // A redirect would repeat the headers (keys included) to another URL.
    req.followRedirects = false;
    headers.forEach(req.headers.set);
    final total = body.fold<int>(0, (n, part) => n + part.length);
    if (body.isNotEmpty) req.contentLength = total;
    var sent = 0;
    for (final part in body) {
      for (var offset = 0; offset < part.length; offset += _uploadChunk) {
        final end = min(offset + _uploadChunk, part.length);
        req.add(Uint8List.sublistView(part, offset, end));
        await req.flush().timeout(responseTimeout);
        sent += end - offset;
        onUpload?.call(total == 0 ? 1 : sent / total);
        cancel?.check();
      }
    }
    final response = await req.close().timeout(responseTimeout);
    final bytes = await _readAll(response, _maxBody).timeout(responseTimeout);
    return HttpReply(response.statusCode, utf8.decode(bytes, allowMalformed: true));
  } on CloudAsrError {
    rethrow;
  } on Object catch (e) {
    if (cancel?.isCancelled ?? false) throw cancelledError;
    if (e is TimeoutException || e is IOException) throw transportError(service, e);
    rethrow;
  } finally {
    client.close(force: true);
  }
}

/// The whole body, or with [truncate] its first [max] bytes; otherwise a
/// longer body is a protocol error.
Future<Uint8List> _readAll(Stream<List<int>> stream, int max, {bool truncate = false}) async {
  final out = BytesBuilder(copy: false);
  await for (final chunk in stream) {
    out.add(chunk);
    if (out.length > max) {
      if (truncate) return Uint8List.sublistView(out.takeBytes(), 0, max);
      throw const CloudAsrError(CloudAsrErrorKind.protocol, 'The reply was too large.');
    }
  }
  return out.takeBytes();
}

// ---------------------------------------------------------------------------
// WebSocket

final _secure = Random.secure();

/// Opens a WebSocket on a fresh [HttpClient] (closed once the socket is
/// detached). Unlike `WebSocket.connect`, a refused upgrade keeps its HTTP
/// status and body ([onRejected] turns them into the error) and no error
/// text contains the URL.
Future<WebSocket> connectSocket(
  String service,
  Uri uri, {
  Map<String, String> headers = const {},
  Duration timeout = const Duration(seconds: 15),
  required CloudAsrError Function(int statusCode, String body) onRejected,
}) async {
  final client = HttpClient()..connectionTimeout = timeout;
  try {
    final httpUri = uri.replace(scheme: uri.scheme == 'wss' ? 'https' : 'http');
    final key = base64.encode(List<int>.generate(16, (_) => _secure.nextInt(256)));
    final request = await client.openUrl('GET', httpUri).timeout(timeout);
    request.followRedirects = false;
    request.headers
      ..set(HttpHeaders.connectionHeader, 'Upgrade')
      ..set(HttpHeaders.upgradeHeader, 'websocket')
      ..set('Sec-WebSocket-Key', key)
      ..set('Sec-WebSocket-Version', '13');
    headers.forEach(request.headers.set);
    final response = await request.close().timeout(timeout);
    if (response.statusCode != HttpStatus.switchingProtocols) {
      final bytes = await _readAll(response, 64 * 1024, truncate: true).timeout(timeout);
      throw onRejected(response.statusCode, utf8.decode(bytes, allowMalformed: true));
    }
    final expected = base64.encode(
      sha1.convert(utf8.encode('${key}258EAFA5-E914-47DA-95CA-C5AB0DC85B11')).bytes,
    );
    final socket = await response.detachSocket();
    if (response.headers.value('Sec-WebSocket-Accept') != expected) {
      socket.destroy();
      throw CloudAsrError(CloudAsrErrorKind.protocol, '$service did not open a WebSocket.');
    }
    return WebSocket.fromUpgradedSocket(
      socket,
      serverSide: false,
      compression: CompressionOptions.compressionOff,
    );
  } on CloudAsrError {
    rethrow;
  } on Object catch (e) {
    if (e is TimeoutException || e is IOException) throw transportError(service, e);
    rethrow;
  } finally {
    client.close();
  }
}

/// Re-chunks PCM into frames of exactly [frameBytes]; [flush] returns the
/// remainder at the end of audio.
final class PcmFramer {
  PcmFramer(this.frameBytes) : _pending = Uint8List(frameBytes);
  final int frameBytes;
  final Uint8List _pending;
  var _fill = 0;

  List<Uint8List> add(Uint8List pcm) {
    final frames = <Uint8List>[];
    var offset = 0;
    if (_fill > 0) {
      final take = min(frameBytes - _fill, pcm.length);
      _pending.setRange(_fill, _fill + take, pcm);
      _fill += take;
      offset = take;
      if (_fill < frameBytes) return frames;
      frames.add(Uint8List.fromList(_pending));
      _fill = 0;
    }
    while (pcm.length - offset >= frameBytes) {
      frames.add(Uint8List.fromList(Uint8List.sublistView(pcm, offset, offset + frameBytes)));
      offset += frameBytes;
    }
    final rest = pcm.length - offset;
    if (rest > 0) {
      _pending.setRange(0, rest, pcm, offset);
      _fill = rest;
    }
    return frames;
  }

  Uint8List? flush() {
    if (_fill == 0) return null;
    final out = Uint8List.fromList(Uint8List.sublistView(_pending, 0, _fill));
    _fill = 0;
    return out;
  }
}

/// The live-stream state machine shared by the WebSocket adapters. Frames
/// PCM, hands text frames to [handleText] and closes [segments] exactly once:
/// after the service's last result, [cancel], the [finish] timeout or a
/// [CloudAsrError] ([fail]).
abstract base class SocketAsrStream implements CloudAsrStream {
  SocketAsrStream(this.socket, {required int frameBytes}) : _framer = PcmFramer(frameBytes) {
    _ready.future.ignore();
    _sub = socket.listen(_onData, onError: _onError, onDone: _onDone);
  }

  final WebSocket socket;
  final PcmFramer _framer;
  final _out = StreamController<CloudSegment>();
  final _ready = Completer<void>();
  final _closed = Completer<void>();
  final _open = <String>{};
  late final StreamSubscription<dynamic> _sub;
  var _ending = false;

  /// Service name for messages.
  String get service;

  /// Completes once the service accepted the session; fails with its error.
  Future<void> get ready => _ready.future;

  /// Whether the end of audio was sent ([finish]) or the stream cancelled.
  bool get ending => _ending;

  bool get isClosed => _closed.isCompleted;

  @override
  Stream<CloudSegment> get segments => _out.stream;

  /// One text frame from the service. Throwing a [CloudAsrError] fails the
  /// stream; a [FormatException] fails it as [CloudAsrErrorKind.protocol].
  @protected
  void handleText(String text);

  /// Sends the service's end-of-audio message.
  @protected
  void sendEnd();

  /// The error when the service closes the socket before the session ended
  /// normally. A normal closure without a message is taken as the service's
  /// own session limit.
  @protected
  CloudAsrError closedEarly(int? closeCode) => closeCode == WebSocketStatus.normalClosure
      ? CloudAsrError(CloudAsrErrorKind.sessionEnded, '$service ended the session.')
      : CloudAsrError(CloudAsrErrorKind.network, 'The connection to $service was lost.');

  @override
  void addPcm(Uint8List pcm16le) {
    if (_ending || isClosed) return;
    for (final frame in _framer.add(pcm16le)) {
      send(frame);
    }
  }

  @override
  Future<void> finish({Duration timeout = const Duration(seconds: 10)}) async {
    if (isClosed) return;
    if (!_ending) {
      _ending = true;
      final rest = _framer.flush();
      if (rest != null) send(rest);
      sendEnd();
    }
    await _closed.future.timeout(timeout, onTimeout: _close);
  }

  @override
  Future<void> cancel() async {
    _ending = true;
    _close();
  }

  @protected
  void send(Object data) {
    if (isClosed) return;
    try {
      socket.add(data);
    } on Object {
      // The socket is closing; onDone reports why.
    }
  }

  /// Emits [segment]. Empty partials are dropped; an empty final is passed on
  /// only when it replaces a partial already sent (so the caller clears it).
  @protected
  void emit(CloudSegment segment) {
    if (isClosed) return;
    if (segment.text.isEmpty) {
      if (!segment.isFinal || !_open.remove(segment.id)) return;
    } else if (segment.isFinal) {
      _open.remove(segment.id);
    } else {
      _open.add(segment.id);
    }
    _out.add(segment);
  }

  @protected
  void markReady() {
    if (!_ready.isCompleted) _ready.complete();
  }

  @protected
  void fail(CloudAsrError error) {
    if (isClosed) return;
    if (_ready.isCompleted) {
      _out.addError(error);
    } else {
      _ready.completeError(error);
    }
    _close();
  }

  /// The service sent its last result.
  @protected
  void complete() => _close();

  void _onData(dynamic message) {
    if (isClosed || message is! String) return;
    try {
      handleText(message);
    } on CloudAsrError catch (e) {
      fail(e);
    } on Object {
      // FormatException or an unexpected shape: the stream only ever ends
      // with a CloudAsrError.
      fail(
        CloudAsrError(CloudAsrErrorKind.protocol, '$service sent a reply this app cannot read.'),
      );
    }
  }

  void _onError(Object error) {
    fail(transportError(service, error));
  }

  void _onDone() {
    if (isClosed) return;
    if (_ending && _ready.isCompleted) {
      complete();
    } else {
      fail(closedEarly(socket.closeCode));
    }
  }

  void _close() {
    if (_closed.isCompleted) return;
    _closed.complete();
    if (!_ready.isCompleted) _ready.completeError(cancelledError);
    unawaited(_out.close());
    unawaited(
      socket
          .close(WebSocketStatus.normalClosure)
          .timeout(const Duration(seconds: 2), onTimeout: () => null)
          .catchError((Object _) => null),
    );
    unawaited(_sub.cancel());
  }
}

// ---------------------------------------------------------------------------
// Values

/// Percent-encodes everything except RFC 3986 unreserved characters
/// (`A-Z a-z 0-9 - _ . ~`). For the values these adapters sign (digits,
/// ids, dates) it equals Python's `quote(v, safe='')` and Java's
/// `URLEncoder.encode`, which the services' own samples use.
String percentEncode(String value) {
  final out = StringBuffer();
  for (final byte in utf8.encode(value)) {
    final unreserved =
        (byte >= 0x30 && byte <= 0x39) ||
        (byte >= 0x41 && byte <= 0x5a) ||
        (byte >= 0x61 && byte <= 0x7a) ||
        byte == 0x2d ||
        byte == 0x2e ||
        byte == 0x5f ||
        byte == 0x7e;
    if (unreserved) {
      out.writeCharCode(byte);
    } else {
      out.write('%${byte.toRadixString(16).toUpperCase().padLeft(2, '0')}');
    }
  }
  return out.toString();
}

/// Base64 HMAC-SHA1 of [message] keyed with [key] (both UTF-8).
String hmacSha1Base64(String key, String message) =>
    base64.encode(Hmac(sha1, utf8.encode(key)).convert(utf8.encode(message)).bytes);

/// A random (version 4) UUID.
String uuidV4(Random random) {
  final b = List<int>.generate(16, (_) => random.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final h = [for (final x in b) x.toRadixString(16).padLeft(2, '0')].join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
      '${h.substring(16, 20)}-${h.substring(20)}';
}

/// [words] when every one lies inside its segment ([startMs]–[endMs], with
/// a little slack for rounding); null when there are none or any falls
/// outside. Word times the documentation gets wrong are dropped, never
/// shifted: playback times must stay real offsets.
List<CloudWord>? wordsInside(List<CloudWord> words, int startMs, int endMs) {
  const slack = 250;
  if (words.isEmpty) return null;
  for (final w in words) {
    if (w.startMs < startMs - slack || w.endMs > endMs + slack || w.endMs < w.startMs) {
      return null;
    }
  }
  return List.unmodifiable(words);
}

/// `host` or `host:port` when the URL names a port.
String hostWithPort(Uri uri) => uri.hasPort ? '${uri.host}:${uri.port}' : uri.host;

/// A base-URL override: `wss://`/`https://`, or `ws://`/`http://` when a test
/// passes one explicitly (the defaults are always secure).
Uri checkedBase(Uri uri, {required bool socket}) {
  final secure = socket ? 'wss' : 'https';
  final plain = socket ? 'ws' : 'http';
  if (uri.scheme == secure || uri.scheme == plain) return uri;
  throw ArgumentError.value(uri.toString(), 'uri', 'must be $secure:// (or $plain:// in tests)');
}

// ---------------------------------------------------------------------------
// JSON

/// Decodes [text] as JSON, or null when it is not JSON.
Object? tryJson(String text) {
  try {
    return jsonDecode(text);
  } on FormatException {
    return null;
  }
}

Map<String, Object?>? jsonMap(Object? value) => value is Map<String, Object?> ? value : null;

List<Object?> jsonList(Object? value) => value is List ? value.cast<Object?>() : const [];

String? jsonString(Object? value) => switch (value) {
  final String s => s,
  final num n => '$n',
  _ => null,
};

int? jsonInt(Object? value) => switch (value) {
  final int i => i,
  final double d => d.isFinite ? d.round() : null,
  final String s => int.tryParse(s.trim()) ?? double.tryParse(s.trim())?.round(),
  _ => null,
};

bool jsonBool(Object? value) => value == true || value == 'true' || value == 1 || value == '1';

/// A map nested in [value] either as an object or as a JSON string (some
/// services double-encode).
Map<String, Object?>? jsonMapOrString(Object? value) =>
    value is String ? jsonMap(tryJson(value)) : jsonMap(value);

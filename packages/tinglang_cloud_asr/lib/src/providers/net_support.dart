import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import '../provider.dart';

// Shared plumbing for the Soniox, AssemblyAI and Azure adapters: one
// HttpClient per call (created inside the call, closed when it ends), JSON
// readers, error scrubbing, PCM framing and a WebSocket stream base. Nothing
// here opens a socket before a call.

// ---------------------------------------------------------------- JSON

/// [value] as a JSON object, or null.
Map<String, Object?>? jsonMap(Object? value) => value is Map<String, Object?> ? value : null;

/// [value] as a JSON array, or empty.
List<Object?> jsonList(Object? value) => value is List<Object?> ? value : const [];

/// [value] as a string, or null.
String? jsonString(Object? value) => value is String ? value : null;

/// [value] as an integer: JSON numbers and numeric strings (Azure sends
/// 100-ns offsets as either).
int? jsonInt(Object? value) => switch (value) {
  int v => v,
  num v => v.round(),
  String v => int.tryParse(v) ?? double.tryParse(v)?.round(),
  _ => null,
};

/// [body] decoded as JSON, or null when it is not JSON.
Object? tryJson(String body) {
  if (body.isEmpty) return null;
  try {
    return jsonDecode(body);
  } on FormatException {
    return null;
  }
}

// ---------------------------------------------------------------- errors

final _longToken = RegExp(r'[A-Za-z0-9_\-+/=]{32,}');
final _controls = RegExp(r'[\x00-\x1f\x7f]+');

/// [message] safe to show and keep: every value in [secrets] removed, long
/// key-like runs masked, control characters dropped, at most [max] chars.
String scrub(String message, Iterable<String> secrets, {int max = 300}) {
  var out = message;
  for (final secret in secrets) {
    final s = secret.trim();
    if (s.length >= 4) out = out.replaceAll(s, '***');
  }
  out = out.replaceAll(_longToken, '***').replaceAll(_controls, ' ').trim();
  if (out.length > max) out = '${out.substring(0, max)}…';
  return out;
}

/// Whether [text] mentions any of [words] (case-insensitive).
bool mentions(String? text, List<String> words) {
  final lower = (text ?? '').toLowerCase();
  return words.any(lower.contains);
}

final _codeShape = RegExp(r'^[A-Za-z0-9_.\-]{1,64}$');

/// A service error code fit for [CloudAsrError.providerCode]: short and
/// plain, or null.
String? safeCode(String? code) => code != null && _codeShape.hasMatch(code) ? code : null;

/// A generous deadline for sending [bytes] (at 50 kB/s or better) and
/// waiting [extra] for the answer.
Duration uploadTimeout(int bytes, {Duration extra = const Duration(minutes: 2)}) =>
    extra + Duration(milliseconds: bytes ~/ 50);

const networkError = CloudAsrError(CloudAsrErrorKind.network, 'Could not reach the service.');
const cancelledError = CloudAsrError(CloudAsrErrorKind.cancelled, 'Cancelled.');

/// A reply this adapter cannot read.
CloudAsrError protocolError(String what) => CloudAsrError(CloudAsrErrorKind.protocol, what);

/// Throws [CloudAsrErrorKind.audioTooLong] when [request] is over the
/// provider's limits, before anything is sent.
void checkFileLimits(CloudAsrInfo info, CloudFileRequest request) {
  final maxMs = info.maxFileMs, maxBytes = info.maxFileBytes;
  if ((maxMs != null && request.durationMs > maxMs) ||
      (maxBytes != null && request.wav.length > maxBytes)) {
    throw CloudAsrError(
      CloudAsrErrorKind.audioTooLong,
      'The file is longer or larger than one ${info.id} request accepts.',
    );
  }
}

// ---------------------------------------------------------------- HTTP

/// One HTTP exchange's result.
final class HttpReply {
  const HttpReply(this.statusCode, this.body);
  final int statusCode;
  final String body;
  bool get ok => statusCode >= 200 && statusCode < 300;
  Object? get json => tryJson(body);
}

const _chunk = 64 * 1024;

/// Sends one request on a fresh [HttpClient] and closes the client after.
/// [body] parts are written in order (multipart pieces, or one JSON body);
/// [onSent] gets bytes written so far. Socket, TLS and timeout failures
/// become [CloudAsrErrorKind.network]; cancelling [cancel] aborts the
/// exchange with [CloudAsrErrorKind.cancelled]. HTTP error statuses are
/// returned, not thrown: each adapter maps its own.
Future<HttpReply> httpSend(
  String method,
  Uri uri, {
  Map<String, String> headers = const {},
  List<List<int>> body = const [],
  CloudCancelToken? cancel,
  void Function(int sent, int total)? onSent,
  Duration connectTimeout = const Duration(seconds: 20),
  Duration? timeout,
}) async {
  cancel?.check();
  final client = HttpClient()..connectionTimeout = connectTimeout;
  var finished = false;
  var aborted = false;
  if (cancel != null) {
    unawaited(
      cancel.whenCancelled.then((_) {
        if (finished) return;
        aborted = true;
        client.close(force: true);
      }),
    );
  }
  Future<HttpReply> exchange() async {
    final request = await client.openUrl(method, uri);
    headers.forEach(request.headers.set);
    final total = body.fold<int>(0, (n, part) => n + part.length);
    if (total > 0 || method != 'GET') request.contentLength = total;
    var sent = 0;
    for (final part in body) {
      for (var i = 0; i < part.length; i += _chunk) {
        final end = min(i + _chunk, part.length);
        request.add(part is Uint8List ? Uint8List.sublistView(part, i, end) : part.sublist(i, end));
        await request.flush();
        sent += end - i;
        onSent?.call(sent, total);
      }
    }
    final response = await request.close();
    final text = await const Utf8Decoder(allowMalformed: true).bind(response).join();
    return HttpReply(response.statusCode, text);
  }

  try {
    final reply = exchange();
    return await (timeout == null ? reply : reply.timeout(timeout));
  } on CloudAsrError {
    rethrow;
  } on Object catch (e) {
    if (aborted || (cancel?.isCancelled ?? false)) throw cancelledError;
    if (e is IOException || e is TimeoutException || e is TlsException) throw networkError;
    rethrow;
  } finally {
    finished = true;
    client.close(force: true);
  }
}

/// Waits [delay], returning early (and throwing) if [cancel] fires.
Future<void> pause(Duration delay, CloudCancelToken? cancel) async {
  cancel?.check();
  if (cancel == null) {
    await Future<void>.delayed(delay);
  } else {
    await Future.any([Future<void>.delayed(delay), cancel.whenCancelled]);
  }
  cancel?.check();
}

final _random = Random.secure();

/// [bytes] random bytes as upper-case hex (request ids, multipart boundaries).
String randomHex(int bytes) =>
    [for (var i = 0; i < bytes; i++) _random.nextInt(256).toRadixString(16).padLeft(2, '0')]
        .join()
        .toUpperCase();

/// A `multipart/form-data` body written as parts, so the audio is never
/// copied into one buffer.
final class MultipartBody {
  MultipartBody() : boundary = 'tinglang-${randomHex(12)}';
  final String boundary;
  final _parts = <List<int>>[];

  String get contentType => 'multipart/form-data; boundary=$boundary';

  void field(String name, String value, {String? contentType}) {
    _parts.add(
      utf8.encode(
        '--$boundary\r\nContent-Disposition: form-data; name="$name"\r\n'
        '${contentType == null ? '' : 'Content-Type: $contentType\r\n'}\r\n$value\r\n',
      ),
    );
  }

  void file(String name, String filename, String contentType, Uint8List bytes) {
    _parts
      ..add(
        utf8.encode(
          '--$boundary\r\nContent-Disposition: form-data; name="$name"; filename="$filename"\r\n'
          'Content-Type: $contentType\r\n\r\n',
        ),
      )
      ..add(bytes)
      ..add(utf8.encode('\r\n'));
  }

  /// The parts, closing boundary included.
  List<List<int>> finish() => [..._parts, utf8.encode('--$boundary--\r\n')];
}

// ---------------------------------------------------------------- WebSocket

/// Opens a WebSocket on a fresh [HttpClient]. A refused upgrade becomes
/// [onHttpStatus]`(status)`; socket, TLS and timeout failures become
/// [CloudAsrErrorKind.network].
Future<WebSocket> openWebSocket(
  Uri uri, {
  Map<String, String> headers = const {},
  required CloudAsrError Function(int status) onHttpStatus,
  Duration timeout = const Duration(seconds: 15),
}) async {
  final client = HttpClient()..connectionTimeout = timeout;
  var ok = false;
  try {
    final ws = await WebSocket.connect(
      uri.toString(),
      headers: headers,
      customClient: client,
    ).timeout(timeout);
    ok = true;
    return ws;
  } on WebSocketException catch (e) {
    final status = e.httpStatusCode;
    if (status != null && status != HttpStatus.switchingProtocols) throw onHttpStatus(status);
    throw protocolError('The service did not accept the WebSocket upgrade.');
  } on Object catch (e) {
    if (e is IOException || e is TimeoutException || e is TlsException) throw networkError;
    rethrow;
  } finally {
    client.close(force: !ok);
  }
}

/// Re-chunks PCM into frames of exactly [frameBytes].
final class PcmFramer {
  PcmFramer(this.frameBytes) : assert(frameBytes > 0 && frameBytes.isEven);
  final int frameBytes;
  final _pending = BytesBuilder(copy: true);

  /// Complete frames available after adding [pcm].
  List<Uint8List> add(Uint8List pcm) {
    _pending.add(pcm);
    if (_pending.length < frameBytes) return const [];
    final all = _pending.takeBytes();
    final frames = <Uint8List>[];
    var i = 0;
    for (; i + frameBytes <= all.length; i += frameBytes) {
      frames.add(Uint8List.sublistView(all, i, i + frameBytes));
    }
    if (i < all.length) _pending.add(Uint8List.sublistView(all, i));
    return frames;
  }

  /// What is left, padded with silence to at least [minBytes]; null when
  /// nothing is left.
  Uint8List? flush({int minBytes = 0}) {
    if (_pending.isEmpty) return null;
    final rest = _pending.takeBytes();
    if (rest.length >= minBytes) return rest;
    return Uint8List(minBytes)..setRange(0, rest.length, rest);
  }
}

/// A [CloudAsrStream] over one WebSocket: subclasses read messages and send
/// audio; this class owns the segments controller and the close rules (the
/// segments stream closes exactly once: after [finish], [cancel] or the
/// first error, which is always a [CloudAsrError]).
abstract base class WsAsrStream implements CloudAsrStream {
  WsAsrStream(this.ws, this.secrets) {
    _sub = ws.listen(
      (Object? data) {
        if (_closed) return;
        if (data is String) {
          onText(data);
        } else if (data is List<int>) {
          onBinary(data);
        }
      },
      onError: (Object _) => fail(networkError),
      onDone: () {
        if (!_closed) onClosed(ws.closeCode, ws.closeReason);
      },
      cancelOnError: true,
    );
  }

  final WebSocket ws;

  /// Credential values to scrub from every message the service sends back.
  final List<String> secrets;
  final _out = StreamController<CloudSegment>();
  final _ended = Completer<void>();
  late final StreamSubscription<Object?> _sub;
  bool _closed = false;
  bool _finishing = false;

  @override
  Stream<CloudSegment> get segments => _out.stream;

  /// Whether [finish] or [cancel] was called.
  bool get finishing => _finishing;
  bool get closed => _closed;

  /// A text message from the service.
  void onText(String text);

  /// A binary message from the service (ignored unless overridden).
  void onBinary(List<int> data) {}

  /// The service closed the socket before [ended] or [fail].
  void onClosed(int? code, String? reason);

  /// Sends [pcm16le] (already checked: not finishing, not closed).
  void sendAudio(Uint8List pcm16le);

  /// Tells the service the audio is over.
  void sendEnd();

  /// Called once when the stream shuts down (timers).
  void onShutdown() {}

  void emit(CloudSegment segment) {
    if (!_closed) _out.add(segment);
  }

  /// A fatal error: reported once, then everything closes.
  void fail(CloudAsrError error) {
    if (_closed) return;
    _out.addError(error);
    _shutdown();
  }

  /// The service sent its last result.
  void ended() => _shutdown();

  void sendText(String text) {
    if (_closed || ws.closeCode != null) return;
    try {
      ws.add(text);
    } on StateError {
      // Closing.
    }
  }

  void sendBytes(List<int> bytes) {
    if (_closed || ws.closeCode != null) return;
    try {
      ws.add(bytes);
    } on StateError {
      // Closing.
    }
  }

  @override
  void addPcm(Uint8List pcm16le) {
    if (_closed || _finishing || pcm16le.isEmpty) return;
    sendAudio(pcm16le);
  }

  @override
  Future<void> finish({Duration timeout = const Duration(seconds: 10)}) async {
    if (_closed) return;
    if (!_finishing) {
      _finishing = true;
      sendEnd();
    }
    try {
      await _ended.future.timeout(timeout);
    } on TimeoutException {
      _shutdown();
    }
  }

  @override
  Future<void> cancel() async {
    _finishing = true;
    _shutdown();
  }

  void _shutdown() {
    if (_closed) return;
    _closed = true;
    onShutdown();
    unawaited(_out.close());
    unawaited(_sub.cancel());
    unawaited(ws.close(WebSocketStatus.normalClosure).catchError((Object _) {}));
    if (!_ended.isCompleted) _ended.complete();
  }
}

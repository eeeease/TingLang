import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:tinglang_cloud_asr/tinglang_cloud_asr.dart';

/// Helpers for the Tencent Cloud, DashScope and iFlytek adapter tests.

/// [ms] of silent 16 kHz mono PCM16.
Uint8List silence(int ms) => Uint8List(ms * 32);

/// A WAV of [ms] whose samples count up (so a test can check the bytes).
Uint8List countingWav(int ms) {
  final pcm = Uint8List(ms * 32);
  for (var i = 0; i < pcm.length; i++) {
    pcm[i] = i & 0xff;
  }
  return wavFromPcm16(pcm);
}

/// Matches a [CloudAsrError] of [kind] whose message and toString contain
/// none of [secrets].
TypeMatcher<CloudAsrError> cloudError(CloudAsrErrorKind kind, {List<String> secrets = const []}) =>
    isA<CloudAsrError>()
        .having((e) => e.kind, 'kind', kind)
        .having((e) => e.toString(), 'toString', _containsNone(secrets))
        .having((e) => e.message, 'message', _containsNone(secrets));

Matcher _containsNone(List<String> values) =>
    predicate<String>((s) => values.every((v) => !s.contains(v)), 'contains no credential');

/// A loopback port nothing listens on.
Future<int> closedPort() async {
  final s = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = s.port;
  await s.close();
  return port;
}

/// Reads a request body.
Future<Uint8List> readBody(HttpRequest request) async {
  final b = BytesBuilder(copy: false);
  await for (final chunk in request) {
    b.add(chunk);
  }
  return b.takeBytes();
}

/// Sends [value] as a JSON text frame.
void sendJson(WebSocket ws, Object value) => ws.add(jsonEncode(value));

/// Everything a stream emits until it closes: segments, then the error if
/// one ended it.
Future<(List<CloudSegment>, Object?)> drain(CloudAsrStream stream) async {
  final segments = <CloudSegment>[];
  Object? error;
  final done = Completer<void>();
  stream.segments.listen(segments.add, onError: (Object e) => error = e, onDone: done.complete);
  await done.future.timeout(const Duration(seconds: 10));
  return (segments, error);
}

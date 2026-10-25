import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../audio.dart';
import '../provider.dart';
import 'net_support.dart';

/// Microsoft Azure AI Speech: the fast transcription REST API
/// (`transcriptions:transcribe`, api-version 2025-10-15) for files, and the
/// Speech service's real-time WebSocket protocol (the one the Speech SDK
/// speaks; written here from its documented behaviour, not verified against
/// the live service) for live captions. Fields: the resource key and its
/// region (`eastus`, `westeurope`, …). Endpoints, limits and error mapping:
/// `doc/azure.md`.
final class AzureSpeechProvider implements CloudAsrProvider {
  /// [restBase] and [speechBase] are for tests (a loopback server) and
  /// replace `https://<region>.api.cognitive.microsoft.com` and
  /// `wss://<region>.stt.speech.microsoft.com` when given; the region is
  /// still validated. [now] stamps protocol messages.
  AzureSpeechProvider({this.restBase, this.speechBase, DateTime Function()? now})
    : _now = now ?? DateTime.now {
    assert(restBase == null || const {'http', 'https'}.contains(restBase!.scheme));
    assert(speechBase == null || const {'ws', 'wss'}.contains(speechBase!.scheme));
  }

  final Uri? restBase, speechBase;
  final DateTime Function() _now;

  /// Fast transcription API version.
  static const apiVersion = '2025-10-15';

  /// Default locale per base language (the first the docs list for it).
  static const defaultLocales = {
    'en': 'en-US',
    'zh': 'zh-CN',
    'ja': 'ja-JP',
    'ko': 'ko-KR',
    'es': 'es-ES',
    'fr': 'fr-FR',
    'de': 'de-DE',
    'it': 'it-IT',
    'pt': 'pt-BR',
    'hi': 'hi-IN',
  };

  /// Locales passed through as given (fast transcription documents these).
  static const knownLocales = {
    'en-US', 'en-GB', 'en-AU', 'en-CA', 'en-IN', 'es-ES', 'es-MX', 'fr-FR', 'fr-CA', //
    'de-DE', 'it-IT', 'ja-JP', 'ko-KR', 'pt-BR', 'zh-CN', 'hi-IN',
  };

  static final _info = CloudAsrInfo(
    id: 'azure',
    fields: const [
      CloudField(CloudFieldKeys.apiKey),
      CloudField(CloudFieldKeys.region, kind: CloudFieldKind.text),
    ],
    languages: defaultLocales.keys.toSet(),
    consoleUrl: Uri.parse(
      'https://portal.azure.com/#create/Microsoft.CognitiveServicesSpeechServices',
    ),
    docsUrl: Uri.parse('https://learn.microsoft.com/azure/ai-services/speech-service/'),
    // The quota page allows < 5 h and < 500 MB; the API reference still says
    // < 2 h and < 250 MB. Stay inside both.
    maxFileMs: 2 * 60 * 60 * 1000,
    maxFileBytes: 240 * 1000 * 1000,
  );

  @override
  CloudAsrInfo get info => _info;

  static final _regionName = RegExp(r'^[a-z][a-z0-9]{2,39}$');

  /// The region from [credentials], normalised (`East US` → `eastus`).
  /// Throws [CloudAsrErrorKind.unauthorized] unless it is a plain public
  /// Azure region name, so it can never change the host it is put into.
  static String region(CloudCredentials credentials) {
    final raw = requireField(credentials, CloudFieldKeys.region);
    final name = raw.toLowerCase().replaceAll(RegExp(r'\s+'), '');
    if (!_regionName.hasMatch(name)) {
      throw const CloudAsrError(
        CloudAsrErrorKind.unauthorized,
        'The region must be an Azure region name such as "eastus".',
      );
    }
    if (name.startsWith('usgov') || name.startsWith('usdod') || name.startsWith('china')) {
      throw const CloudAsrError(
        CloudAsrErrorKind.unauthorized,
        'Azure Government and Azure China regions are not supported.',
      );
    }
    return name;
  }

  @override
  List<String> hosts(CloudCredentials credentials) {
    final String name;
    try {
      name = region(credentials);
    } on CloudAsrError {
      return const [];
    }
    return [
      restBase?.host ?? '$name.api.cognitive.microsoft.com',
      speechBase?.host ?? '$name.stt.speech.microsoft.com',
    ];
  }

  /// The Azure locale for a BCP-47 tag: a documented locale as given
  /// (`en-GB`), otherwise the language's default (`en` → `en-US`,
  /// `zh-Hans` → `zh-CN`).
  static String locale(String tag) {
    final parts = tag.replaceAll('_', '-').split('-');
    final base = parts.first.toLowerCase();
    if (parts.length > 1) {
      final candidate = '$base-${parts.last.toUpperCase()}';
      if (knownLocales.contains(candidate)) return candidate;
    }
    return defaultLocales[base] ??
        (throw const CloudAsrError(
          CloudAsrErrorKind.unsupportedLanguage,
          'Azure Speech is not set up for this language here.',
        ));
  }

  Uri _rest(String region, String path, [Map<String, String>? query]) {
    final base = restBase ?? Uri.https('$region.api.cognitive.microsoft.com');
    return base.replace(path: path, queryParameters: query);
  }

  static Map<String, String> _auth(String key) => {'Ocp-Apim-Subscription-Key': key};

  @override
  Future<void> verify(CloudCredentials credentials) async {
    final key = requireField(credentials, CloudFieldKeys.apiKey);
    final name = region(credentials);
    // Exchanging the key for a token is free, needs a valid key for this
    // region, and sends no audio. The token is discarded.
    final reply = await httpSend(
      'POST',
      _rest(name, '/sts/v1.0/issueToken'),
      headers: {..._auth(key), HttpHeaders.contentTypeHeader: 'application/x-www-form-urlencoded'},
      timeout: const Duration(seconds: 30),
    );
    if (!reply.ok) throw azureHttpError(reply, [key]);
  }

  @override
  Future<List<CloudSegment>> transcribeFile(
    CloudCredentials credentials,
    CloudFileRequest request, {
    void Function(double progress)? onProgress,
    CloudCancelToken? cancel,
  }) async {
    final key = requireField(credentials, CloudFieldKeys.apiKey);
    final name = region(credentials);
    final loc = locale(request.language);
    checkFileLimits(info, request);
    final form = MultipartBody()
      ..file('audio', 'tinglang.wav', 'audio/wav', request.wav)
      ..field(
        'definition',
        jsonEncode({
          'locales': [loc],
          'profanityFilterMode': 'None',
        }),
        contentType: 'application/json',
      );
    // One synchronous request: nothing is stored on the service afterwards.
    final reply = await httpSend(
      'POST',
      _rest(name, '/speechtotext/transcriptions:transcribe', {'api-version': apiVersion}),
      headers: {..._auth(key), HttpHeaders.contentTypeHeader: form.contentType},
      body: form.finish(),
      cancel: cancel,
      onSent: (sent, total) => onProgress?.call(0.5 * sent / total),
      // Fast transcription answers after recognising the whole file.
      timeout: uploadTimeout(
        request.wav.length,
        extra: Duration(minutes: 2, milliseconds: request.durationMs ~/ 2),
      ),
    );
    if (!reply.ok) throw azureHttpError(reply, [key]);
    final body = jsonMap(reply.json) ?? (throw protocolError('Azure sent an unreadable result.'));
    final segments = <CloudSegment>[];
    for (final raw in jsonList(body['phrases'])) {
      final p = jsonMap(raw);
      final text = jsonString(p?['text'])?.trim() ?? '';
      if (p == null || text.isEmpty) continue;
      final start = jsonInt(p['offsetMilliseconds']) ?? 0;
      final words = [
        for (final rw in jsonList(p['words']))
          if (jsonMap(rw) case final w?)
            if (jsonString(w['text']) case final t? when t.isNotEmpty)
              CloudWord(
                t,
                jsonInt(w['offsetMilliseconds']) ?? start,
                (jsonInt(w['offsetMilliseconds']) ?? start) +
                    (jsonInt(w['durationMilliseconds']) ?? 0),
              ),
      ];
      segments.add(
        CloudSegment(
          id: '${segments.length}',
          text: text,
          startMs: start,
          endMs: start + (jsonInt(p['durationMilliseconds']) ?? 0),
          words: request.wordTimestamps && words.isNotEmpty ? words : null,
          language: jsonString(p['locale']),
        ),
      );
    }
    onProgress?.call(1);
    return segments;
  }

  @override
  Future<CloudAsrStream> openStream(
    CloudCredentials credentials,
    CloudStreamOptions options,
  ) async {
    final key = requireField(credentials, CloudFieldKeys.apiKey);
    final name = region(credentials);
    final loc = locale(options.language);
    final base = speechBase ?? Uri(scheme: 'wss', host: '$name.stt.speech.microsoft.com');
    final uri = base.replace(
      path: '/speech/recognition/conversation/cognitiveservices/v1',
      queryParameters: {
        'language': loc,
        'format': 'detailed',
        'profanity': 'raw',
        'wordLevelTimestamps': 'true',
      },
    );
    final connectionId = randomHex(16);
    final ws = await openWebSocket(
      uri,
      headers: {..._auth(key), 'X-ConnectionId': connectionId},
      onHttpStatus: (status) => azureHttpError(HttpReply(status, ''), [key]),
    );
    return _AzureStream(ws, [key], _now, options.sampleRate);
  }
}

/// Maps an Azure Speech HTTP error (`{"error": {"code", "message",
/// "innerError": {"code"}}}`, or a bare status from a refused WebSocket
/// upgrade) to a [CloudAsrError]; [secrets] are scrubbed from the message.
CloudAsrError azureHttpError(HttpReply reply, List<String> secrets) {
  final error = jsonMap(jsonMap(reply.json)?['error']);
  final inner = jsonMap(error?['innerError'] ?? error?['innererror']);
  final code = jsonString(inner?['code']) ?? jsonString(error?['code']);
  final body = reply.body.trim();
  final message =
      jsonString(inner?['message']) ??
      jsonString(error?['message']) ??
      (body.isEmpty || body.startsWith('<') || body.startsWith('{') ? null : body);
  final status = reply.statusCode;
  final kind = switch (code) {
    'AudioLengthLimitExceeded' => CloudAsrErrorKind.audioTooLong,
    'InvalidLocale' ||
    'UnsupportedLanguageCode' ||
    'NoLanguageIdentified' ||
    'MultipleLanguagesIdentified' => CloudAsrErrorKind.unsupportedLanguage,
    'QuotaViolation' => CloudAsrErrorKind.quotaExceeded,
    'InvalidSubscription' ||
    'SubscriptionNotFound' ||
    'InvalidPermissions' => CloudAsrErrorKind.unauthorized,
    _ => switch (status) {
      401 => CloudAsrErrorKind.unauthorized,
      403 when mentions(message, ['quota']) => CloudAsrErrorKind.quotaExceeded,
      403 => CloudAsrErrorKind.unauthorized,
      413 => CloudAsrErrorKind.audioTooLong,
      400 || 404 || 415 || 422 => CloudAsrErrorKind.badRequest,
      429 => CloudAsrErrorKind.rateLimited,
      >= 500 => CloudAsrErrorKind.server,
      _ => CloudAsrErrorKind.protocol,
    },
  };
  return CloudAsrError(
    kind,
    scrub(message ?? 'Azure Speech refused the request (HTTP $status).', secrets),
    statusCode: status,
    providerCode: safeCode(code),
  );
}

/// Maps a WebSocket close from the Speech service to a [CloudAsrError].
CloudAsrError azureCloseError(int? code, String? reason, List<String> secrets) {
  final text = scrub(
    reason == null || reason.isEmpty ? 'Azure Speech closed the stream.' : reason,
    secrets,
  );
  final kind = switch (code) {
    _ when mentions(reason, ['too many', 'concurren', 'throttl']) => CloudAsrErrorKind.rateLimited,
    _ when mentions(reason, ['quota']) => CloudAsrErrorKind.quotaExceeded,
    1000 || 1001 => CloudAsrErrorKind.sessionEnded,
    1007 => CloudAsrErrorKind.badRequest,
    1008 => CloudAsrErrorKind.unauthorized,
    1011 || 4000 => CloudAsrErrorKind.server,
    _ => CloudAsrErrorKind.network,
  };
  return CloudAsrError(kind, text, providerCode: code?.toString());
}

/// A text message of the Speech service protocol: `Name: value` header lines,
/// a blank line, then the body.
String azureTextMessage(Map<String, String> headers, String body) =>
    '${headers.entries.map((e) => '${e.key}: ${e.value}\r\n').join()}\r\n$body';

/// A binary message: a 2-byte big-endian header length, the ASCII header
/// lines (each ending in CRLF), then [body] (none for end of audio).
Uint8List azureBinaryMessage(Map<String, String> headers, [List<int>? body]) {
  final head = ascii.encode(headers.entries.map((e) => '${e.key}: ${e.value}\r\n').join());
  final out = Uint8List(2 + head.length + (body?.length ?? 0));
  ByteData.sublistView(out).setUint16(0, head.length);
  out.setRange(2, 2 + head.length, head);
  if (body != null) out.setRange(2 + head.length, out.length, body);
  return out;
}

/// Headers (names lower-cased) and body of a text message.
({Map<String, String> headers, String body}) parseAzureTextMessage(String message) {
  final split = message.indexOf('\r\n\r\n');
  final head = split < 0 ? message : message.substring(0, split);
  final headers = <String, String>{};
  for (final line in head.split(RegExp(r'\r?\n'))) {
    final colon = line.indexOf(':');
    if (colon <= 0) continue;
    headers[line.substring(0, colon).trim().toLowerCase()] = line.substring(colon + 1).trim();
  }
  return (headers: headers, body: split < 0 ? '' : message.substring(split + 4));
}

/// Milliseconds from a 100-ns tick count.
int _ms(Object? ticks) => (jsonInt(ticks) ?? 0) ~/ 10000;

final class _AzureStream extends WsAsrStream {
  _AzureStream(super.ws, super.secrets, this._now, int sampleRate) : _requestId = randomHex(16) {
    sendText(
      azureTextMessage(
        {
          'Path': 'speech.config',
          'X-RequestId': _requestId,
          'X-Timestamp': _timestamp(),
          'Content-Type': 'application/json',
        },
        jsonEncode({
          'context': {
            'system': {'name': 'Tinglang', 'version': '1', 'build': 'Dart', 'lang': 'Dart'},
            'os': {'platform': Platform.operatingSystem, 'name': Platform.operatingSystem},
          },
        }),
      ),
    );
    // The first audio message carries a WAV header describing the stream.
    sendBytes(
      azureBinaryMessage({
        ..._audioHeaders(),
        'Content-Type': 'audio/x-wav',
      }, wavFromPcm16(Uint8List(0), sampleRate: sampleRate)),
    );
  }

  final DateTime Function() _now;
  final String _requestId;
  int _next = 0;
  String? _lastPartial;

  String _timestamp() {
    final t = _now().toUtc();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${t.year.toString().padLeft(4, '0')}-${two(t.month)}-${two(t.day)}'
        'T${two(t.hour)}:${two(t.minute)}:${two(t.second)}'
        '.${t.millisecond.toString().padLeft(3, '0')}Z';
  }

  Map<String, String> _audioHeaders() => {
    'Path': 'audio',
    'X-RequestId': _requestId,
    'X-Timestamp': _timestamp(),
  };

  @override
  void sendAudio(Uint8List pcm16le) => sendBytes(azureBinaryMessage(_audioHeaders(), pcm16le));

  /// An audio message with no body ends the audio.
  @override
  void sendEnd() => sendBytes(azureBinaryMessage(_audioHeaders()));

  @override
  void onText(String text) {
    final message = parseAzureTextMessage(text);
    final path = message.headers['path']?.toLowerCase();
    switch (path) {
      case 'speech.hypothesis':
        final m = jsonMap(tryJson(message.body));
        final t = jsonString(m?['Text'])?.trim() ?? '';
        if (m == null || t.isEmpty || t == _lastPartial) return;
        _lastPartial = t;
        final start = _ms(m['Offset']);
        emit(
          CloudSegment(
            id: '$_next',
            text: t,
            startMs: start,
            endMs: start + _ms(m['Duration']),
            isFinal: false,
          ),
        );
      case 'speech.phrase':
        final m = jsonMap(tryJson(message.body));
        if (m == null) {
          fail(protocolError('Azure Speech sent an unreadable phrase.'));
          return;
        }
        _phrase(m);
      case 'turn.end':
        if (finishing) {
          ended();
        } else {
          // The service ended the recognition on its own (its time limit):
          // the caller opens a new stream.
          fail(
            const CloudAsrError(CloudAsrErrorKind.sessionEnded, 'Azure Speech ended the session.'),
          );
        }
      default:
      // turn.start, speech.startDetected, speech.endDetected, speech.fragment.
    }
  }

  void _phrase(Map<String, Object?> m) {
    final status = jsonString(m['RecognitionStatus']);
    switch (status) {
      case 'Success':
        final best = jsonMap(jsonList(m['NBest']).firstOrNull);
        final text = (jsonString(m['DisplayText']) ?? jsonString(best?['Display']) ?? '').trim();
        final start = _ms(m['Offset']);
        final words = [
          for (final raw in jsonList(best?['Words']))
            if (jsonMap(raw) case final w?)
              if (jsonString(w['Word']) case final word? when word.isNotEmpty)
                CloudWord(word, _ms(w['Offset']), _ms(w['Offset']) + _ms(w['Duration'])),
        ];
        if (text.isEmpty) return;
        emit(
          CloudSegment(
            id: '$_next',
            text: text,
            startMs: start,
            endMs: start + _ms(m['Duration']),
            words: words.isEmpty ? null : words,
            language: jsonString(jsonMap(m['PrimaryLanguage'])?['Language']),
          ),
        );
        _next++;
        _lastPartial = null;
      case 'TooManyRequests':
        fail(
          const CloudAsrError(CloudAsrErrorKind.rateLimited, 'Azure Speech: too many requests.'),
        );
      case 'BadRequest':
        fail(
          const CloudAsrError(CloudAsrErrorKind.badRequest, 'Azure Speech refused the request.'),
        );
      case 'Forbidden':
        fail(const CloudAsrError(CloudAsrErrorKind.unauthorized, 'Azure Speech refused the key.'));
      case 'Error' || 'ServiceUnavailable':
        fail(const CloudAsrError(CloudAsrErrorKind.server, 'Azure Speech failed.'));
      default:
      // NoMatch, InitialSilenceTimeout, BabbleTimeout, EndOfDictation: no text.
    }
  }

  @override
  void onClosed(int? code, String? reason) {
    if (finishing && code == WebSocketStatus.normalClosure) {
      ended();
    } else {
      fail(azureCloseError(code, reason, secrets));
    }
  }
}

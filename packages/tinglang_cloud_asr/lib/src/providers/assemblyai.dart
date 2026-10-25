import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../provider.dart';
import 'net_support.dart';

/// AssemblyAI (assemblyai.com): Universal-Streaming v3 WebSocket with
/// `universal-3-6-pro` for live captions, and the pre-recorded API
/// (`/v2/upload`, `/v2/transcript`, poll, `/sentences`, then delete) with
/// `universal-3-5-pro` falling back to `universal-2` for files. Fields: the
/// API key and a region (`us`, `eu`: data residency). Endpoints, limits and
/// error mapping: `doc/assemblyai.md`.
final class AssemblyAiProvider implements CloudAsrProvider {
  /// [apiBase] and [streamingUrl] are for tests (a loopback server) and
  /// replace the region's hosts when given. [now], [pollInterval],
  /// [readyTimeout] and [fileTimeout] make timing deterministic.
  AssemblyAiProvider({
    this.apiBase,
    this.streamingUrl,
    DateTime Function()? now,
    this.pollInterval = const Duration(seconds: 3),
    this.readyTimeout = const Duration(seconds: 10),
    this.fileTimeout = const Duration(hours: 3),
  }) : _now = now ?? DateTime.now {
    assert(apiBase == null || const {'http', 'https'}.contains(apiBase!.scheme));
    assert(streamingUrl == null || const {'ws', 'wss'}.contains(streamingUrl!.scheme));
  }

  final Uri? apiBase, streamingUrl;
  final Duration pollInterval, readyTimeout, fileTimeout;
  final DateTime Function() _now;

  /// Live model: AssemblyAI's recommended streaming model (32 languages,
  /// formatted turns, code-switching).
  static const streamingModel = 'universal-3-6-pro';

  /// File models, best first: Universal-3.5 Pro for its languages, then
  /// Universal-2 for the rest (the service's own default list).
  static const fileModels = ['universal-3-5-pro', 'universal-2'];

  /// Region choice ids.
  static const regions = ['us', 'eu'];

  /// `language_codes` accepted by Universal-3.6 Pro Streaming.
  static const streamingLanguages = {
    'af', 'ar', 'yue', 'ca', 'da', 'nl', 'en', 'et', 'fi', 'fr', 'gl', 'de', 'he', 'hi', 'it', //
    'ja', 'ko', 'zh', 'mr', 'no', 'nn', 'fa', 'pt', 'ro', 'ru', 'es', 'sv', 'tr', 'ur', 'vi',
    'xh', 'zu',
  };

  /// Base `language_code`s of the pre-recorded API (Universal-2 covers all;
  /// Universal-3.5 Pro a subset).
  static const fileLanguages = {
    'en', 'es', 'fr', 'de', 'it', 'pt', 'nl', 'af', 'sq', 'am', 'ar', 'hy', 'as', 'az', 'ba', //
    'eu', 'be', 'bn', 'bs', 'br', 'bg', 'my', 'ca', 'zh', 'hr', 'cs', 'da', 'et', 'fo', 'fi',
    'gl', 'ka', 'el', 'gu', 'ht', 'ha', 'haw', 'he', 'hi', 'hu', 'is', 'id', 'ja', 'jw', 'kn',
    'kk', 'km', 'ko', 'lo', 'la', 'lv', 'ln', 'lt', 'lb', 'mk', 'mg', 'ms', 'ml', 'mt', 'mi',
    'mr', 'mn', 'ne', 'no', 'nn', 'oc', 'pa', 'ps', 'fa', 'pl', 'ro', 'ru', 'sa', 'sr', 'sn',
    'sd', 'si', 'sk', 'sl', 'so', 'su', 'sw', 'sv', 'tl', 'tg', 'ta', 'tt', 'te', 'th', 'bo',
    'tr', 'tk', 'uk', 'ur', 'uz', 'vi', 'cy', 'yi', 'yo',
  };

  static final _info = CloudAsrInfo(
    id: 'assemblyai',
    fields: const [
      CloudField(CloudFieldKeys.apiKey),
      CloudField(
        CloudFieldKeys.region,
        kind: CloudFieldKind.choice,
        choices: regions,
        defaultValue: 'us',
      ),
    ],
    // Languages both live and file recognise.
    languages: streamingLanguages.intersection(fileLanguages),
    consoleUrl: Uri.parse('https://www.assemblyai.com/dashboard'),
    docsUrl: Uri.parse('https://www.assemblyai.com/docs'),
    maxFileMs: 10 * 60 * 60 * 1000,
    maxFileBytes: 2200 * 1000 * 1000,
  );

  @override
  CloudAsrInfo get info => _info;

  static String _region(CloudCredentials credentials) {
    final region = credentials[CloudFieldKeys.region]?.trim().toLowerCase() ?? '';
    return region == 'eu' ? 'eu' : 'us';
  }

  /// The REST host for [region]: `api.assemblyai.com` or
  /// `api.eu.assemblyai.com`.
  static String apiHost(String region) =>
      region == 'eu' ? 'api.eu.assemblyai.com' : 'api.assemblyai.com';

  /// The streaming host for [region]: the US or EU data-residency endpoint.
  static String streamingHost(String region) =>
      region == 'eu' ? 'streaming.eu.assemblyai.com' : 'streaming.us.assemblyai.com';

  @override
  List<String> hosts(CloudCredentials credentials) {
    final region = _region(credentials);
    return [apiBase?.host ?? apiHost(region), streamingUrl?.host ?? streamingHost(region)];
  }

  Uri _api(CloudCredentials credentials, String path, [Map<String, String>? query]) {
    final base = apiBase ?? Uri.https(apiHost(_region(credentials)));
    final prefix = base.path.endsWith('/')
        ? base.path.substring(0, base.path.length - 1)
        : base.path;
    return base.replace(path: '$prefix$path', queryParameters: query);
  }

  /// The pre-recorded `language_code` for a BCP-47 tag: `en-US` → `en_us`,
  /// `en-GB` → `en_uk`, `en-AU` → `en_au`, `zh-Hans` → `zh`, otherwise the
  /// base language.
  static String fileLanguage(String tag) {
    final t = tag.replaceAll('_', '-').toLowerCase();
    if (t == 'en-us') return 'en_us';
    if (t == 'en-gb' || t == 'en-uk') return 'en_uk';
    if (t == 'en-au') return 'en_au';
    final base = baseLanguage(tag);
    if (fileLanguages.contains(base)) return base;
    throw _unsupported;
  }

  /// The streaming `language_codes` entry for a BCP-47 tag (its base).
  static String streamingLanguage(String tag) {
    final base = baseLanguage(tag);
    if (streamingLanguages.contains(base)) return base;
    throw _unsupported;
  }

  static const _unsupported = CloudAsrError(
    CloudAsrErrorKind.unsupportedLanguage,
    'AssemblyAI does not recognise this language.',
  );

  @override
  Future<void> verify(CloudCredentials credentials) async {
    final key = requireField(credentials, CloudFieldKeys.apiKey);
    // Listing transcripts is free and needs a valid key.
    final reply = await httpSend(
      'GET',
      _api(credentials, '/v2/transcript', {'limit': '1'}),
      headers: _auth(key),
      timeout: const Duration(seconds: 30),
    );
    if (!reply.ok) throw assemblyAiHttpError(reply, [key]);
  }

  @override
  Future<CloudAsrStream> openStream(
    CloudCredentials credentials,
    CloudStreamOptions options,
  ) async {
    final key = requireField(credentials, CloudFieldKeys.apiKey);
    final language = streamingLanguage(options.language);
    final base =
        streamingUrl ??
        Uri(scheme: 'wss', host: streamingHost(_region(credentials)), path: '/v3/ws');
    final uri = base.replace(
      queryParameters: {
        ...base.queryParameters,
        'sample_rate': '${options.sampleRate}',
        'encoding': 'pcm_s16le',
        'speech_model': streamingModel,
        'language_codes': jsonEncode([language]),
      },
    );
    final ws = await openWebSocket(
      uri,
      headers: _auth(key),
      onHttpStatus: (status) => assemblyAiHttpError(HttpReply(status, ''), [key]),
    );
    final stream = _AssemblyAiStream(ws, [key], options.sampleRate, formatTurns: false);
    try {
      await stream.ready.timeout(readyTimeout);
    } on TimeoutException {
      await stream.cancel();
      throw const CloudAsrError(CloudAsrErrorKind.network, 'AssemblyAI did not start the session.');
    } on CloudAsrError {
      await stream.cancel();
      rethrow;
    }
    return stream;
  }

  @override
  Future<List<CloudSegment>> transcribeFile(
    CloudCredentials credentials,
    CloudFileRequest request, {
    void Function(double progress)? onProgress,
    CloudCancelToken? cancel,
  }) async {
    final key = requireField(credentials, CloudFieldKeys.apiKey);
    final language = fileLanguage(request.language);
    checkFileLimits(info, request);
    cancel?.check();
    String? transcriptId;
    try {
      final upload = await httpSend(
        'POST',
        _api(credentials, '/v2/upload'),
        headers: {..._auth(key), HttpHeaders.contentTypeHeader: 'application/octet-stream'},
        body: [request.wav],
        cancel: cancel,
        onSent: (sent, total) => onProgress?.call(0.5 * sent / total),
        timeout: uploadTimeout(request.wav.length),
      );
      if (!upload.ok) throw assemblyAiHttpError(upload, [key]);
      final uploadUrl =
          jsonString(jsonMap(upload.json)?['upload_url']) ??
          (throw protocolError('AssemblyAI sent no upload URL.'));
      cancel?.check();

      final created = await httpSend(
        'POST',
        _api(credentials, '/v2/transcript'),
        headers: {..._auth(key), HttpHeaders.contentTypeHeader: 'application/json'},
        body: [
          utf8.encode(
            jsonEncode({
              'audio_url': uploadUrl,
              'speech_models': fileModels,
              'language_code': language,
              'punctuate': true,
              'format_text': true,
            }),
          ),
        ],
        cancel: cancel,
        timeout: const Duration(seconds: 60),
      );
      if (!created.ok) throw assemblyAiHttpError(created, [key]);
      transcriptId = _id(created);

      final deadline = _now().add(fileTimeout);
      while (true) {
        await pause(pollInterval, cancel);
        final poll = await httpSend(
          'GET',
          _api(credentials, '/v2/transcript/$transcriptId'),
          headers: _auth(key),
          cancel: cancel,
          timeout: const Duration(minutes: 2),
        );
        if (!poll.ok) throw assemblyAiHttpError(poll, [key]);
        final body =
            jsonMap(poll.json) ?? (throw protocolError('AssemblyAI sent an unreadable status.'));
        final status = jsonString(body['status']);
        if (status == 'completed') break;
        if (status == 'error') throw _jobError(jsonString(body['error']), key);
        if (status != 'queued' && status != 'processing') {
          throw protocolError('AssemblyAI sent an unknown transcript status.');
        }
        if (_now().isAfter(deadline)) {
          throw const CloudAsrError(
            CloudAsrErrorKind.server,
            'AssemblyAI did not finish the transcript in time.',
          );
        }
      }
      onProgress?.call(0.9);

      final sentences = await httpSend(
        'GET',
        _api(credentials, '/v2/transcript/$transcriptId/sentences'),
        headers: _auth(key),
        cancel: cancel,
        timeout: const Duration(minutes: 5),
      );
      if (!sentences.ok) throw assemblyAiHttpError(sentences, [key]);
      final segments = <CloudSegment>[];
      for (final raw in jsonList(jsonMap(sentences.json)?['sentences'])) {
        final s = jsonMap(raw);
        final text = jsonString(s?['text'])?.trim() ?? '';
        if (s == null || text.isEmpty) continue;
        final words = _words(s['words']);
        segments.add(
          CloudSegment(
            id: '${segments.length}',
            text: text,
            startMs: jsonInt(s['start']) ?? (words.isEmpty ? 0 : words.first.startMs),
            endMs: jsonInt(s['end']) ?? (words.isEmpty ? 0 : words.last.endMs),
            words: request.wordTimestamps ? words : null,
          ),
        );
      }
      onProgress?.call(1);
      return segments;
    } finally {
      // Deleting the transcript also deletes the uploaded audio.
      if (transcriptId != null) {
        try {
          await httpSend(
            'DELETE',
            _api(credentials, '/v2/transcript/$transcriptId'),
            headers: _auth(key),
            timeout: const Duration(seconds: 20),
          );
        } on CloudAsrError {
          // Best effort; see doc/assemblyai.md for what remains.
        }
      }
    }
  }

  static Map<String, String> _auth(String key) => {HttpHeaders.authorizationHeader: key};

  static String _id(HttpReply reply) =>
      jsonString(jsonMap(reply.json)?['id']) ?? (throw protocolError('AssemblyAI sent no id.'));

  static CloudAsrError _jobError(String? message, String key) {
    final text = scrub(message ?? 'AssemblyAI could not transcribe the file.', [key]);
    final kind = switch (message) {
      _ when mentions(message, ['language']) => CloudAsrErrorKind.unsupportedLanguage,
      _ when mentions(message, ['too long', 'exceeds the maximum', 'duration is too']) =>
        CloudAsrErrorKind.audioTooLong,
      _ when mentions(message, ['balance', 'credit', 'payment']) => CloudAsrErrorKind.quotaExceeded,
      _ when mentions(message, ['try again', 'internal', 'server error']) =>
        CloudAsrErrorKind.server,
      _ => CloudAsrErrorKind.badRequest,
    };
    return CloudAsrError(kind, text);
  }
}

List<CloudWord> _words(Object? json) => [
  for (final raw in jsonList(json))
    if (jsonMap(raw) case final w?)
      if (jsonString(w['text']) case final text? when text.isNotEmpty)
        CloudWord(text, jsonInt(w['start']) ?? 0, jsonInt(w['end']) ?? jsonInt(w['start']) ?? 0),
];

/// Maps an AssemblyAI HTTP error reply (`{"error": "…"}`) to a
/// [CloudAsrError]; [secrets] are scrubbed from the message.
CloudAsrError assemblyAiHttpError(HttpReply reply, List<String> secrets) {
  final message = jsonString(jsonMap(reply.json)?['error']) ?? _plain(reply.body);
  final text = scrub(message ?? 'AssemblyAI refused the request.', secrets);
  final status = reply.statusCode;
  final kind = switch (status) {
    _ when mentions(message, ['insufficient', 'balance', 'payment required']) =>
      CloudAsrErrorKind.quotaExceeded,
    400 when mentions(message, ['language']) => CloudAsrErrorKind.unsupportedLanguage,
    400 when mentions(message, ['too long', 'exceeds']) => CloudAsrErrorKind.audioTooLong,
    400 || 404 || 410 => CloudAsrErrorKind.badRequest,
    401 || 403 => CloudAsrErrorKind.unauthorized,
    402 => CloudAsrErrorKind.quotaExceeded,
    413 => CloudAsrErrorKind.audioTooLong,
    422 => CloudAsrErrorKind.server,
    429 => CloudAsrErrorKind.rateLimited,
    >= 500 => CloudAsrErrorKind.server,
    _ => CloudAsrErrorKind.protocol,
  };
  return CloudAsrError(kind, text, statusCode: status);
}

String? _plain(String body) {
  final t = body.trim();
  return t.isEmpty || t.startsWith('<') ? null : t;
}

/// Maps an AssemblyAI streaming error (`Error` message or close code with
/// its text) to a [CloudAsrError]. Close codes:
/// https://www.assemblyai.com/docs/streaming/common-session-errors-and-closures
CloudAsrError assemblyAiStreamError(int? code, String? message, List<String> secrets) {
  final text = scrub(
    message == null || message.isEmpty ? 'AssemblyAI closed the stream.' : message,
    secrets,
  );
  final kind = switch (code) {
    1008 when mentions(message, ['too many concurrent', 'too many sessions']) =>
      CloudAsrErrorKind.rateLimited,
    1008 when mentions(message, ['insufficient funds', 'balance', 'metronome']) =>
      CloudAsrErrorKind.quotaExceeded,
    1008 => CloudAsrErrorKind.unauthorized,
    3008 => CloudAsrErrorKind.sessionEnded,
    3006 when mentions(message, ['inactivity']) => CloudAsrErrorKind.sessionEnded,
    3006 || 3007 => CloudAsrErrorKind.badRequest,
    3005 || 1011 => CloudAsrErrorKind.server,
    _ => CloudAsrErrorKind.network,
  };
  return CloudAsrError(kind, text, providerCode: code?.toString());
}

final class _AssemblyAiStream extends WsAsrStream {
  _AssemblyAiStream(super.ws, super.secrets, int sampleRate, {required this.formatTurns})
    : _framer = PcmFramer(sampleRate * 2 ~/ 10), // 100 ms
      _minFrameBytes = sampleRate * 2 ~/ 20; // 50 ms, the service's minimum

  /// Universal-Streaming models send an unformatted and then a formatted
  /// end of turn; Universal-3.x send one formatted end of turn.
  final bool formatTurns;
  final PcmFramer _framer;
  final int _minFrameBytes;
  final _ready = Completer<void>();
  final _finalTurns = <int>{};

  /// Turns that ended unformatted, waiting for the formatted copy.
  final _waiting = <int, CloudSegment>{};
  String? _lastPartial;

  /// Completes on `Begin`; fails if the service refuses the session.
  Future<void> get ready => _ready.future;

  @override
  void sendAudio(Uint8List pcm16le) {
    for (final frame in _framer.add(pcm16le)) {
      sendBytes(frame);
    }
  }

  @override
  void sendEnd() {
    final rest = _framer.flush(minBytes: _minFrameBytes);
    if (rest != null) sendBytes(rest);
    // End the current turn now so its final arrives before Termination.
    sendText('{"type":"ForceEndpoint"}');
    sendText('{"type":"Terminate"}');
  }

  @override
  void onShutdown() {
    if (!_ready.isCompleted) {
      _ready.completeError(networkError);
      unawaited(_ready.future.catchError((Object _) {}));
    }
  }

  void _refuse(CloudAsrError error) {
    if (!_ready.isCompleted) {
      _ready.completeError(error);
      unawaited(_ready.future.catchError((Object _) {}));
    }
    fail(error);
  }

  @override
  void onText(String text) {
    final m = jsonMap(tryJson(text));
    if (m == null) {
      _refuse(protocolError('AssemblyAI sent an unreadable message.'));
      return;
    }
    switch (jsonString(m['type'])) {
      case 'Begin':
        if (!_ready.isCompleted) _ready.complete();
      case 'Turn':
        _turn(m);
      case 'Termination':
        _flushWaiting();
        ended();
      case 'Error':
        _refuse(assemblyAiStreamError(jsonInt(m['error_code']), jsonString(m['error']), secrets));
      default:
      // SpeechStarted, Heartbeat, SpeakerRevision, …: nothing to show.
    }
  }

  void _turn(Map<String, Object?> m) {
    final order = jsonInt(m['turn_order']) ?? 0;
    if (_finalTurns.contains(order)) return;
    for (final earlier in _waiting.keys.where((k) => k < order).toList()) {
      _final(earlier, _waiting.remove(earlier)!);
    }
    final words = _words(m['words']);
    final transcript = jsonString(m['transcript'])?.trim() ?? '';
    final endOfTurn = m['end_of_turn'] == true;
    final formatted = m['turn_is_formatted'] == true;
    final startMs = words.isEmpty ? 0 : words.first.startMs;
    final endMs = words.isEmpty ? 0 : words.last.endMs;
    if (endOfTurn) {
      final utterance = jsonString(m['utterance'])?.trim() ?? '';
      final segment = CloudSegment(
        id: '$order',
        text: transcript.isNotEmpty ? transcript : utterance,
        startMs: startMs,
        endMs: endMs,
        words: words,
        language: jsonString(m['language_code']),
      );
      if (formatted || !formatTurns) {
        _waiting.remove(order);
        _final(order, segment);
        return;
      }
      _waiting[order] = segment;
    }
    // Partial: every word so far, final or not.
    final partial = words.isEmpty ? transcript : words.map((w) => w.text).join(' ');
    if (partial.isEmpty || partial == _lastPartial) return;
    _lastPartial = partial;
    emit(CloudSegment(id: '$order', text: partial, startMs: startMs, endMs: endMs, isFinal: false));
  }

  void _final(int order, CloudSegment segment) {
    _finalTurns.add(order);
    _lastPartial = null;
    if (segment.text.isNotEmpty) emit(segment);
  }

  void _flushWaiting() {
    for (final order in _waiting.keys.toList()..sort()) {
      _final(order, _waiting.remove(order)!);
    }
  }

  @override
  void onClosed(int? code, String? reason) {
    if (finishing && (code == WebSocketStatus.normalClosure || code == null)) {
      _flushWaiting();
      ended();
    } else {
      _refuse(assemblyAiStreamError(code, reason, secrets));
    }
  }
}

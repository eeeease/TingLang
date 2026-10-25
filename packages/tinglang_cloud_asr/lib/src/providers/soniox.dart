import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../provider.dart';
import 'net_support.dart';

/// Soniox (soniox.com): the real-time WebSocket API with `stt-rt-v5` for
/// live captions and the async API with `stt-async-v5` for files (upload,
/// create a transcription, poll, fetch the transcript, then delete both).
/// One field: the API key. Endpoints, limits and error mapping:
/// `doc/soniox.md`.
final class SonioxProvider implements CloudAsrProvider {
  /// [apiBase] and [realtimeUrl] are for tests (a loopback server); they
  /// default to the public `https://api.soniox.com` and
  /// `wss://stt-rt.soniox.com/transcribe-websocket`. [now], [pollInterval],
  /// [keepAliveInterval] and [fileTimeout] make timing deterministic.
  SonioxProvider({
    Uri? apiBase,
    Uri? realtimeUrl,
    DateTime Function()? now,
    this.pollInterval = const Duration(seconds: 1),
    this.keepAliveInterval = const Duration(seconds: 10),
    this.fileTimeout = const Duration(hours: 2),
  }) : apiBase = apiBase ?? Uri.parse('https://api.soniox.com'),
       realtimeUrl = realtimeUrl ?? Uri.parse('wss://stt-rt.soniox.com/transcribe-websocket'),
       _now = now ?? DateTime.now {
    assert(const {'http', 'https'}.contains(this.apiBase.scheme));
    assert(const {'ws', 'wss'}.contains(this.realtimeUrl.scheme));
  }

  /// Real-time model (released June 2026; `stt-rt-v4` is an alias of it).
  static const realtimeModel = 'stt-rt-v5';

  /// Async model (released June 2026; `stt-async-v4` is an alias of it).
  static const asyncModel = 'stt-async-v5';

  final Uri apiBase, realtimeUrl;
  final Duration pollInterval, keepAliveInterval, fileTimeout;
  final DateTime Function() _now;

  /// The 60 languages Soniox lists (ISO 639-1; one model for all of them).
  static const languages = {
    'af', 'sq', 'ar', 'az', 'eu', 'be', 'bn', 'bs', 'bg', 'ca', 'zh', 'hr', 'cs', 'da', 'nl', //
    'en', 'et', 'fi', 'fr', 'gl', 'de', 'el', 'gu', 'he', 'hi', 'hu', 'id', 'it', 'ja', 'kn',
    'kk', 'ko', 'lv', 'lt', 'mk', 'ms', 'ml', 'mr', 'no', 'fa', 'pl', 'pt', 'pa', 'ro', 'ru',
    'sr', 'sk', 'sl', 'es', 'sw', 'sv', 'tl', 'ta', 'te', 'th', 'tr', 'uk', 'ur', 'vi', 'cy',
  };

  static final _info = CloudAsrInfo(
    id: 'soniox',
    fields: const [CloudField(CloudFieldKeys.apiKey)],
    languages: languages,
    consoleUrl: Uri.parse('https://console.soniox.com'),
    docsUrl: Uri.parse('https://soniox.com/docs'),
    // The service allows 300 minutes per file; the upload size limit is not
    // published (an older guide said 500 MB), so stay under both.
    maxFileMs: 240 * 60 * 1000,
    maxFileBytes: 480 * 1000 * 1000,
  );

  @override
  CloudAsrInfo get info => _info;

  @override
  List<String> hosts(CloudCredentials credentials) => [apiBase.host, realtimeUrl.host];

  /// The Soniox language hint for a BCP-47 tag (`en-GB` → `en`,
  /// `zh-Hans` → `zh`).
  static String languageHint(String tag) {
    final base = baseLanguage(tag);
    if (!languages.contains(base)) {
      throw const CloudAsrError(
        CloudAsrErrorKind.unsupportedLanguage,
        'Soniox does not recognise this language.',
      );
    }
    return base;
  }

  Uri _api(String path) => apiBase.replace(path: '${_trimSlash(apiBase.path)}$path');

  @override
  Future<void> verify(CloudCredentials credentials) async {
    final key = requireField(credentials, CloudFieldKeys.apiKey);
    // Listing models is free and needs a valid key.
    final reply = await httpSend(
      'GET',
      _api('/v1/models'),
      headers: _auth(key),
      timeout: const Duration(seconds: 30),
    );
    if (!reply.ok) throw _replyError(reply, key);
  }

  @override
  Future<CloudAsrStream> openStream(
    CloudCredentials credentials,
    CloudStreamOptions options,
  ) async {
    final key = requireField(credentials, CloudFieldKeys.apiKey);
    final hint = languageHint(options.language);
    final ws = await openWebSocket(
      realtimeUrl,
      headers: _auth(key),
      onHttpStatus: (status) => sonioxError(status, null, null, [key], realtime: true),
    );
    final stream = _SonioxStream(ws, [key], keepAliveInterval);
    // The key travels in the Authorization header only (the `api_key` field
    // in this message is deprecated).
    stream.sendText(
      jsonEncode({
        'model': realtimeModel,
        'audio_format': 'pcm_s16le',
        'sample_rate': options.sampleRate,
        'num_channels': 1,
        'language_hints': [hint],
        'enable_endpoint_detection': true,
      }),
    );
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
    final hint = languageHint(request.language);
    checkFileLimits(info, request);
    cancel?.check();
    String? fileId, transcriptionId;
    try {
      final form = MultipartBody()..file('file', 'tinglang.wav', 'audio/wav', request.wav);
      final upload = await httpSend(
        'POST',
        _api('/v1/files'),
        headers: {..._auth(key), HttpHeaders.contentTypeHeader: form.contentType},
        body: form.finish(),
        cancel: cancel,
        onSent: (sent, total) => onProgress?.call(0.5 * sent / total),
        timeout: uploadTimeout(request.wav.length),
      );
      if (!upload.ok) throw _replyError(upload, key);
      fileId = _id(upload);
      cancel?.check();

      final created = await httpSend(
        'POST',
        _api('/v1/transcriptions'),
        headers: {..._auth(key), HttpHeaders.contentTypeHeader: 'application/json'},
        body: [
          utf8.encode(
            jsonEncode({
              'model': asyncModel,
              'file_id': fileId,
              'language_hints': [hint],
            }),
          ),
        ],
        cancel: cancel,
        timeout: const Duration(seconds: 60),
      );
      if (!created.ok) throw _replyError(created, key);
      transcriptionId = _id(created);

      final deadline = _now().add(fileTimeout);
      while (true) {
        await pause(pollInterval, cancel);
        final poll = await httpSend(
          'GET',
          _api('/v1/transcriptions/$transcriptionId'),
          headers: _auth(key),
          cancel: cancel,
          timeout: const Duration(seconds: 60),
        );
        if (!poll.ok) throw _replyError(poll, key);
        final body =
            jsonMap(poll.json) ?? (throw protocolError('Soniox sent an unreadable status.'));
        final status = jsonString(body['status']);
        if (status == 'completed') break;
        if (status == 'error') {
          throw _jobError(jsonString(body['error_type']), jsonString(body['error_message']), key);
        }
        if (status != 'queued' && status != 'processing') {
          throw protocolError('Soniox sent an unknown transcription status.');
        }
        if (_now().isAfter(deadline)) {
          throw const CloudAsrError(
            CloudAsrErrorKind.server,
            'Soniox did not finish the transcription in time.',
          );
        }
      }
      onProgress?.call(0.9);

      final transcript = await httpSend(
        'GET',
        _api('/v1/transcriptions/$transcriptionId/transcript'),
        headers: _auth(key),
        cancel: cancel,
        timeout: const Duration(minutes: 5),
      );
      if (!transcript.ok) throw _replyError(transcript, key);
      final tokens = jsonList(jsonMap(transcript.json)?['tokens']);
      final lines = TokenLines();
      for (final t in tokens) {
        final tok = SonioxToken.fromJson(t);
        if (tok != null) lines.addFinal(tok);
      }
      lines.close();
      onProgress?.call(1);
      return [
        for (final (i, line) in lines.done.indexed)
          line.toSegment('$i', words: request.wordTimestamps),
      ];
    } finally {
      await _cleanUp(key, transcriptionId, fileId);
    }
  }

  /// Deletes what this call left on the service (privacy). Best effort: a
  /// transcription that is still processing (after a cancel) refuses
  /// deletion; deleting its file fails it, and Soniox removes it after 30
  /// days.
  Future<void> _cleanUp(String key, String? transcriptionId, String? fileId) async {
    Future<void> delete(String path) async {
      try {
        await httpSend(
          'DELETE',
          _api(path),
          headers: _auth(key),
          timeout: const Duration(seconds: 20),
        );
      } on CloudAsrError {
        // Nothing more to do; the doc says what remains and for how long.
      }
    }

    if (transcriptionId != null) await delete('/v1/transcriptions/$transcriptionId');
    if (fileId != null) await delete('/v1/files/$fileId');
  }

  static Map<String, String> _auth(String key) => {HttpHeaders.authorizationHeader: 'Bearer $key'};

  static String _id(HttpReply reply) =>
      jsonString(jsonMap(reply.json)?['id']) ?? (throw protocolError('Soniox sent no id.'));

  static CloudAsrError _replyError(HttpReply reply, String key) {
    final body = jsonMap(reply.json);
    return sonioxError(
      reply.statusCode,
      jsonString(body?['error_type']),
      jsonString(body?['message']) ?? jsonString(body?['error_message']),
      [key],
    );
  }

  static CloudAsrError _jobError(String? type, String? message, String key) {
    final text = scrub(message ?? 'Soniox could not transcribe the file.', [key]);
    final kind = switch (type) {
      'file_not_found' || 'invalid_request' => CloudAsrErrorKind.badRequest,
      'internal_error' || 'service_unavailable' || null => CloudAsrErrorKind.server,
      _ when mentions(message, ['too long', 'duration']) => CloudAsrErrorKind.audioTooLong,
      _ when mentions(message, ['language']) => CloudAsrErrorKind.unsupportedLanguage,
      _ => CloudAsrErrorKind.badRequest,
    };
    return CloudAsrError(kind, text, providerCode: safeCode(type));
  }
}

/// Maps a Soniox error (HTTP status or the `error_code` of a WebSocket
/// error message, with its `error_type`) to a [CloudAsrError]. [secrets]
/// are scrubbed from [message].
CloudAsrError sonioxError(
  int? status,
  String? type,
  String? message,
  List<String> secrets, {
  bool realtime = false,
}) {
  final text = scrub(message ?? 'Soniox refused the request.', secrets);
  final kind = switch (status) {
    400 when mentions(message, ['language']) => CloudAsrErrorKind.unsupportedLanguage,
    400 when mentions(message, ['too long', 'too much audio']) => CloudAsrErrorKind.audioTooLong,
    400 => CloudAsrErrorKind.badRequest,
    401 => CloudAsrErrorKind.unauthorized,
    402 => CloudAsrErrorKind.quotaExceeded,
    403 when type == 'temp_api_key_session_expired' => CloudAsrErrorKind.sessionEnded,
    403 => CloudAsrErrorKind.unauthorized,
    404 || 409 => CloudAsrErrorKind.badRequest,
    408 => CloudAsrErrorKind.network,
    413 when realtime || type == 'max_duration_reached' => CloudAsrErrorKind.sessionEnded,
    413 => CloudAsrErrorKind.audioTooLong,
    429 => CloudAsrErrorKind.rateLimited,
    final int s when s >= 500 => CloudAsrErrorKind.server,
    _ => CloudAsrErrorKind.protocol,
  };
  return CloudAsrError(
    kind,
    text,
    statusCode: realtime ? null : status,
    providerCode: safeCode(type),
  );
}

String _trimSlash(String path) => path.endsWith('/') ? path.substring(0, path.length - 1) : path;

/// One Soniox token (`text` may start with a space: a new word).
final class SonioxToken {
  const SonioxToken(this.text, this.startMs, this.endMs, {this.isFinal = true});
  final String text;
  final int startMs, endMs;
  final bool isFinal;

  /// `<end>` (endpoint detected) and `<fin>` (manual finalize) close a line.
  bool get isMarker => text == '<end>' || text == '<fin>';

  static SonioxToken? fromJson(Object? json) {
    final m = jsonMap(json);
    final text = jsonString(m?['text']);
    if (m == null || text == null) return null;
    final start = jsonInt(m['start_ms']) ?? 0;
    return SonioxToken(text, start, jsonInt(m['end_ms']) ?? start, isFinal: m['is_final'] != false);
  }
}

/// Groups Soniox tokens into caption lines: a line ends at `<end>`/`<fin>`,
/// at a pause of [maxGapMs] or more, or at a sentence end — `.`, `?`, `!`
/// followed by a token that starts a new word that is not lower-case and
/// not after a common abbreviation, or `。`, `？`, `！` at once.
final class TokenLines {
  TokenLines({this.maxGapMs = 2000});
  final int maxGapMs;

  /// Completed lines, in order.
  final done = <TokenLine>[];
  final _open = <SonioxToken>[];
  bool _sentenceEnded = false;

  /// Whether the open line has text.
  bool get hasOpen => _open.any((t) => t.text.trim().isNotEmpty);

  /// The open line's final tokens.
  List<SonioxToken> get open => List.unmodifiable(_open);

  /// Adds one final token; may complete [done] lines.
  void addFinal(SonioxToken token) {
    if (token.isMarker) {
      close();
      return;
    }
    if (_open.isNotEmpty) {
      final newSentence =
          (_startsWord(token.text) && !_startsLowerCase(token.text)) ||
          TokenLine._cjk.hasMatch(String.fromCharCodes(token.text.trimLeft().runes.take(1)));
      if ((_sentenceEnded && newSentence) || token.startMs - _open.last.endMs >= maxGapMs) {
        close();
      }
    }
    _sentenceEnded = false;
    _open.add(token);
    final trimmed = token.text.trimRight();
    if (trimmed.isEmpty) return;
    if (_cjkStops.contains(trimmed.substring(trimmed.length - 1))) {
      close();
    } else if (_endsSentence(trimmed) && !_endsAbbreviation()) {
      _sentenceEnded = true;
    }
  }

  /// Ends the open line (if it has text).
  void close() {
    _sentenceEnded = false;
    if (hasOpen) done.add(TokenLine(List.of(_open)));
    _open.clear();
  }

  static bool _startsWord(String text) => text.isNotEmpty && text.startsWith(_space);

  static bool _startsLowerCase(String text) {
    final t = text.trimLeft();
    if (t.isEmpty) return false;
    final c = t[0];
    return c != c.toUpperCase() && c == c.toLowerCase();
  }

  static bool _endsSentence(String text) {
    var t = text;
    while (t.isNotEmpty && _closers.contains(t[t.length - 1])) {
      t = t.substring(0, t.length - 1);
    }
    return t.isNotEmpty && _stops.contains(t[t.length - 1]);
  }

  /// Whether the word the open line ends with is an abbreviation (`Mr.`,
  /// `U.S.`, a single initial).
  bool _endsAbbreviation() {
    var i = _open.length - 1;
    while (i > 0 && !_startsWord(_open[i].text)) {
      i--;
    }
    final word = _open
        .sublist(i)
        .map((t) => t.text)
        .join()
        .trim()
        .toLowerCase()
        .replaceAll(_leadingNonLetters, '');
    final bare = word.replaceAll(RegExp(r'\.+$'), '');
    return _abbreviations.contains(bare) ||
        RegExp(r'^([a-z]\.)+[a-z]?\.?$').hasMatch(word) ||
        RegExp(r'^[a-z]$').hasMatch(bare);
  }

  static final _space = RegExp(r'^\s');
  static final _leadingNonLetters = RegExp(r'^[^\p{L}]+', unicode: true);
  static const _stops = {'.', '?', '!', '…'};
  static const _closers = {'"', "'", ')', ']', '”', '’', '»'};
  static const _cjkStops = {'。', '？', '！'};
  static const _abbreviations = {
    'mr', 'mrs', 'ms', 'dr', 'prof', 'sr', 'jr', 'st', 'vs', 'mt', 'no', 'fig', 'approx', //
    'e.g', 'i.e', 'etc', 'inc', 'ltd', 'co', 'jan', 'feb', 'mar', 'apr', 'jun', 'jul', 'aug',
    'sep', 'sept', 'oct', 'nov', 'dec',
  };
}

/// A caption line built from tokens.
final class TokenLine {
  TokenLine(this.tokens);
  final List<SonioxToken> tokens;

  String get text => tokens.where((t) => !t.isMarker).map((t) => t.text).join().trim();

  CloudSegment toSegment(String id, {bool isFinal = true, bool words = true}) {
    final real = tokens.where((t) => !t.isMarker && t.text.trim().isNotEmpty).toList();
    return CloudSegment(
      id: id,
      text: text,
      startMs: real.isEmpty ? 0 : real.first.startMs,
      endMs: real.isEmpty ? 0 : real.last.endMs,
      isFinal: isFinal,
      words: words ? wordsOf(real) : null,
    );
  }

  /// Joins sub-word tokens into words: a token starting with a space starts
  /// a word; Han and kana tokens are words of their own; punctuation joins
  /// the word before it.
  static List<CloudWord> wordsOf(List<SonioxToken> tokens) {
    final out = <({StringBuffer text, int start, int end, bool cjk})>[];
    for (final t in tokens) {
      final trimmed = t.text.trim();
      if (trimmed.isEmpty) continue;
      final punct = _punctuationOnly.hasMatch(trimmed);
      final cjk = _cjk.hasMatch(trimmed);
      final startsWord = out.isEmpty || t.text.startsWith(TokenLines._space) || cjk || out.last.cjk;
      if (out.isNotEmpty && (punct || !startsWord)) {
        final last = out.removeLast();
        last.text.write(trimmed);
        out.add((text: last.text, start: last.start, end: t.endMs, cjk: last.cjk && cjk));
      } else {
        out.add((text: StringBuffer(trimmed), start: t.startMs, end: t.endMs, cjk: cjk));
      }
    }
    return [for (final w in out) CloudWord(w.text.toString(), w.start, w.end)];
  }

  static final _punctuationOnly = RegExp(r'^[\p{P}\p{S}]+$', unicode: true);
  static final _cjk = RegExp(
    r'[\p{Script=Han}\p{Script=Hiragana}\p{Script=Katakana}]',
    unicode: true,
  );
}

final class _SonioxStream extends WsAsrStream {
  _SonioxStream(super.ws, super.secrets, Duration keepAlive) {
    _keepAlive = Timer.periodic(keepAlive, (_) {
      if (!_sentAudio && !finishing) sendText('{"type":"keepalive"}');
      _sentAudio = false;
    });
  }

  late final Timer _keepAlive;
  bool _sentAudio = false;
  final _lines = TokenLines();
  int _next = 0;
  String? _lastPartial;

  @override
  void sendAudio(Uint8List pcm16le) {
    _sentAudio = true;
    sendBytes(pcm16le);
  }

  /// An empty text frame ends the audio; Soniox finalizes everything, sends
  /// `finished`, then closes.
  @override
  void sendEnd() => sendText('');

  @override
  void onShutdown() => _keepAlive.cancel();

  @override
  void onText(String text) {
    final m = jsonMap(tryJson(text));
    if (m == null) {
      fail(protocolError('Soniox sent an unreadable message.'));
      return;
    }
    final code = jsonInt(m['error_code']);
    if (code != null) {
      fail(
        sonioxError(
          code,
          jsonString(m['error_type']),
          jsonString(m['error_message']),
          secrets,
          realtime: true,
        ),
      );
      return;
    }
    final pending = <SonioxToken>[];
    for (final raw in jsonList(m['tokens'])) {
      final tok = SonioxToken.fromJson(raw);
      if (tok == null) continue;
      if (tok.isFinal) {
        _lines.addFinal(tok);
        _emitDone();
      } else if (!tok.isMarker) {
        pending.add(tok);
      }
    }
    if (m['finished'] == true) {
      _lines.close();
      _emitDone();
      ended();
      return;
    }
    final partial = TokenLine([..._lines.open, ...pending]);
    final partialText = partial.text;
    if (partialText.isNotEmpty && partialText != _lastPartial) {
      _lastPartial = partialText;
      emit(partial.toSegment('$_next', isFinal: false, words: false));
    }
  }

  void _emitDone() {
    for (final line in _lines.done) {
      emit(line.toSegment('$_next'));
      _next++;
      _lastPartial = null;
    }
    _lines.done.clear();
  }

  @override
  void onClosed(int? code, String? reason) {
    if (finishing && code == WebSocketStatus.normalClosure) {
      _lines.close();
      _emitDone();
      ended();
    } else if (code == WebSocketStatus.goingAway) {
      fail(const CloudAsrError(CloudAsrErrorKind.sessionEnded, 'Soniox closed the stream.'));
    } else {
      fail(networkError);
    }
  }
}

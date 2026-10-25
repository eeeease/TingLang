import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:meta/meta.dart';

import '../provider.dart';
import 'cn_support.dart';

/// iFlytek Open Platform (讯飞开放平台), the large-model products that
/// replaced the standard ones on xfyun.cn. Live: 实时语音转写大模型 over
/// WebSocket (`wss://office-api-ast-dx.iflyaisol.com/ast/communicate/v1`,
/// signed query). Files: 录音文件转写大模型 (`https://office-api-ist-dx.iflyaisol.com`:
/// `/v2/upload` the WAV, poll `/v2/getResult`). Endpoints, limits and error
/// codes: `doc/xfyun.md`.
///
/// Credentials, as the console's 服务接口认证信息 shows them:
/// [CloudFieldKeys.appId] = APPID, [CloudFieldKeys.apiKey] = APIKey (sent as
/// `accessKeyId`), [CloudFieldKeys.apiSecret] = APISecret (the HMAC key,
/// `accessKeySecret`). Both products use the same three values.
final class XfyunAsr implements CloudAsrProvider {
  /// [liveBaseUrl] / [fileBaseUrl] replace the two service bases (tests pass
  /// loopback `ws://` / `http://`). [now] and [random] make signatures
  /// deterministic; [pollInterval] is the first `getResult` interval (it
  /// grows, to stay under the documented 100 queries per order).
  XfyunAsr({
    Uri? liveBaseUrl,
    Uri? fileBaseUrl,
    DateTime Function()? now,
    Random? random,
    this._pollInterval = const Duration(seconds: 5),
    this._connectTimeout = const Duration(seconds: 15),
  }) : _liveBase = checkedBase(liveBaseUrl ?? Uri.parse('wss://$liveHost'), socket: true),
       _fileBase = checkedBase(fileBaseUrl ?? Uri.parse('https://$fileHost'), socket: false),
       _now = now ?? DateTime.now,
       _randomOverride = random;

  static const liveHost = 'office-api-ast-dx.iflyaisol.com';
  static const fileHost = 'office-api-ist-dx.iflyaisol.com';
  static const _service = 'iFlytek';

  /// 40 ms of 16 kHz 16-bit mono PCM (documented: 1280 bytes every 40 ms).
  static const frameBytes = 1280;

  /// Polls per order before giving up (the service allows 100).
  static const maxPolls = 96;

  final Uri _liveBase, _fileBase;
  final DateTime Function() _now;
  final Random? _randomOverride;
  late final Random _random = _randomOverride ?? Random.secure();
  final Duration _pollInterval, _connectTimeout;

  static final _info = CloudAsrInfo(
    id: 'xfyun',
    fields: const [
      CloudField(CloudFieldKeys.appId, kind: CloudFieldKind.text),
      CloudField(CloudFieldKeys.apiKey),
      CloudField(CloudFieldKeys.apiSecret),
    ],
    // zh and en need nothing extra (autodialect); ja, ko, es, fr and de use
    // the 37-language mode (autominor), which iFlytek enables per account on
    // request (a work order) — without it the service answers with an
    // unsupported-language error.
    languages: const {'en', 'zh', 'ja', 'ko', 'es', 'fr', 'de'},
    consoleUrl: Uri.parse('https://console.xfyun.cn/services/new_rta'),
    docsUrl: Uri.parse('https://www.xfyun.cn/doc/spark/asr_llm/rtasr_llm.html'),
    // 录音文件转写大模型: at most 5 hours and 500 MB per file.
    maxFileMs: 5 * 60 * 60 * 1000,
    maxFileBytes: 500 * 1000 * 1000,
  );

  @override
  CloudAsrInfo get info => _info;

  @override
  List<String> hosts(CloudCredentials credentials) => {_liveBase.host, _fileBase.host}.toList();

  /// The language mode for a BCP-47 tag: `autodialect` (Chinese, English and
  /// Chinese dialects) or `autominor` with the target language code.
  static ({String mode, String? code}) languageFor(String language) =>
      switch (baseLanguage(language)) {
        'zh' || 'en' => (mode: 'autodialect', code: null),
        final c && ('ja' || 'ko' || 'es' || 'fr' || 'de') => (mode: 'autominor', code: c),
        _ => throw CloudAsrError(
          CloudAsrErrorKind.unsupportedLanguage,
          'iFlytek has no language mode for $language here.',
        ),
      };

  /// The query both products sign and send: parameters sorted by name,
  /// empty values left out, `key=value` percent-encoded, joined with `&`.
  @visibleForTesting
  static String baseString(Map<String, String> params) {
    final keys = [
      for (final e in params.entries)
        if (e.value.isNotEmpty) e.key,
    ]..sort();
    return keys.map((k) => '${percentEncode(k)}=${percentEncode(params[k]!)}').join('&');
  }

  /// Base64(HMAC-SHA1(APISecret, [baseString])).
  @visibleForTesting
  static String sign(Map<String, String> params, String apiSecret) =>
      hmacSha1Base64(apiSecret, baseString(params));

  /// `yyyy-MM-dd'T'HH:mm:ss+0800` (Beijing time; the services take any
  /// offset written this way).
  @visibleForTesting
  static String beijingTime(DateTime t) {
    final b = t.toUtc().add(const Duration(hours: 8));
    String two(int n) => n.toString().padLeft(2, '0');
    return '${b.year.toString().padLeft(4, '0')}-${two(b.month)}-${two(b.day)}'
        'T${two(b.hour)}:${two(b.minute)}:${two(b.second)}+0800';
  }

  ({String appId, String key, String secret}) _keys(CloudCredentials c) => (
    appId: requireField(c, CloudFieldKeys.appId),
    key: requireField(c, CloudFieldKeys.apiKey),
    secret: requireField(c, CloudFieldKeys.apiSecret),
  );

  /// The signed live URL for one session.
  @visibleForTesting
  Uri liveUri(CloudCredentials credentials, String language) {
    final keys = _keys(credentials);
    final lang = languageFor(language);
    final params = <String, String>{
      'appId': keys.appId,
      'accessKeyId': keys.key,
      'utc': beijingTime(_now()),
      // A fresh uuid per session: the service rejects a repeated signature.
      'uuid': uuidV4(_random).replaceAll('-', ''),
      'lang': lang.mode,
      'recognized_language': ?lang.code,
      'audio_encode': 'pcm_s16le',
      'samplerate': '16000',
    };
    final query = '${baseString(params)}&signature=${percentEncode(sign(params, keys.secret))}';
    return Uri.parse('${_liveBase.scheme}://${hostWithPort(_liveBase)}/ast/communicate/v1?$query');
  }

  @override
  Future<void> verify(CloudCredentials credentials) async {
    // The handshake checks APPID, APIKey, APISecret and the live service; no
    // audio is sent. (Ending a session with no audio is an error to the
    // service, so the socket is just closed.)
    final stream = await _open(credentials, 'zh');
    await stream.cancel();
  }

  @override
  Future<CloudAsrStream> openStream(
    CloudCredentials credentials,
    CloudStreamOptions options,
  ) async {
    if (options.sampleRate != 16000) {
      throw const CloudAsrError(CloudAsrErrorKind.badRequest, 'iFlytek needs 16 kHz audio here.');
    }
    return _open(credentials, options.language);
  }

  Future<_XfyunStream> _open(CloudCredentials credentials, String language) async {
    final uri = liveUri(credentials, language);
    final socket = await connectSocket(
      _service,
      uri,
      timeout: _connectTimeout,
      onRejected: (status, body) => _httpError(status, body, credentials, live: true),
    );
    final stream = _XfyunStream(socket, credentials);
    try {
      await stream.ready.timeout(_connectTimeout);
    } on TimeoutException {
      await stream.cancel();
      throw const CloudAsrError(
        CloudAsrErrorKind.network,
        'iFlytek did not start the session in time.',
      );
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
    cancel?.check();
    if (request.wav.length > _info.maxFileBytes! || request.durationMs > _info.maxFileMs!) {
      throw const CloudAsrError(
        CloudAsrErrorKind.audioTooLong,
        'iFlytek takes at most 500 MB or 5 hours per file.',
      );
    }
    final keys = _keys(credentials);
    final lang = languageFor(request.language);
    // One random string for the upload and every query of its order.
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final nonce = String.fromCharCodes(
      List.generate(16, (_) => chars.codeUnitAt(_random.nextInt(chars.length))),
    );
    final upload = <String, String>{
      'appId': keys.appId,
      'accessKeyId': keys.key,
      'dateTime': beijingTime(_now()),
      'signatureRandom': nonce,
      'fileSize': '${request.wav.length}',
      'fileName': 'tinglang.wav',
      'language': lang.mode,
      'durationCheckDisable': 'true',
    };
    final authority = '${_fileBase.scheme}://${hostWithPort(_fileBase)}';
    final uploaded = await httpCall(
      _service,
      'POST',
      Uri.parse('$authority/v2/upload?${baseString(upload)}'),
      headers: {
        'signature': sign(upload, keys.secret),
        HttpHeaders.contentTypeHeader: 'application/octet-stream',
      },
      body: [request.wav],
      onUpload: onProgress == null ? null : (f) => onProgress(0.5 * f),
      cancel: cancel,
      connectTimeout: _connectTimeout,
      responseTimeout: const Duration(minutes: 5),
    );
    final content = _content(uploaded, credentials);
    final orderId = jsonString(content['orderId']);
    if (orderId == null || orderId.isEmpty) {
      throw const CloudAsrError(CloudAsrErrorKind.protocol, 'iFlytek did not return an order id.');
    }
    final estimateMs = jsonInt(content['taskEstimateTime']) ?? 0;
    onProgress?.call(0.5);
    final started = DateTime.now();
    for (var poll = 0; poll < maxPolls; poll++) {
      await _sleep(_pollInterval * (poll < 6 ? 1 : (poll < 18 ? 2 : 9)), cancel);
      final query = <String, String>{
        'accessKeyId': keys.key,
        'dateTime': beijingTime(_now()),
        'signatureRandom': nonce,
        'orderId': orderId,
        'resultType': 'transfer',
      };
      final reply = await httpCall(
        _service,
        'POST',
        Uri.parse('$authority/v2/getResult?${baseString(query)}'),
        headers: {
          'signature': sign(query, keys.secret),
          HttpHeaders.contentTypeHeader: 'application/json',
        },
        body: [utf8.encode('{}')],
        cancel: cancel,
        connectTimeout: _connectTimeout,
      );
      final result = _content(reply, credentials, pending: true);
      if (result.isEmpty) continue; // 100013: order not finished.
      final order = jsonMap(result['orderInfo']) ?? const {};
      final status = jsonInt(order['status']);
      final failType = jsonInt(order['failType']) ?? 0;
      if (status == -1 || failType != 0) {
        if (failType == 6) return const []; // A silent file: nothing to show.
        throw _failTypeError(failType);
      }
      if (status == 4) {
        final segments = parseOrderResult(result['orderResult'], words: request.wordTimestamps);
        onProgress?.call(1);
        return segments;
      }
      if (onProgress != null && estimateMs > 0) {
        final elapsed = DateTime.now().difference(started).inMilliseconds;
        onProgress(0.5 + 0.45 * min(1, elapsed / estimateMs));
      }
    }
    throw const CloudAsrError(CloudAsrErrorKind.server, 'iFlytek did not finish the file in time.');
  }

  /// Sentences from `orderResult`: `lattice[].json_1best` (JSON strings in
  /// practice) → `st` with `bg`/`ed` in ms and words whose `wb`/`we` are
  /// 10 ms frames from `bg`.
  @visibleForTesting
  static List<CloudSegment> parseOrderResult(Object? orderResult, {bool words = true}) {
    final root = jsonMapOrString(orderResult);
    final segments = <CloudSegment>[];
    for (final item in jsonList(root?['lattice'])) {
      final st = jsonMap(jsonMapOrString(jsonMap(item)?['json_1best'])?['st']);
      if (st == null) continue;
      final sentence = _Sentence.parse(st);
      if (sentence.text.isEmpty) continue;
      segments.add(
        CloudSegment(
          id: '${segments.length}',
          text: sentence.text,
          startMs: sentence.startMs,
          endMs: sentence.endMs,
          words: words ? sentence.words : null,
        ),
      );
    }
    return segments;
  }

  /// `content` of a successful file-API reply. With [pending], "order not
  /// finished" (100013) yields an empty map instead of an error.
  Map<String, Object?> _content(
    HttpReply reply,
    CloudCredentials credentials, {
    bool pending = false,
  }) {
    final json = jsonMap(tryJson(reply.body));
    final code = jsonString(json?['code']);
    if (json == null || (!reply.ok && code == null)) {
      throw _httpError(reply.statusCode, reply.body, credentials, live: false);
    }
    if (code != null && code != '000000' && code != '0') {
      if (pending && code == '100013') return const {};
      throw fileCodeError(code, jsonString(json['descInfo']), credentials);
    }
    return jsonMap(json['content']) ?? const {};
  }

  static CloudAsrError _httpError(
    int status,
    String body,
    CloudCredentials credentials, {
    required bool live,
  }) {
    final json = jsonMap(tryJson(body));
    final code = jsonString(json?['code']);
    if (code != null && code != '0' && code != '000000') {
      final message =
          jsonString(json?['descInfo']) ??
          jsonString(json?['desc']) ??
          jsonString(json?['message']);
      final e = live
          ? liveCodeError(code, message, credentials)
          : fileCodeError(code, message, credentials);
      return CloudAsrError(e.kind, e.message, statusCode: status, providerCode: e.providerCode);
    }
    return CloudAsrError(
      kindForHttpStatus(status),
      'iFlytek refused the request (HTTP $status).',
      statusCode: status,
    );
  }

  static const _clock = "iFlytek rejected the request time; check this Mac's date and time.";

  /// A 实时语音转写大模型 error code (also the older 实时语音转写 codes, which
  /// the same accounts can see) as a [CloudAsrError].
  @visibleForTesting
  static CloudAsrError liveCodeError(String code, String? message, CloudCredentials credentials) {
    final (kind, fallback) = switch (code) {
      '35001' ||
      '35004' ||
      '35005' ||
      '35010' ||
      '35017' ||
      '100002' ||
      '100013' ||
      '100016' ||
      '100020' ||
      '10105' => (
        CloudAsrErrorKind.unauthorized,
        'iFlytek rejected the APPID, APIKey or APISecret.',
      ),
      '35002' || '35022' || '35031' || '10110' => (
        CloudAsrErrorKind.quotaExceeded,
        'iFlytek real-time transcription is not activated or its quota is used up.',
      ),
      '35006' ||
      '37002' ||
      '10800' => (CloudAsrErrorKind.rateLimited, 'Too many concurrent iFlytek sessions.'),
      '100001' => (CloudAsrErrorKind.rateLimited, 'Audio was sent faster than real time.'),
      '35014' || '100012' || '35030' => (CloudAsrErrorKind.badRequest, _clock),
      '35020' || '100018' || '100019' => (
        CloudAsrErrorKind.unsupportedLanguage,
        'This language needs iFlytek multilingual mode (autominor), enabled on request.',
      ),
      '37005' => (CloudAsrErrorKind.sessionEnded, 'No audio for 15 seconds; the session ended.'),
      '37007' => (CloudAsrErrorKind.sessionEnded, 'The 8-hour session limit was reached.'),
      '37010' ||
      '37011' ||
      '37012' => (CloudAsrErrorKind.protocol, 'iFlytek did not understand a message.'),
      '10202' ||
      '10204' ||
      '10205' => (CloudAsrErrorKind.network, 'The connection to iFlytek failed.'),
      '35013' ||
      '35015' ||
      '35016' ||
      '35019' ||
      '35021' ||
      '37000' ||
      '100015' ||
      '100021' ||
      '10106' ||
      '10107' => (CloudAsrErrorKind.badRequest, 'iFlytek rejected a parameter.'),
      _ => (CloudAsrErrorKind.server, 'iFlytek failed (code $code).'),
    };
    return serviceError(kind, message, credentials, fallback: fallback, providerCode: code);
  }

  /// A 录音文件转写大模型 error code as a [CloudAsrError].
  @visibleForTesting
  static CloudAsrError fileCodeError(String code, String? message, CloudCredentials credentials) {
    final (kind, fallback) = switch (code) {
      '000002' ||
      '100009' => (CloudAsrErrorKind.unauthorized, 'iFlytek rejected the APIKey or APISecret.'),
      '100007' => (
        CloudAsrErrorKind.quotaExceeded,
        'iFlytek file transcription is not activated for this app, or its quota is used up.',
      ),
      '100008' => (CloudAsrErrorKind.badRequest, _clock),
      '100012' => (CloudAsrErrorKind.rateLimited, 'Too many iFlytek requests; try again later.'),
      '100020' => (
        CloudAsrErrorKind.unsupportedLanguage,
        'This language needs iFlytek multilingual mode (autominor), enabled on request.',
      ),
      '999999' ||
      '100002' ||
      '100004' ||
      '100006' ||
      '100001' ||
      '100037' ||
      '100039' => (CloudAsrErrorKind.server, 'iFlytek could not process the order.'),
      _ => (CloudAsrErrorKind.badRequest, 'iFlytek rejected the request (code $code).'),
    };
    return serviceError(kind, message, credentials, fallback: fallback, providerCode: code);
  }

  static CloudAsrError _failTypeError(int failType) {
    final (kind, message) = switch (failType) {
      2 => (CloudAsrErrorKind.badRequest, 'iFlytek could not decode the audio.'),
      4 => (CloudAsrErrorKind.audioTooLong, 'The file is longer than iFlytek accepts (5 hours).'),
      5 => (CloudAsrErrorKind.badRequest, 'iFlytek rejected the audio duration.'),
      _ => (CloudAsrErrorKind.server, 'iFlytek could not transcribe the file.'),
    };
    return CloudAsrError(kind, message, providerCode: 'failType $failType');
  }

  static Future<void> _sleep(Duration d, CloudCancelToken? cancel) async {
    cancel?.check();
    await (cancel == null
        ? Future<void>.delayed(d)
        : Future.any([Future<void>.delayed(d), cancel.whenCancelled]));
    cancel?.check();
  }
}

/// One recognised sentence: `st.bg`/`st.ed` in ms; tokens `rt[].ws[].cw[0]`
/// with `wp` n (word), s (filler), p (punctuation) or g (paragraph mark) and
/// `wb`/`we` as 10 ms frames from `bg`.
final class _Sentence {
  _Sentence(this.text, this.startMs, this.endMs, this.words);
  final String text;
  final int startMs, endMs;
  final List<CloudWord>? words;

  static final _spaced = RegExp(
    r'[\p{Script=Latin}\p{Script=Cyrillic}\p{Script=Hangul}\p{Script=Greek}\p{N}]',
    unicode: true,
  );

  static _Sentence parse(Map<String, Object?> st) {
    final bg = jsonInt(st['bg']) ?? 0;
    final ed = jsonInt(st['ed']) ?? 0;
    final text = StringBuffer();
    final words = <CloudWord>[];
    var timed = true;
    var last = '';
    for (final r in jsonList(st['rt'])) {
      for (final item in jsonList(jsonMap(r)?['ws'])) {
        final ws = jsonMap(item);
        final cw = jsonMap(jsonList(ws?['cw']).firstOrNull);
        final w = jsonString(cw?['w']) ?? '';
        final wp = jsonString(cw?['wp']) ?? 'n';
        if (wp == 'g' || w.isEmpty) continue;
        final token = w.trim();
        if (token.isEmpty) continue;
        // A space between words of spaced scripts (Latin, Hangul, …) and
        // after ASCII sentence punctuation before one; none around CJK.
        if (wp != 'p' &&
            last.isNotEmpty &&
            _spaced.hasMatch(token[0]) &&
            (_spaced.hasMatch(last[last.length - 1]) ||
                ',.;:!?)'.contains(last[last.length - 1]))) {
          text.write(' ');
        }
        text.write(token);
        last = token;
        if (wp == 'p') continue;
        final wb = jsonInt(ws?['wb'] ?? cw?['wb']);
        final we = jsonInt(ws?['we'] ?? cw?['we']);
        if (wb == null || we == null || we <= wb) {
          timed = false;
        } else {
          words.add(CloudWord(token, bg + wb * 10, bg + we * 10));
        }
      }
    }
    final lastEnd = words.isEmpty ? bg : words.last.endMs;
    final end = ed > bg ? ed : max(bg, lastEnd);
    return _Sentence(text.toString(), bg, end, timed ? wordsInside(words, bg, end) : null);
  }
}

/// One 实时语音转写大模型 session. Text frames are JSON: the handshake
/// (`msg_type` `action`, `data.action` `started` with `data.sessionId`),
/// results (`msg_type` `result`, `res_type` `asr`, `data.cn.st` with `type`
/// 0 final / 1 partial, `data.ls` true on the last) and errors (`action`
/// `error` or a non-zero `code`; `res_type` `frc` with `normal` false). The
/// documented shapes vary between pages, so both the top-level and the
/// `data` forms are read.
final class _XfyunStream extends SocketAsrStream {
  _XfyunStream(super.socket, this._credentials) : super(frameBytes: XfyunAsr.frameBytes);

  final CloudCredentials _credentials;
  String? _sessionId;
  var _sentence = 0;

  @override
  String get service => XfyunAsr._service;

  static bool _isError(String? code) =>
      code != null && code.isNotEmpty && code != '0' && code != '000000';

  @override
  void handleText(String text) {
    final message = jsonMap(tryJson(text));
    if (message == null) throw const FormatException('not a JSON object');
    final msgType = jsonString(message['msg_type']);
    final data = jsonMapOrString(message['data']);
    final action = jsonString(data?['action']) ?? jsonString(message['action']);
    final code = jsonString(data?['code']) ?? jsonString(message['code']);
    if (action == 'error' || _isError(code)) {
      final c = code ?? '';
      if (c == '37009' && ending) return complete(); // the engine's last frame was sent
      throw XfyunAsr.liveCodeError(
        c,
        jsonString(data?['desc']) ?? jsonString(data?['message']) ?? jsonString(message['desc']),
        _credentials,
      );
    }
    if (msgType == 'result' && jsonString(message['res_type']) == 'frc') {
      if (data?['normal'] == false) {
        throw serviceError(
          CloudAsrErrorKind.server,
          jsonString(data?['desc']),
          _credentials,
          fallback: 'iFlytek reported a failure.',
        );
      }
      return;
    }
    if (action == 'started') {
      _sessionId = jsonString(data?['sessionId']) ?? jsonString(message['sid']);
      markReady();
      return;
    }
    if (action == 'end') {
      if (ending) {
        complete();
      } else {
        fail(const CloudAsrError(CloudAsrErrorKind.sessionEnded, 'iFlytek ended the session.'));
      }
      return;
    }
    final isResult =
        (msgType == 'result' && jsonString(message['res_type']) == 'asr') || action == 'result';
    if (!isResult || data == null) return;
    markReady();
    final st = jsonMap(jsonMap(data['cn'])?['st']);
    if (st != null) {
      final sentence = _Sentence.parse(st);
      final isFinal = jsonString(st['type']) == '0';
      emit(
        CloudSegment(
          id: '$_sentence',
          text: sentence.text,
          startMs: sentence.startMs,
          endMs: sentence.endMs,
          isFinal: isFinal,
          words: isFinal ? sentence.words : null,
        ),
      );
      if (isFinal) _sentence++;
    }
    if (jsonBool(data['ls'])) complete();
  }

  @override
  void sendEnd() => send(jsonEncode({'end': true, 'sessionId': ?_sessionId}));
}

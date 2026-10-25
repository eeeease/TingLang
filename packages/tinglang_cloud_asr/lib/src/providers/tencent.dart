import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:meta/meta.dart';

import '../provider.dart';
import 'cn_support.dart';

/// Tencent Cloud ASR (腾讯云语音识别). Live: 实时语音识别 over WebSocket
/// (`wss://asr.cloud.tencent.com/asr/v2/<AppID>`, URL signed with HMAC-SHA1).
/// Files: 录音文件识别极速版, one synchronous signed POST of the WAV
/// (`https://asr.cloud.tencent.com/asr/flash/v1/<AppID>`). Endpoints, limits
/// and error codes: `doc/tencent.md`.
///
/// Credentials: [CloudFieldKeys.appId] (the account's numeric APPID),
/// [CloudFieldKeys.secretId] and [CloudFieldKeys.secretKey] (an API key pair
/// from 访问管理 › API 密钥管理).
final class TencentCloudAsr implements CloudAsrProvider {
  /// [liveBaseUrl] / [fileBaseUrl] replace `wss://asr.cloud.tencent.com` and
  /// `https://asr.cloud.tencent.com` (tests pass `ws://` / `http://`
  /// loopback URLs). [now] and [random] make signatures and ids
  /// deterministic in tests.
  TencentCloudAsr({
    Uri? liveBaseUrl,
    Uri? fileBaseUrl,
    DateTime Function()? now,
    Random? random,
    this._connectTimeout = const Duration(seconds: 15),
    this._fileTimeout = const Duration(minutes: 10),
  }) : _liveBase = checkedBase(liveBaseUrl ?? Uri.parse('wss://$host'), socket: true),
       _fileBase = checkedBase(fileBaseUrl ?? Uri.parse('https://$host'), socket: false),
       _now = now ?? DateTime.now,
       _randomOverride = random;

  /// The service host for both products.
  static const host = 'asr.cloud.tencent.com';

  static const _service = 'Tencent Cloud';

  /// 200 ms of 16 kHz 16-bit mono PCM: the documented frame (send 200 ms of
  /// audio per 200 ms; faster than real time fails with 4000).
  static const frameBytes = 6400;

  final Uri _liveBase, _fileBase;
  final DateTime Function() _now;
  final Random? _randomOverride;
  late final Random _random = _randomOverride ?? Random.secure();
  final Duration _connectTimeout, _fileTimeout;

  static final _info = CloudAsrInfo(
    id: 'tencent',
    fields: const [
      CloudField(CloudFieldKeys.appId, kind: CloudFieldKind.text),
      CloudField(CloudFieldKeys.secretId),
      CloudField(CloudFieldKeys.secretKey),
    ],
    languages: const {'en', 'zh', 'ja', 'ko', 'es', 'fr', 'de'},
    consoleUrl: Uri.parse('https://console.cloud.tencent.com/cam/capi'),
    docsUrl: Uri.parse('https://cloud.tencent.com/document/product/1093/48982'),
    // 录音文件识别极速版: at most 100 MB and 2 hours per request.
    maxFileMs: 2 * 60 * 60 * 1000,
    maxFileBytes: 100 * 1000 * 1000,
  );

  @override
  CloudAsrInfo get info => _info;

  @override
  List<String> hosts(CloudCredentials credentials) => {_liveBase.host, _fileBase.host}.toList();

  /// The engine for a BCP-47 tag: both products take the same 16 kHz
  /// general-engine codes (`engine_model_type` live, `engine_type` files).
  static String engineFor(String language) => switch (baseLanguage(language)) {
    'en' => '16k_en',
    'zh' => '16k_zh',
    'ja' => '16k_ja',
    'ko' => '16k_ko',
    'es' => '16k_es',
    'fr' => '16k_fr',
    'de' => '16k_de',
    _ => throw CloudAsrError(
      CloudAsrErrorKind.unsupportedLanguage,
      'Tencent Cloud has no engine for $language here.',
    ),
  };

  /// Live engines that accept `word_info` (per the 实时语音识别 parameter table).
  static const _liveWordEngines = {'16k_en', '16k_zh', '16k_ja'};

  /// The live signature: Base64(HMAC-SHA1(SecretKey, `<host><path>?<k=v&…>`))
  /// over every parameter but `signature`, sorted by name, values as sent.
  @visibleForTesting
  static String signLive(String hostAndPath, Map<String, String> params, String secretKey) =>
      hmacSha1Base64(secretKey, '$hostAndPath?${_sorted(params)}');

  /// The flash signature: as [signLive] with `POST` in front of the host
  /// (`POSTasr.cloud.tencent.com/asr/flash/v1/<AppID>?…`); sent as the
  /// `Authorization` header.
  @visibleForTesting
  static String signFlash(String hostAndPath, Map<String, String> params, String secretKey) =>
      hmacSha1Base64(secretKey, 'POST$hostAndPath?${_sorted(params)}');

  static String _sorted(Map<String, String> params) =>
      (params.keys.toList()..sort()).map((k) => '$k=${params[k]}').join('&');

  /// The signed live URL for one session.
  @visibleForTesting
  Uri liveUri(CloudCredentials credentials, String engine, String voiceId) {
    final appId = _appId(credentials);
    final secretId = requireField(credentials, CloudFieldKeys.secretId);
    final secretKey = requireField(credentials, CloudFieldKeys.secretKey);
    final ts = _now().millisecondsSinceEpoch ~/ 1000;
    final params = <String, String>{
      'secretid': secretId,
      'timestamp': '$ts',
      // Must be after timestamp and less than 90 days later.
      'expired': '${ts + 24 * 60 * 60}',
      'nonce': '${_random.nextInt(0x7fffffff) + 1}',
      'engine_model_type': engine,
      'voice_id': voiceId,
      'voice_format': '1', // PCM
      'needvad': '1',
      if (_liveWordEngines.contains(engine)) 'word_info': '1',
    };
    final path = '/asr/v2/$appId';
    final authority = hostWithPort(_liveBase);
    final signature = signLive('$authority$path', params, secretKey);
    final query = [
      for (final k in params.keys.toList()..sort()) '$k=${percentEncode(params[k]!)}',
      'signature=${percentEncode(signature)}',
    ].join('&');
    return Uri.parse('${_liveBase.scheme}://$authority$path?$query');
  }

  @override
  Future<void> verify(CloudCredentials credentials) async {
    // The handshake checks AppID, key pair and activation; no audio is sent,
    // so nothing is billed.
    final stream = await _open(credentials, '16k_en');
    await stream.cancel();
  }

  @override
  Future<CloudAsrStream> openStream(
    CloudCredentials credentials,
    CloudStreamOptions options,
  ) async {
    if (options.sampleRate != 16000) {
      throw const CloudAsrError(CloudAsrErrorKind.badRequest, 'Tencent Cloud needs 16 kHz audio.');
    }
    return _open(credentials, engineFor(options.language));
  }

  Future<_TencentStream> _open(CloudCredentials credentials, String engine) async {
    final uri = liveUri(credentials, engine, uuidV4(_random));
    final socket = await connectSocket(
      _service,
      uri,
      timeout: _connectTimeout,
      onRejected: (status, body) => _replyError(status, body, credentials),
    );
    final stream = _TencentStream(socket, credentials);
    try {
      await stream.ready.timeout(_connectTimeout);
    } on TimeoutException {
      await stream.cancel();
      throw const CloudAsrError(
        CloudAsrErrorKind.network,
        'Tencent Cloud did not start the session in time.',
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
        'Tencent Cloud takes at most 100 MB or 2 hours per file.',
      );
    }
    final engine = engineFor(request.language);
    final appId = _appId(credentials);
    final secretId = requireField(credentials, CloudFieldKeys.secretId);
    final secretKey = requireField(credentials, CloudFieldKeys.secretKey);
    final params = <String, String>{
      'secretid': secretId,
      'engine_type': engine,
      'voice_format': 'wav',
      'timestamp': '${_now().millisecondsSinceEpoch ~/ 1000}',
      'word_info': request.wordTimestamps ? '1' : '0',
      'first_channel_only': '1',
      'speaker_diarization': '0',
      'filter_dirty': '0',
      'filter_modal': '0',
      'filter_punc': '0',
      'convert_num_mode': '1',
    };
    final path = '/asr/flash/v1/$appId';
    final authority = hostWithPort(_fileBase);
    final signature = signFlash('$authority$path', params, secretKey);
    final query = [for (final k in params.keys.toList()..sort()) '$k=${percentEncode(params[k]!)}']
        .join('&');
    final reply = await httpCall(
      _service,
      'POST',
      Uri.parse('${_fileBase.scheme}://$authority$path?$query'),
      headers: {
        HttpHeaders.authorizationHeader: signature,
        HttpHeaders.contentTypeHeader: 'application/octet-stream',
      },
      body: [request.wav],
      onUpload: onProgress == null ? null : (f) => onProgress(0.5 * f),
      cancel: cancel,
      connectTimeout: _connectTimeout,
      responseTimeout: _fileTimeout,
    );
    cancel?.check();
    final json = jsonMap(tryJson(reply.body));
    if (json == null) {
      if (!reply.ok) throw _replyError(reply.statusCode, reply.body, credentials);
      throw const CloudAsrError(
        CloudAsrErrorKind.protocol,
        'Tencent Cloud sent an unreadable reply.',
      );
    }
    final code = jsonInt(json['code']) ?? (reply.ok ? 0 : -1);
    if (code != 0 || !reply.ok) {
      throw code > 0
          ? codeError(code, jsonString(json['message']), credentials)
          : _replyError(reply.statusCode, reply.body, credentials);
    }
    final channel = jsonMap(jsonList(json['flash_result']).firstOrNull);
    final segments = <CloudSegment>[];
    for (final s in jsonList(channel?['sentence_list'])) {
      final sentence = jsonMap(s);
      if (sentence == null) continue;
      final text = (jsonString(sentence['text']) ?? '').trim();
      if (text.isEmpty) continue;
      final start = jsonInt(sentence['start_time']) ?? 0;
      final end = max(start, jsonInt(sentence['end_time']) ?? start);
      segments.add(
        CloudSegment(
          id: '${segments.length}',
          text: text,
          startMs: start,
          endMs: end,
          words: request.wordTimestamps ? _words(sentence['word_list'], start, end) : null,
        ),
      );
    }
    onProgress?.call(1);
    return segments;
  }

  static String _appId(CloudCredentials credentials) {
    final appId = requireField(credentials, CloudFieldKeys.appId);
    if (!RegExp(r'^\d+$').hasMatch(appId)) {
      throw const CloudAsrError(
        CloudAsrErrorKind.unauthorized,
        'The Tencent Cloud APPID is a number (账号中心 › 账号信息).',
      );
    }
    return appId;
  }

  /// A Tencent ASR error code (shared by both products) as a [CloudAsrError].
  @visibleForTesting
  static CloudAsrError codeError(int code, String? message, CloudCredentials credentials) {
    final (kind, fallback) = switch (code) {
      4000 => (CloudAsrErrorKind.rateLimited, 'Audio was sent faster than real time.'),
      4001 => (CloudAsrErrorKind.badRequest, 'Tencent Cloud rejected a parameter.'),
      4002 => (CloudAsrErrorKind.unauthorized, 'Tencent Cloud rejected the SecretId or SecretKey.'),
      4003 => (
        CloudAsrErrorKind.quotaExceeded,
        'Speech recognition is not activated for this AppID.',
      ),
      4004 => (CloudAsrErrorKind.quotaExceeded, 'The Tencent Cloud resource pack is used up.'),
      4005 => (CloudAsrErrorKind.quotaExceeded, 'The Tencent Cloud account is in arrears.'),
      4006 => (CloudAsrErrorKind.rateLimited, 'Too many concurrent Tencent Cloud sessions.'),
      4007 => (CloudAsrErrorKind.badRequest, 'Tencent Cloud could not decode the audio.'),
      4008 => (CloudAsrErrorKind.sessionEnded, 'No audio for 15 seconds; the session ended.'),
      4009 => (CloudAsrErrorKind.network, 'The connection to Tencent Cloud was lost.'),
      4010 => (CloudAsrErrorKind.protocol, 'Tencent Cloud did not understand a message.'),
      4011 => (CloudAsrErrorKind.audioTooLong, 'The audio is too large for Tencent Cloud.'),
      4012 => (CloudAsrErrorKind.badRequest, 'The audio was empty.'),
      6001 => (
        CloudAsrErrorKind.badRequest,
        'Calls from outside mainland China need the international site.',
      ),
      _ => (CloudAsrErrorKind.server, 'Tencent Cloud failed (code $code).'),
    };
    return serviceError(kind, message, credentials, fallback: fallback, providerCode: '$code');
  }

  static CloudAsrError _replyError(int status, String body, CloudCredentials credentials) {
    final json = jsonMap(tryJson(body));
    final code = jsonInt(json?['code']);
    if (code != null && code != 0) {
      final error = codeError(code, jsonString(json?['message']), credentials);
      return CloudAsrError(
        error.kind,
        error.message,
        statusCode: status,
        providerCode: error.providerCode,
      );
    }
    return CloudAsrError(
      kindForHttpStatus(status),
      'Tencent Cloud refused the request (HTTP $status).',
      statusCode: status,
    );
  }

  /// Word timings, absolute in the stream or file per the documentation;
  /// dropped when any falls outside its sentence.
  static List<CloudWord>? _words(Object? list, int start, int end) {
    final words = <CloudWord>[];
    for (final item in jsonList(list)) {
      final w = jsonMap(item);
      final text = (jsonString(w?['word']) ?? '').trim();
      final ws = jsonInt(w?['start_time']);
      final we = jsonInt(w?['end_time']);
      if (text.isEmpty || ws == null || we == null) continue;
      words.add(CloudWord(text, ws, we));
    }
    return wordsInside(words, start, end);
  }
}

/// One 实时语音识别 session. Messages are JSON text frames: the handshake
/// (`code` 0), results (`result.slice_type` 0 start / 1 changing / 2 stable,
/// `result.index` per sentence) and the last message (`final` 1).
final class _TencentStream extends SocketAsrStream {
  _TencentStream(super.socket, this._credentials) : super(frameBytes: TencentCloudAsr.frameBytes);

  final CloudCredentials _credentials;

  @override
  String get service => TencentCloudAsr._service;

  @override
  void handleText(String text) {
    final message = jsonMap(tryJson(text));
    if (message == null) throw const FormatException('not a JSON object');
    final code = jsonInt(message['code']) ?? 0;
    if (code != 0) {
      throw TencentCloudAsr.codeError(code, jsonString(message['message']), _credentials);
    }
    markReady();
    final result = jsonMap(message['result']);
    if (result != null) {
      final index = jsonInt(result['index']);
      if (index != null) {
        final start = jsonInt(result['start_time']) ?? 0;
        final end = max(start, jsonInt(result['end_time']) ?? start);
        final isFinal = jsonInt(result['slice_type']) == 2;
        emit(
          CloudSegment(
            id: '$index',
            text: (jsonString(result['voice_text_str']) ?? '').trim(),
            startMs: start,
            endMs: end,
            isFinal: isFinal,
            words: isFinal ? TencentCloudAsr._words(result['word_list'], start, end) : null,
          ),
        );
      }
    }
    if (jsonInt(message['final']) == 1) complete();
  }

  @override
  void sendEnd() => send(jsonEncode({'type': 'end'}));
}

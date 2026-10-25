import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../provider.dart';
import 'cn_support.dart';

/// Alibaba Cloud Model Studio / 阿里云百炼 (DashScope). Live: the DashScope
/// realtime WebSocket (`run-task` / binary audio / `finish-task`) with
/// [liveModel] (`fun-asr-realtime`). Files: the WAV goes to DashScope's
/// temporary storage (upload policy + OSS form POST → `oss://` URL), then an
/// asynchronous [fileModel] (`fun-asr`) transcription task is created and
/// polled. Endpoints, limits and error codes: `doc/dashscope.md`.
///
/// Credentials: [CloudFieldKeys.apiKey] (a Model Studio API key, `sk-…`) and
/// [CloudFieldKeys.region]: `cn` (华北2 北京, `dashscope.aliyuncs.com`) or
/// `intl` (Singapore, `dashscope-intl.aliyuncs.com`). Keys are per region.
final class DashScopeAsr implements CloudAsrProvider {
  /// [httpBaseUrl] / [wsBaseUrl] replace the region's `https://` and `wss://`
  /// base for both regions (tests pass loopback `http://` / `ws://`).
  /// [random] makes task ids and upload names deterministic in tests.
  DashScopeAsr({
    Uri? httpBaseUrl,
    Uri? wsBaseUrl,
    Random? random,
    this.liveModel = 'fun-asr-realtime',
    this.fileModel = 'fun-asr',
    this._pollInterval = const Duration(seconds: 2),
    this._connectTimeout = const Duration(seconds: 15),
  }) : _httpOverride = httpBaseUrl == null ? null : checkedBase(httpBaseUrl, socket: false),
       _wsOverride = wsBaseUrl == null ? null : checkedBase(wsBaseUrl, socket: true),
       _randomOverride = random;

  /// The realtime model (`run-task` `payload.model`).
  final String liveModel;

  /// The recorded-file model (transcription task `model`; also the model the
  /// temporary upload is bound to).
  final String fileModel;

  static const _service = 'DashScope';

  /// API hosts per [CloudFieldKeys.region] choice.
  static const regionHosts = {
    'cn': 'dashscope.aliyuncs.com',
    'intl': 'dashscope-intl.aliyuncs.com',
  };

  /// 100 ms of 16 kHz 16-bit mono PCM, as in the official samples.
  static const frameBytes = 3200;

  final Uri? _httpOverride, _wsOverride;
  final Random? _randomOverride;
  late final Random _random = _randomOverride ?? Random.secure();
  final Duration _pollInterval, _connectTimeout;

  static final _info = CloudAsrInfo(
    id: 'dashscope',
    fields: const [
      CloudField(CloudFieldKeys.apiKey),
      CloudField(
        CloudFieldKeys.region,
        kind: CloudFieldKind.choice,
        choices: ['cn', 'intl'],
        defaultValue: 'cn',
      ),
    ],
    languages: const {'en', 'zh', 'ja', 'ko', 'es', 'fr', 'de'},
    consoleUrl: Uri.parse('https://bailian.console.aliyun.com/cn-beijing/model/settings/api-key'),
    docsUrl: Uri.parse('https://help.aliyun.com/zh/model-studio/asr-model/'),
    // fun-asr accepts 2 GB / 12 h, but the temporary-storage policy caps one
    // upload (100 MB in the documented example); stay at that.
    maxFileMs: 12 * 60 * 60 * 1000,
    maxFileBytes: 100 * 1024 * 1024,
  );

  @override
  CloudAsrInfo get info => _info;

  /// The API host, plus the Alibaba Cloud OSS buckets the temporary upload
  /// and results use in that region.
  @override
  List<String> hosts(CloudCredentials credentials) {
    if (_httpOverride != null || _wsOverride != null) {
      return {?_httpOverride?.host, ?_wsOverride?.host}.toList();
    }
    final region = _region(credentials);
    return [
      regionHosts[region]!,
      region == 'cn' ? '*.oss-cn-beijing.aliyuncs.com' : '*.oss-ap-southeast-1.aliyuncs.com',
    ];
  }

  /// The `language_hints` code for a BCP-47 tag (Fun-ASR takes one).
  static String languageHint(String language) {
    final base = baseLanguage(language);
    if (_info.languages.contains(base)) return base;
    throw CloudAsrError(
      CloudAsrErrorKind.unsupportedLanguage,
      'DashScope has no language hint for $language here.',
    );
  }

  static String _region(CloudCredentials credentials) {
    final region = (credentials[CloudFieldKeys.region] ?? '').trim().toLowerCase();
    if (region.isEmpty) return 'cn';
    if (!regionHosts.containsKey(region)) {
      throw const CloudAsrError(CloudAsrErrorKind.badRequest, 'Unknown DashScope region.');
    }
    return region;
  }

  Uri _http(CloudCredentials c) => _httpOverride ?? Uri.parse('https://${regionHosts[_region(c)]}');
  Uri _ws(CloudCredentials c) => _wsOverride ?? Uri.parse('wss://${regionHosts[_region(c)]}');

  Map<String, String> _auth(CloudCredentials c) => {
    HttpHeaders.authorizationHeader: 'Bearer ${requireField(c, CloudFieldKeys.apiKey)}',
  };

  @override
  Future<void> verify(CloudCredentials credentials) async {
    // The upload-policy request is free, needs no audio and rejects a bad key.
    await _policy(credentials, null);
  }

  @override
  Future<CloudAsrStream> openStream(
    CloudCredentials credentials,
    CloudStreamOptions options,
  ) async {
    final hint = languageHint(options.language);
    final headers = _auth(credentials);
    final socket = await connectSocket(
      _service,
      _ws(credentials).replace(path: '/api-ws/v1/inference'),
      headers: headers,
      timeout: _connectTimeout,
      onRejected: (status, body) => _replyError(status, body, credentials),
    );
    final taskId = uuidV4(_random);
    final stream = _DashScopeStream(socket, credentials, taskId);
    stream.start(
      jsonEncode({
        'header': {'action': 'run-task', 'task_id': taskId, 'streaming': 'duplex'},
        'payload': {
          'task_group': 'audio',
          'task': 'asr',
          'function': 'recognition',
          'model': liveModel,
          'parameters': {
            'format': 'pcm',
            'sample_rate': options.sampleRate,
            'language_hints': [hint],
          },
          'input': <String, Object?>{},
        },
      }),
    );
    try {
      await stream.ready.timeout(_connectTimeout);
    } on TimeoutException {
      await stream.cancel();
      throw const CloudAsrError(
        CloudAsrErrorKind.network,
        'DashScope did not start the task in time.',
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
        'The file is too large for one DashScope upload.',
      );
    }
    final hint = languageHint(request.language);
    // 1. Upload policy, 2. form POST to temporary storage.
    final policy = await _policy(credentials, cancel);
    final ossUrl = await _upload(policy, request.wav, credentials, onProgress, cancel);
    cancel?.check();
    onProgress?.call(0.5);
    // 3. Create the task.
    final api = _http(credentials);
    final submit = await httpCall(
      _service,
      'POST',
      api.replace(path: '/api/v1/services/audio/asr/transcription'),
      headers: {
        ..._auth(credentials),
        HttpHeaders.contentTypeHeader: 'application/json',
        'X-DashScope-Async': 'enable',
        'X-DashScope-OssResourceResolve': 'enable',
      },
      body: [
        utf8.encode(
          jsonEncode({
            'model': fileModel,
            'input': {
              'file_urls': [ossUrl],
            },
            'parameters': {
              'channel_id': [0],
              'language_hints': [hint],
            },
          }),
        ),
      ],
      cancel: cancel,
      connectTimeout: _connectTimeout,
    );
    final created = _json(submit, credentials);
    final taskId = jsonString(jsonMap(created['output'])?['task_id']);
    if (taskId == null || !RegExp(r'^[\w-]+$').hasMatch(taskId)) {
      throw const CloudAsrError(CloudAsrErrorKind.protocol, 'DashScope did not return a task id.');
    }
    // 4. Poll until the task ends.
    final deadline = DateTime.now().add(
      const Duration(minutes: 20) + Duration(milliseconds: request.durationMs),
    );
    Map<String, Object?> output;
    while (true) {
      await _sleep(_pollInterval, cancel);
      final reply = await httpCall(
        _service,
        'GET',
        api.replace(path: '/api/v1/tasks/$taskId'),
        headers: _auth(credentials),
        cancel: cancel,
        connectTimeout: _connectTimeout,
      );
      output = jsonMap(_json(reply, credentials)['output']) ?? const {};
      final status = jsonString(output['task_status']) ?? '';
      if (status == 'SUCCEEDED') break;
      if (status == 'FAILED' || status == 'CANCELED' || status == 'UNKNOWN') {
        throw codeError(
          jsonString(output['code']) ?? status,
          jsonString(output['message']),
          credentials,
          fallback: 'The DashScope task ended as $status.',
        );
      }
      if (status == 'RUNNING') onProgress?.call(0.6);
      if (DateTime.now().isAfter(deadline)) {
        throw const CloudAsrError(
          CloudAsrErrorKind.server,
          'DashScope did not finish the file in time.',
        );
      }
    }
    // 5. The result file.
    final result = jsonMap(jsonList(output['results']).firstOrNull) ?? const {};
    if (jsonString(result['subtask_status']) != 'SUCCEEDED') {
      final code = jsonString(result['code']);
      // No speech in the file is a success with nothing to show.
      if (code == 'SUCCESS_WITH_NO_VALID_FRAGMENT') return const [];
      throw codeError(
        code,
        jsonString(result['message']),
        credentials,
        fallback: 'DashScope could not transcribe the file.',
      );
    }
    final url = Uri.tryParse(jsonString(result['transcription_url']) ?? '');
    if (url == null || !_trustedStorage(url)) {
      throw const CloudAsrError(
        CloudAsrErrorKind.protocol,
        'DashScope returned an unexpected result location.',
      );
    }
    onProgress?.call(0.95);
    // A pre-signed storage URL: no API key goes there.
    final download = await httpCall(
      _service,
      'GET',
      url,
      cancel: cancel,
      connectTimeout: _connectTimeout,
    );
    if (!download.ok) {
      // An expired pre-signed URL is the service's problem, not the key's.
      final kind = kindForHttpStatus(download.statusCode);
      throw CloudAsrError(
        kind == CloudAsrErrorKind.unauthorized ? CloudAsrErrorKind.server : kind,
        'Could not fetch the DashScope result (HTTP ${download.statusCode}).',
        statusCode: download.statusCode,
      );
    }
    final segments = parseTranscription(download.body, words: request.wordTimestamps);
    onProgress?.call(1);
    return segments;
  }

  /// Sentences (and words) from a recorded-file result JSON, first channel.
  @visibleForTesting
  static List<CloudSegment> parseTranscription(String body, {bool words = true}) {
    final json = jsonMap(tryJson(body));
    if (json == null) {
      throw const CloudAsrError(CloudAsrErrorKind.protocol, 'DashScope sent an unreadable result.');
    }
    final transcript = jsonMap(jsonList(json['transcripts']).firstOrNull);
    final segments = <CloudSegment>[];
    for (final item in jsonList(transcript?['sentences'])) {
      final s = jsonMap(item);
      final text = (jsonString(s?['text']) ?? '').trim();
      if (s == null || text.isEmpty) continue;
      final start = jsonInt(s['begin_time']) ?? 0;
      final end = max(start, jsonInt(s['end_time']) ?? start);
      segments.add(
        CloudSegment(
          id: '${segments.length}',
          text: text,
          startMs: start,
          endMs: end,
          words: words ? _words(s['words'], start, end) : null,
        ),
      );
    }
    return segments;
  }

  static List<CloudWord>? _words(Object? list, int start, int end) {
    final out = <CloudWord>[];
    for (final item in jsonList(list)) {
      final w = jsonMap(item);
      final text = (jsonString(w?['text']) ?? '').trim();
      final ws = jsonInt(w?['begin_time']);
      final we = jsonInt(w?['end_time']);
      if (text.isEmpty || ws == null || we == null) continue;
      out.add(CloudWord(text, ws, we));
    }
    return wordsInside(out, start, end);
  }

  Future<Map<String, Object?>> _policy(
    CloudCredentials credentials,
    CloudCancelToken? cancel,
  ) async {
    final reply = await httpCall(
      _service,
      'GET',
      _http(credentials).replace(
        path: '/api/v1/uploads',
        queryParameters: {'action': 'getPolicy', 'model': fileModel},
      ),
      headers: _auth(credentials),
      cancel: cancel,
      connectTimeout: _connectTimeout,
    );
    final data = jsonMap(_json(reply, credentials)['data']);
    if (data == null) {
      throw const CloudAsrError(
        CloudAsrErrorKind.protocol,
        'DashScope did not return an upload policy.',
      );
    }
    return data;
  }

  Future<String> _upload(
    Map<String, Object?> policy,
    Uint8List wav,
    CloudCredentials credentials,
    void Function(double progress)? onProgress,
    CloudCancelToken? cancel,
  ) async {
    String field(String name) {
      final v = jsonString(policy[name]);
      if (v == null || v.isEmpty) {
        throw CloudAsrError(CloudAsrErrorKind.protocol, 'The DashScope upload policy lacks $name.');
      }
      return v;
    }

    final host = Uri.tryParse(field('upload_host'));
    if (host == null || !_trustedStorage(host)) {
      throw const CloudAsrError(
        CloudAsrErrorKind.protocol,
        'DashScope offered an unexpected upload host.',
      );
    }
    final maxMb = jsonInt(policy['max_file_size_mb']);
    if (maxMb != null && maxMb > 0 && wav.length > maxMb * 1024 * 1024) {
      throw CloudAsrError(
        CloudAsrErrorKind.audioTooLong,
        'DashScope takes uploads of at most $maxMb MB.',
      );
    }
    final name =
        'tinglang-${List.generate(8, (_) => _random.nextInt(16).toRadixString(16)).join()}.wav';
    final key = '${field('upload_dir')}/$name';
    final fields = {
      'OSSAccessKeyId': field('oss_access_key_id'),
      'Signature': field('signature'),
      'policy': field('policy'),
      'x-oss-object-acl': field('x_oss_object_acl'),
      'x-oss-forbid-overwrite': field('x_oss_forbid_overwrite'),
      'key': key,
      'success_action_status': '200',
    };
    final boundary =
        'tinglang${List.generate(24, (_) => _random.nextInt(36).toRadixString(36)).join()}';
    final head = StringBuffer();
    fields.forEach((k, v) {
      head
        ..write('--$boundary\r\n')
        ..write('Content-Disposition: form-data; name="$k"\r\n\r\n')
        ..write('$v\r\n');
    });
    head
      ..write('--$boundary\r\n')
      ..write('Content-Disposition: form-data; name="file"; filename="$name"\r\n')
      ..write('Content-Type: audio/wav\r\n\r\n');
    final reply = await httpCall(
      _service,
      'POST',
      host,
      headers: {HttpHeaders.contentTypeHeader: 'multipart/form-data; boundary=$boundary'},
      body: [utf8.encode(head.toString()), wav, utf8.encode('\r\n--$boundary--\r\n')],
      onUpload: onProgress == null ? null : (f) => onProgress(0.5 * f),
      cancel: cancel,
      connectTimeout: _connectTimeout,
      responseTimeout: const Duration(minutes: 5),
    );
    if (!reply.ok) {
      // OSS answers in XML: <Error><Code>…</Code><Message>…</Message></Error>.
      final code = RegExp(r'<Code>([^<]*)</Code>').firstMatch(reply.body)?.group(1);
      final message = RegExp(r'<Message>([^<]*)</Message>').firstMatch(reply.body)?.group(1);
      final kind = switch (reply.statusCode) {
        413 => CloudAsrErrorKind.audioTooLong,
        429 => CloudAsrErrorKind.rateLimited,
        >= 500 => CloudAsrErrorKind.server,
        // An expired or refused policy: a new upload may work.
        401 || 403 => CloudAsrErrorKind.server,
        _ =>
          code == 'EntityTooLarge' ? CloudAsrErrorKind.audioTooLong : CloudAsrErrorKind.badRequest,
      };
      throw serviceError(
        kind,
        message,
        {
          ...credentials,
          'oss': fields['OSSAccessKeyId']!,
          'sig': fields['Signature']!,
          'policy': fields['policy']!,
        },
        fallback: 'DashScope temporary storage refused the upload (HTTP ${reply.statusCode}).',
        statusCode: reply.statusCode,
        providerCode: code,
      );
    }
    return 'oss://$key';
  }

  /// Upload and result URLs come from the service: only Alibaba Cloud hosts
  /// over HTTPS (or the test server) are used.
  bool _trustedStorage(Uri url) {
    if (_httpOverride != null && url.host == _httpOverride.host) return true;
    return url.scheme == 'https' && url.host.endsWith('.aliyuncs.com');
  }

  Map<String, Object?> _json(HttpReply reply, CloudCredentials credentials) {
    final json = jsonMap(tryJson(reply.body));
    if (!reply.ok) throw _replyError(reply.statusCode, reply.body, credentials);
    if (json == null) {
      throw const CloudAsrError(CloudAsrErrorKind.protocol, 'DashScope sent an unreadable reply.');
    }
    return json;
  }

  static CloudAsrError _replyError(int status, String body, CloudCredentials credentials) {
    final json = jsonMap(tryJson(body));
    return codeError(
      jsonString(json?['code']),
      jsonString(json?['message']),
      credentials,
      statusCode: status,
      fallback: 'DashScope refused the request (HTTP $status).',
    );
  }

  /// A DashScope error code (HTTP body `code`, `task-failed` `error_code`, or
  /// a task / subtask `code`) as a [CloudAsrError]; [statusCode] decides
  /// when the code is unknown.
  @visibleForTesting
  static CloudAsrError codeError(
    String? code,
    String? message,
    CloudCredentials credentials, {
    int? statusCode,
    String fallback = 'DashScope failed.',
  }) {
    final c = code ?? '';
    final text = message ?? '';
    final kind = switch (c) {
      'InvalidApiKey' || 'invalid_api_key' || 'NOT AUTHORIZED' => CloudAsrErrorKind.unauthorized,
      'AccessDenied.Unpurchased' ||
      'Arrearage' ||
      'AllocationQuota.FreeTierOnly' ||
      'CommodityNotPurchased' ||
      'PrepaidBillOverdue' ||
      'PostpaidBillOverdue' ||
      'BudgetLimitExceeded' ||
      'ModelNotFound' ||
      'model_not_found' => CloudAsrErrorKind.quotaExceeded,
      _ when c.startsWith('AccessDenied') || c.endsWith('.AccessDenied') || c == 'access_denied' =>
        CloudAsrErrorKind.unauthorized,
      _ when c.startsWith('Throttling') || c == 'limit_requests' || c == 'insufficient_quota' =>
        CloudAsrErrorKind.rateLimited,
      'InvalidFile.AudioLengthError' ||
      'InvalidFile.Duration' ||
      'InvalidFile.Size' ||
      'BadRequest.TooLarge' ||
      'Audio.DurationLimitError' ||
      'FILE_TOO_LARGE' ||
      'AUDIO_DURATION_TOO_LONG' => CloudAsrErrorKind.audioTooLong,
      // The realtime task's idle timeout ("request timeout after 23 seconds").
      'CLIENT_ERROR' when text.toLowerCase().contains('timeout') => CloudAsrErrorKind.sessionEnded,
      'ClientDisconnect' => CloudAsrErrorKind.network,
      _
          when c.startsWith('InternalError') ||
              c == 'SystemError' ||
              c == 'ModelServiceFailed' ||
              c == 'RequestTimeOut' ||
              c == 'ResponseTimeout' ||
              c == 'internal_error' =>
        CloudAsrErrorKind.server,
      _
          when c.startsWith('InvalidParameter') ||
              c.startsWith('BadRequest') ||
              c.startsWith('InvalidFile') ||
              c.startsWith('Audio.') ||
              c.startsWith('FILE_') ||
              c == 'CLIENT_ERROR' =>
        CloudAsrErrorKind.badRequest,
      _ => statusCode == null ? CloudAsrErrorKind.server : kindForHttpStatus(statusCode),
    };
    return serviceError(
      kind,
      message,
      credentials,
      fallback: fallback,
      statusCode: statusCode,
      providerCode: c.isEmpty ? null : c,
    );
  }

  static Future<void> _sleep(Duration d, CloudCancelToken? cancel) async {
    cancel?.check();
    if (cancel == null) {
      await Future<void>.delayed(d);
    } else {
      await Future.any([Future<void>.delayed(d), cancel.whenCancelled]);
    }
    cancel?.check();
  }
}

/// One realtime task. Server events are JSON text frames with
/// `header.event`: `task-started`, `result-generated` (a `sentence` with
/// `sentence_id`, `sentence_end`, `begin_time`/`end_time` in ms from the
/// first audio), `task-finished` and `task-failed`.
final class _DashScopeStream extends SocketAsrStream {
  _DashScopeStream(super.socket, this._credentials, this._taskId)
    : super(frameBytes: DashScopeAsr.frameBytes);

  final CloudCredentials _credentials;
  final String _taskId;

  @override
  String get service => DashScopeAsr._service;

  /// Sends the `run-task` message; `task-started` then makes [ready] complete.
  void start(String runTask) => send(runTask);

  @override
  void handleText(String text) {
    final message = jsonMap(tryJson(text));
    if (message == null) throw const FormatException('not a JSON object');
    final header = jsonMap(message['header']) ?? const {};
    switch (jsonString(header['event'])) {
      case 'task-started':
        markReady();
      case 'result-generated':
        final output = jsonMap(jsonMap(message['payload'])?['output']);
        final sentence = jsonMap(output?['sentence']);
        if (sentence != null) _sentence(sentence);
      case 'task-finished':
        complete();
      case 'task-failed':
        throw DashScopeAsr.codeError(
          jsonString(header['error_code']),
          jsonString(header['error_message']),
          _credentials,
          fallback: 'The DashScope task failed.',
        );
    }
  }

  void _sentence(Map<String, Object?> s) {
    if (jsonBool(s['heartbeat'])) return;
    final id = jsonInt(s['sentence_id']);
    if (id == null) return;
    final isFinal = jsonBool(s['sentence_end']);
    final start = jsonInt(s['begin_time']) ?? 0;
    final words = jsonList(s['words']);
    final lastWordEnd = jsonInt(jsonMap(words.lastOrNull)?['end_time']);
    final end = max(start, jsonInt(s['end_time']) ?? lastWordEnd ?? start);
    emit(
      CloudSegment(
        id: '$id',
        text: (jsonString(s['text']) ?? '').trim(),
        startMs: start,
        endMs: end,
        isFinal: isFinal,
        words: isFinal ? DashScopeAsr._words(words, start, end) : null,
      ),
    );
  }

  @override
  void sendEnd() => send(
    jsonEncode({
      'header': {'action': 'finish-task', 'task_id': _taskId, 'streaming': 'duplex'},
      'payload': {'input': <String, Object?>{}},
    }),
  );
}

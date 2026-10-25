import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:tinglang_cloud_asr/tinglang_cloud_asr.dart';
import 'package:tinglang_platform_interface/tinglang_platform_interface.dart';

import 'cloud_streaming_asr.dart' show asrFailureOf;
import 'sherpa_file_transcriber.dart' show TranscriptionCancelled;

/// A cloud speech service as a file transcriber.
///
/// The platform's [MediaDecoder] writes the media's audio to a temporary
/// f32le 16 kHz file; a worker isolate reads it (PCM never enters the root
/// isolate), cuts it into pieces the service accepts in one request
/// ([CloudAsrInfo.maxFileMs] / [CloudAsrInfo.maxFileBytes], at most
/// [maxChunkMs]) at the quietest moment near each limit, sends each piece as
/// a WAV and shifts the returned times to offsets into the media. Requests
/// that failed on the network or were rate limited are retried. Translation works as for the
/// local models. The temporary file is always deleted.
final class CloudFileTranscriber implements FileTranscriber {
  CloudFileTranscriber(
    this.provider, {
    required this.credentials,
    required this.decoder,
    this.translatorFor,
  });

  final CloudAsrProvider provider;
  final Future<CloudCredentials?> Function() credentials;
  final FutureOr<MediaDecoder> Function() decoder;
  final Future<TranslatorBackend?> Function(LanguagePair pair)? translatorFor;

  /// Longest piece sent in one request, whatever the service allows (keeps
  /// memory and the cost of a failed upload bounded).
  static const maxChunkMs = 30 * 60 * 1000;
  static const translationBatch = 16;

  String get backendId => 'cloud.${provider.info.id}';

  @override
  Set<String> get languages => provider.info.languages;

  @override
  Future<MediaInfo> inspect(String path) async => (await decoder()).inspect(path);

  @override
  TranscriptionJob transcribe(String path, FileTranscriptionOptions options) =>
      _CloudTranscriptionJob(this, path, options).._run();
}

/// Piece length for [info]: the service's limits, WAV header included, and
/// [CloudFileTranscriber.maxChunkMs].
int cloudChunkMs(CloudAsrInfo info) {
  var ms = CloudFileTranscriber.maxChunkMs;
  if (info.maxFileMs case final limit?) ms = math.min(ms, limit);
  if (info.maxFileBytes case final bytes?) {
    // 16 kHz mono 16-bit: 32 bytes per millisecond after the 44-byte header.
    ms = math.min(ms, (bytes - 44) ~/ 32);
  }
  return math.max(ms, 1000);
}

/// Where to cut [samples] (16 kHz) into pieces of at most [chunkMs]: in the
/// last [searchMs] before each limit, at the centre of the quietest 200 ms.
List<int> cloudCutPoints(Float32List samples, int chunkMs, {int searchMs = 10000}) {
  final limit = chunkMs * 16;
  final window = 3200; // 200 ms
  final cuts = <int>[];
  var start = 0;
  while (samples.length - start > limit) {
    final hardEnd = start + limit;
    final searchStart = math.max(start + limit ~/ 2, hardEnd - searchMs * 16);
    var best = hardEnd;
    var bestEnergy = double.infinity;
    for (var w = searchStart; w + window <= hardEnd; w += window ~/ 2) {
      var energy = 0.0;
      for (var i = w; i < w + window; i++) {
        energy += samples[i] * samples[i];
      }
      // Ties go to the later window, so pieces stay as long as allowed.
      if (energy <= bestEnergy) {
        bestEnergy = energy;
        best = w + window ~/ 2;
      }
    }
    cuts.add(best);
    start = best;
  }
  return cuts;
}

final class _CloudTranscriptionJob implements TranscriptionJob {
  _CloudTranscriptionJob(this._owner, this._path, this._options);

  final CloudFileTranscriber _owner;
  final String _path;
  final FileTranscriptionOptions _options;
  final _progress = StreamController<double>.broadcast();
  final _segments = StreamController<TranscriptSegment>.broadcast();
  final _translations = StreamController<(int, String)>.broadcast();
  final _result = Completer<FileTranscript>();
  final _finished = Completer<void>();
  bool _cancelled = false;
  SendPort? _control;

  @override
  Stream<double> get progress => _progress.stream;
  @override
  Stream<TranscriptSegment> get segments => _segments.stream;
  @override
  Stream<(int, String)> get translations => _translations.stream;
  @override
  Future<FileTranscript> get result => _result.future;

  @override
  Future<void> cancel() {
    _cancelled = true;
    _control?.send('cancel');
    return _finished.future;
  }

  void _check() {
    if (_cancelled) throw const TranscriptionCancelled();
  }

  Future<void> _run() async {
    String? pcm;
    try {
      final values = await _owner.credentials();
      if (values == null || values.isEmpty) {
        throw AsrFailure(
          AsrFailureReason.unauthorized,
          'No credentials saved.',
          backendId: _owner.backendId,
        );
      }
      final decoder = await _owner.decoder();
      final info = await decoder.inspect(_path);
      if (!info.hasAudio) throw StateError('No audio track in $_path.');
      _check();
      pcm = await decoder.decodeToFile(_path);
      _check();
      final segments = await _recognize(
        _FileJob(
          provider: _owner.provider,
          credentials: Map.of(values),
          language: _options.speech.locale ?? _options.language,
          wordTimestamps: _options.wordTimestamps,
          pcmPath: pcm,
          backendId: _owner.backendId,
        ),
      );
      _check();
      final translated = await _translate(segments);
      _check();
      _progress.add(1);
      await Future<void>.delayed(Duration.zero);
      _result.complete(
        FileTranscript(
          language: _options.language,
          backendId: _owner.backendId,
          segments: [
            for (var i = 0; i < segments.length; i++)
              TranscriptSegment(
                startMs: segments[i].startMs,
                endMs: segments[i].endMs,
                text: segments[i].text,
                words: segments[i].words,
                translation: translated[i],
              ),
          ],
        ),
      );
    } on Object catch (e, stack) {
      _result.completeError(_cancelled ? const TranscriptionCancelled() : e, stack);
    } finally {
      if (pcm != null) {
        try {
          File(pcm).deleteSync();
        } on FileSystemException {
          // Already gone.
        }
      }
      await Future.wait([_progress.close(), _segments.close(), _translations.close()]);
      _finished.complete();
    }
  }

  Future<List<TranscriptSegment>> _recognize(_FileJob job) async {
    final port = ReceivePort('cloud-file');
    final out = <TranscriptSegment>[];
    final done = Completer<void>();
    Isolate? isolate;
    port.listen((Object? message) {
      switch (message) {
        case SendPort control:
          _control = control;
          if (_cancelled) control.send('cancel');
        case TranscriptSegment segment:
          out.add(segment);
          _segments.add(segment);
        case double fraction:
          _progress.add(fraction);
        case 'done':
          if (!done.isCompleted) done.complete();
        case AsrFailure failure:
          if (!done.isCompleted) done.completeError(failure);
        case 'cancelled':
          if (!done.isCompleted) done.completeError(const TranscriptionCancelled());
        case List<Object?> error:
          if (!done.isCompleted) done.completeError(StateError('${error.first}'));
        case null:
          if (!done.isCompleted) done.completeError(StateError('Recogniser exited.'));
      }
    });
    try {
      isolate = await Isolate.spawn(
        _fileWorker,
        job.withReply(port.sendPort),
        onError: port.sendPort,
        onExit: port.sendPort,
        debugName: 'cloud-file',
      );
      await done.future;
    } finally {
      port.close();
      _control = null;
      isolate?.kill();
    }
    return out;
  }

  Future<List<String?>> _translate(List<TranscriptSegment> segments) async {
    final translated = List<String?>.filled(segments.length, null);
    final target = _options.translateTo;
    final lookup = _owner.translatorFor;
    if (target == null || lookup == null || segments.isEmpty) return translated;
    final pair = LanguagePair(_options.language, target);
    final translator = await lookup(pair);
    if (translator == null) return translated;
    const batch = CloudFileTranscriber.translationBatch;
    for (var start = 0; start < segments.length; start += batch) {
      _check();
      final end = math.min(start + batch, segments.length);
      final List<String> texts;
      try {
        texts = await translator.translate([
          for (var i = start; i < end; i++) segments[i].text,
        ], pair);
      } on Object {
        break;
      }
      for (var i = start; i < end && i - start < texts.length; i++) {
        translated[i] = texts[i - start];
        _translations.add((i, texts[i - start]));
      }
    }
    return translated;
  }
}

final class _FileJob {
  const _FileJob({
    required this.provider,
    required this.credentials,
    required this.language,
    required this.wordTimestamps,
    required this.pcmPath,
    required this.backendId,
    this.reply,
  });
  final CloudAsrProvider provider;
  final Map<String, String> credentials;
  final String language, pcmPath, backendId;
  final bool wordTimestamps;
  final SendPort? reply;

  _FileJob withReply(SendPort port) => _FileJob(
    provider: provider,
    credentials: credentials,
    language: language,
    wordTimestamps: wordTimestamps,
    pcmPath: pcmPath,
    backendId: backendId,
    reply: port,
  );
}

Future<void> _fileWorker(_FileJob job) async {
  final reply = job.reply!;
  final control = ReceivePort();
  final cancel = CloudCancelToken();
  control.listen((Object? message) {
    if (message == 'cancel') cancel.cancel();
  });
  reply.send(control.sendPort);
  try {
    await transcribeCloudPcm(
      job.provider,
      job.credentials,
      File(job.pcmPath),
      language: job.language,
      wordTimestamps: job.wordTimestamps,
      cancel: cancel,
      onSegment: reply.send,
      onProgress: reply.send,
    );
    reply.send('done');
  } on CloudAsrError catch (e) {
    reply.send(
      e.kind == CloudAsrErrorKind.cancelled ? 'cancelled' : asrFailureOf(e, job.backendId),
    );
  } finally {
    control.close();
  }
}

/// Transcribes a headerless 16 kHz f32le file with [provider], piece by
/// piece (see [cloudChunkMs], [cloudCutPoints]), retrying a piece up to
/// [attempts] times after a network failure or rate limiting. Times are
/// offsets into the whole file.
Future<void> transcribeCloudPcm(
  CloudAsrProvider provider,
  CloudCredentials credentials,
  File pcm, {
  required String language,
  required bool wordTimestamps,
  required CloudCancelToken cancel,
  required void Function(TranscriptSegment segment) onSegment,
  required void Function(double fraction) onProgress,
  int attempts = 3,
  Duration Function(int attempt) backoff = _backoff,
}) async {
  final bytes = await pcm.readAsBytes();
  final samples = Float32List.sublistView(bytes, 0, bytes.length ~/ 4 * 4);
  final cuts = [...cloudCutPoints(samples, cloudChunkMs(provider.info)), samples.length];
  var start = 0;
  for (var piece = 0; piece < cuts.length; piece++) {
    cancel.check();
    final end = cuts[piece];
    if (end - start < 1600) {
      start = end; // Under 100 ms: nothing to recognise.
      continue;
    }
    final wav = wavFromPcm16(pcm16FromFloat32(Float32List.sublistView(samples, start, end)));
    final offsetMs = start ~/ 16;
    final request = CloudFileRequest(
      wav: wav,
      durationMs: (end - start) ~/ 16,
      language: language,
      wordTimestamps: wordTimestamps,
    );
    List<CloudSegment>? result;
    for (var attempt = 1; result == null; attempt++) {
      try {
        result = await provider.transcribeFile(
          credentials,
          request,
          cancel: cancel,
          onProgress: (p) => onProgress((piece + p.clamp(0.0, 1.0)) / cuts.length),
        );
      } on CloudAsrError catch (e) {
        // Only failures that sent nothing billable are retried: a server
        // error or a timed-out poll would upload (and bill) the piece again.
        final again =
            e.kind == CloudAsrErrorKind.network || e.kind == CloudAsrErrorKind.rateLimited;
        if (!again || attempt >= attempts) rethrow;
        await Future.any([Future<void>.delayed(backoff(attempt)), cancel.whenCancelled]);
        cancel.check();
      }
    }
    for (final s in result) {
      if (s.text.trim().isEmpty) continue;
      onSegment(
        TranscriptSegment(
          startMs: offsetMs + s.startMs,
          endMs: offsetMs + s.endMs,
          text: s.text.trim(),
          words: s.words == null
              ? null
              : [
                  for (final w in s.words!)
                    TimedWord(w.text, offsetMs + w.startMs, offsetMs + w.endMs),
                ],
        ),
      );
    }
    onProgress((piece + 1) / cuts.length);
    start = end;
  }
}

Duration _backoff(int attempt) => Duration(seconds: attempt * 2);

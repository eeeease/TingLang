import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;
import 'package:tinglang_platform_interface/tinglang_platform_interface.dart';

import 'sherpa_runtime.dart';
import 'sherpa_streaming_asr.dart' show sentenceCased, vadFileName;

/// The job was cancelled; `'$e'` contains `Cancel` (what the app checks).
final class TranscriptionCancelled implements Exception {
  const TranscriptionCancelled();
  @override
  String toString() => 'Cancelled';
}

/// sherpa-onnx offline transducer over Silero VAD segments (X-ASR offline,
/// Parakeet TDT), in a worker isolate.
///
/// The [MediaDecoder] writes the media's audio to a temporary f32le 16 kHz
/// file; the worker reads it in chunks (PCM never enters the root isolate),
/// cuts speech segments of at most [maxSegmentSeconds] and recognises each.
/// Segment times are absolute offsets into the media. Translation, when
/// asked for and a translator is ready for the pair, runs on the finished
/// sentences in batches. The temporary file is always deleted.
final class SherpaFileTranscriber implements FileTranscriber {
  SherpaFileTranscriber(
    this.model, {
    required this.directoryOf,
    required this.decoder,
    this.translatorFor,
    this.sentenceCase = false,
    this.libraryDir,
  });

  final SpeechModel model;

  /// Folder of a model pack (`ModelInventory.directoryOf`), resolved per job.
  final String Function(String packId) directoryOf;

  /// Called per job, so the platform's decoder is picked lazily.
  final FutureOr<MediaDecoder> Function() decoder;

  /// A translator that is ready for the pair, or null to skip translation.
  final Future<TranslatorBackend?> Function(LanguagePair pair)? translatorFor;

  /// See [SherpaStreamingAsr.sentenceCase].
  final bool sentenceCase;
  final String? libraryDir;

  static const maxSegmentSeconds = 20.0;
  static const translationBatch = 16;

  @override
  Set<String> get languages => model.languages;

  @override
  Future<MediaInfo> inspect(String path) async => (await decoder()).inspect(path);

  @override
  TranscriptionJob transcribe(String path, FileTranscriptionOptions options) =>
      _SherpaTranscriptionJob(this, path, options).._run();
}

final class _SherpaTranscriptionJob implements TranscriptionJob {
  _SherpaTranscriptionJob(this._owner, this._path, this._options);

  final SherpaFileTranscriber _owner;
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
      final model = _owner.model;
      final files = model.sherpaFiles;
      final pack = model.pack;
      if (model.engine != SpeechEngine.sherpaOffline || files == null || pack == null) {
        throw StateError('${model.id} is not a sherpa-onnx offline model.');
      }
      final dir = _owner.directoryOf(pack.id);
      final vadDir = _owner.directoryOf(SpeechModels.vad.id);
      final decoder = await _owner.decoder();
      final info = await decoder.inspect(_path);
      if (!info.hasAudio) throw StateError('No audio track in $_path.');
      _check();
      pcm = await decoder.decodeToFile(_path);
      _check();
      final segments = await _recognize(
        _FileJob(
          libraryDir: _owner.libraryDir ?? sherpaLibraryDir(),
          modelType: model.sherpaType == SherpaModelType.nemoTransducer
              ? 'nemo_transducer'
              : 'transducer',
          encoder: '$dir/${files.encoder}',
          decoder: '$dir/${files.decoder}',
          joiner: '$dir/${files.joiner}',
          tokens: '$dir/${files.tokens}',
          vad: '$vadDir/$vadFileName',
          numThreads: _options.numThreads.clamp(1, 8),
          pcmPath: pcm,
          wordTimestamps: _options.wordTimestamps,
          sentenceCase: _owner.sentenceCase,
        ),
      );
      _check();
      final translated = await _translate(segments);
      _check();
      _progress.add(1);
      // Deliver queued segment/translation events before the result.
      await Future<void>.delayed(Duration.zero);
      _result.complete(
        FileTranscript(
          language: _options.language,
          backendId: model.backendId(SpeechUse.file),
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
    final port = ReceivePort('sherpa-file');
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
        case _FileError(:final message):
          if (!done.isCompleted) done.completeError(StateError(message));
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
        debugName: 'sherpa-file',
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
    const batch = SherpaFileTranscriber.translationBatch;
    for (var start = 0; start < segments.length; start += batch) {
      _check();
      final end = start + batch < segments.length ? start + batch : segments.length;
      final List<String> texts;
      try {
        texts = await translator.translate([
          for (var i = start; i < end; i++) segments[i].text,
        ], pair);
      } on Object {
        // The transcript stands without translations.
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

final class _FileError {
  const _FileError(this.message);
  final String message;
}

final class _FileJob {
  const _FileJob({
    required this.libraryDir,
    required this.modelType,
    required this.encoder,
    required this.decoder,
    required this.joiner,
    required this.tokens,
    required this.vad,
    required this.numThreads,
    required this.pcmPath,
    required this.wordTimestamps,
    required this.sentenceCase,
    this.reply,
  });
  final String? libraryDir;
  final String modelType, encoder, decoder, joiner, tokens, vad, pcmPath;
  final int numThreads;
  final bool wordTimestamps, sentenceCase;
  final SendPort? reply;

  _FileJob withReply(SendPort port) => _FileJob(
    libraryDir: libraryDir,
    modelType: modelType,
    encoder: encoder,
    decoder: decoder,
    joiner: joiner,
    tokens: tokens,
    vad: vad,
    numThreads: numThreads,
    pcmPath: pcmPath,
    wordTimestamps: wordTimestamps,
    sentenceCase: sentenceCase,
    reply: port,
  );
}

final _wordChar = RegExp(r'[\p{L}\p{N}]', unicode: true);

Future<void> _fileWorker(_FileJob job) async {
  final reply = job.reply!;
  final control = ReceivePort();
  var cancelled = false;
  control.listen((Object? message) {
    if (message == 'cancel') cancelled = true;
  });
  sherpa.VoiceActivityDetector? vad;
  sherpa.OfflineRecognizer? recognizer;
  RandomAccessFile? file;
  try {
    bindSherpa(job.libraryDir);
    vad = sherpa.VoiceActivityDetector(
      config: sherpa.VadModelConfig(
        sileroVad: sherpa.SileroVadModelConfig(
          model: job.vad,
          maxSpeechDuration: SherpaFileTranscriber.maxSegmentSeconds,
        ),
        numThreads: 1,
        debug: false,
      ),
      bufferSizeInSeconds: 60,
    );
    recognizer = sherpa.OfflineRecognizer(
      sherpa.OfflineRecognizerConfig(
        model: sherpa.OfflineModelConfig(
          transducer: sherpa.OfflineTransducerModelConfig(
            encoder: job.encoder,
            decoder: job.decoder,
            joiner: job.joiner,
          ),
          tokens: job.tokens,
          numThreads: job.numThreads,
          modelType: job.modelType,
          provider: 'cpu',
          debug: false,
        ),
        decodingMethod: 'greedy_search',
      ),
    );
    reply.send(control.sendPort);
    final pcm = file = File(job.pcmPath).openSync();
    final total = pcm.lengthSync() ~/ 4;
    const chunk = 16000 * 10;
    final bytes = Uint8List(chunk * 4);
    var read = 0;
    void drain() {
      while (!vad!.isEmpty()) {
        final segment = vad.front();
        vad.pop();
        final stream = recognizer!.createStream();
        stream.acceptWaveform(samples: segment.samples, sampleRate: 16000);
        recognizer.decode(stream);
        final result = recognizer.getResult(stream);
        stream.free();
        var text = result.text.trim();
        if (!_wordChar.hasMatch(text)) continue;
        if (job.sentenceCase) text = sentenceCased(text);
        final startMs = segment.start ~/ 16;
        final endMs = (segment.start + segment.samples.length) ~/ 16;
        var words = job.wordTimestamps
            ? wordsFromTokens(result.tokens, result.timestamps, offsetMs: startMs, endMs: endMs)
            : null;
        if (job.sentenceCase && words != null) {
          words = [
            for (var i = 0; i < words.length; i++)
              TimedWord(
                sentenceCased(words[i].text, first: i == 0),
                words[i].startMs,
                words[i].endMs,
              ),
          ];
        }
        reply.send(TranscriptSegment(startMs: startMs, endMs: endMs, text: text, words: words));
      }
    }

    while (!cancelled) {
      final n = pcm.readIntoSync(bytes) ~/ 4;
      if (n <= 0) break;
      read += n;
      // The VAD takes one 512-sample window per call.
      final samples = bytes.buffer.asFloat32List(0, n);
      for (var i = 0; i < n; i += 512) {
        vad.acceptWaveform(Float32List.sublistView(samples, i, i + 512 < n ? i + 512 : n));
      }
      drain();
      if (total > 0) reply.send(read / total * .99);
      // Let a cancel message in.
      await Future<void>.delayed(Duration.zero);
    }
    if (!cancelled) {
      vad.flush();
      drain();
    }
  } on Object catch (e) {
    reply.send(_FileError('$e'));
  } finally {
    file?.closeSync();
    recognizer?.free();
    vad?.free();
    control.close();
  }
  reply.send('done');
}

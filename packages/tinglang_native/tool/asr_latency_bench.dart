// Live-caption latency benchmark for the sherpa-onnx streaming backends.
//
// Plays FLEURS utterances (with pauses between them) in real time, 100 ms
// blocks, through SherpaStreamingAsr in push mode, once per model and
// latency tier, and prints a markdown table.
//
//   fvm dart run tool/asr_latency_bench.dart \
//     --fleurs <bench>/prepared/fleurs_en_us --vad <dir with silero_vad.onnx> \
//     --model sherpa.xasr_zh_en_480=<dir> [--model sherpa.zipformer_en_small=<dir> …] \
//     [--minutes 5] [--gap 1.5] [--tiers powerSaver,balanced,fastest] [--dump <dir>]
//
// Definitions (audio clock = wall time since playback started; block k is
// sent when its last sample would have been captured, at (k+1) × 100 ms):
// - word lag: for word k of a final (start/end from the model's token
//   times), arrival of the first partial or final of that line with more
//   than k words, minus the word's end. Words the model emitted only at the
//   final count too. Negative values (word recognised before its estimated
//   end) are kept.
// - final after speech end: arrival of a final minus its `endMs` (the VAD's
//   end of speech on the capture clock).
// - final after clip end: arrival of an utterance's last final minus the
//   end of its audio clip (FLEURS clips carry ~0.5–1 s of trailing silence).
// - CPU: process user+system time (getrusage) over wall time, one core =
//   100 %; worker CPU: the session's own AsrStats.cpuMsPerSecond (thread CPU
//   of the worker around VAD + recogniser calls); RSS: peak resident size.
// - Fed: audio handed to the recogniser (VAD-gated speech, pre-roll and
//   the 0.64 s warm-up per stream) over the audio played; can exceed 100 %.
// - WER: all finals against all references, lower case, punctuation removed.
import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:tinglang_native/src/shared/sherpa_streaming_asr.dart';
import 'package:tinglang_platform_interface/tinglang_platform_interface.dart';

Future<void> main(List<String> args) async {
  final options = _parse(args);
  final fleurs = options['fleurs']?.single ?? _die('--fleurs <dir> is required');
  final vad = options['vad']?.single ?? _die('--vad <dir> is required');
  final minutes = double.parse(options['minutes']?.single ?? '5');
  final gap = double.parse(options['gap']?.single ?? '1.5');
  final tiers = (options['tiers']?.single ?? 'powerSaver,balanced,fastest')
      .split(',')
      .map((name) => LatencyTier.values.byName(name))
      .toList();
  final models = <SpeechModel, String>{
    for (final spec in options['model'] ?? const <String>[])
      SpeechModels.byId(spec.split('=').first) ?? _die('unknown model ${spec.split('=').first}'):
          spec.substring(spec.indexOf('=') + 1),
  };
  if (models.isEmpty) _die('give at least one --model <id>=<dir>');

  final program = _program(fleurs, minutes * 60, gap);
  stdout.writeln(
    '# ${program.utterances.length} FLEURS utterances, '
    '${(program.samples.length / 16000 / 60).toStringAsFixed(1)} min, '
    '${gap}s pauses, ${Platform.localHostname}, ${Platform.numberOfProcessors} cores\n',
  );
  final rows = <String>[];
  for (final entry in models.entries) {
    for (final tier in tiers) {
      stderr.writeln('running ${entry.key.id} $tier …');
      final result = await _run(
        entry.key,
        entry.value,
        vad,
        tier,
        program,
        options['dump']?.single,
      );
      rows.add(result.row(entry.key.id, tier));
      stderr.writeln(rows.last);
    }
  }
  stdout
    ..writeln(
      '| Model | Tier | Word lag p50 / p90 | Final after speech end p50 / p90 | '
      'Final after clip end p50 / p90 | CPU | Worker CPU | Peak RSS | Fed | WER |',
    )
    ..writeln('|---|---|---|---|---|---|---|---|---|---|')
    ..writeln(rows.join('\n'));
}

final class _Utterance {
  const _Utterance(this.reference, this.startSample, this.endSample);
  final String reference;
  final int startSample, endSample;
}

final class _Program {
  const _Program(this.samples, this.utterances);
  final Float32List samples;
  final List<_Utterance> utterances;
}

_Program _program(String dir, double seconds, double gap) {
  final lines = File('$dir/manifest.jsonl').readAsLinesSync();
  final out = <double>[...List.filled((gap * 16000).round(), 0.0)];
  final utterances = <_Utterance>[];
  for (final line in lines) {
    if (out.length >= seconds * 16000) break;
    final entry = jsonDecode(line) as Map<String, Object?>;
    final samples = _readWav(entry['wav']! as String);
    final start = out.length;
    out.addAll(samples);
    utterances.add(_Utterance(entry['ref']! as String, start, out.length));
    out.addAll(List.filled((gap * 16000).round(), 0.0));
  }
  return _Program(Float32List.fromList(out), utterances);
}

final class _Result {
  final wordLags = <double>[];
  final finalLags = <double>[];
  final clipLags = <double>[];
  double cpuPercent = 0, workerCpuPercent = 0, wer = 0, fedFraction = 0;
  int peakRss = 0;

  String row(String model, LatencyTier tier) =>
      '| $model | ${tier.name} | ${_pp(wordLags)} | ${_pp(finalLags)} | ${_pp(clipLags)} | '
      '${cpuPercent.toStringAsFixed(1)} % | ${workerCpuPercent.toStringAsFixed(1)} % | ${(peakRss / 1e9).toStringAsFixed(2)} GB | '
      '${(fedFraction * 100).toStringAsFixed(0)} % | ${(wer * 100).toStringAsFixed(1)} |';

  static String _pp(List<double> values) {
    if (values.isEmpty) return '–';
    final sorted = [...values]..sort();
    double at(double q) => sorted[math.min(sorted.length - 1, (q * sorted.length).floor())];
    return '${at(.5).toStringAsFixed(2)} / ${at(.9).toStringAsFixed(2)} s';
  }
}

final class _Arrival {
  const _Arrival(this.segmentId, this.words, this.atMs);
  final String segmentId;
  final int words;
  final double atMs;
}

Future<_Result> _run(
  SpeechModel model,
  String dir,
  String vadDir,
  LatencyTier tier,
  _Program program,
  String? dump,
) async {
  final asr = SherpaStreamingAsr(
    model,
    directoryOf: (pack) => pack == SpeechModels.vad.id ? vadDir : dir,
    sentenceCase: model.id.startsWith('sherpa.zipformer_en_'),
  );
  final session = await asr.start(AsrSessionConfig(language: 'en', latency: tier));
  final clock = Stopwatch();
  final arrivals = <_Arrival>[];
  final finals = <(AsrFinal, double)>[];
  final done = Completer<void>();
  final workerCpu = <double>[];
  session.stats.listen((s) => workerCpu.add(s.cpuMsPerSecond));
  session.events.listen((event) {
    final at = clock.elapsedMicroseconds / 1000;
    switch (event) {
      case AsrPartial():
        arrivals.add(_Arrival(event.segmentId, _words(event.text).length, at));
      case AsrFinal():
        arrivals.add(_Arrival(event.segmentId, _words(event.text).length, at));
        finals.add((event, at));
      case AsrGap():
        stderr.writeln('gap ${event.startMs}-${event.endMs}');
    }
  }, onDone: done.complete);

  final cpu0 = _cpuMicros();
  final wall = Stopwatch()..start();
  clock.start();
  const block = 1600;
  final samples = program.samples;
  for (var k = 0; k * block < samples.length; k++) {
    final due = (k + 1) * 100000;
    final wait = due - clock.elapsedMicroseconds;
    if (wait > 0) await Future<void>.delayed(Duration(microseconds: wait));
    final end = math.min(samples.length, (k + 1) * block);
    session.acceptWaveform(Float32List.sublistView(samples, k * block, end), 16000);
  }
  await session.stop();
  await done.future;
  final result = _Result()
    ..cpuPercent = (_cpuMicros() - cpu0) / wall.elapsedMicroseconds * 100
    ..workerCpuPercent = workerCpu.isEmpty
        ? 0
        : workerCpu.reduce((a, b) => a + b) / workerCpu.length / 10
    ..peakRss = ProcessInfo.maxRss
    ..fedFraction = session.fedSamples / samples.length;

  for (final (line, at) in finals) {
    result.finalLags.add((at - line.endMs) / 1000);
    final words = line.words;
    if (words == null) continue;
    final ofLine = arrivals.where((a) => a.segmentId == line.segmentId).toList();
    for (var k = 0; k < words.length; k++) {
      final first = ofLine.firstWhere((a) => a.words > k, orElse: () => ofLine.last);
      result.wordLags.add((first.atMs - words[k].endMs) / 1000);
    }
  }
  for (final utterance in program.utterances) {
    final clipEndMs = utterance.endSample / 16;
    // The last final that started inside this utterance.
    final mine = finals.where(
      (f) => f.$1.startMs >= utterance.startSample / 16 - 500 && f.$1.startMs < clipEndMs,
    );
    if (mine.isNotEmpty) result.clipLags.add((mine.last.$2 - clipEndMs) / 1000);
  }
  if (dump != null) {
    File('$dump/${model.id}-${tier.name}.txt').writeAsStringSync(
      [
        for (final (line, at) in finals)
          '${line.startMs}-${line.endMs} @${at.round()} ${line.segmentId}: ${line.text}',
        '',
        for (final u in program.utterances)
          '${u.startSample ~/ 16}-${u.endSample ~/ 16} REF ${u.reference}',
      ].join('\n'),
    );
  }
  result.wer = _wer(
    program.utterances.expand((u) => _words(u.reference)).toList(),
    finals.expand((f) => _words(f.$1.text)).toList(),
  );
  return result;
}

List<String> _words(String text) => text
    .toLowerCase()
    .replaceAll(RegExp(r"[^\p{L}\p{N}' ]", unicode: true), ' ')
    .split(RegExp(r'\s+'))
    .where((w) => w.isNotEmpty)
    .toList();

double _wer(List<String> reference, List<String> hypothesis) {
  if (reference.isEmpty) return 0;
  var previous = List<int>.generate(hypothesis.length + 1, (j) => j);
  for (var i = 1; i <= reference.length; i++) {
    final current = List<int>.filled(hypothesis.length + 1, 0)..[0] = i;
    for (var j = 1; j <= hypothesis.length; j++) {
      final substitution = previous[j - 1] + (reference[i - 1] == hypothesis[j - 1] ? 0 : 1);
      current[j] = math.min(substitution, math.min(previous[j] + 1, current[j - 1] + 1));
    }
    previous = current;
  }
  return previous[hypothesis.length] / reference.length;
}

typedef _GetrusageNative = Int32 Function(Int32 who, Pointer<Uint8> usage);
final _getrusage = DynamicLibrary.process()
    .lookupFunction<_GetrusageNative, int Function(int, Pointer<Uint8>)>('getrusage');

/// User + system CPU of this process in microseconds (`struct rusage`
/// starts with two `struct timeval`s).
int _cpuMicros() {
  final usage = calloc<Uint8>(256);
  try {
    if (_getrusage(0, usage) != 0) throw StateError('getrusage failed');
    final view = ByteData.sublistView(usage.asTypedList(256));
    int timeval(int offset) {
      final seconds = view.getInt64(offset, Endian.host);
      final micros = Platform.isMacOS
          ? view.getInt32(offset + 8, Endian.host)
          : view.getInt64(offset + 8, Endian.host);
      return seconds * 1000000 + micros;
    }

    return timeval(0) + timeval(16);
  } finally {
    calloc.free(usage);
  }
}

Float32List _readWav(String path) {
  final bytes = File(path).readAsBytesSync();
  final data = ByteData.sublistView(bytes);
  var offset = 12;
  while (offset + 8 <= bytes.length) {
    final id = String.fromCharCodes(bytes, offset, offset + 4);
    final size = data.getUint32(offset + 4, Endian.little);
    if (id == 'data') {
      final n = size ~/ 2;
      return Float32List.fromList([
        for (var i = 0; i < n; i++) data.getInt16(offset + 8 + 2 * i, Endian.little) / 32768,
      ]);
    }
    offset += 8 + size + (size & 1);
  }
  throw FormatException('no data chunk in $path');
}

Map<String, List<String>> _parse(List<String> args) {
  final out = <String, List<String>>{};
  for (var i = 0; i + 1 < args.length; i += 2) {
    if (!args[i].startsWith('--')) _die('unexpected ${args[i]}');
    (out[args[i].substring(2)] ??= []).add(args[i + 1]);
  }
  return out;
}

Never _die(String message) {
  stderr.writeln(message);
  exit(64);
}

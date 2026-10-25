import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tinglang_native/src/shared/sherpa_runtime.dart';
import 'package:tinglang_native/src/shared/sherpa_streaming_asr.dart';
import 'package:tinglang_platform_interface/tinglang_platform_interface.dart';

/// Real-model tests run only with `TINGLANG_SHERPA_MODELS` pointing at the
/// benchmark folder (X-ASR streaming + silero_vad.onnx); FLEURS clips come
/// from `../prepared/fleurs_en_us` next to it.
final modelsRoot = Platform.environment['TINGLANG_SHERPA_MODELS'];
const xasrDir =
    'sherpa-onnx-x-asr-480ms-streaming-zipformer-transducer-zh-en-punct-int8-2026-06-05';
const clip = '10035998729701048400.wav'; // 16.4 s

/// 16-bit PCM WAV → f32 samples.
Float32List readWav(String path) {
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

void main() {
  group('words from tokens', () {
    test('groups SentencePiece pieces; a word ends where the next token starts', () {
      final words = wordsFromTokens(
        [' Now', ' w', 'id', 'e', 'ly', ',', ' I'],
        [0.72, 1.12, 1.2, 1.32, 1.4, 1.5, 1.8],
        offsetMs: 1000,
        endMs: 3000,
      )!;
      expect(words.map((w) => w.text), ['Now', 'widely,', 'I']);
      expect(words.map((w) => w.startMs), [1720, 2120, 2800]);
      expect(words.map((w) => w.endMs), [2120, 2500, 3000]);
    });

    test('LibriSpeech ▁ pieces and CJK characters', () {
      final words = wordsFromTokens(
        ['▁HE', 'LLO', '▁WORLD', '你', '好', '。'],
        [0, .2, .4, .8, 1.0, 1.1],
        offsetMs: 0,
        endMs: 1500,
      )!;
      expect(words.map((w) => w.text), ['HELLO', 'WORLD', '你', '好。']);
      expect(words.map((w) => w.endMs), [400, 800, 1000, 1100]);
    });

    test('no timing, no words', () {
      expect(wordsFromTokens(['a', 'b'], [0.1], offsetMs: 0, endMs: 10), isNull);
      expect(wordsFromTokens(const [], const [], offsetMs: 0, endMs: 10), isNull);
    });

    test('sentence case for upper-case models', () {
      expect(sentenceCased("I THINK I'M HERE AND IT IS FINE"), "I think I'm here and it is fine");
      expect(sentenceCased('HELLO', first: false), 'hello');
    });
  });

  group(
    'SherpaStreamingAsr with X-ASR',
    skip: modelsRoot == null ? 'set TINGLANG_SHERPA_MODELS' : null,
    () {
      late SherpaStreamingAsr backend;
      late Float32List speech;

      setUpAll(() {
        backend = SherpaStreamingAsr(
          SpeechModels.xasrStreaming,
          directoryOf: (pack) => pack == SpeechModels.vad.id ? modelsRoot! : '$modelsRoot/$xasrDir',
        );
        speech = readWav('$modelsRoot/../prepared/fleurs_en_us/$clip');
      });

      Future<(List<AsrEvent>, SherpaAsrSession)> run(
        List<Float32List> parts, {
        LatencyTier tier = LatencyTier.balanced,
      }) async {
        final session = await backend.start(AsrSessionConfig(language: 'en', latency: tier));
        final events = <AsrEvent>[];
        session.events.listen(events.add);
        for (final part in parts) {
          for (var i = 0; i < part.length; i += 1600) {
            session.acceptWaveform(
              Float32List.sublistView(part, i, (i + 1600).clamp(0, part.length)),
              16000,
            );
          }
        }
        await session.stop();
        return (events, session);
      }

      test('silence is never fed to the recogniser', () async {
        final noise = Float32List.fromList([
          for (var i = 0; i < 16000 * 4; i++) (i % 7 - 3) * 1e-4,
        ]);
        final (events, session) = await run([noise]);
        expect(events, isEmpty);
        expect(session.fedSamples, 0);
      });

      test('partials, then a final at the pause, on the capture clock', () async {
        final lead = Float32List(16000 * 3);
        final tail = Float32List(16000 * 3);
        final (events, session) = await run([lead, speech, tail]);
        final partials = events.whereType<AsrPartial>().toList();
        final finals = events.whereType<AsrFinal>().toList();
        expect(partials, isNotEmpty);
        expect(finals, hasLength(1));
        final last = finals.single;
        expect(partials.every((p) => p.segmentId == last.segmentId), isTrue);
        expect(events.indexOf(last), greaterThan(events.indexOf(partials.last)));
        expect(last.text.toLowerCase(), contains('widely available'));
        expect(last.text.toLowerCase(), contains('aromatic spices'));
        // Speech starts ~0.7 s into the clip, which starts at 3 s.
        expect(last.startMs, inInclusiveRange(3400, 4000));
        expect(last.endMs, inInclusiveRange(17500, 19800));
        expect(last.language, 'en');
        final words = last.words!;
        expect(words.first.text, 'Now');
        for (var i = 0; i < words.length; i++) {
          expect(words[i].startMs, greaterThanOrEqualTo(last.startMs));
          expect(words[i].endMs, lessThanOrEqualTo(last.endMs));
          if (i > 0) expect(words[i].startMs, greaterThanOrEqualTo(words[i - 1].startMs));
        }
        // The lead-in silence and most of the tail were gated out.
        final total = lead.length + speech.length + tail.length;
        expect(session.fedSamples, lessThan(total - 16000 * 2));
        expect(session.fedSamples, greaterThan(speech.length * .8));
      });

      test('stop flushes the line in progress', () async {
        final half = Float32List.sublistView(speech, 0, 16000 * 8);
        for (final tier in LatencyTier.values) {
          final (events, _) = await run([Float32List(8000), half], tier: tier);
          // The fastest tier's 0.5 s endpoint may split at a comma pause.
          final text = events.whereType<AsrFinal>().map((f) => f.text).join(' ').toLowerCase();
          expect(text, contains('widely available'), reason: '$tier');
          // The words just before stop come out as a final, not a lost partial.
          expect(text, contains('predominant'), reason: '$tier');
          expect(events.last, isA<AsrFinal>(), reason: '$tier');
        }
      });

      test('stats arrive about once a second', () async {
        final session = await backend.start(const AsrSessionConfig(language: 'en'));
        final stats = <AsrStats>[];
        session.stats.listen(stats.add);
        for (var i = 0; i < 25; i++) {
          session.acceptWaveform(Float32List.sublistView(speech, i * 1600, (i + 1) * 1600), 16000);
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
        await session.stop();
        expect(stats.length, inInclusiveRange(1, 3));
        expect(stats.any((s) => s.realTimeFactor > 0 && s.realTimeFactor < 1), isTrue);
        expect(stats.any((s) => s.cpuMsPerSecond > 0), isTrue);
      });
    },
  );
}

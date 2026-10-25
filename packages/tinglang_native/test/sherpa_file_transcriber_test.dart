import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tinglang_native/src/shared/sherpa_file_transcriber.dart';
import 'package:tinglang_platform_interface/testing.dart';
import 'package:tinglang_platform_interface/tinglang_platform_interface.dart';

import 'sherpa_streaming_asr_test.dart' show modelsRoot, readWav;

const clips = [
  '15158676295442294624.wav', // "The main local beer is 'Number One'…"
  '16131823300806444840.wav', // "Insects were the first animals…"
];
const dirs = {
  'xasr-zh-en-offline-punct-int8':
      'sherpa-onnx-x-asr-zipformer-transducer-zh-en-punct-int8-2026-06-03',
  'parakeet-tdt-0.6b-v2-int8': 'sherpa-onnx-nemo-parakeet-tdt-0.6b-v2-int8',
};

/// Treats the "media" as raw f32 already and copies it to a temp file, as
/// the native decoders do; records what it handed out.
final class F32Decoder implements MediaDecoder {
  F32Decoder(this.samples);
  final Float32List samples;
  final files = <String>[];
  @override
  Future<MediaInfo> inspect(String path) async =>
      MediaInfo(durationMs: samples.length ~/ 16, hasVideo: false, hasAudio: true);
  @override
  Stream<Float32List> decodePcm(String path, {int sampleRate = 16000}) => Stream.value(samples);
  @override
  Future<String> decodeToFile(String path, {int sampleRate = 16000}) async {
    final dir = await Directory.systemTemp.createTemp('tinglang-pcm');
    final file = File('${dir.path}/audio.f32');
    await file.writeAsBytes(
      samples.buffer.asUint8List(samples.offsetInBytes, samples.lengthInBytes),
    );
    files.add(file.path);
    return file.path;
  }
}

void main() {
  group(
    'SherpaFileTranscriber',
    skip: modelsRoot == null ? 'set TINGLANG_SHERPA_MODELS' : null,
    () {
      late Float32List media;
      late List<int> clipStartsMs;

      setUpAll(() {
        final parts = <Float32List>[Float32List(16000)];
        clipStartsMs = [];
        var at = 16000;
        for (final clip in clips) {
          final samples = readWav('$modelsRoot/../prepared/fleurs_en_us/$clip');
          clipStartsMs.add(at ~/ 16);
          parts
            ..add(samples)
            ..add(Float32List(16000 * 2));
          at += samples.length + 16000 * 2;
        }
        media = Float32List.fromList([for (final p in parts) ...p]);
      });

      SherpaFileTranscriber transcriber(SpeechModel model, F32Decoder decoder) =>
          SherpaFileTranscriber(
            model,
            directoryOf: (pack) =>
                pack == SpeechModels.vad.id ? modelsRoot! : '$modelsRoot/${dirs[pack]}',
            decoder: () => decoder,
            translatorFor: (pair) async => FakeTranslator(),
          );

      for (final model in [SpeechModels.xasrOffline, SpeechModels.parakeet]) {
        test('${model.id}: sentences on the media clock, translated, temp file deleted', () async {
          final decoder = F32Decoder(media);
          final job = transcriber(model, decoder).transcribe(
            'clip.wav',
            const FileTranscriptionOptions(language: 'en', translateTo: 'zh-Hans', numThreads: 2),
          );
          final progress = <double>[];
          final segments = <TranscriptSegment>[];
          final translations = <(int, String)>[];
          job.progress.listen(progress.add);
          job.segments.listen(segments.add);
          job.translations.listen(translations.add);
          final result = await job.result;

          expect(result.backendId, model.id);
          expect(result.segments, hasLength(segments.length));
          expect(segments.length, inInclusiveRange(2, 4));
          final text = segments.map((s) => s.text).join(' ').toLowerCase();
          expect(text, contains('local beer'));
          expect(text, contains('insects'));
          // The second clip's first sentence starts within a second of where
          // it was placed.
          final insects = segments.firstWhere((s) => s.text.toLowerCase().contains('insects'));
          expect(insects.startMs, inInclusiveRange(clipStartsMs[1] - 500, clipStartsMs[1] + 1200));
          for (var i = 0; i < segments.length; i++) {
            expect(segments[i].endMs, greaterThan(segments[i].startMs));
            if (i > 0) expect(segments[i].startMs, greaterThanOrEqualTo(segments[i - 1].endMs));
            final words = segments[i].words;
            if (words != null) {
              expect(words.first.startMs, greaterThanOrEqualTo(segments[i].startMs));
              expect(words.last.endMs, lessThanOrEqualTo(segments[i].endMs));
            }
          }
          expect(translations.map((t) => t.$1), [for (var i = 0; i < segments.length; i++) i]);
          expect(result.segments.first.translation, '[zh-Hans] ${segments.first.text}');
          expect(progress.last, 1);
          expect(progress, orderedEquals([...progress]..sort()));
          expect(File(decoder.files.single).existsSync(), isFalse);
        });
      }

      test('cancel stops the worker, deletes the file and fails with Cancel', () async {
        final decoder = F32Decoder(media);
        final job = transcriber(
          SpeechModels.parakeet,
          decoder,
        ).transcribe('clip.wav', const FileTranscriptionOptions(language: 'en'));
        final failed = expectLater(
          job.result,
          throwsA(predicate((Object e) => '$e'.contains('Cancel'), 'mentions Cancel')),
        );
        await job.progress.first.timeout(const Duration(seconds: 30));
        await job.cancel();
        await failed;
        expect(File(decoder.files.single).existsSync(), isFalse);
      });
    },
  );
}

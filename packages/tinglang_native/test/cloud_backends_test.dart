import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tinglang_cloud_asr/tinglang_cloud_asr.dart';
import 'package:tinglang_native/src/shared/cloud_backends.dart';
import 'package:tinglang_native/src/shared/cloud_file_transcriber.dart';
import 'package:tinglang_native/src/shared/cloud_streaming_asr.dart';
import 'package:tinglang_native/src/shared/sherpa_file_transcriber.dart';
import 'package:tinglang_platform_interface/testing.dart';
import 'package:tinglang_platform_interface/tinglang_platform_interface.dart';

/// A stream the test drives from outside (same isolate).
final class DrivenStream implements CloudAsrStream {
  final _segments = StreamController<CloudSegment>();
  final sent = <int>[]; // samples per addPcm call
  bool finished = false, cancelled = false;
  int get samples => sent.fold(0, (a, b) => a + b);

  @override
  Stream<CloudSegment> get segments => _segments.stream;
  @override
  void addPcm(Uint8List pcm16le) => sent.add(pcm16le.length ~/ 2);
  void emit(CloudSegment s) => _segments.add(s);
  void fail(CloudAsrError e) {
    _segments.addError(e);
  }

  void end() => _segments.close();
  @override
  Future<void> finish({Duration timeout = const Duration(seconds: 10)}) async {
    finished = true;
    if (!_segments.isClosed) await _segments.close();
  }

  @override
  Future<void> cancel() async {
    cancelled = true;
    if (!_segments.isClosed) await _segments.close();
  }
}

Float32List tone(int ms, {double level = .1}) => Float32List.fromList(List.filled(ms * 16, level));

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

/// A provider that can run in a worker isolate: it recognises one "word"
/// per second of audio it receives, as a partial, and finalises the line
/// when the stream finishes. [mode] scripts failures.
final class EchoProvider implements CloudAsrProvider {
  const EchoProvider({this.mode = 'ok', this.maxFileMs, this.failFirstFile = false});
  final String mode;
  final int? maxFileMs;
  final bool failFirstFile;

  @override
  CloudAsrInfo get info => CloudAsrInfo(
    id: 'soniox',
    fields: const [CloudField(CloudFieldKeys.apiKey)],
    languages: const {'en'},
    consoleUrl: Uri.parse('https://example.invalid/console'),
    maxFileMs: maxFileMs,
  );

  @override
  List<String> hosts(CloudCredentials credentials) => const ['example.invalid'];

  @override
  Future<void> verify(CloudCredentials credentials) async {}

  @override
  Future<CloudAsrStream> openStream(
    CloudCredentials credentials,
    CloudStreamOptions options,
  ) async {
    if (mode == 'unauthorized' || credentials['apiKey'] != 'k') {
      throw const CloudAsrError(CloudAsrErrorKind.unauthorized, 'Key refused.', statusCode: 401);
    }
    return _EchoStream();
  }

  @override
  Future<List<CloudSegment>> transcribeFile(
    CloudCredentials credentials,
    CloudFileRequest request, {
    void Function(double progress)? onProgress,
    CloudCancelToken? cancel,
  }) async {
    cancel?.check();
    if (mode == 'quota') {
      throw const CloudAsrError(CloudAsrErrorKind.quotaExceeded, 'No balance.');
    }
    if (maxFileMs != null && request.durationMs > maxFileMs!) {
      throw const CloudAsrError(CloudAsrErrorKind.audioTooLong, 'Too long.');
    }
    onProgress?.call(.5);
    return [
      CloudSegment(
        id: '0',
        text: 'piece of ${request.durationMs} ms',
        startMs: 100,
        endMs: request.durationMs - 100,
        words: const [CloudWord('piece', 100, 300)],
      ),
    ];
  }
}

final class _EchoStream implements CloudAsrStream {
  final _segments = StreamController<CloudSegment>();
  int _samples = 0;
  @override
  Stream<CloudSegment> get segments => _segments.stream;
  @override
  void addPcm(Uint8List pcm16le) {
    _samples += pcm16le.length ~/ 2;
    final words = _samples ~/ 16000;
    if (words > 0) {
      _segments.add(
        CloudSegment(
          id: 'line',
          text: List.filled(words, 'word').join(' '),
          startMs: 0,
          endMs: _samples ~/ 16,
          isFinal: false,
        ),
      );
    }
  }

  @override
  Future<void> finish({Duration timeout = const Duration(seconds: 10)}) async {
    _segments.add(
      CloudSegment(
        id: 'line',
        text: 'final ${_samples ~/ 16} ms',
        startMs: 0,
        endMs: _samples ~/ 16,
        words: [CloudWord('final', 0, 200)],
      ),
    );
    await _segments.close();
  }

  @override
  Future<void> cancel() => _segments.close();
}

void main() {
  group('CloudLiveRelay', () {
    late List<Object> out;
    late List<DrivenStream> streams;
    late List<Object> openErrors;
    late CloudLiveRelay relay;

    setUp(() {
      out = [];
      streams = [];
      openErrors = [];
      relay = CloudLiveRelay(
        open: () async {
          if (openErrors.isNotEmpty) throw openErrors.removeAt(0);
          final s = DrivenStream();
          streams.add(s);
          return s;
        },
        segmentPrefix: 'p',
        backendId: 'cloud.test',
        send: out.add,
        backoff: (_) => const Duration(milliseconds: 5),
        maxBufferMs: 2000,
      );
    });

    test('sends 100 ms pieces and maps partials and finals to capture time', () async {
      await relay.connect();
      relay.accept(tone(40));
      expect(streams.single.sent, isEmpty, reason: 'waits for 100 ms');
      relay.accept(tone(80));
      expect(streams.single.sent, [1920]);
      streams.single
        ..emit(const CloudSegment(id: '1', text: 'hel', startMs: 10, endMs: 60, isFinal: false))
        ..emit(
          const CloudSegment(
            id: '1',
            text: 'hello ',
            startMs: 10,
            endMs: 110,
            words: [CloudWord('hello', 10, 110)],
          ),
        );
      await settle();
      final partial = out.whereType<AsrPartial>().single;
      final last = out.whereType<AsrFinal>().single;
      expect(partial.segmentId, last.segmentId, reason: 'a partial and its final share the id');
      expect(last.text, 'hello');
      expect((last.startMs, last.endMs), (10, 110));
      expect(last.words!.single.endMs, 110);
    });

    test('a stream ended by the service is replaced at once and keeps the clock', () async {
      await relay.connect();
      relay.accept(tone(1000));
      streams.first.fail(const CloudAsrError(CloudAsrErrorKind.sessionEnded, 'limit'));
      await settle();
      expect(streams, hasLength(2));
      relay.accept(tone(500));
      streams[1].emit(const CloudSegment(id: '1', text: 'later', startMs: 100, endMs: 300));
      await settle();
      final later = out.whereType<AsrFinal>().single;
      expect(later.startMs, 1100, reason: 'second stream starts at 1000 ms of capture');
      expect(later.endMs, 1300);
      expect(later.segmentId, isNot(startsWith('p-1-')));
    });

    test('the last partial of a dropped stream is kept as a final', () async {
      await relay.connect();
      relay.accept(tone(200));
      streams.first.emit(
        const CloudSegment(id: '7', text: 'half a line', startMs: 0, endMs: 150, isFinal: false),
      );
      await settle();
      streams.first.fail(const CloudAsrError(CloudAsrErrorKind.network, 'reset'));
      await settle();
      expect(out.whereType<AsrFinal>().single.text, 'half a line');
    });

    test('network failures retry with buffered audio; overflow becomes a gap', () async {
      await relay.connect();
      openErrors.addAll([
        const CloudAsrError(CloudAsrErrorKind.network, 'down'),
        const CloudAsrError(CloudAsrErrorKind.network, 'down'),
      ]);
      streams.first.fail(const CloudAsrError(CloudAsrErrorKind.network, 'reset'));
      await Future<void>.delayed(Duration.zero);
      relay.accept(tone(2500)); // more than the 2 s buffer while offline
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(streams, hasLength(2));
      final gap = out.whereType<AsrGap>().single;
      expect(gap.startMs, 0);
      expect(gap.endMs, 500);
      expect(streams[1].samples, 2000 * 16, reason: 'the kept 2 s are sent on reconnect');
      streams[1].emit(const CloudSegment(id: '1', text: 'x', startMs: 0, endMs: 10));
      await settle();
      expect(out.whereType<AsrFinal>().single.startMs, 500);
    });

    test('a refused key ends the session with a failure', () async {
      openErrors.add(const CloudAsrError(CloudAsrErrorKind.unauthorized, 'bad key'));
      await expectLater(
        relay.connect(),
        throwsA(isA<AsrFailure>().having((f) => f.reason, 'reason', AsrFailureReason.unauthorized)),
      );

      await relay.connect();
      streams.single.fail(const CloudAsrError(CloudAsrErrorKind.quotaExceeded, 'no balance'));
      await relay.failed;
      expect(out.whereType<AsrFailure>().single.reason, AsrFailureReason.quotaExceeded);
    });

    test('gives up after repeated failed reconnects', () async {
      await relay.connect();
      openErrors.addAll(List.filled(10, const CloudAsrError(CloudAsrErrorKind.network, 'down')));
      streams.first.fail(const CloudAsrError(CloudAsrErrorKind.network, 'reset'));
      await relay.failed.timeout(const Duration(seconds: 2));
      expect(out.whereType<AsrFailure>().single.reason, AsrFailureReason.network);
    });

    test('lost frames finish the stream and start a new one after the gap', () async {
      await relay.connect();
      relay.accept(tone(300));
      relay.lost(16 * 700);
      await settle();
      expect(streams.first.finished, isTrue);
      expect(streams, hasLength(2));
      final gap = out.whereType<AsrGap>().single;
      expect((gap.startMs, gap.endMs), (300, 1000));
      relay.accept(tone(200));
      streams[1].emit(const CloudSegment(id: '1', text: 'after', startMs: 0, endMs: 100));
      await settle();
      expect(out.whereType<AsrFinal>().single.startMs, 1000);
    });

    test('finish flushes short audio and waits for the last result', () async {
      await relay.connect();
      relay.accept(tone(30));
      streams.single.emit(
        const CloudSegment(id: '1', text: 'tail', startMs: 0, endMs: 30, isFinal: false),
      );
      await settle();
      await relay.finish();
      expect(streams.single.sent, [480]);
      expect(streams.single.finished, isTrue);
      expect(out.whereType<AsrFinal>().single.text, 'tail');
    });
  });

  group('CloudStreamingAsr in a worker isolate', () {
    test('streams pushed audio and finalises on stop', () async {
      final asr = CloudStreamingAsr(const EchoProvider(), credentials: () async => {'apiKey': 'k'});
      final session = await asr.start(const AsrSessionConfig(language: 'en'));
      final events = <AsrEvent>[];
      final sub = session.events.listen(events.add);
      for (var i = 0; i < 25; i++) {
        session.acceptWaveform(tone(100), 16000);
      }
      await session.stop();
      await sub.cancel();
      final last = events.whereType<AsrFinal>().single;
      expect(last.text, 'final 2500 ms');
      expect(events.whereType<AsrPartial>().map((p) => p.segmentId).toSet(), {last.segmentId});
    });

    test('a refused key or no saved key fails the start', () async {
      final refused = CloudStreamingAsr(
        const EchoProvider(),
        credentials: () async => {'apiKey': 'wrong'},
      );
      await expectLater(
        refused.start(const AsrSessionConfig(language: 'en')),
        throwsA(isA<AsrFailure>().having((f) => f.reason, 'reason', AsrFailureReason.unauthorized)),
      );
      final missing = CloudStreamingAsr(const EchoProvider(), credentials: () async => null);
      await expectLater(
        missing.start(const AsrSessionConfig(language: 'en')),
        throwsA(isA<AsrFailure>()),
      );
    });
  });

  group('cloud file transcription', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('cloud-file'));
    tearDown(() => dir.deleteSync(recursive: true));

    File pcmFile(Float32List samples) =>
        File('${dir.path}/audio.f32')..writeAsBytesSync(samples.buffer.asUint8List());

    test('pieces respect the limit and cut at the quietest moment', () {
      // 25 s of tone with silence at 8.0–8.4 s and 17–17.4 s.
      final samples = tone(25000);
      for (final at in [8000, 17000]) {
        samples.fillRange(at * 16, (at + 400) * 16, 0);
      }
      final cuts = cloudCutPoints(samples, 10000);
      expect(cuts, hasLength(2));
      expect(cuts[0] / 16, inInclusiveRange(8000, 8400));
      expect((cuts[1] - cuts[0]) / 16, lessThanOrEqualTo(10000));
      expect(cuts[1] / 16, inInclusiveRange(17000, 17400));
      expect(cloudChunkMs(const EchoProvider(maxFileMs: 60000).info), 60000);
      expect(cloudChunkMs(const EchoProvider().info), CloudFileTranscriber.maxChunkMs);
    });

    test('times become offsets into the whole file', () async {
      final segments = <TranscriptSegment>[];
      final progress = <double>[];
      await transcribeCloudPcm(
        const EchoProvider(maxFileMs: 4000),
        {'apiKey': 'k'},
        pcmFile(tone(10000)),
        language: 'en',
        wordTimestamps: true,
        cancel: CloudCancelToken(),
        onSegment: segments.add,
        onProgress: progress.add,
      );
      expect(segments, hasLength(3));
      var expectedStart = 0;
      for (final s in segments) {
        expect(s.startMs, greaterThan(expectedStart));
        expect(s.words!.single.startMs, s.startMs);
        expectedStart = s.endMs;
      }
      expect(segments.last.endMs, 10000 - 100);
      expect(progress.last, 1);
      expect(progress, orderedEquals([...progress]..sort()));
    });

    test('a refused request stops the job with its reason', () async {
      await expectLater(
        transcribeCloudPcm(
          const EchoProvider(mode: 'quota'),
          {'apiKey': 'k'},
          pcmFile(tone(2000)),
          language: 'en',
          wordTimestamps: true,
          cancel: CloudCancelToken(),
          onSegment: (_) {},
          onProgress: (_) {},
        ),
        throwsA(
          isA<CloudAsrError>().having((e) => e.kind, 'kind', CloudAsrErrorKind.quotaExceeded),
        ),
      );
    });

    test('the transcriber decodes, recognises in a worker and deletes the PCM', () async {
      final pcm = pcmFile(tone(3000));
      final decoder = _FileDecoder(pcm.path);
      final transcriber = CloudFileTranscriber(
        const EchoProvider(),
        credentials: () async => {'apiKey': 'k'},
        decoder: () => decoder,
      );
      final job = transcriber.transcribe(
        '/media.m4a',
        const FileTranscriptionOptions(language: 'en'),
      );
      final result = await job.result;
      expect(result.backendId, 'cloud.soniox');
      expect(result.segments.single.text, 'piece of 3000 ms');
      expect(pcm.existsSync(), isFalse, reason: 'the temporary PCM is deleted');

      final failing = CloudFileTranscriber(
        const EchoProvider(mode: 'quota'),
        credentials: () async => {'apiKey': 'k'},
        decoder: () => _FileDecoder(pcmFile(tone(1000)).path),
      );
      await expectLater(
        failing.transcribe('/media.m4a', const FileTranscriptionOptions(language: 'en')).result,
        throwsA(
          isA<AsrFailure>().having((f) => f.reason, 'reason', AsrFailureReason.quotaExceeded),
        ),
      );
    });

    test('cancel ends the job as cancelled', () async {
      final transcriber = CloudFileTranscriber(
        const EchoProvider(),
        credentials: () async => {'apiKey': 'k'},
        decoder: () => _FileDecoder(pcmFile(tone(1000)).path),
      );
      final job = transcriber.transcribe(
        '/media.m4a',
        const FileTranscriptionOptions(language: 'en'),
      );
      final cancelled = job.cancel();
      await expectLater(job.result, throwsA(isA<TranscriptionCancelled>()));
      await cancelled;
    });
  });

  group('registration and credentials', () {
    test('every provider becomes a cloud backend that needs opt-in', () async {
      final probe = FakeProbes.macos(const OsVersion(14, 2));
      final platform = fakeTinglangPlatform(probe);
      registerCloudBackends(platform, providers: const [EchoProvider()]);
      expect(platform.liveAsr.byId('cloud.soniox'), isNotNull);
      expect(platform.fileAsr.byId('cloud.soniox'), isNotNull);
      expect(platform.liveAsr.byId('cloud.soniox')!.create(), isA<CloudStreamingAsr>());
      expect(platform.fileAsr.byId('cloud.soniox')!.create(), isA<CloudFileTranscriber>());
      expect(
        platform.liveAsr.pick(await platform.probe(), 'cloud.soniox').preferredAvailability,
        isA<NeedsOptIn>(),
      );
      platform.enabledCloudBackends = {'cloud.soniox'};
      expect(platform.liveAsr.pick(await platform.probe(), 'cloud.soniox').id, 'cloud.soniox');
    });

    test('credentials are one JSON entry per service in the secret store', () async {
      final store = InMemorySecretStore();
      final secrets = CloudAsrSecrets(() => store);
      expect(await secrets.read('tencent'), isNull);
      await secrets.write('tencent', {'appId': '1', 'secretKey': 's'});
      expect(await store.read('asr:tencent'), contains('"secretKey"'));
      expect(await secrets.read('tencent'), {'appId': '1', 'secretKey': 's'});
      await store.write('asr:broken', 'not json');
      expect(await secrets.read('broken'), isNull);
      await secrets.delete('tencent');
      expect(await secrets.read('tencent'), isNull);
    });
  });

  test('the shared backends include every cloud service with a spec', () {
    final ids = {for (final p in CloudAsrProviders.all) 'cloud.${p.info.id}'};
    final specs = {for (final s in BackendCatalog.cloudAsr) s.id};
    expect(specs.containsAll(ids), isTrue, reason: 'add a BackendSpec for each provider');
    expect(math.max(ids.length, 0), ids.length);
  });
}

/// A decoder whose "decoded" file already exists.
final class _FileDecoder implements MediaDecoder {
  _FileDecoder(this.pcmPath);
  final String pcmPath;
  @override
  Future<MediaInfo> inspect(String path) async =>
      const MediaInfo(durationMs: 3000, hasVideo: false, hasAudio: true);
  @override
  Stream<Float32List> decodePcm(String path, {int sampleRate = 16000}) => const Stream.empty();
  @override
  Future<String> decodeToFile(String path, {int sampleRate = 16000}) async => pcmPath;
}

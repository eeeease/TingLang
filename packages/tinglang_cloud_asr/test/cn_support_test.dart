import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:tinglang_cloud_asr/src/providers/cn_support.dart';
import 'package:tinglang_cloud_asr/src/providers/dashscope.dart';
import 'package:tinglang_cloud_asr/src/providers/tencent.dart';
import 'package:tinglang_cloud_asr/src/providers/xfyun.dart';
import 'package:tinglang_cloud_asr/tinglang_cloud_asr.dart';

import 'support/cn_fakes.dart';

final class _CountingOverrides extends HttpOverrides {
  var clients = 0;
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    clients++;
    return super.createHttpClient(context);
  }
}

void main() {
  test('constructing the China providers, info and hosts open nothing', () async {
    final overrides = _CountingOverrides();
    await HttpOverrides.runWithHttpOverrides(() async {
      final providers = <CloudAsrProvider>[TencentCloudAsr(), DashScopeAsr(), XfyunAsr()];
      for (final p in providers) {
        expect(p.info.id, isNotEmpty);
        expect(p.hosts(const {CloudFieldKeys.region: 'intl'}), isNotEmpty);
      }
      expect(overrides.clients, 0);
      // The counter does see a real call.
      final port = await closedPort();
      await expectLater(
        DashScopeAsr(httpBaseUrl: Uri.parse('http://127.0.0.1:$port'))
            .verify(const {CloudFieldKeys.apiKey: 'k'}),
        throwsA(isA<CloudAsrError>()),
      );
      expect(overrides.clients, 1);
    }, overrides);
  });

  test('base URLs must be wss/https or explicit ws/http', () {
    expect(() => TencentCloudAsr(liveBaseUrl: Uri.parse('ftp://x')), throwsArgumentError);
    expect(() => DashScopeAsr(httpBaseUrl: Uri.parse('ws://x')), throwsArgumentError);
    expect(() => XfyunAsr(fileBaseUrl: Uri.parse('wss://x')), throwsArgumentError);
  });

  test('PCM is re-framed exactly, remainder at flush', () {
    final framer = PcmFramer(1280);
    final input = Uint8List.fromList(List.generate(3000, (i) => i & 0xff));
    final out = <int>[];
    final sizes = <int>[];
    for (final chunk in [input.sublist(0, 700), input.sublist(700, 2000), input.sublist(2000)]) {
      for (final f in framer.add(chunk)) {
        sizes.add(f.length);
        out.addAll(f);
      }
    }
    final rest = framer.flush()!;
    out.addAll(rest);
    expect(sizes, [1280, 1280]);
    expect(rest.length, 440);
    expect(out, input);
    expect(framer.flush(), isNull);
  });

  test('percent-encoding keeps only unreserved characters', () {
    expect(percentEncode('2025-09-04T15:38:07+0800'), '2025-09-04T15%3A38%3A07%2B0800');
    expect(percentEncode('a/b=c d~_.-'), 'a%2Fb%3Dc%20d~_.-');
    expect(percentEncode('分'), '%E5%88%86');
  });

  test('redaction removes every credential value and clips long text', () {
    const creds = {CloudFieldKeys.apiKey: 'sk-abcdef', CloudFieldKeys.region: 'cn'};
    expect(redact('bad key sk-abcdef for cn', creds), 'bad key *** for cn');
    expect(redact('x' * 400, creds).length, lessThanOrEqualTo(301));
  });

  test('words outside their segment are rejected as a whole', () {
    const inside = [CloudWord('a', 100, 200), CloudWord('b', 200, 300)];
    expect(wordsInside(inside, 100, 300), inside);
    expect(wordsInside(const [CloudWord('a', 0, 100)], 5000, 6000), isNull);
    expect(wordsInside(const [], 0, 10), isNull);
  });

  test('UUIDs are version 4', () {
    final id = uuidV4(Random(1));
    expect(
      id,
      matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')),
    );
  });
}

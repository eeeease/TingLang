import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:tinglang_cloud_asr/tinglang_cloud_asr.dart';

void main() {
  test('float samples become clipped 16-bit PCM', () {
    final pcm = pcm16FromFloat32(Float32List.fromList([0, 1, -1, 2, -2, 0.5]));
    final view = ByteData.sublistView(pcm);
    expect([for (var i = 0; i < 6; i++) view.getInt16(i * 2, Endian.little)], [
      0,
      32767,
      -32767,
      32767,
      -32768,
      16384,
    ]);
  });

  test('a WAV header describes 16 kHz mono 16-bit PCM', () {
    final pcm = Uint8List(32000); // one second
    final wav = wavFromPcm16(pcm);
    final h = ByteData.sublistView(wav);
    expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
    expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
    expect(h.getUint32(4, Endian.little), 36 + 32000);
    expect(h.getUint16(22, Endian.little), 1);
    expect(h.getUint32(24, Endian.little), 16000);
    expect(h.getUint16(34, Endian.little), 16);
    expect(h.getUint32(40, Endian.little), 32000);
    expect(wav.length, 44 + 32000);
    expect(pcm16DurationMs(pcm.length), 1000);
  });

  test('base language and required fields', () {
    expect(baseLanguage('en-GB'), 'en');
    expect(baseLanguage('zh-Hans'), 'zh');
    expect(baseLanguage('ja'), 'ja');
    expect(requireField({'apiKey': ' k '}, CloudFieldKeys.apiKey), 'k');
    expect(
      () => requireField({'apiKey': 'secret-value'}, CloudFieldKeys.secretKey),
      throwsA(
        isA<CloudAsrError>()
            .having((e) => e.kind, 'kind', CloudAsrErrorKind.unauthorized)
            .having((e) => e.message, 'message', isNot(contains('secret-value'))),
      ),
    );
  });

  test('every provider id is unique', () {
    final ids = [for (final p in CloudAsrProviders.all) p.info.id];
    expect(ids.toSet().length, ids.length);
  });
}

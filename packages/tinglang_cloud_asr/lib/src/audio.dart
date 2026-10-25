import 'dart:typed_data';

/// Float samples (−1…1) to 16-bit little-endian PCM, clipping.
Uint8List pcm16FromFloat32(Float32List samples) {
  final out = ByteData(samples.length * 2);
  for (var i = 0; i < samples.length; i++) {
    final v = (samples[i] * 32767).round().clamp(-32768, 32767);
    out.setInt16(i * 2, v, Endian.little);
  }
  return out.buffer.asUint8List();
}

/// A complete mono 16-bit PCM WAV file around [pcm16le].
Uint8List wavFromPcm16(Uint8List pcm16le, {int sampleRate = 16000}) {
  final header = ByteData(44);
  void ascii(int offset, String s) {
    for (var i = 0; i < s.length; i++) {
      header.setUint8(offset + i, s.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  header.setUint32(4, 36 + pcm16le.length, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  header.setUint32(16, 16, Endian.little); // PCM chunk size
  header.setUint16(20, 1, Endian.little); // PCM
  header.setUint16(22, 1, Endian.little); // mono
  header.setUint32(24, sampleRate, Endian.little);
  header.setUint32(28, sampleRate * 2, Endian.little); // byte rate
  header.setUint16(32, 2, Endian.little); // block align
  header.setUint16(34, 16, Endian.little); // bits per sample
  ascii(36, 'data');
  header.setUint32(40, pcm16le.length, Endian.little);
  return Uint8List(44 + pcm16le.length)
    ..setRange(0, 44, header.buffer.asUint8List())
    ..setRange(44, 44 + pcm16le.length, pcm16le);
}

/// Milliseconds of 16-bit mono PCM.
int pcm16DurationMs(int bytes, {int sampleRate = 16000}) => bytes * 1000 ~/ (2 * sampleRate);

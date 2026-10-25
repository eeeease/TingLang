import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinglang_native/src/shared/pcm_ring.dart';

Float32List ramp(int start, int n) =>
    Float32List.fromList([for (var i = 0; i < n; i++) start + i * 1.0]);

void main() {
  test('header layout matches the native ABI', () {
    expect(sizeOf<PcmRingHeader>(), 56);
    final ring = DartPcmRing(capacity: 64);
    final bytes = Pointer<Uint8>.fromAddress(ring.address).asTypedList(56).buffer.asByteData();
    expect(bytes.getUint32(0, Endian.little), 0x544C5052);
    expect(bytes.getUint32(4, Endian.little), 1);
    expect(bytes.getInt32(40, Endian.little), 16000);
    expect(bytes.getInt32(44, Endian.little), 64);
    ring.dispose();
  });

  test('rejects a wrong magic or version', () {
    final header = calloc<PcmRingHeader>();
    addTearDown(() => calloc.free(header));
    header.ref.magic = 0x12345678;
    expect(() => PcmRingReader.attach(header.address), throwsStateError);
    header.ref
      ..magic = pcmRingMagic
      ..version = 2;
    expect(() => PcmRingReader.attach(header.address), throwsStateError);
    expect(() => PcmRingReader.attach(0), throwsArgumentError);
  });

  test('reads across the wrap-around in order', () {
    final ring = DartPcmRing(capacity: 10);
    final reader = PcmRingReader.attach(ring.address, maxRead: 6);
    expect(reader.sampleRate, 16000);
    expect(reader.capacity, 10);
    final into = Float32List(8);
    ring.write(ramp(0, 7));
    expect(reader.read(into), 6, reason: 'bounded by maxRead');
    expect(into.sublist(0, 6), ramp(0, 6));
    ring.write(ramp(7, 8)); // tail wraps past the end of the buffer
    expect(reader.read(into), 6);
    expect(into.sublist(0, 6), ramp(6, 6));
    expect(reader.read(into), 3);
    expect(into.sublist(0, 3), ramp(12, 3));
    expect(reader.read(into), 0);
    expect(reader.dropped, 0);
    reader.close();
    ring.dispose();
  });

  test('overflow drops the oldest samples and counts them', () {
    final ring = DartPcmRing(capacity: 8);
    final reader = PcmRingReader.attach(ring.address);
    ring.write(ramp(0, 12));
    expect(reader.dropped, 4);
    final into = Float32List(16);
    expect(reader.read(into), 8);
    expect(into.sublist(0, 8), ramp(4, 8));
    reader.close();
    ring.dispose();
  });

  test('returns -1 once closed and drained, and after close', () {
    final ring = DartPcmRing(capacity: 8);
    final reader = PcmRingReader.attach(ring.address);
    final into = Float32List(8);
    ring.write(ramp(0, 3));
    ring.closeProducer();
    expect(reader.read(into), 3);
    expect(reader.read(into), -1);
    reader.close();
    expect(ring.released, isTrue);
    expect(reader.read(into), -1);
    reader.close(); // idempotent
    ring.dispose();
  });

  test('wake-ups are delivered; close clears the wake before releasing', () async {
    final ring = DartPcmRing(capacity: 4000, wakeThreshold: 800);
    final woke = <int>[];
    final reader = PcmRingReader.attach(ring.address, onWake: woke.add);
    expect(ring.hasWake, isTrue);
    ring.write(Float32List(500));
    ring.write(Float32List(500)); // crosses the threshold
    await pumpEventQueue();
    expect(woke, [1000]);
    final into = Float32List(2000);
    expect(reader.read(into), 1000);
    reader.close();
    expect(ring.hasWake, isFalse);
    expect(ring.released, isTrue);
    ring.write(Float32List(1000)); // no callback left to call
    await pumpEventQueue();
    expect(woke, [1000]);
    ring.dispose();
  });
}

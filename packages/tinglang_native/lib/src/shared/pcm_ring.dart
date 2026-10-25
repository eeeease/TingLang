import 'dart:ffi';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

typedef PcmRingReadNative = Int32 Function(
  Pointer<PcmRingHeader> ring,
  Pointer<Float> dst,
  Int32 max,
);
typedef PcmRingWakeNative = Void Function(Int32 available);
typedef PcmRingSetWakeNative = Void Function(
  Pointer<PcmRingHeader> ring,
  Pointer<NativeFunction<PcmRingWakeNative>> wake,
);
typedef PcmRingReleaseNative = Void Function(Pointer<PcmRingHeader> ring);
typedef PcmRingDroppedNative = Int64 Function(Pointer<PcmRingHeader> ring);

/// `'TLPR'`, the first field of every ring header.
const pcmRingMagic = 0x544C5052;

/// The header layout this reader understands.
const pcmRingVersion = 1;

/// Header of the native PCM ring (layout version 1, little-endian, 8-byte
/// aligned). The capture side (Swift, later C++) allocates it and passes its
/// address to Dart as an int; the functions take the header address as
/// their `ring` argument.
///
/// | offset | field |
/// |---|---|
/// | 0 | `uint32 magic` = `'TLPR'` (0x544C5052) |
/// | 4 | `uint32 version` = 1 |
/// | 8 | `int32 read(ring, float* dst, int32 max)`: samples copied, -1 once closed and drained |
/// | 16 | `void setWake(ring, void (*wake)(int32 available))`; NULL clears |
/// | 24 | `void release(ring)`: the reader is done (called once) |
/// | 32 | `int64 dropped(ring)`: samples lost to overflow so far |
/// | 40 | `int32 sampleRate` |
/// | 44 | `int32 capacity` (samples) |
/// | 48 | `void* context` (owned by the capture side) |
final class PcmRingHeader extends Struct {
  @Uint32()
  external int magic;
  @Uint32()
  external int version;
  external Pointer<NativeFunction<PcmRingReadNative>> read;
  external Pointer<NativeFunction<PcmRingSetWakeNative>> setWake;
  external Pointer<NativeFunction<PcmRingReleaseNative>> release;
  external Pointer<NativeFunction<PcmRingDroppedNative>> dropped;
  @Int32()
  external int sampleRate;
  @Int32()
  external int capacity;
  external Pointer<Void> context;
}

/// Reads a native PCM ring inside the ASR worker isolate. PCM is copied from
/// native memory straight into the worker; it never crosses the root
/// isolate.
///
/// The wake-up is a `NativeCallable.listener`, so the producer may call it
/// from its audio thread (under its lock): Dart runs [onWake] later on this
/// isolate's event loop.
final class PcmRingReader {
  PcmRingReader._(this._ring, this._buffer, this._bufferSamples, this._wake)
    : _read = _ring.ref.read.asFunction(),
      _setWake = _ring.ref.setWake.asFunction(),
      _release = _ring.ref.release.asFunction(),
      _dropped = _ring.ref.dropped.asFunction();

  /// Attaches to the ring at [address] after checking magic and version.
  /// [maxRead] bounds one [read] (default 1 s at 16 kHz).
  factory PcmRingReader.attach(
    int address, {
    void Function(int available)? onWake,
    int maxRead = 16000,
  }) {
    if (address == 0) throw ArgumentError.value(address, 'address', 'null ring');
    final ring = Pointer<PcmRingHeader>.fromAddress(address);
    final header = ring.ref;
    if (header.magic != pcmRingMagic) {
      throw StateError('Not a PCM ring (magic 0x${header.magic.toRadixString(16)}).');
    }
    if (header.version != pcmRingVersion) {
      throw StateError('Unsupported PCM ring version ${header.version}.');
    }
    final size = math.max(1, maxRead);
    final wake = onWake == null ? null : NativeCallable<PcmRingWakeNative>.listener(onWake);
    final reader = PcmRingReader._(ring, calloc<Float>(size), size, wake);
    if (wake != null) reader._setWake(ring, wake.nativeFunction);
    return reader;
  }

  final Pointer<PcmRingHeader> _ring;
  final Pointer<Float> _buffer;
  final int _bufferSamples;
  final NativeCallable<PcmRingWakeNative>? _wake;
  final int Function(Pointer<PcmRingHeader>, Pointer<Float>, int) _read;
  final void Function(Pointer<PcmRingHeader>, Pointer<NativeFunction<PcmRingWakeNative>>) _setWake;
  final void Function(Pointer<PcmRingHeader>) _release;
  final int Function(Pointer<PcmRingHeader>) _dropped;
  bool _closed = false;

  int get sampleRate => _ring.ref.sampleRate;
  int get capacity => _ring.ref.capacity;
  bool get isClosed => _closed;

  /// Copies up to `into.length` samples (at most `maxRead`) into [into].
  /// Returns the count (0 when empty), or -1 when the producer closed the
  /// ring and everything was read, or after [close].
  int read(Float32List into) {
    if (_closed) return -1;
    final max = math.min(into.length, _bufferSamples);
    final n = _read(_ring, _buffer, max);
    if (n > 0) into.setRange(0, n, _buffer.asTypedList(n));
    return n;
  }

  /// Total samples the producer dropped because the reader fell behind.
  int get dropped => _closed ? 0 : _dropped(_ring);

  /// Clears the wake-up, closes the callable, then releases the ring. The
  /// header must not be touched afterwards (the producer may free it).
  void close() {
    if (_closed) return;
    _closed = true;
    final wake = _wake;
    if (wake != null) {
      _setWake(_ring, nullptr);
      wake.close();
    }
    _release(_ring);
    calloc.free(_buffer);
  }
}

/// A ring with the native ABI implemented in Dart, for tests of
/// [PcmRingReader] and of code that takes a ring address. Its functions are
/// `NativeCallable.isolateLocal`, so the reader must run on the isolate that
/// created it. Overflow drops the oldest samples (like the capture side).
final class DartPcmRing {
  DartPcmRing({this.capacity = 16000, this.sampleRate = 16000, this.wakeThreshold = 800})
    : _samples = Float32List(capacity) {
    _readCallable = NativeCallable<PcmRingReadNative>.isolateLocal(
      _readImpl,
      exceptionalReturn: -1,
    );
    _setWakeCallable = NativeCallable<PcmRingSetWakeNative>.isolateLocal(_setWakeImpl);
    _releaseCallable = NativeCallable<PcmRingReleaseNative>.isolateLocal(_releaseImpl);
    _droppedCallable = NativeCallable<PcmRingDroppedNative>.isolateLocal(
      _droppedImpl,
      exceptionalReturn: 0,
    );
    _header = calloc<PcmRingHeader>();
    _header.ref
      ..magic = pcmRingMagic
      ..version = pcmRingVersion
      ..read = _readCallable.nativeFunction
      ..setWake = _setWakeCallable.nativeFunction
      ..release = _releaseCallable.nativeFunction
      ..dropped = _droppedCallable.nativeFunction
      ..sampleRate = sampleRate
      ..capacity = capacity;
  }

  final int capacity, sampleRate;

  /// The producer calls the wake-up once at least this many new samples
  /// arrived since the last call.
  final int wakeThreshold;
  final Float32List _samples;
  late final Pointer<PcmRingHeader> _header;
  late final NativeCallable<PcmRingReadNative> _readCallable;
  late final NativeCallable<PcmRingSetWakeNative> _setWakeCallable;
  late final NativeCallable<PcmRingReleaseNative> _releaseCallable;
  late final NativeCallable<PcmRingDroppedNative> _droppedCallable;
  void Function(int)? _wake;
  int _head = 0, _size = 0, _sinceWake = 0, _dropped = 0;
  bool _producerClosed = false, released = false, _freed = false;

  /// Header address, as the capture side would report it.
  int get address => _header.address;
  int get available => _size;
  int get droppedSamples => _dropped;
  bool get hasWake => _wake != null;

  /// Producer side: appends [block], dropping the oldest samples on overflow.
  void write(Float32List block) {
    for (final sample in block) {
      if (_size == capacity) {
        _head = (_head + 1) % capacity;
        _size--;
        _dropped++;
      }
      _samples[(_head + _size) % capacity] = sample;
      _size++;
    }
    _sinceWake += block.length;
    final wake = _wake;
    if (wake != null && _sinceWake >= wakeThreshold) {
      _sinceWake = 0;
      wake(_size);
    }
  }

  /// Producer side: no more samples; `read` returns -1 once drained.
  void closeProducer() => _producerClosed = true;

  /// Frees the header and callables (after the reader released it).
  void dispose() {
    if (_freed) return;
    _freed = true;
    _readCallable.close();
    _setWakeCallable.close();
    _releaseCallable.close();
    _droppedCallable.close();
    calloc.free(_header);
  }

  int _readImpl(Pointer<PcmRingHeader> ring, Pointer<Float> dst, int max) {
    if (_size == 0) return _producerClosed ? -1 : 0;
    final n = math.min(max, _size);
    final out = dst.asTypedList(n);
    for (var i = 0; i < n; i++) {
      out[i] = _samples[(_head + i) % capacity];
    }
    _head = (_head + n) % capacity;
    _size -= n;
    return n;
  }

  void _setWakeImpl(Pointer<PcmRingHeader> ring, Pointer<NativeFunction<PcmRingWakeNative>> wake) {
    _wake = wake == nullptr ? null : wake.asFunction<void Function(int)>();
    _sinceWake = 0;
  }

  void _releaseImpl(Pointer<PcmRingHeader> ring) => released = true;

  int _droppedImpl(Pointer<PcmRingHeader> ring) => _dropped;
}

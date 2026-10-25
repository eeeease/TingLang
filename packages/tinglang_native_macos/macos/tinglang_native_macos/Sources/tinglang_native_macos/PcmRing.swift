import Foundation
import os

/// `int32 read(void* ring, float* dst, int32 max)`: samples copied (≥0), or
/// -1 once the ring is closed and drained.
typealias PcmRingRead = @convention(c) (UnsafeMutableRawPointer?, UnsafeMutablePointer<Float>?, Int32) -> Int32
/// `void wake(int32 available)`, set by the reader (a Dart
/// `NativeCallable.listener`).
typealias PcmRingWake = @convention(c) (Int32) -> Void
/// `void setWake(void* ring, wake)`; NULL clears it. After it returns the old
/// callback is never called again.
typealias PcmRingSetWake = @convention(c) (UnsafeMutableRawPointer?, PcmRingWake?) -> Void
/// `void release(void* ring)`: the reader is done (called once).
typealias PcmRingRelease = @convention(c) (UnsafeMutableRawPointer?) -> Void
/// `int64 dropped(void* ring)`: samples dropped on overflow so far.
typealias PcmRingDropped = @convention(c) (UnsafeMutableRawPointer?) -> Int64

/// Single-producer/single-consumer ring of 16 kHz mono f32 that a Dart worker
/// isolate reads through FFI, so PCM never crosses Pigeon or the root
/// isolate. The C-visible header (little-endian, 8-byte aligned, version 1):
///
/// | offset | type   | field                                  |
/// |--------|--------|----------------------------------------|
/// | 0      | uint32 | magic `0x544C5052` ('TLPR')            |
/// | 4      | uint32 | version = 1                            |
/// | 8      | fnptr  | read                                   |
/// | 16     | fnptr  | setWake                                |
/// | 24     | fnptr  | release                                |
/// | 32     | fnptr  | dropped                                |
/// | 40     | int32  | sampleRate (16000)                     |
/// | 44     | int32  | capacity (samples)                     |
/// | 48     | ptr    | opaque context (this object, retained) |
///
/// Every function takes the header address as `ring`. The writer drops the
/// oldest samples when the reader falls behind and counts them. `wake` is
/// called under the lock whenever ≥ 50 ms of new samples arrived since the
/// last wake, and once more on close. The samples and the header are freed
/// only after both [close] (Swift) and `release` (reader); the lock and
/// counters live as long as this object, so late writes are safely ignored.
final class PcmRing: @unchecked Sendable {
  static let magic: UInt32 = 0x544C_5052
  static let version: UInt32 = 1
  static let headerSize = 56
  /// 50 ms at 16 kHz.
  static let wakeThreshold = 800

  let sampleRate: Int
  let capacity: Int
  /// The header; its address is what Dart receives.
  let header: UnsafeMutableRawPointer

  private let samples: UnsafeMutablePointer<Float>
  private let lockPointer: UnsafeMutablePointer<os_unfair_lock>
  // Guarded by the lock.
  private var written = 0  // total samples ever written
  private var consumed = 0  // total samples read or dropped
  private var droppedTotal: Int64 = 0
  private var sinceWake = 0
  private var wake: PcmRingWake?
  private var closed = false
  private var releasedByReader = false

  init(capacity: Int, sampleRate: Int = 16_000) {
    self.capacity = capacity
    self.sampleRate = sampleRate
    samples = .allocate(capacity: capacity)
    samples.initialize(repeating: 0, count: capacity)
    lockPointer = .allocate(capacity: 1)
    lockPointer.initialize(to: os_unfair_lock())
    header = .allocate(byteCount: Self.headerSize, alignment: 8)
    header.initializeMemory(as: UInt8.self, repeating: 0, count: Self.headerSize)
    header.storeBytes(of: Self.magic.littleEndian, toByteOffset: 0, as: UInt32.self)
    header.storeBytes(of: Self.version.littleEndian, toByteOffset: 4, as: UInt32.self)
    header.storeBytes(of: unsafeBitCast(pcmRingRead, to: UnsafeRawPointer.self), toByteOffset: 8, as: UnsafeRawPointer.self)
    header.storeBytes(of: unsafeBitCast(pcmRingSetWake, to: UnsafeRawPointer.self), toByteOffset: 16, as: UnsafeRawPointer.self)
    header.storeBytes(of: unsafeBitCast(pcmRingRelease, to: UnsafeRawPointer.self), toByteOffset: 24, as: UnsafeRawPointer.self)
    header.storeBytes(of: unsafeBitCast(pcmRingDropped, to: UnsafeRawPointer.self), toByteOffset: 32, as: UnsafeRawPointer.self)
    header.storeBytes(of: Int32(sampleRate).littleEndian, toByteOffset: 40, as: Int32.self)
    header.storeBytes(of: Int32(capacity).littleEndian, toByteOffset: 44, as: Int32.self)
    // The header owns one reference until both sides are done.
    header.storeBytes(of: Unmanaged.passRetained(self).toOpaque(), toByteOffset: 48, as: UnsafeMutableRawPointer.self)
  }

  /// The ring behind a header address handed out by [header].
  static func from(_ header: UnsafeMutableRawPointer) -> PcmRing {
    let context = header.load(fromByteOffset: 48, as: UnsafeMutableRawPointer.self)
    return Unmanaged<PcmRing>.fromOpaque(context).takeUnretainedValue()
  }

  var address: Int64 { Int64(Int(bitPattern: header)) }

  private func locked<T>(_ body: () -> T) -> T {
    os_unfair_lock_lock(lockPointer)
    defer { os_unfair_lock_unlock(lockPointer) }
    return body()
  }

  /// Samples written but not yet read.
  var available: Int { locked { written - consumed } }

  var dropped: Int64 { locked { droppedTotal } }

  /// Producer side (the capture context). Ignored after [close].
  func write(_ source: UnsafePointer<Float>, count: Int) {
    guard count > 0 else { return }
    locked {
      guard !closed else { return }
      var source = source
      var count = count
      if count > capacity {
        // Only the newest `capacity` samples can be kept.
        let skip = count - capacity
        source += skip
        count = capacity
        written += skip
        consumed += skip
        droppedTotal += Int64(skip)
      }
      let overflow = written - consumed + count - capacity
      if overflow > 0 {
        consumed += overflow
        droppedTotal += Int64(overflow)
      }
      let start = written % capacity
      let first = min(count, capacity - start)
      (samples + start).update(from: source, count: first)
      if first < count { samples.update(from: source + first, count: count - first) }
      written += count
      sinceWake += count
      if sinceWake >= Self.wakeThreshold, let wake {
        sinceWake = 0
        wake(Int32(clamping: written - consumed))
      }
    }
  }

  fileprivate func read(_ destination: UnsafeMutablePointer<Float>, max: Int) -> Int32 {
    locked {
      if releasedByReader { return -1 }
      let available = written - consumed
      if available == 0 { return closed ? -1 : 0 }
      let count = min(max, available)
      let start = consumed % capacity
      let first = min(count, capacity - start)
      destination.update(from: samples + start, count: first)
      if first < count { (destination + first).update(from: samples, count: count - first) }
      consumed += count
      return Int32(count)
    }
  }

  fileprivate func setWake(_ callback: PcmRingWake?) {
    locked {
      wake = callback
      sinceWake = 0
    }
  }

  /// Producer is done: the reader drains what is left, then `read` returns
  /// -1. The reader is woken once more so it notices.
  func close() {
    let free: Bool = locked {
      guard !closed else { return false }
      closed = true
      wake?(Int32(clamping: written - consumed))
      return releasedByReader
    }
    if free { deallocate() }
  }

  /// For a ring whose address never reached a reader (open failed).
  func discard() {
    close()
    releaseFromReader()
  }

  fileprivate func releaseFromReader() {
    let free: Bool = locked {
      guard !releasedByReader else { return false }
      releasedByReader = true
      wake = nil
      return closed
    }
    if free { deallocate() }
  }

  /// Called exactly once, by whichever of [close] and `release` comes last.
  private func deallocate() {
    withExtendedLifetime(self) {
      samples.deallocate()
      header.deallocate()
      // Balances passRetained in init.
      Unmanaged.passUnretained(self).release()
    }
  }

  deinit {
    lockPointer.deinitialize(count: 1)
    lockPointer.deallocate()
  }
}

private let pcmRingRead: PcmRingRead = { ring, destination, max in
  guard let ring, let destination, max > 0 else { return 0 }
  return PcmRing.from(ring).read(destination, max: Int(max))
}

private let pcmRingSetWake: PcmRingSetWake = { ring, wake in
  guard let ring else { return }
  PcmRing.from(ring).setWake(wake)
}

private let pcmRingRelease: PcmRingRelease = { ring in
  guard let ring else { return }
  PcmRing.from(ring).releaseFromReader()
}

private let pcmRingDropped: PcmRingDropped = { ring in
  guard let ring else { return 0 }
  return PcmRing.from(ring).dropped
}

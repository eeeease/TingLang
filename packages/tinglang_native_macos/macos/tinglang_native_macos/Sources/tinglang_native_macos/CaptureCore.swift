import AVFoundation
import Foundation

/// A capture source plus what every consumer needs around it: the level
/// meter and the silent-tap watchdog (falls back to ScreenCaptureKit). Shared
/// by LiveCaptionEngine and PortableCapture; works on macOS 14.2+.
final class MeteredCapture: @unchecked Sendable {
  /// `system` or `microphone`.
  let kind: String
  private let onBuffer: (AVAudioPCMBuffer) -> Void
  private let onIssue: (String, String?) -> Void

  private let lock = NSLock()
  private var source: LiveAudioSource?
  private var levelSum: Float = 0
  private var levelCount = 0
  private var heardSound = false
  private var startedAt = Date()
  private var fellBack = false

  init(kind: String, onBuffer: @escaping (AVAudioPCMBuffer) -> Void, onIssue: @escaping (String, String?) -> Void) {
    self.kind = kind
    self.onBuffer = onBuffer
    self.onIssue = onIssue
  }

  var sourceName: String? { lock.withLock { source?.name } }

  func start() throws {
    startedAt = Date()
    if kind.hasPrefix("file:") {
      // Tests only: a local file played in real time instead of a device,
      // so the whole capture → ring → recogniser path runs without
      // permission prompts. Refused unless the process opts in.
      guard ProcessInfo.processInfo.environment["TINGLANG_TEST_CAPTURE_FILES"] == "1" else {
        throw AudioSourceError.unsupportedFormat
      }
      try start(FileAudioSource(path: String(kind.dropFirst("file:".count))))
      return
    }
    try start(kind == "microphone" ? MicrophoneSource() : SystemAudioTap())
  }

  private func start(_ source: LiveAudioSource) throws {
    lock.withLock { self.source = source }
    try source.start { [weak self] buffer in
      self?.meter(buffer)
      self?.onBuffer(buffer)
    }
  }

  func stop() {
    let source: LiveAudioSource? = lock.withLock {
      let source = self.source
      self.source = nil
      return source
    }
    source?.stop()
  }

  private func meter(_ buffer: AVAudioPCMBuffer) {
    guard let data = buffer.floatChannelData, buffer.frameLength > 0 else { return }
    var sum: Float = 0
    let samples = data[0]
    for i in 0..<Int(buffer.frameLength) { sum += samples[i] * samples[i] }
    lock.withLock {
      levelSum += sum / Float(buffer.frameLength)
      levelCount += 1
      if sum > 0 { heardSound = true }
    }
  }

  /// The level (0…1) since the last call, or nil when no audio arrived.
  func takeLevel() -> Double? {
    let rms: Float? = lock.withLock {
      let rms = levelCount > 0 ? sqrt(levelSum / Float(levelCount)) : nil
      levelSum = 0
      levelCount = 0
      return rms
    }
    return rms.map { Double(min(1, $0 * 8)) }
  }

  /// Call about once a second. All-zero tap buffers while something is
  /// playing means the tap is denied or the usage string is missing: switch
  /// to ScreenCaptureKit (once).
  func checkSilentTap() {
    let heard = lock.withLock { heardSound }
    guard !fellBack, kind == "system", !heard, Date().timeIntervalSince(startedAt) > 4,
      SystemAudioTap.outputIsPlaying()
    else { return }
    fellBack = true
    onIssue("silent_tap", "System audio tap delivers silence")
    stop()
    do {
      try start(ScreenCaptureAudioSource())
      onIssue("fallback_screencapture", nil)
    } catch {
      onIssue("tap_failed", error.localizedDescription)
    }
  }
}

/// Converts capture buffers to one fixed format, rebuilding the converter
/// when the input format changes (e.g. after the ScreenCaptureKit fallback).
/// Use from the capture context only.
final class PcmConverter {
  let format: AVAudioFormat
  private let downmix: Bool
  private var converter: AVAudioConverter?

  init(to format: AVAudioFormat, downmix: Bool = false) {
    self.format = format
    self.downmix = downmix
  }

  /// 16 kHz mono Float32, the portable pipeline's format.
  static let speechFormat = AVAudioFormat(
    commonFormat: .pcmFormatFloat32, sampleRate: 16_000, channels: 1, interleaved: false)!

  func reset() { converter = nil }

  func convert(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
    if converter == nil || converter?.inputFormat != buffer.format {
      converter = AVAudioConverter(from: buffer.format, to: format)
      converter?.downmix = downmix
    }
    guard let converter else { return nil }
    let ratio = format.sampleRate / buffer.format.sampleRate
    let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 32
    guard let out = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else { return nil }
    var consumed = false
    var error: NSError?
    converter.convert(to: out, error: &error) { _, status in
      if consumed {
        status.pointee = .noDataNow
        return nil
      }
      consumed = true
      status.pointee = .haveData
      return buffer
    }
    if let error {
      liveLog.error("convert failed: \(error.localizedDescription, privacy: .public)")
      return nil
    }
    return out.frameLength > 0 ? out : nil
  }
}

/// AAC (.m4a, mono, 48 kbit/s) for buffers in [format], so recording and
/// recognition share one clock.
func makeRecorder(path: String, format: AVAudioFormat) throws -> AVAudioFile {
  try AVAudioFile(
    forWriting: URL(fileURLWithPath: path),
    settings: [
      AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: format.sampleRate,
      AVNumberOfChannelsKey: 1, AVEncoderBitRateKey: 48_000,
    ],
    commonFormat: format.commonFormat, interleaved: format.isInterleaved)
}

/// Plays an audio file in real time, 100 ms per buffer, like a capture
/// device (see [MeteredCapture.start]: tests only).
final class FileAudioSource: LiveAudioSource, @unchecked Sendable {
  private let path: String
  private var timer: DispatchSourceTimer?
  init(path: String) { self.path = path }

  var name: String { "file" }

  func start(onBuffer: @escaping (AVAudioPCMBuffer) -> Void) throws {
    let file = try AVAudioFile(forReading: URL(fileURLWithPath: path))
    let frames = AVAudioFrameCount(file.processingFormat.sampleRate / 10)
    let queue = DispatchQueue(label: "dev.eeeease.tinglang.file-capture")
    let timer = DispatchSource.makeTimerSource(queue: queue)
    timer.schedule(deadline: .now(), repeating: .milliseconds(100))
    timer.setEventHandler { [weak self] in
      guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: frames) else { return }
      do { try file.read(into: buffer, frameCount: frames) } catch { buffer.frameLength = 0 }
      if buffer.frameLength == 0 {
        // After the file: silence, like a quiet device.
        buffer.frameLength = frames
        for channel in 0..<Int(buffer.format.channelCount) {
          buffer.floatChannelData?[channel].update(repeating: 0, count: Int(frames))
        }
      }
      if self?.timer != nil { onBuffer(buffer) }
    }
    self.timer = timer
    timer.resume()
  }

  func stop() {
    timer?.cancel()
    timer = nil
  }
}

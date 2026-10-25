import AVFoundation
import Foundation

/// Capture for the portable pipeline (sherpa-onnx in a Dart worker isolate),
/// macOS 14.2+: the tap / ScreenCaptureKit fallback / microphone, converted
/// to 16 kHz mono f32 into a [PcmRing] and, optionally, AAC on the same
/// clock (sample index / 16000 = seconds into the .m4a). Events carry the
/// capture id as `sessionId`: `level` (10 Hz), `stats` (1 Hz), `issue`,
/// `stopped`.
final class PortableCapture: @unchecked Sendable {
  /// Seconds of audio the ring holds before the oldest is dropped.
  static let ringSeconds = 30

  let captureId: String
  let ring: PcmRing
  private let sourceKind: String
  private let recordPath: String?
  private let emit: (LiveEvent) -> Void
  private let level: ((Double) -> Void)?

  private let converter = PcmConverter(to: PcmConverter.speechFormat, downmix: true)
  private var capture: MeteredCapture?
  private var tickTask: Task<Void, Never>?
  // The recorder is written on the capture context and closed on stop.
  private let lock = NSLock()
  private var recorder: AVAudioFile?
  private var stopped = false

  init(
    captureId: String, request: CaptureRequest, emit: @escaping (LiveEvent) -> Void,
    level: ((Double) -> Void)? = nil
  ) {
    self.captureId = captureId
    self.sourceKind =
      request.source == "microphone" || request.source.hasPrefix("file:") ? request.source : "system"
    self.recordPath = request.recordPath
    self.emit = emit
    self.level = level
    ring = PcmRing(capacity: Self.ringSeconds * 16_000)
  }

  /// On failure everything is undone (the ring is discarded, a started
  /// recording removed) and no events are sent.
  func start() throws {
    do {
      if let recordPath {
        recorder = try makeRecorder(path: recordPath, format: converter.format)
      }
      let capture = MeteredCapture(
        kind: sourceKind, onBuffer: { [weak self] buffer in self?.ingest(buffer) },
        onIssue: { [weak self] code, message in self?.emitIssue(code, message) })
      self.capture = capture
      try capture.start()
    } catch {
      capture?.stop()
      capture = nil
      lock.withLock {
        stopped = true
        recorder = nil
      }
      if let recordPath { try? FileManager.default.removeItem(atPath: recordPath) }
      ring.discard()
      throw error
    }
    let capture = self.capture!
    liveLog.info("capture \(self.captureId, privacy: .public) started: \(capture.sourceName ?? "-", privacy: .public)")
    tickTask = Task { [weak self] in await self?.tick() }
  }

  /// Runs on the capture context.
  private func ingest(_ buffer: AVAudioPCMBuffer) {
    guard let out = converter.convert(buffer), let data = out.floatChannelData else { return }
    ring.write(data[0], count: Int(out.frameLength))
    lock.withLock {
      guard let recorder else { return }
      do { try recorder.write(from: out) } catch {
        liveLog.error("recording write failed: \(error.localizedDescription, privacy: .public)")
        self.recorder = nil
        emitIssue("recording_failed", error.localizedDescription)
      }
    }
  }

  private func tick() async {
    var ticks = 0
    var lastCpu = processCpuSeconds()
    var lastDropped: Int64 = 0
    while !Task.isCancelled {
      try? await Task.sleep(for: .milliseconds(100))
      if Task.isCancelled { break }
      ticks += 1
      if let value = capture?.takeLevel() {
        level?(value)
        send(LiveEvent(kind: "level", sessionId: captureId, level: value))
      }
      if ticks % 10 == 0 {
        let cpu = processCpuSeconds()
        send(
          LiveEvent(
            kind: "stats", sessionId: captureId, cpuMsPerSecond: (cpu - lastCpu) * 1000,
            queuedMs: Int64(ring.available / 16)))
        lastCpu = cpu
        let dropped = ring.dropped
        if dropped > lastDropped {
          emitIssue("frames_dropped", String(dropped - lastDropped))
          lastDropped = dropped
        }
        capture?.checkSilentTap()
      }
    }
  }

  /// Stops capture, finalises the recording and closes the ring. The reader
  /// still drains what is buffered.
  func stop(reason: String? = nil) async {
    guard !lock.withLock({ () -> Bool in let was = stopped; stopped = true; return was }) else { return }
    tickTask?.cancel()
    await tickTask?.value
    capture?.stop()
    capture = nil
    lock.withLock { recorder = nil }  // closes and finalises the .m4a
    ring.close()
    send(LiveEvent(kind: "stopped", sessionId: captureId, message: reason))
  }

  private func emitIssue(_ code: String, _ message: String?) {
    liveLog.notice("capture issue \(code, privacy: .public): \(message ?? "", privacy: .public)")
    send(LiveEvent(kind: "issue", sessionId: captureId, code: code, message: message))
  }

  private func send(_ event: LiveEvent) {
    DispatchQueue.main.async { [emit] in emit(event) }
  }
}

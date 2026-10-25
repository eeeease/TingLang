import AVFoundation
import Foundation
import Speech

enum MediaError: LocalizedError {
  case noAudioTrack
  case unreadable(String)

  var errorDescription: String? {
    switch self {
    case .noAudioTrack: return "This file has no audio track"
    case .unreadable(let reason): return "Cannot read this file: \(reason)"
    }
  }
}

func inspectMediaFile(_ path: String) async throws -> MediaFacts {
  let asset = AVURLAsset(url: URL(fileURLWithPath: path))
  let duration = try await asset.load(.duration)
  let audio = try await asset.loadTracks(withMediaType: .audio)
  let video = try await asset.loadTracks(withMediaType: .video)
  return MediaFacts(
    durationMs: Int64((duration.seconds.isFinite ? duration.seconds : 0) * 1000),
    hasVideo: !video.isEmpty, hasAudio: !audio.isEmpty)
}

/// Reads the first audio track of any AVFoundation-readable file (audio or
/// video) as 16 kHz mono little-endian Float32 sample buffers. MKV/WebM/Ogg
/// are not supported by AVFoundation and fail here with a readable message.
private func readSpeechPcm(_ path: String, _ body: (CMSampleBuffer) throws -> Void) async throws {
  let asset = AVURLAsset(url: URL(fileURLWithPath: path))
  guard let track = try await asset.loadTracks(withMediaType: .audio).first else {
    throw MediaError.noAudioTrack
  }
  let reader = try AVAssetReader(asset: asset)
  let settings: [String: Any] = [
    AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: 16_000, AVNumberOfChannelsKey: 1,
    AVLinearPCMBitDepthKey: 32, AVLinearPCMIsFloatKey: true, AVLinearPCMIsNonInterleaved: false,
    AVLinearPCMIsBigEndianKey: false,
  ]
  let output = AVAssetReaderTrackOutput(track: track, outputSettings: settings)
  output.alwaysCopiesSampleData = false
  reader.add(output)
  guard reader.startReading() else {
    throw MediaError.unreadable(reader.error?.localizedDescription ?? "unknown error")
  }
  do {
    while let sample = output.copyNextSampleBuffer() {
      try Task.checkCancellation()
      try body(sample)
    }
  } catch {
    reader.cancelReading()
    throw error
  }
  if reader.status == .failed {
    throw MediaError.unreadable(reader.error?.localizedDescription ?? "decode failed")
  }
}

/// Decodes the first audio track to a temporary 16 kHz mono Float32 CAF (for
/// SpeechAnalyzer's file input).
func decodeToCafFile(_ path: String) async throws -> URL {
  let format = PcmConverter.speechFormat
  let url = FileManager.default.temporaryDirectory.appendingPathComponent("tinglang-\(UUID().uuidString).caf")
  let file = try AVAudioFile(forWriting: url, settings: format.settings, commonFormat: .pcmFormatFloat32, interleaved: false)
  do {
    try await readSpeechPcm(path) { sample in
      let frames = AVAudioFrameCount(CMSampleBufferGetNumSamples(sample))
      guard frames > 0, let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else { return }
      buffer.frameLength = frames
      let status = CMSampleBufferCopyPCMDataIntoAudioBufferList(
        sample, at: 0, frameCount: Int32(frames), into: buffer.mutableAudioBufferList)
      if status == noErr { try file.write(from: buffer) }
    }
  } catch {
    try? FileManager.default.removeItem(at: url)
    throw error
  }
  return url
}

/// Decodes the first audio track to a temporary headerless file of mono
/// little-endian Float32 at 16 kHz (`.f32`), read by Dart worker isolates.
/// The caller deletes it.
func decodeToRawPcmFile(_ path: String) async throws -> URL {
  let url = FileManager.default.temporaryDirectory.appendingPathComponent("tinglang-\(UUID().uuidString).f32")
  guard FileManager.default.createFile(atPath: url.path, contents: nil) else {
    throw MediaError.unreadable("cannot create \(url.lastPathComponent)")
  }
  let handle = try FileHandle(forWritingTo: url)
  do {
    try await readSpeechPcm(path) { sample in
      guard let block = CMSampleBufferGetDataBuffer(sample) else { return }
      let length = CMBlockBufferGetDataLength(block)
      guard length > 0 else { return }
      var data = Data(count: length)
      let status = data.withUnsafeMutableBytes { bytes in
        CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: length, destination: bytes.baseAddress!)
      }
      if status == kCMBlockBufferNoErr { try handle.write(contentsOf: data) }
    }
    try handle.close()
  } catch {
    try? handle.close()
    try? FileManager.default.removeItem(at: url)
    throw error
  }
  return url
}

/// Offline transcription of a local file with word timings, then (optional)
/// translation of every sentence. Events use the job id as `sessionId`.
@available(macOS 26.0, *)
final class FileTranscriptionJob: @unchecked Sendable {
  let request: FileTranscribeRequest
  private let settings: SpeechSettings
  private let emit: (LiveEvent) -> Void

  init(request: FileTranscribeRequest, settings: SpeechSettings = .defaults, emit: @escaping (LiveEvent) -> Void) {
    self.request = request
    self.settings = settings
    self.emit = emit
  }

  func run() async throws {
    let facts = try await inspectMediaFile(request.path)
    guard facts.hasAudio else { throw MediaError.noAudioTrack }
    let durationMs = max(1, Double(facts.durationMs))
    // Check the model before decoding: nothing is downloaded here.
    let recognizer = try await Recognizer.make(
      locale: settings.locale ?? request.locale, settings: settings, live: false)
    try await recognizer.requireAssets()
    let locale = recognizer.locale
    let pcm = try await decodeToCafFile(request.path)
    defer { try? FileManager.default.removeItem(at: pcm) }
    send(LiveEvent(kind: "progress", sessionId: request.jobId, level: 0.02))

    let analyzer = SpeechAnalyzer(modules: [recognizer.module])
    let jobId = request.jobId
    let collector = Task { () -> [(String, String)] in
      let state = FinalCollector()
      try await recognizer.forEachResult { result in
        guard result.isFinal else { return }
        let text = result.plainText
        guard !text.isEmpty else { return }
        let id = "\(jobId)-\(state.finals.count)"
        var event = LiveEvent(
          kind: "final", sessionId: jobId, segmentId: id, text: text,
          startMs: result.startMs, endMs: result.endMs)
        event.wordsJson = wordsJSON(result.text)
        self.send(event)
        state.finals.append((id, text))
        let progress = min(0.9, 0.02 + 0.88 * Double(result.endMs) / durationMs)
        if progress - state.lastProgress >= 0.01 {
          state.lastProgress = progress
          self.send(LiveEvent(kind: "progress", sessionId: jobId, level: progress))
        }
      }
      return state.finals
    }
    let file = try AVAudioFile(forReading: pcm)
    do {
      if let last = try await analyzer.analyzeSequence(from: file) {
        try await analyzer.finalizeAndFinish(through: last)
      } else {
        await analyzer.cancelAndFinishNow()
      }
    } catch {
      collector.cancel()
      throw error
    }
    let finals = try await collector.value
    try Task.checkCancellation()

    if let target = request.targetLanguage, let language = locale.language.languageCode?.identifier,
      let translator = await AppleTranslator(source: language, target: target)
    {
      for (offset, (id, text)) in finals.enumerated() {
        try Task.checkCancellation()
        if let translated = try? await translator.translate(text) {
          send(LiveEvent(kind: "translation", sessionId: jobId, segmentId: id, text: translated))
        }
        if offset % 5 == 0 {
          send(LiveEvent(kind: "progress", sessionId: jobId, level: 0.9 + 0.1 * Double(offset) / Double(max(1, finals.count))))
        }
      }
    } else if request.targetLanguage != nil {
      send(LiveEvent(kind: "issue", sessionId: jobId, code: "translation_pack_missing",
                     message: "\(locale.language.languageCode?.identifier ?? "")→\(request.targetLanguage!)"))
    }
    send(LiveEvent(kind: "done", sessionId: jobId))
  }

  private func send(_ event: LiveEvent) {
    DispatchQueue.main.async { [emit] in emit(event) }
  }
}

/// Results arrive one at a time on the collector task.
private final class FinalCollector: @unchecked Sendable {
  var finals: [(String, String)] = []
  var lastProgress = 0.0
}

// Latency and CPU of Apple's live recognisers per Tinglang latency tier.
//
// Feeds FLEURS-style utterances (16 kHz mono WAV + reference text in a
// manifest.jsonl: {"wav": path, "ref": text}) in real time, 100 ms at a time
// with 1 s of silence between utterances, through SpeechAnalyzer configured
// exactly like the app's tiers (SpeechRecognizers.swift), and prints one
// markdown row.
//
//   swiftc -O -parse-as-library tools/bench/apple_latency_bench.swift -o /tmp/apple_bench
//   /tmp/apple_bench <manifest.jsonl> <utterances> <appleSpeech|appleDictation> <powerSaver|balanced|fastest>
//
// Partial lag: audio already fed minus the end of the newest partial's range,
// measured when the partial arrives, plus the wait for the app's next
// coalescing tick. Final latency: wall time from the end of an utterance's
// audio to the last final that covers it. CPU: this process plus the
// out-of-process `localspeechrecognition` and `aned` services (from `ps`),
// per second of audio (100% = one core).
import AVFoundation
import Foundation
import Speech

func note(_ s: String) { FileHandle.standardError.write(Data("[bench] \(s)\n".utf8)) }

struct Utterance { let samples: [Float]; let ref: String }

func loadManifest(_ path: String, count: Int) throws -> [Utterance] {
  let lines = try String(contentsOfFile: path, encoding: .utf8).split(separator: "\n")
  var result: [Utterance] = []
  for line in lines.prefix(count) {
    let json = try JSONSerialization.jsonObject(with: Data(line.utf8)) as! [String: Any]
    let file = try AVAudioFile(forReading: URL(fileURLWithPath: json["wav"] as! String))
    let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16_000, channels: 1, interleaved: false)!
    let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(file.length))!
    try file.read(into: buffer)
    let samples = Array(UnsafeBufferPointer(start: buffer.floatChannelData![0], count: Int(buffer.frameLength)))
    result.append(Utterance(samples: samples, ref: json["ref"] as! String))
  }
  return result
}

/// CPU seconds of the speech services by pid, from `ps`.
func serviceCpuByPid() -> [Int: Double] {
  let ps = Process()
  ps.executableURL = URL(fileURLWithPath: "/bin/ps")
  ps.arguments = ["-axo", "pid=,time=,comm="]
  let pipe = Pipe()
  ps.standardOutput = pipe
  try? ps.run()
  // Read before waiting: a full pipe would block `ps` forever.
  let data = pipe.fileHandleForReading.readDataToEndOfFile()
  ps.waitUntilExit()
  var result: [Int: Double] = [:]
  for line in String(decoding: data, as: UTF8.self).split(separator: "\n") {
    let parts = line.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
    guard parts.count == 3, let pid = Int(parts[0]),
      parts[2].hasSuffix("localspeechrecognition") || parts[2].hasSuffix("/aned")
    else { continue }
    // [[dd-]hh:]mm:ss.ss
    var seconds = 0.0
    for (i, field) in parts[1].split(separator: ":").reversed().enumerated() {
      seconds += (Double(field.split(separator: "-").last ?? "0") ?? 0) * pow(60, Double(i))
    }
    result[pid] = seconds
  }
  return result
}

/// Sums service CPU across process restarts: sampled every second, a new pid
/// counts from zero, a pid that exits keeps what it used until its last sample.
final class ServiceCpu: @unchecked Sendable {
  private let lock = NSLock()
  private var baseline: [Int: Double] = [:]
  private var last: [Int: Double] = [:]
  private var task: Task<Void, Never>?

  func start() {
    let first = serviceCpuByPid()
    lock.withLock { baseline = first; last = first }
    task = Task.detached { [weak self] in
      while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(1))
        self?.sample()
      }
    }
  }

  private func sample() {
    let now = serviceCpuByPid()
    lock.withLock { for (pid, t) in now { last[pid] = t } }
  }

  /// Seconds used since [start].
  func stop() -> Double {
    task?.cancel()
    sample()
    return lock.withLock { last.reduce(0) { $0 + $1.value - (baseline[$1.key] ?? 0) } }
  }
}

func selfCpuSeconds() -> Double {
  var usage = rusage()
  getrusage(RUSAGE_SELF, &usage)
  return Double(usage.ru_utime.tv_sec) + Double(usage.ru_utime.tv_usec) / 1e6
    + Double(usage.ru_stime.tv_sec) + Double(usage.ru_stime.tv_usec) / 1e6
}

func words(_ text: String) -> [String] {
  text.lowercased().components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "'")).inverted)
    .filter { !$0.isEmpty }
}

func editDistance(_ a: [String], _ b: [String]) -> Int {
  if a.isEmpty { return b.count }
  var previous = Array(0...b.count)
  for i in 1...a.count {
    var row = [i] + Array(repeating: 0, count: b.count)
    for j in 1...max(1, b.count) where !b.isEmpty {
      row[j] = min(previous[j] + 1, row[j - 1] + 1, previous[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1))
    }
    previous = row
  }
  return previous[b.count]
}

func percentile(_ values: [Double], _ p: Double) -> Double {
  guard !values.isEmpty else { return .nan }
  let sorted = values.sorted()
  return sorted[min(sorted.count - 1, Int(Double(sorted.count - 1) * p + 0.5))]
}

final class Log: @unchecked Sendable {
  let lock = NSLock()
  var partialLags: [Double] = []
  var finals: [(wall: Double, start: Double, end: Double, text: String)] = []
}

@main struct Bench {
  static func main() async throws {
    let args = CommandLine.arguments
    let utterances = try loadManifest(args[1], count: Int(args[2]) ?? 20)
    let engine = args[3], tier = args[4]
    let intervalMs: Double = tier == "powerSaver" ? 250 : tier == "fastest" ? 50 : 100
    let priority: TaskPriority = tier == "powerSaver" ? .utility : tier == "fastest" ? .high : .userInitiated
    let retention: SpeechAnalyzer.Options.ModelRetention =
      tier == "powerSaver" ? .whileInUse : tier == "fastest" ? .processLifetime : .lingering
    let locale = Locale(identifier: "en-US")

    let module: any SpeechModule
    let results: AsyncThrowingStream<(AttributedString, CMTimeRange, Bool), Error>
    if engine == "appleDictation" {
      var reporting: Set<DictationTranscriber.ReportingOption> = [.volatileResults]
      // As in the app: on every tier.
      reporting.insert(.frequentFinalization)
      let t = DictationTranscriber(locale: locale, contentHints: [], transcriptionOptions: [.punctuation],
                                   reportingOptions: reporting, attributeOptions: [.audioTimeRange])
      module = t
      results = AsyncThrowingStream { c in Task { do { for try await r in t.results { c.yield((r.text, r.range, r.isFinal)) }; c.finish() } catch { c.finish(throwing: error) } } }
    } else {
      let preset = SpeechTranscriber.Preset.timeIndexedProgressiveTranscription
      var reporting = preset.reportingOptions
      if tier == "fastest" { reporting.insert(.fastResults) }
      let t = SpeechTranscriber(locale: locale, transcriptionOptions: preset.transcriptionOptions,
                                reportingOptions: reporting, attributeOptions: preset.attributeOptions)
      module = t
      results = AsyncThrowingStream { c in Task { do { for try await r in t.results { c.yield((r.text, r.range, r.isFinal)) }; c.finish() } catch { c.finish(throwing: error) } } }
    }
    if try await AssetInventory.assetInstallationRequest(supporting: [module]) != nil {
      print("assets missing for \(engine) en-US; not downloading"); exit(2)
    }
    let options: SpeechAnalyzer.Options
    if #available(macOS 27.0, *) {
      options = SpeechAnalyzer.Options(priority: priority, modelRetention: retention, ignoresResourceLimits: tier == "fastest")
    } else {
      options = SpeechAnalyzer.Options(priority: priority, modelRetention: retention)
    }
    note("assets ok")
    let analyzer = SpeechAnalyzer(modules: [module], options: options)
    let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [module])!
    try await analyzer.prepareToAnalyze(in: format)
    let (stream, input) = AsyncStream<AnalyzerInput>.makeStream()
    try await analyzer.start(inputSequence: stream)
    note("analyzer started \(format)")

    // The stream: utterance, 1 s silence, … with each utterance's span.
    var audio: [Float] = []
    var spans: [(start: Double, end: Double, ref: String)] = []
    for u in utterances {
      let start = Double(audio.count) / 16_000
      audio += u.samples
      spans.append((start, Double(audio.count) / 16_000, u.ref))
      audio += [Float](repeating: 0, count: 16_000)
    }
    let source = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16_000, channels: 1, interleaved: false)!
    let converter = AVAudioConverter(from: source, to: format)!

    let log = Log()
    let t0 = Date()
    let fedSamples = ManagedAtomicCounter()
    let consumer = Task {
      for try await (text, range, isFinal) in results {
        let wall = Date().timeIntervalSince(t0)
        let fed = Double(fedSamples.value) / 16_000
        let plain = String(text.characters)
        log.lock.withLock {
          if isFinal {
            log.finals.append((wall, range.start.seconds, range.end.seconds, plain))
          } else if range.end.seconds.isFinite {
            // The app shows a partial on its next coalescing tick.
            let tick = (wall * 1000 / intervalMs).rounded(.up) * intervalMs / 1000
            log.partialLags.append(max(0, fed - range.end.seconds) + (tick - wall))
          }
        }
      }
    }
    let cpu0 = selfCpuSeconds()
    let services = ServiceCpu()
    services.start()
    let block = 1600
    var offset = 0
    while offset < audio.count {
      let n = min(block, audio.count - offset)
      let buffer = AVAudioPCMBuffer(pcmFormat: source, frameCapacity: AVAudioFrameCount(n))!
      buffer.frameLength = AVAudioFrameCount(n)
      audio.withUnsafeBufferPointer { buffer.floatChannelData![0].update(from: $0.baseAddress! + offset, count: n) }
      let out = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(Double(n) * format.sampleRate / 16_000) + 32)!
      var used = false
      converter.convert(to: out, error: nil) { _, status in
        if used { status.pointee = .noDataNow; return nil }
        used = true; status.pointee = .haveData; return buffer
      }
      input.yield(AnalyzerInput(buffer: out))
      offset += n
      fedSamples.value = offset
      let due = t0.addingTimeInterval(Double(offset) / 16_000)
      let wait = due.timeIntervalSinceNow
      if wait > 0 { try await Task.sleep(for: .milliseconds(Int(wait * 1000))) }
    }
    let audioSeconds = Double(audio.count) / 16_000
    let cpu = selfCpuSeconds() - cpu0, service = services.stop()
    note("fed \(audioSeconds) s")
    input.finish()
    try await analyzer.finalizeAndFinishThroughEndOfInput()
    note("finalized")
    _ = try? await consumer.value

    var finalLatencies: [Double] = []
    for span in spans {
      let mine = log.finals.filter { $0.end > span.start && $0.start < span.end + 0.5 }
      if let last = mine.max(by: { $0.wall < $1.wall }) { finalLatencies.append(last.wall - span.end) }
    }
    // WER over the whole run: a final may span several utterances.
    let ref = words(spans.map(\.ref).joined(separator: " "))
    let hyp = words(log.finals.sorted { $0.start < $1.start }.map(\.text).joined(separator: " "))
    let errors = editDistance(ref, hyp), refWords = ref.count
    let total = (cpu + service) / audioSeconds * 100
    print(String(format: "| %@ | %@ | %.1f%% (app %.1f%% + services %.1f%%) | %.2f / %.2f s | %.2f / %.2f s | %.1f | %d utts, %.0f s |",
                 engine, tier, total, cpu / audioSeconds * 100, service / audioSeconds * 100,
                 percentile(log.partialLags, 0.5), percentile(log.partialLags, 0.9),
                 percentile(finalLatencies, 0.5), percentile(finalLatencies, 0.9),
                 Double(errors) / Double(max(1, refWords)) * 100, utterances.count, audioSeconds))
  }
}

final class ManagedAtomicCounter: @unchecked Sendable {
  private let lock = NSLock()
  private var _value = 0
  var value: Int {
    get { lock.withLock { _value } }
    set { lock.withLock { _value = newValue } }
  }
}

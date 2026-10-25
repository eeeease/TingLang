import AVFoundation
import Foundation
import Speech
import Translation
import os

let liveLog = Logger(subsystem: "dev.eeeease.tinglang", category: "live")

/// Serial translator for finalised lines (never partials). Uses a session
/// over installed language packs; packs are installed through
/// LanguagePackWindow, which needs a SwiftUI host.
@available(macOS 26.0, *)
actor AppleTranslator {
  private let session: TranslationSession

  init?(source: String, target: String) async {
    let from = Locale.Language(identifier: source), to = Locale.Language(identifier: target)
    guard await LanguageAvailability().status(from: from, to: to) == .installed else { return nil }
    session = TranslationSession(installedSource: from, target: to)
  }

  func translate(_ text: String) async throws -> String {
    try await session.translate(text).targetText
  }

  /// One batch, results in the order of [texts].
  func translate(_ texts: [String]) async throws -> [String] {
    guard !texts.isEmpty else { return [] }
    let requests = texts.enumerated().map { TranslationSession.Request(sourceText: $1, clientIdentifier: String($0)) }
    var results = [String?](repeating: nil, count: texts.count)
    for response in try await session.translations(from: requests) {
      if let id = response.clientIdentifier, let index = Int(id), results.indices.contains(index) {
        results[index] = response.targetText
      }
    }
    let complete = results.compactMap { $0 }
    guard complete.count == texts.count else { throw TranslationError.incompleteBatch }
    return complete
  }
}

/// Live captions entirely in Swift (topology A): capture → SpeechTranscriber
/// or DictationTranscriber (progressive, on the Neural Engine, out of
/// process) → Apple Translation → overlay. Dart receives coalesced events
/// only; PCM never leaves Swift.
@available(macOS 26.0, *)
final class LiveCaptionEngine: @unchecked Sendable {
  typealias Emit = (LiveEvent) -> Void

  let sessionId: String
  private let locale: String
  private let target: String?
  private let sourceKind: String
  private let settings: SpeechSettings
  private let overlay: CaptionOverlayController?
  private let emit: Emit

  private var capture: MeteredCapture?
  private var recognizer: Recognizer?
  private var analyzer: SpeechAnalyzer?
  private var input: AsyncStream<AnalyzerInput>.Continuation?
  private var converter: PcmConverter?
  private var resultsTask: Task<Void, Never>?
  private var tickTask: Task<Void, Never>?
  private var translator: AppleTranslator?
  private let recordPath: String?
  private var recorder: AVAudioFile?
  private var translationChain: Task<Void, Never>?

  // Mutated from the capture thread and the results task; guarded by lock.
  private let lock = NSLock()
  private var segmentIndex = 0
  private var pendingPartial: LiveEvent?
  private var stopping = false
  private var lines: [CaptionLine] = []

  init(
    sessionId: String, request: LiveStartRequest, settings: SpeechSettings = .defaults,
    overlay: CaptionOverlayController?, emit: @escaping Emit
  ) {
    self.sessionId = sessionId
    self.locale = settings.locale ?? request.locale
    self.target = request.targetLanguage
    self.sourceKind = request.source
    self.settings = settings
    self.overlay = request.showOverlay ? overlay : nil
    self.recordPath = request.recordPath
    self.emit = emit
  }

  func start() async throws {
    let recognizer = try await Recognizer.make(locale: locale, settings: settings, live: true)
    try await recognizer.requireAssets()
    let analyzer = SpeechAnalyzer(modules: [recognizer.module], options: settings.analyzerOptions)
    guard let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [recognizer.module])
    else { throw LiveEngineError.noAudioFormat }
    // Loads the model before audio arrives, so the first words are not late.
    try await analyzer.prepareToAnalyze(in: format)
    let (stream, continuation) = AsyncStream<AnalyzerInput>.makeStream()
    try await analyzer.start(inputSequence: stream)
    self.recognizer = recognizer
    self.analyzer = analyzer
    self.converter = PcmConverter(to: format)
    self.input = continuation
    if let recordPath {
      // AAC on the recognizer's own clock: transcript times are offsets
      // into this file.
      recorder = try makeRecorder(path: recordPath, format: format)
    }
    liveLog.info(
      "analyzer ready: engine=\(self.settings.engine.rawValue, privacy: .public) tier=\(self.settings.tier.rawValue, privacy: .public) locale=\(recognizer.locale.identifier, privacy: .public) format=\(format.description, privacy: .public)"
    )

    if let target, let language = recognizer.locale.language.languageCode?.identifier {
      liveLog.info("translator check \(language, privacy: .public)→\(target, privacy: .public)")
      translator = await AppleTranslator(source: language, target: target)
      liveLog.info("translator ready=\(self.translator != nil)")
      if translator == nil {
        emitIssue("translation_pack_missing", "\(language)→\(target)")
      }
    }

    resultsTask = Task(priority: settings.priority) { [weak self] in await self?.consumeResults(recognizer) }
    liveLog.info("starting source \(self.sourceKind, privacy: .public)")
    let capture = MeteredCapture(
      kind: sourceKind, onBuffer: { [weak self] buffer in self?.ingest(buffer) },
      onIssue: { [weak self] code, message in self?.emitIssue(code, message) })
    self.capture = capture
    try capture.start()
    liveLog.info("source started: \(capture.sourceName ?? "-", privacy: .public)")
    tickTask = Task { [weak self] in await self?.tick() }
    overlay?.begin()
  }

  /// Runs on the capture context. Converts once to the analyzer format.
  private var ingested = 0
  private func ingest(_ buffer: AVAudioPCMBuffer) {
    guard let converter, let input else { return }
    ingested += 1
    if ingested == 1 {
      liveLog.info("buffer #\(self.ingested) frames=\(buffer.frameLength) format=\(buffer.format.description, privacy: .public)")
    }
    guard let out = converter.convert(buffer) else { return }
    input.yield(AnalyzerInput(buffer: out))
    do { try recorder?.write(from: out) } catch {
      liveLog.error("recording write failed: \(error.localizedDescription, privacy: .public)")
      recorder = nil
      emitIssue("recording_failed", error.localizedDescription)
    }
  }

  private func consumeResults(_ recognizer: Recognizer) async {
    do {
      try await recognizer.forEachResult { [weak self] result in self?.handle(result) }
    } catch {
      liveLog.error("results failed: \(error.localizedDescription, privacy: .public)")
      emitIssue("asr_failed", error.localizedDescription)
    }
  }

  private func handle(_ result: RecognizerResult) {
    let text = result.plainText
    liveLog.debug("result final=\(result.isFinal) chars=\(text.count)")
    if result.isFinal {
      let id: String = lock.withLock {
        let id = "\(sessionId)-\(segmentIndex)"
        segmentIndex += 1
        pendingPartial = nil
        return id
      }
      guard !text.isEmpty else { return }
      var event = LiveEvent(
        kind: "final", sessionId: sessionId, segmentId: id, text: text,
        startMs: result.startMs, endMs: result.endMs)
      event.wordsJson = wordsJSON(result.text)
      send(event)
      updateLine(id: id, text: text, translation: nil, isFinal: true)
      translate(id: id, text: text)
    } else {
      guard !text.isEmpty else { return }
      lock.withLock {
        pendingPartial = LiveEvent(
          kind: "partial", sessionId: sessionId, segmentId: "\(sessionId)-\(segmentIndex)", text: text,
          startMs: result.startMs)
      }
    }
  }

  private func translate(id: String, text: String) {
    guard let translator else { return }
    let previous = translationChain
    translationChain = Task { [weak self] in
      await previous?.value
      guard let self else { return }
      do {
        let translated = try await translator.translate(text)
        self.send(LiveEvent(kind: "translation", sessionId: self.sessionId, segmentId: id, text: translated))
        self.updateLine(id: id, text: nil, translation: translated, isFinal: true)
      } catch {
        self.emitIssue("translation_failed", error.localizedDescription)
      }
    }
  }

  /// Flushes the latest partial at the tier's interval (250/100/50 ms), the
  /// level at 10 Hz, and stats plus the silent-tap watchdog at 1 Hz.
  private func tick() async {
    let partialMs = settings.partialIntervalMs
    let step = gcd(partialMs, 100)
    var elapsedMs = 0
    var lastCpu = processCpuSeconds()
    while !Task.isCancelled {
      try? await Task.sleep(for: .milliseconds(step))
      elapsedMs += step
      if elapsedMs % partialMs == 0 {
        let partial: LiveEvent? = lock.withLock {
          let partial = pendingPartial
          pendingPartial = nil
          return partial
        }
        if let partial {
          send(partial)
          updateLine(id: partial.segmentId!, text: partial.text, translation: nil, isFinal: false)
        }
      }
      if elapsedMs % 100 == 0, let level = capture?.takeLevel() {
        overlay?.level(level)
        send(LiveEvent(kind: "level", sessionId: sessionId, level: level))
      }
      if elapsedMs % 1000 == 0 {
        let cpu = processCpuSeconds()
        send(LiveEvent(kind: "stats", sessionId: sessionId, cpuMsPerSecond: (cpu - lastCpu) * 1000, queuedMs: 0))
        lastCpu = cpu
        capture?.checkSilentTap()
      }
    }
  }

  func stop() async {
    guard !lock.withLock({ () -> Bool in let was = stopping; stopping = true; return was }) else { return }
    capture?.stop()
    capture = nil
    recorder = nil  // closes and finalises the .m4a
    tickTask?.cancel()
    input?.finish()
    try? await analyzer?.finalizeAndFinishThroughEndOfInput()
    await resultsTask?.value
    await translationChain?.value
    overlay?.end()
    send(LiveEvent(kind: "stopped", sessionId: sessionId))
  }

  private func updateLine(id: String, text: String?, translation: String?, isFinal: Bool) {
    guard let overlay else { return }
    let snapshot: [CaptionLine] = lock.withLock {
      if let index = lines.lastIndex(where: { $0.id == id }) {
        if let text { lines[index].text = text }
        if let translation { lines[index].translation = translation }
        lines[index].isFinal = lines[index].isFinal || isFinal
      } else if let text {
        lines.append(CaptionLine(id: id, text: text, translation: translation, isFinal: isFinal))
        if lines.count > 30 { lines.removeFirst(lines.count - 30) }
      }
      return lines
    }
    overlay.show(lines: snapshot, awaitingTranslation: translator != nil)
  }

  private func emitIssue(_ code: String, _ message: String?) {
    liveLog.notice("issue \(code, privacy: .public): \(message ?? "", privacy: .public)")
    send(LiveEvent(kind: "issue", sessionId: sessionId, code: code, message: message))
  }

  private func send(_ event: LiveEvent) {
    DispatchQueue.main.async { [emit] in emit(event) }
  }
}

private func gcd(_ a: Int, _ b: Int) -> Int { b == 0 ? a : gcd(b, a % b) }

enum LiveEngineError: LocalizedError {
  case unsupportedLocale(String)
  case noAudioFormat
  case requiresMacOS26
  /// The system speech model for the locale is not installed; Dart asks
  /// the user and calls `installSpeechAssetsFor` first.
  case assetsMissing(String)
  case unknownEngine(String)

  /// Stable code for Dart (`PlatformException.code`).
  var code: String {
    switch self {
    case .unsupportedLocale: return "unsupportedLocale"
    case .noAudioFormat: return "noAudioFormat"
    case .requiresMacOS26: return "requiresMacOS26"
    case .assetsMissing: return "assetsMissing"
    case .unknownEngine: return "unknownEngine"
    }
  }

  var errorDescription: String? {
    switch self {
    case .unsupportedLocale(let locale): return "Speech recognition does not support \(locale) on this Mac"
    case .noAudioFormat: return "No audio format available for speech recognition"
    case .requiresMacOS26: return "Live captions with Apple speech recognition need macOS 26 or later"
    case .assetsMissing(let locale): return "The speech model for \(locale) is not installed"
    case .unknownEngine(let name): return "Unknown speech engine \(name)"
    }
  }
}

func processCpuSeconds() -> Double {
  var usage = rusage()
  getrusage(RUSAGE_SELF, &usage)
  return Double(usage.ru_utime.tv_sec) + Double(usage.ru_utime.tv_usec) / 1e6
    + Double(usage.ru_stime.tv_sec) + Double(usage.ru_stime.tv_usec) / 1e6
}

/// Word timings from SpeechTranscriber's `audioTimeRange` runs, as
/// `[{"w":"word","s":ms,"e":ms}]`; nil when the result carries no timings.
@available(macOS 26.0, *)
func wordsJSON(_ text: AttributedString) -> String? {
  var words: [[String: Any]] = []
  for run in text.runs {
    guard let range = run.audioTimeRange else { continue }
    let word = String(text[run.range].characters).trimmingCharacters(in: .whitespacesAndNewlines)
    guard !word.isEmpty, range.start.seconds.isFinite, range.end.seconds.isFinite else { continue }
    words.append(["w": word, "s": Int(range.start.seconds * 1000), "e": Int(range.end.seconds * 1000)])
  }
  guard !words.isEmpty, let data = try? JSONSerialization.data(withJSONObject: words) else { return nil }
  return String(data: data, encoding: .utf8)
}

enum TranslationError: LocalizedError {
  case incompleteBatch
  case packMissing(String)
  case requiresMacOS26

  var code: String {
    switch self {
    case .incompleteBatch: return "translationFailed"
    case .packMissing: return "translationPackMissing"
    case .requiresMacOS26: return "requiresMacOS26"
    }
  }

  var errorDescription: String? {
    switch self {
    case .incompleteBatch: return "Apple Translation returned an incomplete batch"
    case .packMissing(let pair): return "The translation pack for \(pair) is not installed"
    case .requiresMacOS26: return "Translation with installed Apple language packs needs macOS 26 or later"
    }
  }
}

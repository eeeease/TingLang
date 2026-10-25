import AVFoundation
import CoreMedia
import Foundation
import Speech

/// The recogniser and latency tier chosen in Settings, decoded from Pigeon's
/// `SpeechConfig`. The tier knobs mirror Dart's `LatencyTiers.apple()`.
struct SpeechSettings {
  enum Engine: String { case appleSpeech, appleDictation }
  enum Tier: String { case powerSaver, balanced, fastest }

  var engine: Engine = .appleSpeech
  var tier: Tier = .balanced
  /// Replaces the request's locale when set.
  var locale: String?
  var farField = false
  var shortForm = false

  /// SpeechTranscriber on the balanced tier (what `startLive` and
  /// `transcribeFile` use).
  static let defaults = SpeechSettings()

  init() {}

  init(_ config: SpeechConfig) throws {
    guard let engine = Engine(rawValue: config.engine) else {
      throw LiveEngineError.unknownEngine(config.engine)
    }
    self.engine = engine
    tier = Tier(rawValue: config.latency) ?? .balanced
    locale = config.locale?.isEmpty == false ? config.locale : nil
    farField = config.farField
    shortForm = config.shortForm
  }

  static func engine(_ name: String) throws -> Engine {
    guard let engine = Engine(rawValue: name) else { throw LiveEngineError.unknownEngine(name) }
    return engine
  }

  /// `SpeechTranscriber.ReportingOption.fastResults`.
  var fastResults: Bool { tier == .fastest }

  /// `DictationTranscriber.ReportingOption.frequentFinalization`, on every
  /// tier for live captions: without it a line ended ~15 s after speech
  /// (p50, docs/perf/asr-latency-2026-10.md).
  var frequentFinalization: Bool { true }

  /// How often the latest partial goes to the panel and Dart.
  var partialIntervalMs: Int {
    switch tier {
    case .powerSaver: return 250
    case .balanced: return 100
    case .fastest: return 50
    }
  }

  var priority: TaskPriority {
    switch tier {
    case .powerSaver: return .utility
    case .balanced: return .userInitiated
    case .fastest: return .high
    }
  }

  @available(macOS 26.0, *)
  var analyzerOptions: SpeechAnalyzer.Options {
    let retention: SpeechAnalyzer.Options.ModelRetention =
      switch tier {
      case .powerSaver: .whileInUse
      case .balanced: .lingering
      case .fastest: .processLifetime
      }
    // `ignoresResourceLimits` exists only in the macOS 27 SDK (Xcode 27,
    // Swift 6.4); older Xcode versions build without it.
    #if compiler(>=6.4)
      if #available(macOS 27.0, *) {
        return SpeechAnalyzer.Options(
          priority: priority, modelRetention: retention, ignoresResourceLimits: tier == .fastest)
      }
    #endif
    return SpeechAnalyzer.Options(priority: priority, modelRetention: retention)
  }
}

/// One result of either Apple recogniser.
@available(macOS 26.0, *)
struct RecognizerResult {
  let text: AttributedString
  let range: CMTimeRange
  let isFinal: Bool

  var plainText: String {
    String(text.characters).trimmingCharacters(in: .whitespacesAndNewlines)
  }

  var startMs: Int64 { Self.ms(range.start) }
  var endMs: Int64 { Self.ms(range.end) }

  private static func ms(_ time: CMTime) -> Int64 {
    Int64((time.seconds.isFinite ? time.seconds : 0) * 1000)
  }
}

/// SpeechTranscriber or DictationTranscriber behind one shape, so the live
/// engine and file jobs handle results the same way.
@available(macOS 26.0, *)
final class Recognizer: @unchecked Sendable {
  let module: any SpeechModule
  /// The supported locale the module was built for.
  let locale: Locale
  private let iterate: (@escaping (RecognizerResult) async -> Void) async throws -> Void

  private init(
    module: any SpeechModule, locale: Locale,
    iterate: @escaping (@escaping (RecognizerResult) async -> Void) async throws -> Void
  ) {
    self.module = module
    self.locale = locale
    self.iterate = iterate
  }

  /// Calls [handle] for every result until the analyzer finishes.
  func forEachResult(_ handle: @escaping (RecognizerResult) async -> Void) async throws {
    try await iterate(handle)
  }

  /// The locale [identifier] resolves to for [engine], or nil when that
  /// recogniser does not support it.
  static func supportedLocale(_ identifier: String, engine: SpeechSettings.Engine) async -> Locale? {
    let locale = Locale(identifier: identifier)
    switch engine {
    case .appleSpeech: return await SpeechTranscriber.supportedLocale(equivalentTo: locale)
    case .appleDictation: return await DictationTranscriber.supportedLocale(equivalentTo: locale)
    }
  }

  /// Builds the module for live captions ([live], volatile results) or file
  /// jobs (finals only). Throws `unsupportedLocale` for unknown locales.
  static func make(locale identifier: String, settings: SpeechSettings, live: Bool) async throws -> Recognizer {
    guard let locale = await supportedLocale(identifier, engine: settings.engine) else {
      throw LiveEngineError.unsupportedLocale(identifier)
    }
    switch settings.engine {
    case .appleSpeech:
      let transcriber: SpeechTranscriber
      if live {
        // `.timeIndexedProgressiveTranscription`, plus `fastResults` on the
        // fastest tier.
        let preset = SpeechTranscriber.Preset.timeIndexedProgressiveTranscription
        var reporting = preset.reportingOptions
        if settings.fastResults { reporting.insert(.fastResults) }
        transcriber = SpeechTranscriber(
          locale: locale, transcriptionOptions: preset.transcriptionOptions,
          reportingOptions: reporting, attributeOptions: preset.attributeOptions)
      } else {
        transcriber = SpeechTranscriber(
          locale: locale, transcriptionOptions: [], reportingOptions: [],
          attributeOptions: [.audioTimeRange])
      }
      return Recognizer(module: transcriber, locale: locale) { handle in
        for try await result in transcriber.results {
          await handle(RecognizerResult(text: result.text, range: result.range, isFinal: result.isFinal))
        }
      }
    case .appleDictation:
      var hints = Set<DictationTranscriber.ContentHint>()
      if settings.farField { hints.insert(.farField) }
      if settings.shortForm { hints.insert(.shortForm) }
      var reporting = Set<DictationTranscriber.ReportingOption>()
      if live {
        reporting.insert(.volatileResults)
        if settings.frequentFinalization { reporting.insert(.frequentFinalization) }
      }
      let transcriber = DictationTranscriber(
        locale: locale, contentHints: hints, transcriptionOptions: [.punctuation],
        reportingOptions: reporting, attributeOptions: [.audioTimeRange])
      return Recognizer(module: transcriber, locale: locale) { handle in
        for try await result in transcriber.results {
          await handle(RecognizerResult(text: result.text, range: result.range, isFinal: result.isFinal))
        }
      }
    }
  }

  /// Throws `assetsMissing` when the model must be downloaded first; never
  /// downloads (Dart asks the user before any download).
  func requireAssets() async throws {
    if try await AssetInventory.assetInstallationRequest(supporting: [module]) != nil {
      throw LiveEngineError.assetsMissing(locale.identifier(.bcp47))
    }
  }
}

/// System speech models per recogniser and locale (`AssetInventory`).
@available(macOS 26.0, *)
enum SpeechAssets {
  /// A plain module for asset checks; options do not change which model a
  /// locale needs.
  private static func module(_ locale: Locale, _ engine: SpeechSettings.Engine) -> any SpeechModule {
    switch engine {
    case .appleSpeech:
      return SpeechTranscriber(locale: locale, preset: .timeIndexedProgressiveTranscription)
    case .appleDictation:
      return DictationTranscriber(locale: locale, preset: .timeIndexedLongDictation)
    }
  }

  static func status(_ identifier: String, _ engine: SpeechSettings.Engine) async throws -> AssetStatus {
    guard let locale = await Recognizer.supportedLocale(identifier, engine: engine) else { return .unsupported }
    let module = module(locale, engine)
    switch await AssetInventory.status(forModules: [module]) {
    case .installed: return .installed
    case .unsupported: return .unsupported
    default:
      // `status` can say "supported" for models already on the Mac (installed
      // for another app or preset); only a non-nil request means a download.
      let request = try await AssetInventory.assetInstallationRequest(supporting: [module])
      return request == nil ? .installed : .supported
    }
  }

  /// Downloads the model when one is needed, reporting the request's
  /// `fractionCompleted` at ≤10 Hz. Cancelling the task cancels the download.
  static func install(
    _ identifier: String, _ engine: SpeechSettings.Engine, progress report: ((Double) -> Void)? = nil
  ) async throws {
    guard let locale = await Recognizer.supportedLocale(identifier, engine: engine) else {
      throw LiveEngineError.unsupportedLocale(identifier)
    }
    guard let request = try await AssetInventory.assetInstallationRequest(supporting: [module(locale, engine)])
    else { return }
    let progress = request.progress
    var observation: NSKeyValueObservation?
    if let report {
      let throttle = ProgressThrottle(report)
      observation = progress.observe(\.fractionCompleted, options: [.initial, .new]) { progress, _ in
        throttle.offer(progress.fractionCompleted)
      }
    }
    defer { observation?.invalidate() }
    try await withTaskCancellationHandler {
      try await request.downloadAndInstall()
    } onCancel: {
      progress.cancel()
    }
    try Task.checkCancellation()
    report?(1)
  }

  static func release(_ identifier: String, _ engine: SpeechSettings.Engine) async -> Bool {
    guard let locale = await Recognizer.supportedLocale(identifier, engine: engine) else { return false }
    return await AssetInventory.release(reservedLocale: locale)
  }

  static func inventory() async -> SpeechInventory {
    func tags(_ locales: [Locale]) -> [String] {
      Array(Set(locales.map { $0.identifier(.bcp47) })).sorted()
    }
    return SpeechInventory(
      speechSupported: tags(await SpeechTranscriber.supportedLocales),
      speechInstalled: tags(await SpeechTranscriber.installedLocales),
      dictationSupported: tags(await DictationTranscriber.supportedLocales),
      dictationInstalled: tags(await DictationTranscriber.installedLocales))
  }
}

/// Passes on at most one value per 100 ms (plus the first), from any thread.
final class ProgressThrottle: @unchecked Sendable {
  private let lock = NSLock()
  private var last = Date.distantPast
  private let report: (Double) -> Void

  init(_ report: @escaping (Double) -> Void) { self.report = report }

  func offer(_ value: Double) {
    let now = Date()
    let pass: Bool = lock.withLock {
      guard now.timeIntervalSince(last) >= 0.1 else { return false }
      last = now
      return true
    }
    if pass { report(value) }
  }
}

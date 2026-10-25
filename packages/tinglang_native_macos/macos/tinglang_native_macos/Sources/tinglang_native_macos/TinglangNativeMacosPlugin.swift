import AVFoundation
import CoreGraphics
import FlutterMacOS
import Foundation
import Speech
import Translation

/// Registers Tinglang's Pigeon host API and live event stream. Live captions
/// run entirely in Swift (capture → SpeechTranscriber → Apple Translation →
/// caption panel); Dart only sends control calls and receives events.
/// Parts are ported from SubFlow (MIT, Copyright (c) 2025 Jinsong Zhou).
public class TinglangNativeMacosPlugin: NSObject, FlutterPlugin, TinglangHostApi {
  private let events = LiveEventsHandler()
  private let overlay = MainActor.assumeIsolated { CaptionOverlayController() }
  private let hotkeys = MainActor.assumeIsolated { GlobalHotkeys() }
  private let webAuth = MainActor.assumeIsolated { WebAuthentication() }
  private var engine: AnyObject?
  private var languagePacks: AnyObject?
  private var jobs: [String: Task<Void, Error>] = [:]
  private let jobsLock = NSLock()
  private var assetInstalls: [String: Task<Void, Error>] = [:]
  private var captures: [String: PortableCapture] = [:]
  private var translators: [String: AnyObject] = [:]
  private weak var registrar: FlutterPluginRegistrar?
  private var isReady = false
  /// Files opened with the app that Dart has not taken yet (main thread).
  private var openedFiles: [String] = []

  public static func register(with registrar: FlutterPluginRegistrar) {
    let plugin = TinglangNativeMacosPlugin()
    plugin.registrar = registrar
    TinglangHostApiSetup.setUp(binaryMessenger: registrar.messenger, api: plugin)
    MainActor.assumeIsolated {
      plugin.webAuth.anchorWindow = { [weak registrar] in registrar?.view?.window }
    }
    LiveEventsStreamHandler.register(with: registrar.messenger, streamHandler: plugin.events)
    // Documents opened from Finder or the Dock (see CloudDrive.swift).
    registrar.addApplicationDelegate(plugin)
    MainActor.assumeIsolated {
      plugin.hotkeys.onPressed = { [events = plugin.events] id in
        events.send(LiveEvent(kind: "hotkey", code: id))
      }
      plugin.overlay.onAction = { [events = plugin.events] action, value in
        events.send(LiveEvent(kind: "panel", code: action, message: value))
      }
      plugin.overlay.onDrop = { [events = plugin.events] paths in
        events.send(LiveEvent(kind: "drop", message: paths.joined(separator: "\n")))
      }
      plugin.overlay.onStyle = { [events = plugin.events] json in
        events.send(LiveEvent(kind: "panelStyle", message: json))
      }
      // Files dropped on the main window (posted by the runner's window).
      NotificationCenter.default.addObserver(
        forName: Notification.Name("dev.eeeease.tinglang.windowDrop"), object: nil, queue: .main
      ) { [events = plugin.events] note in
        guard let paths = note.userInfo?["paths"] as? [String], !paths.isEmpty else { return }
        events.send(LiveEvent(kind: "drop", code: "window", message: paths.joined(separator: "\n")))
      }
      // Dock menu items posted by the runner's AppDelegate.
      NotificationCenter.default.addObserver(
        forName: Notification.Name("dev.eeeease.tinglang.panelAction"), object: nil, queue: .main
      ) { [weak plugin] note in
        guard let plugin, let action = note.userInfo?["action"] as? String else { return }
        MainActor.assumeIsolated { plugin.dockAction(action) }
      }
    }
    // The main window starts hidden; if Dart never reports in (it could not
    // start at all), show it anyway. Generous because a debug VM alone takes
    // several seconds; Dart reports in before it does anything slow.
    DispatchQueue.main.asyncAfter(deadline: .now() + 20) { [weak plugin] in
      guard let plugin, !plugin.isReady else { return }
      MainActor.assumeIsolated { plugin.revealMainWindow() }
    }
  }

  @MainActor
  private func dockAction(_ action: String) {
    switch action {
    case "showPanel":
      overlay.setVisible(true)
      events.send(LiveEvent(kind: "panel", code: "show"))
    case "unlock":
      events.send(LiveEvent(kind: "panel", code: "unlock"))
    default:
      events.send(LiveEvent(kind: "panel", code: action))
    }
  }

  /// The runner's window ignores show requests until it is revealed (see
  /// scripts/native/MainFlutterWindow.swift).
  @MainActor
  private func revealMainWindow() {
    let window =
      registrar?.view?.window
      ?? NSApp.windows.first { $0.contentViewController is FlutterViewController }
    let reveal = NSSelectorFromString("reveal")
    if let window, window.responds(to: reveal) {
      window.perform(reveal)
    } else {
      NSApp.activate()
      window?.makeKeyAndOrderFront(nil)
    }
  }

  func probe() async throws -> HostProbe {
    let version = ProcessInfo.processInfo.operatingSystemVersion
    var locales: [String] = []
    if #available(macOS 26.0, *) {
      locales = await SpeechTranscriber.supportedLocales.map { $0.identifier(.bcp47) }
    }
    return HostProbe(
      osMajor: Int64(version.majorVersion),
      osMinor: Int64(version.minorVersion),
      osPatch: Int64(version.patchVersion),
      osVersionString: ProcessInfo.processInfo.operatingSystemVersionString,
      arch: Self.processArch,
      microphone: Self.microphoneStatus(),
      screenCapture: CGPreflightScreenCaptureAccess() ? .granted : .notDetermined,
      speechLocales: locales
    )
  }

  func speechAssetStatus(locale: String) async throws -> AssetStatus {
    try await speechAssetStatusFor(locale: locale, engine: SpeechSettings.Engine.appleSpeech.rawValue)
  }

  func installSpeechAssets(locale: String) async throws {
    guard #available(macOS 26.0, *) else { throw LiveEngineError.requiresMacOS26 }
    try await pigeonErrors { try await SpeechAssets.install(locale, .appleSpeech) }
  }

  func translationStatus(source: String, target: String) async throws -> AssetStatus {
    guard #available(macOS 15.0, *) else { return .unsupported }
    let status = await LanguageAvailability().status(
      from: Locale.Language(identifier: source), to: Locale.Language(identifier: target))
    switch status {
    case .installed: return .installed
    case .supported: return .supported
    default: return .unsupported
    }
  }

  func prepareTranslation(source: String, target: String) async throws {
    guard #available(macOS 15.0, *) else { throw LiveEngineError.requiresMacOS26 }
    let window: LanguagePackWindow = await MainActor.run {
      let window = (languagePacks as? LanguagePackWindow) ?? LanguagePackWindow()
      languagePacks = window
      return window
    }
    try await window.prepare(source: source, target: target)
  }

  func startLive(request: LiveStartRequest) async throws -> String {
    try await startLive(request, .defaults)
  }

  private func startLive(_ request: LiveStartRequest, _ settings: SpeechSettings) async throws -> String {
    guard #available(macOS 26.0, *) else { throw LiveEngineError.requiresMacOS26 }
    if let running = engine as? LiveCaptionEngine { await running.stop() }
    let sessionId = UUID().uuidString.lowercased()
    let engine = LiveCaptionEngine(sessionId: sessionId, request: request, settings: settings, overlay: overlay) {
      [events] event in events.send(event)
    }
    self.engine = engine
    do {
      try await pigeonErrors { try await engine.start() }
    } catch {
      await engine.stop()
      self.engine = nil
      throw error
    }
    return sessionId
  }

  func stopLive() async throws {
    guard #available(macOS 26.0, *), let engine = engine as? LiveCaptionEngine else { return }
    self.engine = nil
    await engine.stop()
  }

  func inspectMedia(path: String) async throws -> MediaFacts {
    try await inspectMediaFile(path)
  }

  func transcribeFile(request: FileTranscribeRequest) async throws {
    try await transcribeFile(request, .defaults)
  }

  private func transcribeFile(_ request: FileTranscribeRequest, _ settings: SpeechSettings) async throws {
    guard #available(macOS 26.0, *) else { throw LiveEngineError.requiresMacOS26 }
    let job = FileTranscriptionJob(request: request, settings: settings) { [events] event in events.send(event) }
    let task = Task { try await job.run() }
    jobsLock.withLock { jobs[request.jobId] = task }
    defer { _ = jobsLock.withLock { jobs.removeValue(forKey: request.jobId) } }
    try await pigeonErrors { try await task.value }
  }

  func cancelTranscription(jobId: String) throws {
    jobsLock.withLock { jobs[jobId] }?.cancel()
  }

  func secretRead(account: String) throws -> String? { try Keychain.read(account) }
  func secretWrite(account: String, value: String) throws { try Keychain.write(account, value) }
  func secretDelete(account: String) throws { try Keychain.delete(account) }

  func configureOverlay(config: OverlayConfig) throws {
    MainActor.assumeIsolated { overlay.configure(config) }
    // Dock menu titles for the runner's AppDelegate (see scripts/native).
    let dock = ["toggle", "showPanel", "unlock"].reduce(into: [String: String]()) { titles, key in
      if let title = config.strings["dock_\(key)"] { titles[key] = title }
    }
    UserDefaults.standard.set(dock, forKey: "dev.eeeease.tinglang.dockMenu")
  }

  func setOverlayVisible(visible: Bool) throws {
    MainActor.assumeIsolated { overlay.setVisible(visible) }
  }

  func resetOverlayPosition() throws {
    MainActor.assumeIsolated { overlay.resetPosition() }
  }

  func updatePanel(state: PanelState) throws {
    MainActor.assumeIsolated { overlay.update(state) }
  }

  func showMainWindow() throws {
    MainActor.assumeIsolated { revealMainWindow() }
  }

  func appReady() throws {
    isReady = true
  }

  func setWindowAppearance(mode: String) throws {
    let appearance: NSAppearance? =
      switch mode {
      case "light": NSAppearance(named: .aqua)
      case "dark": NSAppearance(named: .darkAqua)
      default: nil
      }
    MainActor.assumeIsolated { NSApp.appearance = appearance }
  }

  func openSystemSettings(pane: String) throws {
    let anchor =
      switch pane {
      case "microphone": "Privacy_Microphone"
      case "screenRecording": "Privacy_ScreenCapture"
      case "fullDiskAccess": "Privacy_AllFiles"
      default: ""
      }
    guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") else { return }
    NSWorkspace.shared.open(url)
  }

  func openUrl(url: String) throws {
    guard let target = URL(string: url), ["http", "https"].contains(target.scheme?.lowercased() ?? "")
    else { throw PigeonError(code: "invalid", message: "Only web pages can be opened", details: nil) }
    NSWorkspace.shared.open(target)
  }

  func authenticate(url: String, callbackScheme: String) async throws -> String {
    guard let start = URL(string: url) else {
      throw PigeonError(code: "invalid", message: "Not a valid sign-in address", details: nil)
    }
    return try await withCheckedThrowingContinuation { continuation in
      DispatchQueue.main.async { [webAuth] in
        MainActor.assumeIsolated {
          webAuth.start(start, callbackScheme: callbackScheme) { continuation.resume(with: $0) }
        }
      }
    }
  }

  func registerHotkey(id: String, key: String, command: Bool, shift: Bool, option: Bool, control: Bool) throws -> Bool {
    MainActor.assumeIsolated {
      hotkeys.register(id: id, key: key, command: command, shift: shift, option: option, control: control)
    }
  }

  func unregisterHotkey(id: String) throws {
    MainActor.assumeIsolated { hotkeys.unregister(id: id) }
  }

  // MARK: Speech models, portable capture and helpers (feat/speech-models)

  func startLiveWith(request: LiveStartRequest, speech: SpeechConfig) async throws -> String {
    try await startLive(request, pigeonErrorsNow { try SpeechSettings(speech) })
  }

  func transcribeFileWith(request: FileTranscribeRequest, speech: SpeechConfig) async throws {
    try await transcribeFile(request, pigeonErrorsNow { try SpeechSettings(speech) })
  }

  func speechAssetStatusFor(locale: String, engine: String) async throws -> AssetStatus {
    guard #available(macOS 26.0, *) else { return .unsupported }
    return try await pigeonErrors { try await SpeechAssets.status(locale, SpeechSettings.engine(engine)) }
  }

  func installSpeechAssetsFor(requestId: String, locale: String, engine: String) async throws {
    guard #available(macOS 26.0, *) else { throw pigeonError(LiveEngineError.requiresMacOS26) }
    let kind = try pigeonErrorsNow { try SpeechSettings.engine(engine) }
    let task = Task { [events] in
      try await SpeechAssets.install(locale, kind) { fraction in
        events.send(LiveEvent(kind: "assetProgress", sessionId: requestId, level: fraction))
      }
    }
    jobsLock.withLock { assetInstalls[requestId] = task }
    defer { _ = jobsLock.withLock { assetInstalls.removeValue(forKey: requestId) } }
    do {
      try await task.value
    } catch {
      if task.isCancelled || error is CancellationError {
        throw PigeonError(code: "canceled", message: "Cancelled the speech model download", details: nil)
      }
      throw pigeonError(error)
    }
  }

  func cancelSpeechAssets(requestId: String) throws {
    jobsLock.withLock { assetInstalls[requestId] }?.cancel()
  }

  func releaseSpeechAssets(locale: String, engine: String) async throws -> Bool {
    guard #available(macOS 26.0, *) else { return false }
    let kind = try pigeonErrorsNow { try SpeechSettings.engine(engine) }
    return await SpeechAssets.release(locale, kind)
  }

  func speechInventory() async throws -> SpeechInventory {
    guard #available(macOS 26.0, *) else {
      return SpeechInventory(speechSupported: [], speechInstalled: [], dictationSupported: [], dictationInstalled: [])
    }
    return await SpeechAssets.inventory()
  }

  func openCapture(request: CaptureRequest) async throws -> CaptureHandle {
    let captureId = "capture-\(UUID().uuidString.lowercased())"
    let capture = PortableCapture(
      captureId: captureId, request: request,
      emit: { [events] event in events.send(event) },
      // The panel's level meter (drawn only while it shows captions).
      level: { [overlay] value in overlay.level(value) })
    try pigeonErrorsNow { try capture.start() }
    jobsLock.withLock { captures[captureId] = capture }
    return CaptureHandle(
      captureId: captureId, ringAddress: capture.ring.address, capacity: Int64(capture.ring.capacity))
  }

  func closeCapture(captureId: String) async throws {
    let capture = jobsLock.withLock { captures.removeValue(forKey: captureId) }
    await capture?.stop()
  }

  func showCaptionLines(lines: [CaptionLineMessage], awaitingTranslation: Bool) throws {
    let tail = lines.suffix(30).map {
      CaptionLine(id: $0.segmentId, text: $0.text, translation: $0.translation, isFinal: $0.isFinal)
    }
    overlay.show(lines: Array(tail), awaitingTranslation: awaitingTranslation)
  }

  func decodeToPcmFile(path: String) async throws -> String {
    try await pigeonErrors { try await decodeToRawPcmFile(path).path }
  }

  func translateTexts(source: String, target: String, texts: [String]) async throws -> [String] {
    guard #available(macOS 26.0, *) else { throw pigeonError(TranslationError.requiresMacOS26) }
    let key = "\(source)→\(target)"
    var translator = jobsLock.withLock { translators[key] } as? AppleTranslator
    if translator == nil {
      guard let made = await AppleTranslator(source: source, target: target) else {
        throw pigeonError(TranslationError.packMissing(key))
      }
      jobsLock.withLock { translators[key] = made }
      translator = made
    }
    return try await pigeonErrors { try await translator!.translate(texts) }
  }

  func translationReady(source: String, target: String) async throws -> Bool {
    guard #available(macOS 26.0, *) else { return false }
    let status = await LanguageAvailability().status(
      from: Locale.Language(identifier: source), to: Locale.Language(identifier: target))
    return status == .installed
  }

  // MARK: Files opened with the app, iCloud Drive (sync)

  /// Queues files AppKit opened with the app and tells Dart (if it listens).
  func receiveOpenedFiles(_ paths: [String]) {
    openedFiles.append(contentsOf: paths)
    events.send(LiveEvent(kind: "filesOpened"))
  }

  func takeOpenedFiles() throws -> [String] {
    let files = openedFiles
    openedFiles.removeAll()
    return files
  }

  func cloudItemStates(paths: [String]) async throws -> [String] {
    paths.map(CloudDrive.state)
  }

  func cloudDownload(paths: [String]) async throws {
    for path in paths { CloudDrive.download(path) }
  }

  func machineIdentifier() throws -> String? {
    CloudDrive.machineIdentifier()
  }

  private static var processArch: String {
    #if arch(arm64)
      return "arm64"
    #elseif arch(x86_64)
      return "x86_64"
    #else
      return "other"
    #endif
  }

  private static func microphoneStatus() -> PermissionStatus {
    switch AVCaptureDevice.authorizationStatus(for: .audio) {
    case .authorized: return .granted
    case .denied: return .denied
    case .restricted: return .restricted
    case .notDetermined: return .notDetermined
    @unknown default: return .notDetermined
    }
  }
}

/// Holds the Dart event sink; events are delivered on the main thread.
final class LiveEventsHandler: LiveEventsStreamHandler, @unchecked Sendable {
  private var sink: PigeonEventSink<LiveEvent>?

  override func onListen(withArguments arguments: Any?, sink: PigeonEventSink<LiveEvent>) {
    self.sink = sink
  }

  override func onCancel(withArguments arguments: Any?) {
    sink = nil
  }

  func send(_ event: LiveEvent) {
    if Thread.isMainThread {
      sink?.success(event)
    } else {
      DispatchQueue.main.async { [weak self] in self?.sink?.success(event) }
    }
  }
}

/// Engine errors as PigeonError, so Dart sees a stable code (e.g.
/// `assetsMissing`) and the readable message instead of a Swift type name.
func pigeonError(_ error: Error) -> Error {
  switch error {
  case let error as LiveEngineError:
    return PigeonError(code: error.code, message: error.localizedDescription, details: nil)
  case let error as TranslationError:
    return PigeonError(code: error.code, message: error.localizedDescription, details: nil)
  case is CancellationError:
    return PigeonError(code: "canceled", message: "Cancelled", details: nil)
  case let error as PigeonError:
    return error
  case let error as LocalizedError:
    return PigeonError(code: "failed", message: error.localizedDescription, details: nil)
  default:
    return error
  }
}

func pigeonErrorsNow<T>(_ body: () throws -> T) throws -> T {
  do { return try body() } catch { throw pigeonError(error) }
}

func pigeonErrors<T>(_ body: () async throws -> T) async throws -> T {
  do { return try await body() } catch { throw pigeonError(error) }
}

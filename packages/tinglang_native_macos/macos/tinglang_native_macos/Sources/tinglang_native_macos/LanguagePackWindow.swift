// Portions adapted from SubFlow SubFlowApp.setupTranslation()
// Copyright (c) 2025 Jinsong Zhou, MIT License; modified 2026.
import AppKit
import SwiftUI
import Translation

/// Translation packs can only be downloaded from a SwiftUI `.translationTask`.
/// This small window hosts one, lets macOS show its download prompt and
/// closes itself when the pack is ready (or the user dismisses it).
@available(macOS 15.0, *)
@MainActor
final class LanguagePackWindow {
  private var window: NSWindow?

  func prepare(source: String, target: String) async throws {
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
      var finished = false
      let finish: (Error?) -> Void = { [weak self] error in
        guard !finished else { return }
        finished = true
        self?.window?.orderOut(nil)
        self?.window = nil
        if let error { continuation.resume(throwing: error) } else { continuation.resume() }
      }
      let configuration = TranslationSession.Configuration(
        source: Locale.Language(identifier: source), target: Locale.Language(identifier: target))
      let view = VStack(spacing: 12) {
        ProgressView()
        Text("\(source) → \(target)").font(.headline)
      }
      .padding(28)
      .frame(width: 360, height: 140)
      .translationTask(configuration) { session in
        do {
          try await session.prepareTranslation()
          finish(nil)
        } catch {
          finish(error)
        }
      }
      let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 360, height: 140), styleMask: [.titled, .closable],
        backing: .buffered, defer: false)
      window.isReleasedWhenClosed = false
      window.title = "Tinglang"
      window.contentView = NSHostingView(rootView: view)
      window.center()
      window.makeKeyAndOrderFront(nil)
      NSApp.activate()
      self.window = window
      NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { _ in
        MainActor.assumeIsolated { finish(CancellationError()) }
      }
    }
  }
}

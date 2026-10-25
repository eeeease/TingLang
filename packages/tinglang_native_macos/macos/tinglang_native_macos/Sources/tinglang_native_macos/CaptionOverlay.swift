// Portions adapted from SubFlow FloatingPanel.swift / FloatingCaptionView.swift
// Copyright (c) 2025 Jinsong Zhou, MIT License; modified 2026 (rewritten as an
// interactive capture panel: controls, states, appearance, drop target).
import AppKit
import SwiftUI

/// The floating capture panel: the app's front door. A non-activating,
/// always-on-top panel on every Space (including over full-screen apps) that
/// starts and stops live captions, shows them, and accepts dropped audio.
/// Dart owns the state and the persisted look; button presses go back to it.
@MainActor
final class CaptionOverlayController {
  static let anchorKey = "dev.eeeease.tinglang.panelAnchor"
  static let widthKey = "dev.eeeease.tinglang.panelCaptionWidth"
  static let sideBySideWidthKey = "dev.eeeease.tinglang.panelSideBySideWidth"

  let model = PanelModel()
  /// (action, value) for Dart: `toggle`, `openHistory`, `openSession`…
  var onAction: ((String, String?) -> Void)?
  var onDrop: (([String]) -> Void)?
  /// JSON of a look chosen on the panel itself.
  var onStyle: ((String) -> Void)?

  private var panel: CapturePanelWindow?
  private var host: PanelHostingView<CapturePanelView>?
  private var badge: UnlockBadge?
  private var lockTimer: Timer?
  private var visible = false
  /// Pointer and window origin when a drag of the panel began.
  private var dragStart: (mouse: NSPoint, origin: NSPoint)?

  /// How long the pointer rests on a control before its hint shows.
  static let hintDelay: TimeInterval = 0.5
  private var hintWindow: PanelHintWindow?
  private var hintTimer: Timer?
  /// The control under the pointer.
  private var hoveredHint: PanelHint?
  /// A click hides the hint until the pointer leaves that control.
  private var suppressedHintId: String?
  private var hintHiddenAt = Date.distantPast

  init() {
    let width = UserDefaults.standard.double(forKey: Self.widthKey)
    if width >= 360 { model.captionWidth = width }
    let sideBySide = UserDefaults.standard.double(forKey: Self.sideBySideWidthKey)
    if sideBySide >= 360 { model.sideBySideWidth = sideBySide }
    model.onHint = { [weak self] hint, id in self?.hover(hint, id: id) }
  }

  // MARK: Dart control

  func configure(_ config: OverlayConfig) {
    let style = PanelStyle(config)
    model.strings = config.strings
    model.translatingLabel = config.translatingLabel
    model.style = style
    model.setScrollback(style.scrollbackLines)
    applyStyle()
  }

  func update(_ state: PanelState) {
    model.phase = PanelPhase(rawValue: state.phase) ?? .idle
    model.source = state.source
    model.startedAt = state.startedAtMs.map { Date(timeIntervalSince1970: Double($0) / 1000) }
    model.message = state.message
    model.action = state.action
    model.actionLabel = state.actionLabel
    model.progress = state.progress
    model.dueCount = Int(state.dueCount)
    model.newRecordings = Int(state.newRecordings)
    model.sessionId = state.sessionId
    model.summary = state.summary
    model.canStart = state.canStart
    if !model.isListening { model.level = 0 }
    applyStyle()
  }

  func setVisible(_ visible: Bool) {
    self.visible = visible
    if visible {
      open()
    } else {
      hideHint()
      panel?.orderOut(nil)
      badge?.orderOut(nil)
    }
  }

  func resetPosition() {
    guard let panel, let screen = NSScreen.main?.visibleFrame else { return }
    let size = panel.frame.size
    let origin = NSPoint(x: screen.midX - size.width / 2, y: screen.minY + 72)
    panel.setFrameOrigin(origin)
    saveAnchor()
  }

  // MARK: Engine (any thread)

  nonisolated func begin() { Task { @MainActor in self.model.clearCaptions() } }
  nonisolated func end() { Task { @MainActor in self.model.clearCaptions() } }

  /// Called at ≤10 Hz with the engine's newest lines; the panel keeps up to
  /// the scroll-back limit of them.
  nonisolated func show(lines: [CaptionLine], awaitingTranslation: Bool) {
    Task { @MainActor in
      self.model.receive(lines)
      self.model.awaitingTranslation = awaitingTranslation
    }
  }

  nonisolated func level(_ value: Double) {
    Task { @MainActor in self.model.level = value }
  }

  // MARK: Window

  private func open() {
    if panel == nil { makePanel() }
    guard let panel else { return }
    panel.orderFrontRegardless()
    applyStyle()
  }

  private func makePanel() {
    let panel = CapturePanelWindow(
      contentRect: NSRect(x: 0, y: 0, width: 420, height: 52),
      styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
      backing: .buffered, defer: false)
    panel.level = .floating
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = true
    // Moved by a drag gesture and CapturePanelWindow.sendEvent instead (see moveWindow).
    panel.isMovableByWindowBackground = false
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    panel.hidesOnDeactivate = false
    panel.isReleasedWhenClosed = false
    // A click (or the start of a drag) puts the hint away, like a tooltip.
    panel.onMouseDown = { [weak self] in self?.hideHint(suppress: true) }

    let view = CapturePanelView(
      model: model,
      send: { [weak self] action, value in self?.handle(action: action, value: value) },
      changeStyle: { [weak self] style in self?.changeStyle(style) },
      moveWindow: { [weak self] translation in self?.moveWindow(translation: translation) })
    let host = PanelHostingView(rootView: view)
    host.sizingOptions = [.intrinsicContentSize]
    host.onSizeChange = { [weak self] size in self?.resize(to: size) }
    host.onDragChange = { [weak self] inside in self?.model.isDropTarget = inside }
    host.onDropFiles = { [weak self] urls in self?.onDrop?(urls.map(\.path)) }
    panel.contentView = host
    self.panel = panel
    self.host = host

    NotificationCenter.default.addObserver(forName: NSWindow.didMoveNotification, object: panel, queue: .main) {
      [weak self] _ in
      MainActor.assumeIsolated {
        self?.hideHint()
        self?.saveAnchor()
      }
    }
    let size = host.intrinsicContentSize
    panel.setContentSize(size)
    if let anchor = UserDefaults.standard.string(forKey: Self.anchorKey) {
      let point = NSPointFromString(anchor)
      let frame = NSRect(x: point.x - size.width / 2, y: point.y, width: size.width, height: size.height)
      if NSScreen.screens.contains(where: { $0.visibleFrame.intersects(frame) }) {
        panel.setFrameOrigin(frame.origin)
      } else {
        resetPosition()
      }
    } else {
      resetPosition()
    }
  }

  /// Keeps the bottom edge and the horizontal centre still while the content
  /// grows (pill → captions) or shrinks.
  private func resize(to size: NSSize) {
    guard let panel, size.width > 0, size.height > 0, panel.frame.size != size else { return }
    let old = panel.frame
    var frame = NSRect(x: old.midX - size.width / 2, y: old.minY, width: size.width, height: size.height)
    // A wider look (side by side) must not push the panel off its screen.
    if let screen = (panel.screen ?? NSScreen.main)?.visibleFrame, frame.width <= screen.width {
      frame.origin.x = min(max(frame.minX, screen.minX), screen.maxX - frame.width)
    }
    panel.setFrame(frame, display: true)
    panel.invalidateShadow()
  }

  /// Follows the pointer in screen coordinates, so the moving window does not
  /// feed back into the gesture. [translation] (window points, y down) is
  /// only used once, to find where the drag began.
  private func moveWindow(translation: CGSize?) {
    guard let panel else { return }
    guard let translation else {
      dragStart = nil
      saveAnchor()
      return
    }
    let mouse = Self.pointerOnScreen()
    let start =
      dragStart ?? (NSPoint(x: mouse.x - translation.width, y: mouse.y + translation.height), panel.frame.origin)
    dragStart = start
    panel.setFrameOrigin(NSPoint(x: start.origin.x + mouse.x - start.mouse.x, y: start.origin.y + mouse.y - start.mouse.y))
  }

  /// Where the event being handled happened, else the pointer now.
  private static func pointerOnScreen() -> NSPoint {
    if let event = NSApp.currentEvent, let window = event.window,
      [.leftMouseDown, .leftMouseDragged, .leftMouseUp].contains(event.type)
    {
      return window.convertPoint(toScreen: event.locationInWindow)
    }
    return NSEvent.mouseLocation
  }

  private func saveAnchor() {
    guard let frame = panel?.frame else { return }
    UserDefaults.standard.set(NSStringFromPoint(NSPoint(x: frame.midX, y: frame.minY)), forKey: Self.anchorKey)
    if let badge, badge.isVisible { positionBadge(badge) }
  }

  private func applyStyle() {
    guard let panel else { return }
    let style = model.style
    let locked = model.isLocked
    panel.ignoresMouseEvents = locked
    // A text-only panel with no background must not cast a box-shaped shadow.
    panel.hasShadow = !(model.isListening && style.isTextOnly && style.background == "clear")
    panel.invalidateShadow()
    if locked { startLockWatch() } else { stopLockWatch() }
  }

  // MARK: Actions

  private func handle(action: String, value: String?) {
    switch action {
    case "resetPosition":
      resetPosition()
    case "hide":
      setVisible(false)
      onAction?(action, value)
    default:
      onAction?(action, value)
    }
  }

  private func changeStyle(_ style: PanelStyle) {
    model.style = style
    applyStyle()
    onStyle?(style.json)
  }

  // MARK: Hints

  /// The pointer entered a control ([hint]) or left the control [id]. The hint
  /// shows after [hintDelay]; moving on to the next control while one shows
  /// (or just did) changes it at once, as tooltips do.
  private func hover(_ hint: PanelHint?, id: String) {
    guard let hint else {
      if suppressedHintId == id { suppressedHintId = nil }
      // Leaving a control after the pointer already entered the next one.
      guard hoveredHint?.id == id else { return }
      hoveredHint = nil
      hideHint()
      return
    }
    hoveredHint = hint
    guard hint.id != suppressedHintId else { return }
    hintTimer?.invalidate()
    hintTimer = nil
    if hintWindow?.isVisible == true || Date().timeIntervalSince(hintHiddenAt) < 0.3 {
      showHint()
    } else {
      let timer = Timer(timeInterval: Self.hintDelay, repeats: false) { [weak self] _ in
        MainActor.assumeIsolated { self?.showHint() }
      }
      // Common modes: also while AppKit tracks the mouse or scrolls.
      RunLoop.main.add(timer, forMode: .common)
      hintTimer = timer
    }
  }

  /// Above the panel, centred on the control; below it when the panel is at
  /// the top of the screen.
  private func showHint() {
    hintTimer = nil
    guard let hint = hoveredHint, let panel, panel.isVisible, !model.isLocked, !hint.text.isEmpty else { return }
    let window = hintWindow ?? PanelHintWindow()
    hintWindow = window
    let size = window.setText(hint.text)
    // The hosting view fills the borderless panel; SwiftUI's frame is top-left.
    let controlMidX = panel.frame.minX + hint.frame.midX
    var origin = NSPoint(x: controlMidX - size.width / 2, y: panel.frame.maxY + 6)
    if let screen = (panel.screen ?? NSScreen.main)?.visibleFrame {
      if origin.y + size.height > screen.maxY { origin.y = panel.frame.minY - 6 - size.height }
      origin.x = min(max(origin.x, screen.minX + 4), screen.maxX - size.width - 4)
    }
    window.setFrameOrigin(origin)
    window.orderFrontRegardless()
  }

  /// [suppress]: after a click, the hint stays away until the pointer leaves
  /// that control.
  private func hideHint(suppress: Bool = false) {
    hintTimer?.invalidate()
    hintTimer = nil
    if suppress, let hoveredHint { suppressedHintId = hoveredHint.id }
    if let hintWindow, hintWindow.isVisible {
      hintWindow.orderOut(nil)
      hintHiddenAt = suppress ? .distantPast : Date()
    }
  }

  // MARK: Lock

  /// While locked the panel ignores the mouse, so a tiny separate window
  /// offers "unlock" when the pointer rests over the captions.
  private func startLockWatch() {
    guard lockTimer == nil else { return }
    lockTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
      MainActor.assumeIsolated { self?.checkPointer() }
    }
  }

  private func stopLockWatch() {
    lockTimer?.invalidate()
    lockTimer = nil
    badge?.orderOut(nil)
    model.pointerInside = false
  }

  private func checkPointer() {
    guard let panel, panel.isVisible else { return }
    let inside = panel.frame.insetBy(dx: -6, dy: -6).contains(NSEvent.mouseLocation)
    let overBadge = badge.map { $0.isVisible && $0.frame.contains(NSEvent.mouseLocation) } ?? false
    if model.pointerInside != (inside || overBadge) { model.pointerInside = inside || overBadge }
    if inside {
      let badge = self.badge ?? makeBadge()
      positionBadge(badge)
      badge.orderFrontRegardless()
    } else if let badge, !badge.frame.contains(NSEvent.mouseLocation) {
      badge.orderOut(nil)
    }
  }

  private func makeBadge() -> UnlockBadge {
    let badge = UnlockBadge(title: model.text("unlock", "Unlock"), accent: Color(argb: model.style.accentColor)) {
      [weak self] in
      guard let self else { return }
      var next = self.model.style
      next.clickThrough = false
      self.changeStyle(next)
    }
    self.badge = badge
    return badge
  }

  private func positionBadge(_ badge: UnlockBadge) {
    guard let panel else { return }
    let size = badge.frame.size
    badge.setFrameOrigin(NSPoint(x: panel.frame.maxX - size.width - 8, y: panel.frame.maxY + 6))
  }
}

/// Becomes key for its popovers without activating the app, so whatever the
/// user is watching keeps focus.
final class CapturePanelWindow: NSPanel {
  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { false }

  /// Any press on the panel.
  var onMouseDown: (() -> Void)?
  /// A press on the captions that may become a move of the panel.
  private var captionDrag: (mouse: NSPoint, origin: NSPoint, moving: Bool)?

  /// The captions scroll view keeps mouse drags to itself, and a SwiftUI
  /// gesture inside it misses drags while lines stream in; so a drag that
  /// starts on the captions moves the window here. Elsewhere the SwiftUI
  /// gesture in CapturePanelView does it.
  override func sendEvent(_ event: NSEvent) {
    switch event.type {
    case .rightMouseDown:
      onMouseDown?()
    case .leftMouseDown:
      onMouseDown?()
      captionDrag = startsOnCaptions(event) ? (convertPoint(toScreen: event.locationInWindow), frame.origin, false) : nil
    case .leftMouseDragged:
      if var drag = captionDrag {
        let mouse = convertPoint(toScreen: event.locationInWindow)
        if !drag.moving && hypot(mouse.x - drag.mouse.x, mouse.y - drag.mouse.y) >= 3 { drag.moving = true }
        captionDrag = drag
        if drag.moving {
          setFrameOrigin(NSPoint(x: drag.origin.x + mouse.x - drag.mouse.x, y: drag.origin.y + mouse.y - drag.mouse.y))
          return
        }
      }
    case .leftMouseUp:
      captionDrag = nil
    default:
      break
    }
    super.sendEvent(event)
  }

  private func startsOnCaptions(_ event: NSEvent) -> Bool {
    guard let content = contentView, let hit = content.hitTest(content.convert(event.locationInWindow, from: nil))
    else { return false }
    if hit is NSScroller { return false }
    return hit is NSScrollView || hit.enclosingScrollView != nil
  }
}

/// Hosts the SwiftUI panel: first click works without activating, the window
/// follows the content size, and audio files (including Voice Memos' file
/// promises) can be dropped on it.
final class PanelHostingView<Content: View>: NSHostingView<Content> {
  var onSizeChange: ((NSSize) -> Void)?
  var onDragChange: ((Bool) -> Void)?
  var onDropFiles: (([URL]) -> Void)?

  required init(rootView: Content) {
    super.init(rootView: rootView)
    registerForDraggedTypes([.fileURL] + NSFilePromiseReceiver.readableDraggedTypes.map { NSPasteboard.PasteboardType($0) })
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

  override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

  override func invalidateIntrinsicContentSize() {
    super.invalidateIntrinsicContentSize()
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      self.onSizeChange?(self.intrinsicContentSize)
    }
  }

  override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
    onDragChange?(true)
    return .copy
  }

  override func draggingExited(_ sender: NSDraggingInfo?) { onDragChange?(false) }

  override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
    onDragChange?(false)
    let board = sender.draggingPasteboard
    if let urls = board.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
      !urls.isEmpty
    {
      onDropFiles?(urls)
      return true
    }
    guard let promises = board.readObjects(forClasses: [NSFilePromiseReceiver.self]) as? [NSFilePromiseReceiver],
      !promises.isEmpty
    else { return false }
    let folder = FileManager.default.temporaryDirectory
      .appendingPathComponent("dropped-\(UUID().uuidString)", isDirectory: true)
    try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    var received: [URL] = []
    let group = DispatchGroup()
    for promise in promises {
      group.enter()
      promise.receivePromisedFiles(atDestination: folder, options: [:], operationQueue: .main) { url, error in
        if error == nil { received.append(url) }
        group.leave()
      }
    }
    group.notify(queue: .main) { [weak self] in
      if !received.isEmpty { self?.onDropFiles?(received) }
    }
    return true
  }
}

/// "Unlock" chip shown above a locked (click-through) panel.
final class UnlockBadge: NSPanel {
  init(title: String, accent: Color, action: @escaping () -> Void) {
    super.init(
      contentRect: NSRect(x: 0, y: 0, width: 96, height: 30),
      styleMask: [.nonactivatingPanel, .borderless], backing: .buffered, defer: false)
    level = .floating
    isOpaque = false
    backgroundColor = .clear
    hasShadow = true
    collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    hidesOnDeactivate = false
    let host = FirstClickHostingView(
      rootView: Button(action: action) {
        Label(title, systemImage: "lock.open.fill")
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(Color(red: 0.1, green: 0.06, blue: 0.03))
          .padding(.horizontal, 12).padding(.vertical, 6)
          .background(Capsule().fill(accent))
      }
      .buttonStyle(.plain)
      .fixedSize())
    host.sizingOptions = [.intrinsicContentSize]
    contentView = host
    setContentSize(host.intrinsicContentSize)
  }
}

/// The hint above the panel: what the control under the pointer does. It never
/// takes the mouse, so it cannot get in the way of the panel or what is below.
final class PanelHintWindow: NSPanel {
  private let host = NSHostingView(rootView: PanelHintLabel(text: ""))

  init() {
    super.init(
      contentRect: NSRect(x: 0, y: 0, width: 40, height: 24),
      styleMask: [.nonactivatingPanel, .borderless], backing: .buffered, defer: false)
    // Above the panel, which is at .floating.
    level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + 1)
    isOpaque = false
    backgroundColor = .clear
    hasShadow = true
    ignoresMouseEvents = true
    collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
    hidesOnDeactivate = false
    isReleasedWhenClosed = false
    contentView = host
  }

  /// Shows [text] and returns the window's new size.
  func setText(_ text: String) -> NSSize {
    host.rootView = PanelHintLabel(text: text)
    let size = host.fittingSize
    setContentSize(size)
    invalidateShadow()
    return size
  }
}

/// Dark like the panel, whatever the system appearance.
struct PanelHintLabel: View {
  let text: String

  var body: some View {
    let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
    Text(text)
      .font(.system(size: 12, weight: .medium))
      .foregroundStyle(.white.opacity(0.92))
      .lineLimit(1)
      .fixedSize()
      .padding(.horizontal, 10)
      .padding(.vertical, 5)
      .background(shape.fill(Color(argb: 0xFF1E_1E1D).opacity(0.94)))
      .overlay(shape.strokeBorder(.white.opacity(0.14), lineWidth: 1))
      .environment(\.colorScheme, .dark)
  }
}

/// A hosting view whose first click acts even though the panel never
/// activates the app.
final class FirstClickHostingView<Content: View>: NSHostingView<Content> {
  override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

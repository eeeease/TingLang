import Cocoa
import FlutterMacOS

// The history/library/settings window. The floating capture panel is the
// app's front door, so this window starts hidden (MainMenu.xib) and stays
// hidden until the user asks for it: the Dock icon, a panel button, or a
// failed start. Other attempts to show it (for example once Flutter has
// drawn its first frame) are ignored. Mic permission is in Info.plist.
class MainFlutterWindow: NSWindow {
  private var revealed = false

  override func awakeFromNib() {
    // A plain FlutterViewController starts Dart only once its view appears;
    // this window starts hidden and Dart drives the floating panel, so the
    // engine is created and run here.
    let engine = FlutterEngine(name: "main", project: nil, allowHeadlessExecution: true)
    let controller = FlutterViewController(engine: engine, nibName: nil, bundle: nil)
    contentViewController = controller
    let visible = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 960)
    setContentSize(NSSize(width: min(1380, visible.width - 80), height: min(900, visible.height - 80)))
    minSize = NSSize(width: 850, height: 620)
    title = "TingLang"
    // No title bar strip: the content runs under transparent window chrome;
    // Flutter leaves the traffic lights and the top 28 pt (dragging) free.
    titleVisibility = .hidden
    titlebarAppearsTransparent = true
    styleMask.insert(.fullSizeContentView)
    center()
    // Audio or video dropped anywhere on the window is imported, as on the
    // floating panel; the plugin hands the paths to Dart.
    registerForDraggedTypes([.fileURL])
    RegisterGeneratedPlugins(registry: controller)
    engine.run(withEntrypoint: nil)
    super.awakeFromNib()
  }

  /// Shows and focuses the window (called by the plugin and AppDelegate).
  @objc func reveal() {
    revealed = true
    NSApp.activate()
    makeKeyAndOrderFront(nil)
  }

  override func order(_ place: NSWindow.OrderingMode, relativeTo otherWin: Int) {
    guard revealed || place == .out else { return }
    super.order(place, relativeTo: otherWin)
  }

  override func orderFrontRegardless() {
    guard revealed else { return }
    super.orderFrontRegardless()
  }
}

// The Flutter view does not take drops, so they fall through to the window.
extension MainFlutterWindow: NSDraggingDestination {
  private func fileURLs(_ sender: NSDraggingInfo) -> [URL] {
    sender.draggingPasteboard.readObjects(
      forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
  }

  func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
    fileURLs(sender).isEmpty ? [] : .copy
  }

  func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
    let paths = fileURLs(sender).map(\.path)
    guard !paths.isEmpty else { return false }
    NotificationCenter.default.post(
      name: Notification.Name("dev.eeeease.tinglang.windowDrop"), object: nil,
      userInfo: ["paths": paths])
    return true
  }
}

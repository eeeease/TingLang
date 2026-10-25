import Cocoa
import FlutterMacOS

// The floating capture panel is the app's front door; the main window
// (history, library, settings) is hidden at launch and opened on demand.
@main
class AppDelegate: FlutterAppDelegate {
  override func applicationWillFinishLaunching(_ notification: Notification) {
    super.applicationWillFinishLaunching(notification)
    // ⌘W closes the main window (the generated menu has no Close item).
    let close = NSMenuItem(title: "Close Window", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
    NSApp.windowsMenu?.insertItem(close, at: 0)
  }

  /// Closing the main window keeps the app, and its panel, running.
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  /// A click on the Dock icon opens the main window.
  override func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    (mainFlutterWindow as? MainFlutterWindow)?.reveal()
    return true
  }

  /// Caption controls in the Dock menu. Titles follow the app's language; the
  /// native plugin stores them and handles the actions.
  override func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
    let titles = UserDefaults.standard.dictionary(forKey: "dev.eeeease.tinglang.dockMenu") as? [String: String] ?? [:]
    let menu = NSMenu()
    for (action, fallback) in [
      ("toggle", "Start or stop captions"), ("showPanel", "Show floating window"), ("unlock", "Unlock captions"),
    ] {
      let item = NSMenuItem(title: titles[action] ?? fallback, action: #selector(dockAction(_:)), keyEquivalent: "")
      item.target = self
      item.representedObject = action
      menu.addItem(item)
    }
    return menu
  }

  @objc private func dockAction(_ sender: NSMenuItem) {
    NotificationCenter.default.post(
      name: Notification.Name("dev.eeeease.tinglang.panelAction"), object: nil,
      userInfo: ["action": sender.representedObject as? String ?? ""])
  }
}

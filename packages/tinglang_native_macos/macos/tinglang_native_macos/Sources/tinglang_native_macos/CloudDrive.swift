import FlutterMacOS
import Foundation
import IOKit

/// iCloud Drive for sync: plain files in ~/Library/Mobile Documents that
/// macOS uploads and downloads. Tinglang has no iCloud container (no paid
/// developer account), so it never talks to iCloud itself; these helpers
/// only read what macOS knows about each file and ask it to download.
enum CloudDrive {
  /// `local`, `current`, `outdated`, `notDownloaded` or `missing`.
  static func state(_ path: String) -> String {
    let url = URL(fileURLWithPath: path)
    let keys: Set<URLResourceKey> = [.isUbiquitousItemKey, .ubiquitousItemDownloadingStatusKey]
    guard let values = try? url.resourceValues(forKeys: keys) else {
      return FileManager.default.fileExists(atPath: path) ? "local" : "missing"
    }
    guard values.isUbiquitousItem == true, let status = values.ubiquitousItemDownloadingStatus else {
      return FileManager.default.fileExists(atPath: path) ? "local" : "missing"
    }
    switch status {
    case .current: return "current"
    case .downloaded: return "outdated"
    case .notDownloaded: return "notDownloaded"
    default: return "local"
    }
  }

  /// Requests a download; falls back to `brctl download` when FileManager
  /// refuses (for example an item it does not consider ubiquitous yet).
  static func download(_ path: String) {
    do {
      try FileManager.default.startDownloadingUbiquitousItem(at: URL(fileURLWithPath: path))
    } catch {
      let process = Process()
      process.executableURL = URL(fileURLWithPath: "/usr/bin/brctl")
      process.arguments = ["download", path]
      process.standardOutput = FileHandle.nullDevice
      process.standardError = FileHandle.nullDevice
      try? process.run()
    }
  }

  /// IOPlatformUUID of this Mac. Used only to notice a library that was
  /// copied to another Mac; it is hashed and never leaves the Mac.
  static func machineIdentifier() -> String? {
    let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
    guard service != 0 else { return nil }
    defer { IOObjectRelease(service) }
    let value = IORegistryEntryCreateCFProperty(service, "IOPlatformUUID" as CFString, kCFAllocatorDefault, 0)
    return value?.takeRetainedValue() as? String
  }
}

extension TinglangNativeMacosPlugin: FlutterAppLifecycleDelegate {
  /// Documents opened with the app (Finder, Open With, the Dock icon) arrive
  /// here through FlutterAppDelegate, also on a cold launch: the plugin is
  /// registered while the main window loads, before AppKit opens files.
  /// They wait until Dart takes them, so none is lost while Dart starts.
  @objc(handleOpenURLs:)
  public func handleOpen(_ urls: [URL]) -> Bool {
    let paths = urls.filter(\.isFileURL).map(\.path)
    guard !paths.isEmpty else { return false }
    receiveOpenedFiles(paths)
    return true
  }
}

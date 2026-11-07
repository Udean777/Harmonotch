import AppKit
import Foundation

enum AppLauncher {
  static func activateOrOpen(bundleID: String, fallbackURL: URL? = nil) {
    let clean = bundleID.trimmingCharacters(in: .whitespacesAndNewlines)
    if !clean.isEmpty {
      if let running = NSRunningApplication.runningApplications(withBundleIdentifier: clean).first {
        running.activate(options: [.activateAllWindows])
        return
      }
      if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: clean) {
        NSWorkspace.shared.openApplication(
          at: url,
          configuration: NSWorkspace.OpenConfiguration(),
          completionHandler: nil
        )
        return
      }
    }
    if let fallbackURL {
      NSWorkspace.shared.open(fallbackURL)
    }
  }
}

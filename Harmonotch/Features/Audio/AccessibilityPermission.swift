import AppKit
import ApplicationServices
import Foundation

extension VolumeHUDController {
  /// Resets the stale TCC entry of ad-hoc builds so the System Settings switch is valid again.
  func requestAccessibilityPermission(resetStaleEntry: Bool = true, openSettings: Bool = true) {
    let bundleID = Bundle.main.bundleIdentifier ?? "com.ssajudn.Harmonotch"
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      if resetStaleEntry && !AXIsProcessTrusted() {
        ProcessRunner.runQuietly("/usr/bin/tccutil", ["reset", "Accessibility", bundleID])
      }
      DispatchQueue.main.async {
        let options =
          [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        if openSettings {
          if let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
          ) {
            NSWorkspace.shared.open(url)
          }
        }
        self?.syncWithPreferences()
      }
    }
  }

  static func openAccessibilitySettings() {
    shared.requestAccessibilityPermission(resetStaleEntry: true, openSettings: true)
  }

  func updatePermissionPolling(enabled: Bool, trusted: Bool) {
    let shouldPoll = enabled && !trusted && isSessionActive
    if shouldPoll {
      guard permissionPollTimer == nil else { return }
      let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
        guard let self else { return }
        let nowTrusted = AXIsProcessTrusted()
        if nowTrusted != self.isAccessibilityGranted {
          self.syncWithPreferences()
        }
      }
      timer.tolerance = 0.3
      RunLoop.main.add(timer, forMode: .common)
      permissionPollTimer = timer
    } else {
      permissionPollTimer?.invalidate()
      permissionPollTimer = nil
    }
  }
}

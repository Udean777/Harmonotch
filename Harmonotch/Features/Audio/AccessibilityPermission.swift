import AppKit
import ApplicationServices
import Foundation

extension VolumeHUDController {
  /// Prompts the macOS system accessibility permission alert dialog if not already trusted.
  /// Resets stale TCC entries of ad-hoc/local builds so macOS triggers the system prompt cleanly.
  func requestAccessibilityPermission(resetStaleEntry: Bool = true) {
    let bundleID = Bundle.main.bundleIdentifier ?? "com.ssajudn.Harmonotch"
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      if resetStaleEntry && !AXIsProcessTrusted() {
        ProcessRunner.runQuietly("/usr/bin/tccutil", ["reset", "Accessibility", bundleID])
        usleep(100_000)
      }
      DispatchQueue.main.async {
        let options =
          [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        self?.syncWithPreferences()
      }
    }
  }

  static func openAccessibilitySettings() {
    shared.requestAccessibilityPermission(resetStaleEntry: true)
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

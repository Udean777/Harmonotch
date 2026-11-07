import AppKit
import Foundation

extension UpdateManager {
  func performBackgroundInstall(dmgPath: String, targetVersion: String) {
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self = self else { return }
      let appPath = Bundle.main.bundlePath
      let script = UpdateInstallerSupport.installScript(
        appPath: appPath, dmgPath: dmgPath, expectedVersion: targetVersion)

      var installSucceeded = ProcessRunner.runQuietly("/bin/sh", ["-c", script])

      // If user permissions failed on /Applications, retry with AppleScript admin privileges
      if !installSucceeded {
        installSucceeded = AppleScriptRunner.runAsAdmin(shell: script)
      }

      try? FileManager.default.removeItem(atPath: dmgPath)

      DispatchQueue.main.async {
        if installSucceeded {
          self.state = .readyToQuit(version: targetVersion)
        } else {
          self.state = .failed("Installation failed.")
          self.showAlert(
            title: L10n.Update.downloadFailedTitle,
            message: "Installation failed. Please try again or download manually.")
        }
      }
    }
  }

  func quitAfterUpdate(relaunch: Bool = false) {
    if relaunch {
      let appPath = Bundle.main.bundlePath
      let pid = ProcessInfo.processInfo.processIdentifier
      DetachedProcess.relaunchAfterExit(appPath: appPath, pid: pid)
    }
    NSApplication.shared.terminate(nil)
  }

  func openReleasePage() {
    guard
      let url = releaseNotesUrl
        ?? URL(string: "https://github.com/\(repoOwner)/\(repoName)/releases/latest")
    else { return }
    NSWorkspace.shared.open(url)
  }
}

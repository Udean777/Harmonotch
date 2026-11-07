import AppKit
import Foundation

extension UpdateManager {
  func showAlert(title: String, message: String) {
    let alert = NSAlert()
    alert.messageText = title
    alert.informativeText = message
    alert.alertStyle = .informational
    alert.addButton(withTitle: L10n.About.close)
    alert.runModal()
  }

  func showUpdateAvailableDialog(version: String) {
    let alert = NSAlert()
    alert.messageText = L10n.Update.updateAvailableTitle(version: version)
    alert.informativeText = L10n.Update.updateAvailablePrompt
    alert.alertStyle = .informational
    alert.addButton(withTitle: L10n.Update.updateNow)
    alert.addButton(withTitle: L10n.Update.viewReleaseNotes)
    alert.addButton(withTitle: L10n.Update.later)

    let response = alert.runModal()
    switch response {
    case .alertFirstButtonReturn:
      downloadAndInstallUpdate()
    case .alertSecondButtonReturn:
      openReleasePage()
    default:
      break
    }
  }
}

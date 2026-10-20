import Foundation
import AppKit
import Combine

struct GitHubRelease: Codable {
    let tagName: String
    let htmlUrl: String
    let body: String?
    let assets: [GitHubAsset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlUrl = "html_url"
        case body
        case assets
    }
}

struct GitHubAsset: Codable {
    let name: String
    let browserDownloadUrl: String

    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadUrl = "browser_download_url"
    }
}

final class UpdateManager: ObservableObject {
    static let shared = UpdateManager()

    @Published var isChecking: Bool = false
    @Published var hasUpdate: Bool = false
    @Published var latestVersion: String = ""
    @Published var releaseNotesUrl: URL? = nil
    @Published var dmgDownloadUrl: URL? = nil
    @Published var lastCheckedDate: Date? = nil

    private let repoOwner = "Udean777"
    private let repoName = "Harmonotch"

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    private init() {}

    func checkForUpdates(isUserInitiated: Bool = false) {
        guard !isChecking else { return }

        guard let url = URL(string: "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest") else {
            return
        }

        isChecking = true

        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15.0)
        request.setValue("Harmonotch-App", forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isChecking = false
                self.lastCheckedDate = Date()

                if let error = error {
                    if isUserInitiated {
                        self.showAlert(title: L10n.Update.checkFailedTitle, message: error.localizedDescription)
                    }
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode),
                      let data = data else {
                    if isUserInitiated {
                        self.showAlert(title: L10n.Update.checkFailedTitle, message: L10n.Update.networkErrorDesc)
                    }
                    return
                }

                do {
                    let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
                    let cleanRemote = release.tagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV "))

                    if self.isVersion(cleanRemote, higherThan: self.currentVersion) {
                        self.hasUpdate = true
                        self.latestVersion = cleanRemote
                        self.releaseNotesUrl = URL(string: release.htmlUrl)

                        let dmgAsset = release.assets.first(where: { $0.name.lowercased().hasSuffix(".dmg") })
                        if let dmgAsset = dmgAsset, let dmgUrl = URL(string: dmgAsset.browserDownloadUrl) {
                            self.dmgDownloadUrl = dmgUrl
                        } else {
                            self.dmgDownloadUrl = URL(string: release.htmlUrl)
                        }

                        if isUserInitiated {
                            self.showUpdateAvailableDialog(version: cleanRemote)
                        }
                    } else {
                        self.hasUpdate = false
                        if isUserInitiated {
                            self.showAlert(
                                title: L10n.Update.upToDateTitle,
                                message: L10n.Update.upToDateMessage(version: self.currentVersion)
                            )
                        }
                    }
                } catch {
                    if isUserInitiated {
                        self.showAlert(title: L10n.Update.checkFailedTitle, message: error.localizedDescription)
                    }
                }
            }
        }.resume()
    }

    func downloadLatestDMG() {
        guard let url = dmgDownloadUrl ?? releaseNotesUrl else { return }
        NSWorkspace.shared.open(url)
    }

    func openReleasePage() {
        guard let url = releaseNotesUrl ?? URL(string: "https://github.com/\(repoOwner)/\(repoName)/releases/latest") else { return }
        NSWorkspace.shared.open(url)
    }

    private func isVersion(_ remote: String, higherThan current: String) -> Bool {
        let remoteParts = remote.split(separator: ".").compactMap { Int($0) }
        let currentParts = current.split(separator: ".").compactMap { Int($0) }

        let count = max(remoteParts.count, currentParts.count)
        for i in 0..<count {
            let r = i < remoteParts.count ? remoteParts[i] : 0
            let c = i < currentParts.count ? currentParts[i] : 0
            if r > c { return true }
            if r < c { return false }
        }
        return false
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: L10n.About.close)
        alert.runModal()
    }

    private func showUpdateAvailableDialog(version: String) {
        let alert = NSAlert()
        alert.messageText = L10n.Update.updateAvailableTitle(version: version)
        alert.informativeText = L10n.Update.updateAvailablePrompt
        alert.alertStyle = .informational
        alert.addButton(withTitle: L10n.Update.downloadDMG)
        alert.addButton(withTitle: L10n.Update.viewReleaseNotes)
        alert.addButton(withTitle: L10n.Update.later)

        let response = alert.runModal()
        switch response {
        case .alertFirstButtonReturn:
            downloadLatestDMG()
        case .alertSecondButtonReturn:
            openReleasePage()
        default:
            break
        }
    }
}

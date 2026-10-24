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
    @Published var isDownloading: Bool = false
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

                    if Version.isNewer(cleanRemote, than: self.currentVersion) {
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
                        self.latestVersion = ""
                        self.releaseNotesUrl = nil
                        self.dmgDownloadUrl = nil
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

        // Opening the DMG URL in the browser tags every download with com.apple.quarantine, so
        // Gatekeeper blocks the app until the user runs `xattr -cr`. Downloading it ourselves
        // leaves the file unquarantined (this app sets no LSFileQuarantineEnabled).
        guard url.pathExtension.lowercased() == "dmg" else {
            NSWorkspace.shared.open(url)
            return
        }
        guard !isDownloading else { return }
        isDownloading = true

        URLSession.shared.downloadTask(with: url) { [weak self] tempURL, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isDownloading = false

                guard let tempURL = tempURL,
                      let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    self.showAlert(
                        title: L10n.Update.downloadFailedTitle,
                        message: error?.localizedDescription ?? L10n.Update.networkErrorDesc
                    )
                    return
                }

                let destination = FileManager.default.temporaryDirectory
                    .appendingPathComponent(url.lastPathComponent)
                do {
                    try? FileManager.default.removeItem(at: destination)
                    try FileManager.default.moveItem(at: tempURL, to: destination)
                    NSWorkspace.shared.open(destination)
                } catch {
                    self.showAlert(title: L10n.Update.downloadFailedTitle, message: error.localizedDescription)
                }
            }
        }.resume()
    }

    func openReleasePage() {
        guard let url = releaseNotesUrl ?? URL(string: "https://github.com/\(repoOwner)/\(repoName)/releases/latest") else { return }
        NSWorkspace.shared.open(url)
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

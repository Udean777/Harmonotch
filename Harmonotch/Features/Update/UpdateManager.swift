import AppKit
import Combine
import Foundation

enum UpdateState: Equatable {
  case idle
  case checking
  case upToDate
  case available(version: String)
  case downloading(progress: Double?)
  case installing
  case readyToQuit(version: String)
  case failed(String)
}

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
  let size: Int64?

  enum CodingKeys: String, CodingKey {
    case name
    case browserDownloadUrl = "browser_download_url"
    case size
  }
}

final class UpdateManager: ObservableObject {
  static let shared = UpdateManager()

  @Published var state: UpdateState = .idle
  @Published var isChecking: Bool = false
  @Published var isDownloading: Bool = false
  @Published var hasUpdate: Bool = false
  @Published var latestVersion: String = ""
  @Published var releaseNotesUrl: URL? = nil
  @Published var dmgDownloadUrl: URL? = nil
  @Published var downloadProgress: Double? = nil
  @Published var lastCheckedDate: Date? = nil

  let repoOwner = "Udean777"
  let repoName = "Harmonotch"
  var downloadSession: URLSession?
  var downloadExpectedBytes: Int64?

  var currentVersion: String {
    Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
  }

  private init() {}

  func checkForUpdates(isUserInitiated: Bool = false) {
    guard !isChecking else { return }
    if case .downloading = state { return }
    if case .installing = state { return }

    guard
      let url = URL(
        string: "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest")
    else {
      return
    }

    isChecking = true
    state = .checking

    var request = URLRequest(
      url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15.0)
    request.setValue("Harmonotch-App", forHTTPHeaderField: "User-Agent")
    request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")

    URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
      DispatchQueue.main.async {
        guard let self = self else { return }
        self.isChecking = false
        self.lastCheckedDate = Date()

        if let error = error {
          self.state = .failed(error.localizedDescription)
          if isUserInitiated {
            self.showAlert(
              title: L10n.Update.checkFailedTitle, message: error.localizedDescription)
          }
          return
        }

        guard let httpResponse = response as? HTTPURLResponse,
          (200...299).contains(httpResponse.statusCode),
          let data = data
        else {
          self.state = .failed(L10n.Update.networkErrorDesc)
          if isUserInitiated {
            self.showAlert(
              title: L10n.Update.checkFailedTitle, message: L10n.Update.networkErrorDesc)
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
              self.downloadExpectedBytes = dmgAsset.size
            } else {
              self.dmgDownloadUrl = URL(string: release.htmlUrl)
              self.downloadExpectedBytes = nil
            }

            self.state = .available(version: cleanRemote)

            if isUserInitiated {
              self.showUpdateAvailableDialog(version: cleanRemote)
            }
          } else {
            self.hasUpdate = false
            self.latestVersion = ""
            self.releaseNotesUrl = nil
            self.dmgDownloadUrl = nil
            self.downloadExpectedBytes = nil
            self.state = .upToDate
            if isUserInitiated {
              self.showAlert(
                title: L10n.Update.upToDateTitle,
                message: L10n.Update.upToDateMessage(version: self.currentVersion)
              )
            }
          }
        } catch {
          self.state = .failed(error.localizedDescription)
          if isUserInitiated {
            self.showAlert(
              title: L10n.Update.checkFailedTitle, message: error.localizedDescription)
          }
        }
      }
    }.resume()
  }
}

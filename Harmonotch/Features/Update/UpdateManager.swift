import Foundation
import AppKit
import Combine

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

    private let repoOwner = "Udean777"
    private let repoName = "Harmonotch"
    private var downloadSession: URLSession?
    private var downloadExpectedBytes: Int64?

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    private init() {}

    func checkForUpdates(isUserInitiated: Bool = false) {
        guard !isChecking else { return }
        if case .downloading = state { return }
        if case .installing = state { return }

        guard let url = URL(string: "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest") else {
            return
        }

        isChecking = true
        state = .checking

        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15.0)
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
                        self.showAlert(title: L10n.Update.checkFailedTitle, message: error.localizedDescription)
                    }
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode),
                      let data = data else {
                    self.state = .failed(L10n.Update.networkErrorDesc)
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
                        self.showAlert(title: L10n.Update.checkFailedTitle, message: error.localizedDescription)
                    }
                }
            }
        }.resume()
    }

    func downloadAndInstallUpdate() {
        guard let url = dmgDownloadUrl ?? releaseNotesUrl else { return }

        guard url.pathExtension.lowercased() == "dmg" else {
            NSWorkspace.shared.open(url)
            return
        }

        // Check if running from read-only image or AppTranslocation
        if UpdateInstallerSupport.runsFromImmutableLocation(
            appPath: Bundle.main.bundlePath,
            volumeIsReadOnly: { path in
                (try? URL(fileURLWithPath: path).resourceValues(forKeys: [.volumeIsReadOnlyKey]).volumeIsReadOnly) ?? false
            }
        ) {
            showAlert(title: L10n.Update.needsApplicationsTitle, message: L10n.Update.needsApplicationsBody)
            return
        }

        guard !isDownloading else { return }
        isDownloading = true
        downloadProgress = nil
        state = .downloading(progress: nil)

        let expectedBytes = downloadExpectedBytes
        let byteLimit = UpdateInstallerSupport.downloadByteLimit(expectedBytes: expectedBytes)

        let delegate: BoundedUpdateDownloadDelegate
        do {
            delegate = try BoundedUpdateDownloadDelegate(
                byteLimit: byteLimit,
                progress: { [weak self] received, total in
                    let expected = expectedBytes ?? total
                    guard let expected, expected > 0 else { return }
                    let fraction = min(Double(received) / Double(expected), 1.0)
                    DispatchQueue.main.async {
                        guard let self = self else { return }
                        if UpdateInstallerSupport.progressStepAdvanced(from: self.downloadProgress, to: fraction) {
                            self.downloadProgress = fraction
                            self.state = .downloading(progress: fraction)
                        }
                    }
                },
                completion: { [weak self] tempURL, response, error in
                    guard let self = self else { return }
                    self.downloadSession?.finishTasksAndInvalidate()
                    DispatchQueue.main.async {
                        self.downloadSession = nil
                        self.isDownloading = false
                    }

                    guard let tempURL = tempURL, error == nil else {
                        DispatchQueue.main.async {
                            self.state = .failed(error?.localizedDescription ?? L10n.Update.networkErrorDesc)
                            self.showAlert(title: L10n.Update.downloadFailedTitle, message: error?.localizedDescription ?? L10n.Update.networkErrorDesc)
                        }
                        return
                    }

                    let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                    let received = (try? FileManager.default.attributesOfItem(atPath: tempURL.path))
                        .flatMap { $0[.size] as? NSNumber }?.int64Value ?? 0

                    guard UpdateInstallerSupport.downloadIsUsable(status: status, receivedBytes: received, expectedBytes: expectedBytes) else {
                        try? FileManager.default.removeItem(at: tempURL)
                        DispatchQueue.main.async {
                            self.state = .failed("Invalid download payload (HTTP \(status))")
                            self.showAlert(title: L10n.Update.downloadFailedTitle, message: "Invalid download payload.")
                        }
                        return
                    }

                    let destination = FileManager.default.temporaryDirectory.appendingPathComponent("Harmonotch-update-\(UUID().uuidString).dmg")
                    do {
                        try? FileManager.default.removeItem(at: destination)
                        try FileManager.default.moveItem(at: tempURL, to: destination)
                    } catch {
                        DispatchQueue.main.async {
                            self.state = .failed(error.localizedDescription)
                            self.showAlert(title: L10n.Update.downloadFailedTitle, message: error.localizedDescription)
                        }
                        return
                    }

                    DispatchQueue.main.async {
                        self.state = .installing
                        self.performBackgroundInstall(dmgPath: destination.path, targetVersion: self.latestVersion)
                    }
                }
            )
        } catch {
            isDownloading = false
            state = .failed(error.localizedDescription)
            showAlert(title: L10n.Update.downloadFailedTitle, message: error.localizedDescription)
            return
        }

        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        downloadSession = session
        let task = session.dataTask(with: url)
        task.resume()
    }

    private func performBackgroundInstall(dmgPath: String, targetVersion: String) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let appPath = Bundle.main.bundlePath
            let script = UpdateInstallerSupport.installScript(appPath: appPath, dmgPath: dmgPath, expectedVersion: targetVersion)

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/sh")
            process.arguments = ["-c", script]

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe

            var installSucceeded = false
            do {
                try process.run()
                process.waitUntilExit()
                installSucceeded = (process.terminationStatus == 0)
            } catch {
                installSucceeded = false
            }

            // If user permissions failed on /Applications, retry with AppleScript admin privileges
            if !installSucceeded {
                let escapedScript = script.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
                let appleScriptSource = "do shell script \"\(escapedScript)\" with administrator privileges"
                if let appleScript = NSAppleScript(source: appleScriptSource) {
                    var errorDict: NSDictionary?
                    appleScript.executeAndReturnError(&errorDict)
                    installSucceeded = (errorDict == nil)
                }
            }

            try? FileManager.default.removeItem(atPath: dmgPath)

            DispatchQueue.main.async {
                if installSucceeded {
                    self.state = .readyToQuit(version: targetVersion)
                } else {
                    self.state = .failed("Installation failed.")
                    self.showAlert(title: L10n.Update.downloadFailedTitle, message: "Installation failed. Please try again or download manually.")
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

/// Download delegate that writes stream to file and checks size bounds.
final class BoundedUpdateDownloadDelegate: NSObject, URLSessionDataDelegate {
    private let byteLimit: Int64
    private let progress: (Int64, Int64?) -> Void
    private let completion: (URL?, URLResponse?, Error?) -> Void
    private let fileURL: URL
    private let fileHandle: FileHandle
    private var response: URLResponse?
    private var responseExpectedBytes: Int64?
    private var receivedBytes: Int64 = 0
    private var completed = false
    private var exceededLimit = false
    private var writeError: Error?

    init(byteLimit: Int64,
         progress: @escaping (Int64, Int64?) -> Void,
         completion: @escaping (URL?, URLResponse?, Error?) -> Void) throws {
        self.byteLimit = byteLimit
        self.progress = progress
        self.completion = completion
        let temporaryFileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("Harmonotch-update-\(UUID().uuidString).download")
        fileURL = temporaryFileURL
        guard FileManager.default.createFile(atPath: temporaryFileURL.path, contents: nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
        do {
            fileHandle = try FileHandle(forWritingTo: temporaryFileURL)
        } catch {
            try? FileManager.default.removeItem(at: temporaryFileURL)
            throw error
        }
    }

    deinit {
        try? fileHandle.close()
        try? FileManager.default.removeItem(at: fileURL)
    }

    func urlSession(_ session: URLSession,
                    dataTask: URLSessionDataTask,
                    didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        self.response = response
        responseExpectedBytes = response.expectedContentLength > 0 ? response.expectedContentLength : nil
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession,
                    dataTask: URLSessionDataTask,
                    didReceive data: Data) {
        guard writeError == nil, !exceededLimit else { return }
        let chunkBytes = Int64(data.count)
        guard chunkBytes <= byteLimit - receivedBytes else {
            exceededLimit = true
            dataTask.cancel()
            return
        }
        do {
            try fileHandle.write(contentsOf: data)
            receivedBytes += chunkBytes
            progress(receivedBytes, responseExpectedBytes)
        } catch {
            writeError = error
            dataTask.cancel()
        }
    }

    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didCompleteWithError error: Error?) {
        let closeError: Error?
        do {
            try fileHandle.close()
            closeError = nil
        } catch {
            closeError = error
        }
        if let writeError {
            complete(location: nil, response: response, error: writeError)
        } else if exceededLimit {
            complete(location: nil, response: response, error: POSIXError(.EFBIG))
        } else if let error {
            complete(location: nil, response: response, error: error)
        } else if let closeError {
            complete(location: nil, response: response, error: closeError)
        } else {
            complete(location: fileURL, response: response, error: nil)
        }
    }

    private func complete(location: URL?, response: URLResponse?, error: Error?) {
        guard !completed else { return }
        completed = true
        if location == nil {
            try? FileManager.default.removeItem(at: fileURL)
        }
        completion(location, response, error)
    }
}

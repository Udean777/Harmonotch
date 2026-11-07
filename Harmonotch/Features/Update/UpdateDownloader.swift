import AppKit
import Foundation

extension UpdateManager {
  func downloadAndInstallUpdate() {
    guard let url = dmgDownloadUrl ?? releaseNotesUrl else { return }

    guard url.pathExtension.lowercased() == "dmg" else {
      NSWorkspace.shared.open(url)
      return
    }

    if UpdateInstallerSupport.runsFromImmutableLocation(
      appPath: Bundle.main.bundlePath,
      volumeIsReadOnly: { path in
        (try? URL(fileURLWithPath: path).resourceValues(forKeys: [.volumeIsReadOnlyKey]).volumeIsReadOnly)
          ?? false
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
              self.showAlert(
                title: L10n.Update.downloadFailedTitle,
                message: error?.localizedDescription ?? L10n.Update.networkErrorDesc)
            }
            return
          }

          let status = (response as? HTTPURLResponse)?.statusCode ?? 0
          let received =
            (try? FileManager.default.attributesOfItem(atPath: tempURL.path))
            .flatMap { $0[.size] as? NSNumber }?.int64Value ?? 0

          guard
            UpdateInstallerSupport.downloadIsUsable(
              status: status, receivedBytes: received, expectedBytes: expectedBytes)
          else {
            try? FileManager.default.removeItem(at: tempURL)
            DispatchQueue.main.async {
              self.state = .failed("Invalid download payload (HTTP \(status))")
              self.showAlert(
                title: L10n.Update.downloadFailedTitle, message: "Invalid download payload.")
            }
            return
          }

          let destination = FileManager.default.temporaryDirectory.appendingPathComponent(
            "Harmonotch-update-\(UUID().uuidString).dmg")
          do {
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.moveItem(at: tempURL, to: destination)
          } catch {
            DispatchQueue.main.async {
              self.state = .failed(error.localizedDescription)
              self.showAlert(
                title: L10n.Update.downloadFailedTitle, message: error.localizedDescription)
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
}

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

  init(
    byteLimit: Int64,
    progress: @escaping (Int64, Int64?) -> Void,
    completion: @escaping (URL?, URLResponse?, Error?) -> Void
  ) throws {
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

  func urlSession(
    _ session: URLSession,
    dataTask: URLSessionDataTask,
    didReceive response: URLResponse,
    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
  ) {
    self.response = response
    responseExpectedBytes = response.expectedContentLength > 0 ? response.expectedContentLength : nil
    completionHandler(.allow)
  }

  func urlSession(
    _ session: URLSession,
    dataTask: URLSessionDataTask,
    didReceive data: Data
  ) {
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

  func urlSession(
    _ session: URLSession,
    task: URLSessionTask,
    didCompleteWithError error: Error?
  ) {
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

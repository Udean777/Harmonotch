import Foundation

/// Unique identity for a media candidate across applications and processes.
public struct MediaIdentity: Hashable, Equatable, Sendable, CustomStringConvertible {
  public let bundleID: String
  public let pid: pid_t?
  public let contentID: String?

  public init(bundleID: String, pid: pid_t? = nil, contentID: String? = nil) {
    self.bundleID = bundleID.trimmingCharacters(in: .whitespacesAndNewlines)
    self.pid = pid
    self.contentID = contentID?.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  public var description: String {
    let pidStr = pid.map { "pid:\($0)" } ?? "no-pid"
    let contentStr = contentID.map { "content:\($0)" } ?? "no-content"
    return "MediaIdentity(\(bundleID)|\(pidStr)|\(contentStr))"
  }
}

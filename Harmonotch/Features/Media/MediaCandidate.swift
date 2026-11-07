import Foundation

public enum MediaAwareness: String, Equatable, Hashable, Sendable {
  case mediaRemote
  case script
  case presence
}

public enum MediaArtworkSource: Equatable, Hashable, Sendable {
  case data(Data)
  case url(URL)
}

/// Represents one active or paused media session from any audio-producing app.
public struct MediaCandidate: Equatable, Sendable {
  public var identity: MediaIdentity
  public var app: MediaAppInfo
  public var title: String
  public var artist: String
  public var album: String
  public var duration: Double
  public var position: Double
  public var isPlaying: Bool
  public var hasMetadata: Bool
  public var isMusicApp: Bool
  public var artwork: MediaArtworkSource?
  public var awareness: MediaAwareness
  public var capabilities: MediaCapabilities
  public var startedPlayingAt: TimeInterval?
  public var lastUpdated: TimeInterval

  public init(
    identity: MediaIdentity,
    app: MediaAppInfo,
    title: String = "",
    artist: String = "",
    album: String = "",
    duration: Double = 0,
    position: Double = 0,
    isPlaying: Bool = false,
    hasMetadata: Bool? = nil,
    isMusicApp: Bool? = nil,
    artwork: MediaArtworkSource? = nil,
    awareness: MediaAwareness = .mediaRemote,
    capabilities: MediaCapabilities = .standardPlayer,
    startedPlayingAt: TimeInterval? = nil,
    lastUpdated: TimeInterval = Date().timeIntervalSince1970
  ) {
    self.identity = identity
    self.app = app
    self.title = title
    self.artist = artist
    self.album = album
    self.duration = duration
    self.position = position
    self.isPlaying = isPlaying
    self.hasMetadata = hasMetadata ?? !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    self.isMusicApp = isMusicApp ?? (app.category == .music)
    self.artwork = artwork
    self.awareness = awareness
    self.capabilities = capabilities
    self.startedPlayingAt = startedPlayingAt
    self.lastUpdated = lastUpdated
  }
}

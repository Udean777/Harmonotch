import Foundation

/// Pure presentation state consumed by the user interface (Pill, Drawer, MenuBar).
public struct MediaPresentation: Equatable, Sendable {
  public struct TrackInfo: Equatable, Sendable {
    public let title: String
    public let artist: String
    public let album: String
    public let duration: Double
    public let position: Double
    public let artwork: MediaArtworkSource?

    public init(
      title: String,
      artist: String,
      album: String = "",
      duration: Double = 0,
      position: Double = 0,
      artwork: MediaArtworkSource? = nil
    ) {
      self.title = title
      self.artist = artist
      self.album = album
      self.duration = duration
      self.position = position
      self.artwork = artwork
    }
  }

  public enum Kind: Equatable, Sendable {
    case track(TrackInfo)
    case audioOnly(MediaAppInfo)
  }

  public let identity: MediaIdentity
  public let app: MediaAppInfo
  public let kind: Kind
  public let isPlaying: Bool
  public let capabilities: MediaCapabilities

  public init(
    identity: MediaIdentity,
    app: MediaAppInfo,
    kind: Kind,
    isPlaying: Bool,
    capabilities: MediaCapabilities
  ) {
    self.identity = identity
    self.app = app
    self.kind = kind
    self.isPlaying = isPlaying
    self.capabilities = capabilities
  }

  public init(candidate: MediaCandidate) {
    self.identity = candidate.identity
    self.app = candidate.app
    self.isPlaying = candidate.isPlaying
    self.capabilities = candidate.capabilities

    if candidate.hasMetadata {
      self.kind = .track(
        TrackInfo(
          title: candidate.title,
          artist: candidate.artist,
          album: candidate.album,
          duration: candidate.duration,
          position: candidate.position,
          artwork: candidate.artwork
        )
      )
    } else {
      self.kind = .audioOnly(candidate.app)
    }
  }

  public var hasMetadata: Bool {
    switch kind {
    case .track: return true
    case .audioOnly: return false
    }
  }

  public var title: String {
    switch kind {
    case .track(let info): return info.title
    case .audioOnly: return ""
    }
  }

  public var artist: String {
    switch kind {
    case .track(let info): return info.artist
    case .audioOnly: return app.displayName
    }
  }

  public var album: String {
    switch kind {
    case .track(let info): return info.album
    case .audioOnly: return ""
    }
  }

  public var duration: Double {
    switch kind {
    case .track(let info): return info.duration
    case .audioOnly: return 0
    }
  }

  public var position: Double {
    switch kind {
    case .track(let info): return info.position
    case .audioOnly: return 0
    }
  }

  public var artwork: MediaArtworkSource? {
    switch kind {
    case .track(let info): return info.artwork
    case .audioOnly: return nil
    }
  }
}

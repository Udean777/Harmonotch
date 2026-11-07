import Foundation
import SwiftUI

enum MediaSource: String {
  case spotify = "Spotify"
  case appleMusic = "Apple Music"
  case safari = "YouTube"
  case web = "Web"
  case iina = "IINA"
  case vlc = "VLC"
  case quicktime = "QuickTime"
  case podcasts = "Podcasts"
  case system = "Media"
  case none = "None"

  var iconName: String {
    switch self {
    case .spotify: return "waveform"
    case .appleMusic: return "apple.logo"
    case .safari: return "play.rectangle.fill"
    case .web: return "globe"
    case .iina: return "play.circle.fill"
    case .vlc: return "cone.fill"
    case .quicktime: return "play.tv.fill"
    case .podcasts: return "antenna.radiowaves.left.and.right"
    case .system: return "music.note"
    case .none: return "music.note"
    }
  }

  var brandColor: Color {
    switch self {
    case .spotify: return Color(red: 0.20, green: 0.82, blue: 0.48)
    case .appleMusic: return Color(red: 0.98, green: 0.35, blue: 0.55)
    case .safari: return Color(red: 0.95, green: 0.25, blue: 0.25)
    case .web: return Color(red: 0.25, green: 0.55, blue: 0.95)
    case .iina, .vlc: return Color(red: 0.98, green: 0.55, blue: 0.15)
    case .quicktime: return Color(red: 0.25, green: 0.75, blue: 0.95)
    case .podcasts: return Color(red: 0.70, green: 0.40, blue: 0.95)
    case .system: return Color.white
    case .none: return Color.gray
    }
  }
}

/// Queue item shown when user opens the queue from the notch.
struct QueueItem: Identifiable, Hashable {
  let id = UUID()
  let title: String
  let artist: String
}

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

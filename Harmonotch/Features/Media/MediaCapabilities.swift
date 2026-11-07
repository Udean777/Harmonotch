import Foundation

/// Defines supported control actions for a media source or active candidate.
public struct MediaCapabilities: OptionSet, Equatable, Hashable, Sendable {
  public let rawValue: Int

  public init(rawValue: Int) {
    self.rawValue = rawValue
  }

  public static let playPause     = MediaCapabilities(rawValue: 1 << 0)
  public static let nextTrack     = MediaCapabilities(rawValue: 1 << 1)
  public static let previousTrack = MediaCapabilities(rawValue: 1 << 2)
  public static let seek          = MediaCapabilities(rawValue: 1 << 3)
  public static let openApp       = MediaCapabilities(rawValue: 1 << 4)

  public static let all: MediaCapabilities = [
    .playPause, .nextTrack, .previousTrack, .seek, .openApp
  ]

  public static let standardPlayer: MediaCapabilities = [
    .playPause, .nextTrack, .previousTrack, .seek, .openApp
  ]

  public static let audioOnlyDefault: MediaCapabilities = [
    .openApp
  ]
}

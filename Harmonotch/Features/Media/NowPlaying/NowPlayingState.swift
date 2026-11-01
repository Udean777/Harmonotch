import Foundation

/// One `{"event":"state",…}` line from the now-playing adapter.
nonisolated struct NowPlayingState: Decodable, Equatable {
  var source: String
  var title: String
  var artist: String
  var album: String
  var duration: Double
  var elapsed: Double
  var rate: Double
  var playing: Bool
  var contentID: String
  var artwork: String?

  var sourceKind: NowPlayingSourceKind { NowPlayingSourceKind(bundleID: source) }
}

/// One line from the adapter: state, command result, or fatal error.
nonisolated enum NowPlayingEvent: Decodable {
  case state(NowPlayingState)
  case result(id: String, ok: Bool)
  case error(String)

  private enum CodingKeys: String, CodingKey {
    case event, id, ok, message
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    switch try container.decode(String.self, forKey: .event) {
    case "state":
      self = .state(try NowPlayingState(from: decoder))
    case "result":
      self = .result(
        id: try container.decode(String.self, forKey: .id),
        ok: try container.decode(Bool.self, forKey: .ok))
    case "error":
      self = .error(try container.decodeIfPresent(String.self, forKey: .message) ?? "")
    default:
      throw DecodingError.dataCorruptedError(
        forKey: .event, in: container, debugDescription: "unknown now-playing event")
    }
  }
}

/// Bundle ID reported by MediaRemote, mapped to the app that owns playback.
/// Pure so `Tests/run-tests.sh` can cover the mapping.
nonisolated enum NowPlayingSourceKind: String, Equatable {
  case spotify
  case appleMusic
  case safari
  case web
  case quicktime
  case podcasts
  case system

  init(bundleID: String) {
    switch bundleID {
    case "com.spotify.client":
      self = .spotify
    case "com.apple.Music":
      self = .appleMusic
    case "com.apple.WebKit.GPU", "com.apple.WebKit.WebContent", "com.apple.Safari":
      self = .safari
    case "com.apple.QuickTimePlayerX":
      self = .quicktime
    case "com.apple.podcasts":
      self = .podcasts
    case "company.thebrowser.Browser":
      self = .web
    default:
      let lower = bundleID.lowercased()
      let contains: (String) -> Bool = { lower.contains($0) }
      if contains("chrome") || contains("brave") || contains("arc") || contains("edgemac")
        || contains("opera") || contains("firefox")
      {
        self = .web
      } else {
        self = .system
      }
    }
  }
}

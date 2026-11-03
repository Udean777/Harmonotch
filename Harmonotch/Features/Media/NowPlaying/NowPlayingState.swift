import Foundation

/// Strongly-typed playback commands sent to the MediaRemote bridge.
nonisolated enum NowPlayingCommand: Equatable, Sendable {
  case play
  case pause
  case toggle
  case next
  case previous
  case seek(position: TimeInterval)

  var commandName: String {
    switch self {
    case .play: return "play"
    case .pause: return "pause"
    case .toggle: return "toggle"
    case .next: return "next"
    case .previous: return "previous"
    case .seek: return "seek"
    }
  }

  var position: Double? {
    switch self {
    case .seek(let pos): return max(0, pos)
    default: return nil
    }
  }
}

/// Wire payload sent over stdin to the adapter helper.
nonisolated struct NowPlayingCommandMessage: Encodable, Sendable {
  let id: String
  let cmd: String
  let position: Double?

  init(id: String = UUID().uuidString, command: NowPlayingCommand) {
    self.id = id
    self.cmd = command.commandName
    self.position = command.position
  }
}

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

import AppKit
import Foundation

public enum MediaAppCategory: String, Equatable, Sendable, CaseIterable {
  case music
  case video
  case call
  case general

  public var isMusicApp: Bool {
    self == .music
  }
}

public struct MediaAppInfo: Equatable, Hashable, Sendable {
  public let bundleID: String
  public let displayName: String
  public let iconSymbolName: String
  public let category: MediaAppCategory

  public init(
    bundleID: String,
    displayName: String,
    iconSymbolName: String = "speaker.wave.2.fill",
    category: MediaAppCategory = .general
  ) {
    self.bundleID = bundleID
    self.displayName = displayName
    self.iconSymbolName = iconSymbolName
    self.category = category
  }

  /// Resolves the application bundle icon from running applications or NSWorkspace, if available.
  public var appIcon: NSImage? {
    let clean = bundleID.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !clean.isEmpty else { return nil }
    if let running = NSRunningApplication.runningApplications(withBundleIdentifier: clean).first,
       let icon = running.icon {
      return icon
    }
    if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: clean) {
      return NSWorkspace.shared.icon(forFile: url.path)
    }
    return nil
  }

  /// Resolves app metadata from bundle identifier, system application info, or known directory.
  public static func resolve(bundleID: String, preferredName: String? = nil) -> MediaAppInfo {
    let cleanBundleID = bundleID.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !cleanBundleID.isEmpty else {
      return MediaAppInfo(
        bundleID: "",
        displayName: preferredName?.isEmpty == false ? preferredName! : "Unknown",
        iconSymbolName: "speaker.wave.2.fill",
        category: .general
      )
    }

    let category = category(for: cleanBundleID)
    let iconSymbol = iconSymbolName(for: cleanBundleID, category: category)

    if let preferredName, !preferredName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      return MediaAppInfo(
        bundleID: cleanBundleID,
        displayName: preferredName,
        iconSymbolName: iconSymbol,
        category: category
      )
    }

    // Try finding running application name
    if let running = NSRunningApplication.runningApplications(withBundleIdentifier: cleanBundleID).first,
       let name = running.localizedName, !name.isEmpty {
      return MediaAppInfo(
        bundleID: cleanBundleID,
        displayName: name,
        iconSymbolName: iconSymbol,
        category: category
      )
    }

    // Fall back to known bundle ID names
    let knownName =
      knownDisplayNames[cleanBundleID]
      ?? BrowserCatalog.entry(forBundleID: cleanBundleID)?.name
      ?? fallbackNameFromBundleID(cleanBundleID)
    return MediaAppInfo(
      bundleID: cleanBundleID,
      displayName: knownName,
      iconSymbolName: iconSymbol,
      category: category
    )
  }

  public static func category(for bundleID: String) -> MediaAppCategory {
    let lower = bundleID.lowercased()

    if knownMusicBundleIDs.contains(lower) || lower.contains("spotify") || lower.contains("music") {
      return .music
    }

    if knownCallBundleIDs.contains(lower) || lower.contains("zoom") || lower.contains("teams") || lower.contains("meeting") {
      return .call
    }

    if BrowserCatalog.isBrowser(bundleID: bundleID) || knownVideoBundleIDs.contains(lower) ||
       lower.contains("iina") || lower.contains("vlc") ||
       lower.contains("quicktime") || lower.contains("podcasts") {
      return .video
    }

    return .general
  }

  public static func iconSymbolName(for bundleID: String, category: MediaAppCategory? = nil) -> String {
    let lower = bundleID.lowercased()

    if lower.contains("spotify") { return "waveform" }
    if lower == "com.apple.music" { return "apple.logo" }
    if BrowserCatalog.isSafari(bundleID: bundleID) { return "play.rectangle.fill" }
    if BrowserCatalog.isBrowser(bundleID: bundleID) { return "globe" }
    if lower.contains("iina") { return "play.circle.fill" }
    if lower.contains("vlc") { return "cone.fill" }
    if lower.contains("quicktime") { return "play.tv.fill" }
    if lower.contains("podcasts") { return "antenna.radiowaves.left.and.right" }

    switch category ?? self.category(for: bundleID) {
    case .music: return "music.note"
    case .video: return "play.fill"
    case .call: return "phone.fill"
    case .general: return "speaker.wave.2.fill"
    }
  }

  private static func fallbackNameFromBundleID(_ bundleID: String) -> String {
    guard let lastComponent = bundleID.split(separator: ".").last, !lastComponent.isEmpty else {
      return bundleID
    }
    return String(lastComponent)
  }

  private static let knownMusicBundleIDs: Set<String> = [
    "com.spotify.client",
    "com.apple.music",
    "com.tidal.desktop",
    "deezer.music",
    "com.amazon.mp3",
    "com.soundcloud.desktop"
  ]

  private static let knownVideoBundleIDs: Set<String> = [
    "com.apple.quicktimeplayerx",
    "com.apple.podcasts",
    "com.colliderli.iina",
    "org.videolan.vlc"
  ]

  private static let knownCallBundleIDs: Set<String> = [
    "us.zoom.xos",
    "com.microsoft.teams",
    "com.microsoft.teams2",
    "com.cisco.webexmeetingsapp",
    "com.apple.facetime",
    "com.tinyspeck.slackmacgap",
    "com.hnc.discord",
    "net.whatsapp.whatsapp"
  ]

  private static let knownDisplayNames: [String: String] = [
    "com.spotify.client": "Spotify",
    "com.apple.Music": "Apple Music",
    "com.apple.music": "Apple Music",
    "com.apple.QuickTimePlayerX": "QuickTime",
    "com.apple.podcasts": "Podcasts",
    "com.colliderli.iina": "IINA",
    "org.videolan.vlc": "VLC",
    "us.zoom.xos": "Zoom",
    "com.microsoft.teams": "Microsoft Teams",
    "com.microsoft.teams2": "Microsoft Teams",
    "com.apple.FaceTime": "FaceTime",
    "com.tinyspeck.slackmacgap": "Slack",
    "com.hnc.Discord": "Discord",
    "net.whatsapp.WhatsApp": "WhatsApp"
  ]
}

import AppKit
import Combine
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

struct ParsedWebMedia {
  let title: String
  let artist: String
  let source: MediaSource
  let videoId: String?
}

/// Picks a readable accent color out of album artwork for media UI tinting.
enum ArtworkPalette {
  private static let sampleSize = 16

  static func accent(from image: NSImage) -> NSColor? {
    guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
      return nil
    }
    var pixels = [UInt8](repeating: 0, count: sampleSize * sampleSize * 4)
    guard
      let context = CGContext(
        data: &pixels,
        width: sampleSize,
        height: sampleSize,
        bitsPerComponent: 8,
        bytesPerRow: sampleSize * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
      )
    else { return nil }
    context.interpolationQuality = .low
    context.draw(
      cgImage,
      in: CGRect(x: 0, y: 0, width: sampleSize, height: sampleSize))
    return accent(fromRGBA: pixels)
  }

  /// Weighted average that favors saturated pixels, so covers with a colorful
  /// subject on a gray/black background still yield that subject's hue.
  /// Returns nil for grayscale artwork; callers fall back to white.
  static func accent(fromRGBA pixels: [UInt8]) -> NSColor? {
    var redSum = 0.0
    var greenSum = 0.0
    var blueSum = 0.0
    var weightSum = 0.0

    var index = 0
    while index + 3 < pixels.count {
      let alpha = Double(pixels[index + 3]) / 255
      if alpha > 0.1 {
        let red = Double(pixels[index]) / 255
        let green = Double(pixels[index + 1]) / 255
        let blue = Double(pixels[index + 2]) / 255
        let maxChannel = max(red, green, blue)
        let minChannel = min(red, green, blue)
        let saturation = maxChannel > 0 ? (maxChannel - minChannel) / maxChannel : 0
        let weight = saturation * saturation
        if weight > 0.002 {
          redSum += red * weight
          greenSum += green * weight
          blueSum += blue * weight
          weightSum += weight
        }
      }
      index += 4
    }

    guard weightSum > 0.02 else { return nil }

    let base = NSColor(
      srgbRed: redSum / weightSum,
      green: greenSum / weightSum,
      blue: blueSum / weightSum,
      alpha: 1
    )
    guard let rgb = base.usingColorSpace(.deviceRGB) else { return nil }
    var hue: CGFloat = 0
    var saturation: CGFloat = 0
    var brightness: CGFloat = 0
    var alpha: CGFloat = 0
    rgb.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
    guard saturation >= 0.15 else { return nil }

    // Keep bars and controls legible on the black surface.
    return NSColor(
      hue: hue,
      saturation: max(saturation, 0.45),
      brightness: max(brightness, 0.85),
      alpha: 1
    )
  }
}

final class MediaManager: ObservableObject {
  static let shared = MediaManager()

  @Published var isPlaying: Bool = false
  @Published var mediaSource: MediaSource = .none
  @Published var trackTitle: String = ""
  @Published var artistName: String = ""
  @Published var albumName: String = ""
  @Published var duration: TimeInterval = 0
  @Published var playbackPosition: TimeInterval = 0
  @Published var artworkImage: NSImage? = nil
  @Published private(set) var artworkAccentColor: NSColor? = nil

  @Published var syncedLyrics: [LyricLine] = []
  @Published var unsyncedLyrics: [String] = []
  @Published var currentLyricIndex: Int = -1
  @Published var currentLyricText: String = ""
  @Published var isLoadingLyrics: Bool = false
  @Published var isInstrumental: Bool = false
  @Published var lyricsStatus: LyricsStatus = .idle

  var hasActiveTrack: Bool {
    !trackTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  var progress: Double {
    duration > 0 ? min(1.0, max(0.0, playbackPosition / duration)) : 0.0
  }

  var formattedPosition: String {
    formatTime(playbackPosition)
  }

  var formattedDuration: String {
    formatTime(duration)
  }

  private var playbackTimer: AnyCancellable?
  private var fastPollingTimer: AnyCancellable?
  private var lastFetchedTrackKey: String = ""
  private var cancellables = Set<AnyCancellable>()
  private var scriptCache: [String: NSAppleScript] = [:]
  private var lastDetectedRawWebTitle: String = ""

  private let appleScriptQueue = DispatchQueue(
    label: "com.harmonotch.media.applescript", qos: .utility)
  private let appleScriptQueueKey = DispatchSpecificKey<Void>()
  private let artworkCache = NSCache<NSString, NSImage>()
  private var lyricsCache:
    [String: (
      status: LyricsStatus, synced: [LyricLine], unsynced: [String], isInstrumental: Bool,
      duration: TimeInterval
    )] = [:]

  @Published var webMediaHint: WebMediaProbeError? = nil
  private var activeWebTarget: WebMediaSnapshot?
  private var localPollPlaying = false
  private var lastCommandAt = Date.distantPast
  private var expectedPlayingState: Bool = false
  private let nowPlayingBridge = NowPlayingBridge()

  private init() {
    appleScriptQueue.setSpecific(key: appleScriptQueueKey, value: ())
    setupDistributedNotificationObservers()
    setupFastPollingTimer()
    nowPlayingBridge.onState = { [weak self] state in
      self?.handleNowPlayingState(state)
    }
    nowPlayingBridge.start()
    pollCurrentMediaState()
  }

  /// Called on quit so the perl child does not outlive the app.
  func stop() {
    nowPlayingBridge.stop()
  }

  // MARK: - Distributed Notifications

  private func setupDistributedNotificationObservers() {
    let center = DistributedNotificationCenter.default()

    center.addObserver(
      forName: NSNotification.Name("com.spotify.client.PlaybackStateChanged"),
      object: nil,
      queue: .main
    ) { [weak self] notification in
      self?.handleSpotifyNotification(notification)
    }

    center.addObserver(
      forName: NSNotification.Name("com.apple.Music.playerInfo"),
      object: nil,
      queue: .main
    ) { [weak self] notification in
      self?.handleAppleMusicNotification(notification)
    }
  }

  private func extractDouble(from value: Any?) -> Double? {
    if let d = value as? Double { return d }
    if let n = value as? NSNumber { return n.doubleValue }
    if let i = value as? Int { return Double(i) }
    if let s = value as? String {
      let normalized = s.trimmingCharacters(in: .whitespacesAndNewlines)
        .replacingOccurrences(of: ",", with: ".")
      return Double(normalized)
    }
    return nil
  }

  private func handleSpotifyNotification(_ notification: Notification) {
    guard let userInfo = notification.userInfo else { return }

    let state = userInfo["Player State"] as? String ?? ""
    let isNowPlaying = state.lowercased() == "playing"

    let title = userInfo["Name"] as? String ?? ""
    let artist = userInfo["Artist"] as? String ?? ""
    let album = userInfo["Album"] as? String ?? ""
    let durationMs = extractDouble(from: userInfo["Duration"]) ?? 0
    let positionSec =
      extractDouble(from: userInfo["Playback Position"])
      ?? extractDouble(from: userInfo["Position"])
      ?? 0

    self.lastDetectedRawWebTitle = ""
    updateTrack(
      source: .spotify,
      title: title,
      artist: artist,
      album: album,
      duration: durationMs / 1000.0,
      position: positionSec,
      isPlaying: isNowPlaying
    )
  }

  private func handleAppleMusicNotification(_ notification: Notification) {
    guard let userInfo = notification.userInfo else { return }

    let state = userInfo["Player State"] as? String ?? ""
    let isNowPlaying = state.lowercased() == "playing"

    let title = userInfo["Name"] as? String ?? ""
    let artist = userInfo["Artist"] as? String ?? ""
    let album = userInfo["Album"] as? String ?? ""
    let totalTimeMs = extractDouble(from: userInfo["Total Time"]) ?? 0
    let positionSec =
      extractDouble(from: userInfo["Player Position"])
      ?? extractDouble(from: userInfo["Playback Position"])
      ?? extractDouble(from: userInfo["Position"])
      ?? 0

    self.lastDetectedRawWebTitle = ""
    updateTrack(
      source: .appleMusic,
      title: title,
      artist: artist,
      album: album,
      duration: totalTimeMs / 1000.0,
      position: positionSec,
      isPlaying: isNowPlaying
    )
  }

  private func updateTrack(
    source: MediaSource,
    title: String,
    artist: String,
    album: String,
    duration: TimeInterval,
    position: TimeInterval,
    isPlaying: Bool,
    artworkURL: URL? = nil,
    directArtwork: NSImage? = nil
  ) {
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      self.emptySnapshotCount = 0

      self.mediaSource = source
      self.isPlaying = isPlaying
      self.updatePlaybackTimerState()

      let trackChanged = (self.trackTitle != title || self.artistName != artist)
      if position > 0 || trackChanged {
        self.playbackPosition = position
      }
      if duration > 0 {
        self.duration = duration
      }

      self.trackTitle = title
      self.artistName = artist
      self.albumName = album

      if let direct = directArtwork {
        self.applyArtwork(direct)
      }
      if trackChanged && !title.isEmpty {
        if directArtwork == nil {
          self.fetchArtworkAsync(source: source, directURL: artworkURL)
        }
        self.fetchLyrics(track: title, artist: artist, album: album, duration: duration)
      }

      self.updateCurrentLyric()
    }
  }

  // MARK: - MediaRemote bridge

  private func handleNowPlayingState(_ state: NowPlayingState) {
    let artwork = state.artwork.flatMap { Data(base64Encoded: $0) }
      .flatMap { NSImage(data: $0) }

    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      guard !state.title.isEmpty else {
        // The adapter pushes the final empty line once; AppleScript polls resume after this.
        if !state.playing, self.hasActiveTrack,
          Date().timeIntervalSince(self.lastCommandAt) > 1.5
        {
          self.clearSession()
        }
        return
      }
      // A command may not have landed yet; don't let a stale line undo it.
      if Date().timeIntervalSince(self.lastCommandAt) < 1.5,
        state.playing != self.expectedPlayingState, state.title == self.trackTitle
      {
        return
      }
      self.lastDetectedRawWebTitle = ""
      self.updateTrack(
        source: Self.mediaSource(for: state.sourceKind),
        title: state.title,
        artist: state.artist,
        album: state.album,
        duration: state.duration,
        position: state.elapsed,
        isPlaying: state.playing,
        directArtwork: artwork)
    }
  }

  private static func mediaSource(for kind: NowPlayingSourceKind) -> MediaSource {
    switch kind {
    case .spotify: return .spotify
    case .appleMusic: return .appleMusic
    case .safari: return .safari
    case .web: return .web
    case .quicktime: return .quicktime
    case .podcasts: return .podcasts
    case .system: return .system
    }
  }

  /// Counts consecutive polls that found no media session anywhere.
  /// A paused session is kept; it is dropped only once every source stays empty.
  private var emptySnapshotCount = 0

  private var artworkAccentTrackKey = ""

  /// Artwork arrives on every NowPlaying push; recompute the accent only when
  /// the track changes so the palette work does not run every poll.
  private func applyArtwork(_ image: NSImage?) {
    artworkImage = image
    guard let image else {
      artworkAccentColor = nil
      artworkAccentTrackKey = ""
      return
    }
    let key = "\(trackTitle)|\(artistName)"
    guard artworkAccentTrackKey != key else { return }
    artworkAccentTrackKey = key
    artworkAccentColor = ArtworkPalette.accent(from: image)
  }

  private func clearSession() {
    isPlaying = false
    trackTitle = ""
    artistName = ""
    albumName = ""
    applyArtwork(nil)
    lastDetectedRawWebTitle = ""
    playbackPosition = 0
    duration = 0
    expectedPlayingState = false
    updatePlaybackTimerState()
    updateCurrentLyric()
  }

  private func registerEmptyPoll() {
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      self.emptySnapshotCount += 1
      guard self.emptySnapshotCount >= 3, self.hasActiveTrack else { return }
      self.clearSession()
    }
  }

  private func updatePlaybackTimerState() {
    if isPlaying {
      if playbackTimer == nil {
        playbackTimer = Timer.publish(every: 0.25, on: .main, in: .common)
          .autoconnect()
          .sink { [weak self] _ in
            guard let self = self, self.isPlaying else { return }
            self.playbackPosition += 0.25
            if self.duration > 0 && self.playbackPosition > self.duration {
              self.playbackPosition = self.duration
            }
            self.updateCurrentLyric()
          }
      }
    } else {
      playbackTimer?.cancel()
      playbackTimer = nil
    }
  }

  // AppleScript polling keeps sources without notification payloads in sync.
  private func setupFastPollingTimer() {
    fastPollingTimer = Timer.publish(every: 2.0, on: .main, in: .common)
      .autoconnect()
      .sink { [weak self] _ in
        self?.pollCurrentMediaState()
      }
  }

  private func updateCurrentLyric() {
    guard !syncedLyrics.isEmpty else {
      currentLyricText = ""
      currentLyricIndex = -1
      return
    }

    var matchedIndex = -1
    for (i, line) in syncedLyrics.enumerated() {
      if line.time <= playbackPosition {
        matchedIndex = i
      } else {
        break
      }
    }

    if matchedIndex != currentLyricIndex {
      currentLyricIndex = matchedIndex
      currentLyricText =
        (matchedIndex >= 0 && matchedIndex < syncedLyrics.count)
        ? syncedLyrics[matchedIndex].text : ""
    }
  }

  func pollCurrentMediaState() {
    // The bridge pushes state; AppleScript only covers what the bridge cannot.
    if nowPlayingBridge.isAvailable && hasActiveTrack { return }
    appleScriptQueue.async { [weak self] in
      guard let self = self else { return }
      self.localPollPlaying = false
      let localHasTrack =
        self.pollSpotifyState() || self.pollAppleMusicState() || self.pollQuickTimeState()
      // A local player that is actually playing wins; otherwise a playing browser tab does.
      if localHasTrack && self.localPollPlaying { return }
      self.pollWebMediaState(localHasTrack: localHasTrack)
    }
  }

  private func pollSpotifyState() -> Bool {
    guard
      !NSRunningApplication.runningApplications(withBundleIdentifier: "com.spotify.client").isEmpty
    else { return false }
    let spotifyScript = """
      if application id "com.spotify.client" is running then
          tell application id "com.spotify.client"
              set playerState to player state as string
              set trackName to name of current track
              set artistName to artist of current track
              set albumName to album of current track
              set trackDuration to (duration of current track) / 1000
              set playerPos to player position
              return playerState & "|||" & trackName & "|||" & artistName & "|||" & albumName & "|||" & (trackDuration as string) & "|||" & (playerPos as string)
          end tell
      else
          return ""
      end if
      """

    guard let result = executeAppleScript(spotifyScript), !result.isEmpty else { return false }
    let parts = result.components(separatedBy: "|||")
    guard parts.count >= 6 else { return false }
    let isPlaying = parts[0].lowercased() == "playing"
    let title = parts[1]
    let artist = parts[2]
    let album = parts[3]
    let duration = extractDouble(from: parts[4]) ?? 0
    let pos = extractDouble(from: parts[5]) ?? 0
    guard !title.isEmpty else { return false }
    localPollPlaying = isPlaying
    updateTrack(
      source: .spotify, title: title, artist: artist, album: album, duration: duration,
      position: pos, isPlaying: isPlaying)
    return true
  }

  private func pollAppleMusicState() -> Bool {
    guard !NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Music").isEmpty
    else { return false }
    let musicScript = """
      if application id "com.apple.Music" is running then
          tell application id "com.apple.Music"
              set playerState to player state as string
              set trackName to name of current track
              set artistName to artist of current track
              set albumName to album of current track
              set trackDuration to duration of current track
              set playerPos to player position
              return playerState & "|||" & trackName & "|||" & artistName & "|||" & albumName & "|||" & (trackDuration as string) & "|||" & (playerPos as string)
          end tell
      else
          return ""
      end if
      """

    guard let result = executeAppleScript(musicScript), !result.isEmpty else { return false }
    let parts = result.components(separatedBy: "|||")
    guard parts.count >= 6 else { return false }
    let isPlaying = parts[0].lowercased() == "playing"
    let title = parts[1]
    let artist = parts[2]
    let album = parts[3]
    let duration = extractDouble(from: parts[4]) ?? 0
    let pos = extractDouble(from: parts[5]) ?? 0
    guard !title.isEmpty else { return false }
    localPollPlaying = isPlaying
    updateTrack(
      source: .appleMusic, title: title, artist: artist, album: album, duration: duration,
      position: pos, isPlaying: isPlaying)
    return true
  }

  private func pollQuickTimeState() -> Bool {
    guard
      !NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.QuickTimePlayerX")
        .isEmpty
    else { return false }
    let qtScript = """
      tell application "QuickTime Player"
          try
              if exists (document 1) then
                  if playing of document 1 then
                      return (name of document 1) & "|||" & (current time of document 1 as string) & "|||" & (duration of document 1 as string)
                  end if
              end if
          end try
      end tell
      return ""
      """

    guard let res = executeAppleScript(qtScript), !res.isEmpty else { return false }
    let parts = res.components(separatedBy: "|||")
    guard parts.count >= 3 else { return false }
    let name = parts[0]
    let pos = extractDouble(from: parts[1]) ?? 0
    let dur = extractDouble(from: parts[2]) ?? 0
    localPollPlaying = true
    updateTrack(
      source: .quicktime, title: name, artist: "QuickTime", album: "", duration: dur, position: pos,
      isPlaying: true)
    return true
  }

  private static let chromiumBrowsers: [(name: String, bundleIDs: [String])] = [
    ("Google Chrome", ["com.google.Chrome"]),
    ("Arc", ["company.thebrowser.Browser"]),
    ("Brave Browser", ["com.brave.Browser"]),
    ("Microsoft Edge", ["com.microsoft.edgemac"]),
    ("Opera", ["com.operasoftware.Opera", "com.operasoftware.OperaGX"]),
  ]

  private func isRunning(_ bundleIDs: [String]) -> Bool {
    bundleIDs.contains {
      !NSRunningApplication.runningApplications(withBundleIdentifier: $0).isEmpty
    }
  }

  /// Must run on `appleScriptQueue`. Reads every media tab of every running browser,
  /// then follows the tab that is really playing.
  private func pollWebMediaState(localHasTrack: Bool) {
    let browsers = runningBrowsers()

    guard !browsers.isEmpty else {
      setWebHint(nil)
      if !localHasTrack {
        resetWebMediaState()
        registerEmptyPoll()
      }
      return
    }

    let (snapshots, hint) = probeWebSnapshots(browsers)

    guard let chosen = WebMediaParser.pick(from: snapshots, preferredURL: activeWebTarget?.url)
    else {
      setWebHint(hint)
      if !localHasTrack {
        resetWebMediaState()
        registerEmptyPoll()
      }
      return
    }
    setWebHint(nil)

    // A paused tab must not hide a paused local player that has a track.
    guard !chosen.isPaused || !localHasTrack else { return }
    applyWebSnapshot(chosen)
  }

  private func runningBrowsers() -> [String] {
    var browsers: [String] = []
    if isRunning(["com.apple.Safari"]) { browsers.append("Safari") }
    for browser in Self.chromiumBrowsers where isRunning(browser.bundleIDs) {
      browsers.append(browser.name)
    }
    return browsers
  }

  /// Must run on `appleScriptQueue`.
  private func probeWebSnapshots(_ browsers: [String])
    -> ([WebMediaSnapshot], WebMediaProbeError?)
  {
    var snapshots: [WebMediaSnapshot] = []
    var hint: WebMediaProbeError?
    for browser in browsers {
      guard let output = executeAppleScript(WebMediaScripts.probe(browser: browser)) else {
        continue
      }
      let found = WebMediaParser.parse(output: output, browser: browser)
      if found.isEmpty, let error = WebMediaParser.error(from: output, browser: browser) {
        hint = hint ?? error
      }
      snapshots.append(contentsOf: found)
    }
    return (snapshots, hint)
  }

  private func setWebHint(_ hint: WebMediaProbeError?) {
    DispatchQueue.main.async { [weak self] in
      if self?.webMediaHint != hint { self?.webMediaHint = hint }
    }
  }

  private func resetWebMediaState() {
    if mediaSource == .safari || mediaSource == .web {
      DispatchQueue.main.async { [weak self] in
        guard let self = self else { return }
        self.isPlaying = false
        self.activeWebTarget = nil
        self.lastDetectedRawWebTitle = ""
        self.updatePlaybackTimerState()
      }
    }
  }

  private func applyWebSnapshot(_ snapshot: WebMediaSnapshot) {
    var title = snapshot.title
    var artist = snapshot.artist
    var videoId: String?
    var source: MediaSource = .web

    // The browser's own media session is exact. Parse the tab title only when it is missing.
    if let parsed = parseWebMedia(title: snapshot.title, url: snapshot.url) {
      source = parsed.source
      videoId = parsed.videoId
      if artist.isEmpty {
        title = parsed.title
        artist = parsed.artist
      }
    } else if artist.isEmpty {
      return
    }
    guard !title.isEmpty else { return }

    // Right after a command the tab may not have reflected it yet; trust the command.
    let isPlaying = !snapshot.isPaused
    if Date().timeIntervalSince(lastCommandAt) < 1.5, isPlaying != expectedPlayingState,
      title == trackTitle
    {
      return
    }

    var artworkURL = URL(string: snapshot.artworkURL)
    if artworkURL == nil, let videoId {
      artworkURL = URL(string: "https://img.youtube.com/vi/\(videoId)/hqdefault.jpg")
    }

    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      self.activeWebTarget = snapshot
      self.updateTrack(
        source: source, title: title, artist: artist, album: "", duration: snapshot.duration,
        position: snapshot.currentTime, isPlaying: isPlaying, artworkURL: artworkURL)
    }
  }

  private func parseWebMedia(title: String, url: String) -> ParsedWebMedia? {
    var clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !clean.isEmpty else { return nil }

    // Strip notification badge e.g. (1), (123)
    clean = clean.replacingOccurrences(
      of: #"^\(\d+\+?\)\s*"#, with: "", options: .regularExpression)

    var videoId: String? = nil
    if url.contains("youtube.com/watch") {
      if let match = url.range(of: #"[?&]v=([a-zA-Z0-9_-]{11})"#, options: .regularExpression) {
        let matched = String(url[match])
        if let vIndex = matched.range(of: "v=") {
          videoId = String(matched[vIndex.upperBound...])
        }
      }
    } else if url.contains("youtu.be/") {
      if let match = url.range(of: #"youtu\.be/([a-zA-Z0-9_-]{11})"#, options: .regularExpression) {
        let matched = String(url[match])
        if let slashIdx = matched.range(of: "/") {
          videoId = String(matched[slashIdx.upperBound...])
        }
      }
    }

    if url.contains("music.youtube.com") {
      clean = clean.replacingOccurrences(
        of: #"\s*-\s*YouTube Music\s*$"#, with: "", options: [.regularExpression, .caseInsensitive])
      if clean.isEmpty || clean.lowercased() == "youtube music" {
        return nil
      }
      let parts = clean.components(separatedBy: "•")
      if parts.count >= 2 {
        let track = parts[0].trimmingCharacters(in: .whitespaces)
        let artist = parts[1].trimmingCharacters(in: .whitespaces)
        return ParsedWebMedia(title: track, artist: artist, source: .safari, videoId: videoId)
      }
      return ParsedWebMedia(title: clean, artist: "", source: .safari, videoId: videoId)
    }

    if url.contains("youtube.com") || url.contains("youtu.be") {
      clean = clean.replacingOccurrences(
        of: #"\s*-\s*YouTube\s*$"#, with: "", options: [.regularExpression, .caseInsensitive])
      if clean.isEmpty || clean.lowercased() == "youtube" {
        return nil
      }
      clean = clean.replacingOccurrences(
        of:
          #"\s*[\(\[](?:Official\s*(?:Music\s*)?Video|Official\s*Audio|Official\s*Lyric\s*Video|Lyric\s*Video|Visualizer|Audio|MV|HD|4K|Remastered|Live).*?[\)\]]"#,
        with: "", options: [.regularExpression, .caseInsensitive])
      clean = clean.replacingOccurrences(
        of: #"\s*\|\s*Official\s*.*$"#, with: "", options: [.regularExpression, .caseInsensitive])

      let separators = [" - ", " – ", " — ", " : "]
      for sep in separators {
        if clean.contains(sep) {
          let parts = clean.components(separatedBy: sep)
          if parts.count >= 2 {
            let artist = parts[0].trimmingCharacters(in: .whitespaces)
            let track = parts[1].trimmingCharacters(in: .whitespaces)
            return ParsedWebMedia(title: track, artist: artist, source: .safari, videoId: videoId)
          }
        }
      }
      return ParsedWebMedia(title: clean, artist: "", source: .safari, videoId: videoId)
    }

    if url.contains("open.spotify.com") {
      clean = clean.replacingOccurrences(
        of: #"\s*\|\s*Spotify\s*$"#, with: "", options: [.regularExpression, .caseInsensitive])
      clean = clean.replacingOccurrences(
        of: #"\s*-\s*Spotify\s*$"#, with: "", options: [.regularExpression, .caseInsensitive])
      if clean.isEmpty || clean.lowercased().contains("web player")
        || clean.lowercased() == "spotify"
      {
        return nil
      }

      let pattern = #"^(.*?)\s*-\s*song and lyrics by\s+(.*)$"#
      if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
        let ns = clean as NSString
        if let match = regex.firstMatch(in: clean, range: NSRange(location: 0, length: ns.length)) {
          let track = ns.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespaces)
          let artist = ns.substring(with: match.range(at: 2)).trimmingCharacters(in: .whitespaces)
          return ParsedWebMedia(title: track, artist: artist, source: .web, videoId: nil)
        }
      }

      if clean.contains("•") {
        let parts = clean.components(separatedBy: "•")
        if parts.count >= 2 {
          return ParsedWebMedia(
            title: parts[0].trimmingCharacters(in: .whitespaces),
            artist: parts[1].trimmingCharacters(in: .whitespaces), source: .web, videoId: nil)
        }
      }

      if clean.contains(" - ") {
        let parts = clean.components(separatedBy: " - ")
        if parts.count >= 2 {
          return ParsedWebMedia(
            title: parts[0].trimmingCharacters(in: .whitespaces),
            artist: parts[1].trimmingCharacters(in: .whitespaces), source: .web, videoId: nil)
        }
      }

      return ParsedWebMedia(title: clean, artist: "Spotify Web", source: .web, videoId: nil)
    }

    return nil
  }

  /// Sends `js` to the browser tab currently shown in the drawer.
  /// A permission or JavaScript error becomes the drawer hint.
  private func sendWebCommand(_ js: String) {
    appleScriptQueue.async { [weak self] in
      guard let self = self else { return }
      // The bridge may have been the source, so the tab was never recorded here.
      if self.activeWebTarget == nil {
        let snapshots = self.probeWebSnapshots(self.runningBrowsers()).0
        self.activeWebTarget = WebMediaParser.pick(from: snapshots)
      }
      guard let target = self.activeWebTarget else { return }
      let script = WebMediaScripts.control(browser: target.browser, url: target.url, js: js)
      guard let output = self.executeAppleScript(script) else {
        self.setWebHint(.automationDenied(browser: target.browser))
        return
      }
      if let error = WebMediaParser.error(from: output, browser: target.browser) {
        self.setWebHint(error)
      }
    }
  }

  private func pollSoon(after delay: TimeInterval = 0.35) {
    DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
      self?.pollCurrentMediaState()
    }
  }

  /// Sends a command to the MediaRemote bridge; falls back to AppleScript only
  /// when the bridge is missing or does not answer.
  private func sendBridge(
    _ command: String, position: TimeInterval? = nil, fallback: @escaping () -> Void
  ) {
    var payload: [String: Any] = ["id": UUID().uuidString, "cmd": command]
    if let position = position { payload["position"] = position }
    nowPlayingBridge.send(payload) { ok in
      guard !ok else { return }
      DispatchQueue.main.async(execute: fallback)
    }
  }

  func playPause() {
    let wasPlaying = isPlaying
    expectedPlayingState = !wasPlaying
    lastCommandAt = Date()

    isPlaying = !wasPlaying
    updatePlaybackTimerState()

    sendBridge("toggle") { [weak self] in
      self?.fallbackPlayPause(wasPlaying: wasPlaying)
    }

    pollSoon(after: 0.8)
  }

  func nextTrack() {
    lastCommandAt = Date()
    expectedPlayingState = isPlaying

    sendBridge("next") { [weak self] in
      self?.fallbackNext()
    }

    pollSoon(after: 0.8)
  }

  func previousTrack() {
    lastCommandAt = Date()
    expectedPlayingState = isPlaying

    sendBridge("previous") { [weak self] in
      self?.fallbackPrevious()
    }

    pollSoon(after: 0.8)
  }

  func seek(to position: TimeInterval) {
    playbackPosition = position
    sendBridge("seek", position: position) { [weak self] in
      self?.fallbackSeek(position)
    }
  }

  private func fallbackPlayPause(wasPlaying: Bool) {
    switch mediaSource {
    case .spotify:
      runAppleScriptAsync("tell application id \"com.spotify.client\" to playpause")
    case .appleMusic:
      runAppleScriptAsync("tell application id \"com.apple.Music\" to playpause")
    case .quicktime:
      runAppleScriptAsync("tell application \"QuickTime Player\" to playpause document 1")
    case .safari, .web:
      sendWebCommand(wasPlaying ? WebMediaScripts.pauseJS() : WebMediaScripts.playJS())
    default:
      break
    }
  }

  private func fallbackNext() {
    switch mediaSource {
    case .spotify:
      runAppleScriptAsync("tell application id \"com.spotify.client\" to next track")
    case .appleMusic:
      runAppleScriptAsync("tell application id \"com.apple.Music\" to next track")
    case .safari, .web:
      sendWebCommand(WebMediaScripts.nextJS())
    default:
      break
    }
  }

  private func fallbackPrevious() {
    switch mediaSource {
    case .spotify:
      runAppleScriptAsync("tell application id \"com.spotify.client\" to previous track")
    case .appleMusic:
      runAppleScriptAsync("tell application id \"com.apple.Music\" to previous track")
    case .safari, .web:
      sendWebCommand(WebMediaScripts.previousJS())
    default:
      break
    }
  }

  private func fallbackSeek(_ position: TimeInterval) {
    switch mediaSource {
    case .spotify:
      runAppleScriptAsync(
        "tell application id \"com.spotify.client\" to set player position to \(Int(position))")
    case .appleMusic:
      runAppleScriptAsync(
        "tell application id \"com.apple.Music\" to set player position to \(Int(position))")
    case .safari, .web:
      sendWebCommand(WebMediaScripts.seekJS(to: position))
    default:
      break
    }
  }

  private func fetchArtworkAsync(source: MediaSource, directURL: URL? = nil) {
    let cacheKey = (directURL?.absoluteString ?? "\(trackTitle)--\(artistName)") as NSString
    if let cached = artworkCache.object(forKey: cacheKey) {
      DispatchQueue.main.async {
        self.applyArtwork(cached)
      }
      return
    }

    if let direct = directURL {
      URLSession.shared.dataTask(with: direct) { [weak self] data, _, _ in
        if let data = data, let image = NSImage(data: data) {
          self?.artworkCache.setObject(image, forKey: cacheKey)
          DispatchQueue.main.async {
            self?.applyArtwork(image)
          }
        }
      }.resume()
      return
    }

    if source == .spotify {
      appleScriptQueue.async { [weak self] in
        let script =
          "tell application id \"com.spotify.client\" to get artwork url of current track"
        if let urlString = self?.executeAppleScript(script),
          let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines))
        {
          URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            if let data = data, let image = NSImage(data: data) {
              self?.artworkCache.setObject(image, forKey: cacheKey)
              DispatchQueue.main.async {
                self?.applyArtwork(image)
              }
            }
          }.resume()
        }
      }
    } else if source == .appleMusic {
      appleScriptQueue.async { [weak self] in
        guard let self = self else { return }
        let script = """
          tell application id "com.apple.Music"
              try
                  return raw data of artwork 1 of current track
              on error
                  return ""
              end try
          end tell
          """
        guard let data = self.executeAppleScriptData(script),
          let image = NSImage(data: data)
        else { return }
        self.artworkCache.setObject(image, forKey: cacheKey)
        DispatchQueue.main.async {
          self.applyArtwork(image)
        }
      }
    }
  }

  private func sanitizeTrackTitle(_ title: String) -> String {
    var clean = title
    clean = clean.replacingOccurrences(
      of: #"\s*[\(\[](?:feat\.|featuring|with).*?[\)\]]"#, with: "",
      options: [.regularExpression, .caseInsensitive])
    clean = clean.replacingOccurrences(
      of: #"\s*[-–—]\s*(?:Remastered|Live|Acoustic|Single|Bonus Track|Radio Edit).*"#, with: "",
      options: [.regularExpression, .caseInsensitive])
    clean = clean.replacingOccurrences(
      of: #"\s*[\(\[](?:Remastered|Deluxe|Live|Acoustic|Radio Edit|Bonus).*?[\)\]]"#, with: "",
      options: [.regularExpression, .caseInsensitive])
    let trimmed = clean.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? title : trimmed
  }

  private func sanitizeArtistName(_ artist: String) -> String {
    var clean = artist
    if let first = clean.components(separatedBy: ",").first {
      clean = first
    }
    let trimmed = clean.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? artist : trimmed
  }

  func refetchLyrics() {
    lastFetchedTrackKey = ""
    fetchLyrics(track: trackTitle, artist: artistName, album: albumName, duration: duration)
  }

  func fetchLyrics(track: String, artist: String, album: String, duration: TimeInterval) {
    let cleanTrack = sanitizeTrackTitle(track)
    let cleanArtist = sanitizeArtistName(artist)
    let key = "\(cleanTrack.lowercased())--\(cleanArtist.lowercased())"

    guard !cleanTrack.isEmpty else {
      DispatchQueue.main.async {
        self.isLoadingLyrics = false
        self.lyricsStatus = .idle
        self.syncedLyrics = []
        self.unsyncedLyrics = []
        self.currentLyricIndex = -1
        self.currentLyricText = ""
        self.isInstrumental = false
      }
      return
    }

    if let cached = lyricsCache[key] {
      DispatchQueue.main.async {
        self.isLoadingLyrics = false
        self.lyricsStatus = cached.status
        self.syncedLyrics = cached.synced
        self.unsyncedLyrics = cached.unsynced
        self.isInstrumental = cached.isInstrumental
        if self.duration == 0 && cached.duration > 0 {
          self.duration = cached.duration
        }
        self.lastFetchedTrackKey = key
        self.updateCurrentLyric()
      }
      return
    }

    if key == lastFetchedTrackKey && lyricsStatus != .idle && lyricsStatus != .loading {
      return
    }

    DispatchQueue.main.async {
      self.isLoadingLyrics = true
      self.lyricsStatus = .loading
      self.syncedLyrics = []
      self.unsyncedLyrics = []
      self.currentLyricIndex = -1
      self.currentLyricText = ""
      self.isInstrumental = false
    }

    let isGenericArtist =
      (cleanArtist.isEmpty || cleanArtist == "YouTube" || cleanArtist == "YouTube Music"
        || cleanArtist == "Spotify Web")

    if !isGenericArtist {
      searchLRCLIB(track: cleanTrack, artist: cleanArtist) { [weak self] success in
        guard let self = self else { return }
        if !success {
          self.searchLRCLIBGeneral(query: "\(cleanArtist) \(cleanTrack)") { success2 in
            if !success2 {
              self.searchLRCLIBGeneral(query: cleanTrack) { success3 in
                if !success3 {
                  self.fetchAppleMusicLocalLyrics(key: key)
                }
              }
            }
          }
        }
      }
    } else {
      searchLRCLIBGeneral(query: cleanTrack) { [weak self] success in
        guard let self = self else { return }
        if !success {
          self.fetchAppleMusicLocalLyrics(key: key)
        }
      }
    }
  }

  private func searchLRCLIB(track: String, artist: String, completion: @escaping (Bool) -> Void) {
    guard var components = URLComponents(string: "https://lrclib.net/api/search") else {
      completion(false)
      return
    }
    components.queryItems = [
      URLQueryItem(name: "track_name", value: track),
      URLQueryItem(name: "artist_name", value: artist),
    ]

    guard let url = components.url else {
      completion(false)
      return
    }

    performLyricsRequest(url: url, track: track, artist: artist, completion: completion)
  }

  private func searchLRCLIBGeneral(query: String, completion: @escaping (Bool) -> Void) {
    guard var components = URLComponents(string: "https://lrclib.net/api/search") else {
      completion(false)
      return
    }
    components.queryItems = [
      URLQueryItem(name: "q", value: query)
    ]

    guard let url = components.url else {
      completion(false)
      return
    }

    performLyricsRequest(url: url, track: query, artist: "", completion: completion)
  }

  private func performLyricsRequest(
    url: URL, track: String, artist: String, completion: @escaping (Bool) -> Void
  ) {
    var request = URLRequest(url: url)
    request.setValue("Harmonotch macOS Island v1.0", forHTTPHeaderField: "User-Agent")
    request.timeoutInterval = 8.0

    URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
      if let error = error {
        NSLog("[Harmonotch:Media] Lyrics network error: %@", error.localizedDescription)
        completion(false)
        return
      }

      guard let self = self, let data = data else {
        completion(false)
        return
      }

      var matchedItem: [String: Any]? = nil

      if let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
        let currentDuration = self.duration
        if currentDuration > 0 {
          matchedItem = array.first(where: { item in
            guard let s = item["syncedLyrics"] as? String,
              !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
            let itemDur = self.extractDouble(from: item["duration"]) ?? 0
            return itemDur > 0 ? abs(itemDur - currentDuration) <= 15 : true
          })
        }
        if matchedItem == nil {
          matchedItem = array.first(where: {
            guard let s = $0["syncedLyrics"] as? String else { return false }
            return !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
          })
        }
        if matchedItem == nil {
          matchedItem = array.first(where: {
            let plain = $0["plainLyrics"] as? String ?? ""
            let instrumental = $0["instrumental"] as? Bool ?? false
            return !plain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || instrumental
          }) ?? array.first
        }
      } else if let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
        matchedItem = dict
      }

      guard let item = matchedItem else {
        completion(false)
        return
      }

      let instrumental = item["instrumental"] as? Bool ?? false
      let syncedLRC = item["syncedLyrics"] as? String ?? ""
      let plainLyrics = item["plainLyrics"] as? String ?? ""
      let trackDuration = self.extractDouble(from: item["duration"]) ?? 0

      var verifiedSyncedLyrics: [LyricLine] = []
      if !syncedLRC.isEmpty {
        let parsed = LRCParser.parse(syncedLRC)
        let hasDistinctTimestamps = parsed.count > 1 && (parsed.last?.time ?? 0) > (parsed.first?.time ?? 0)
        if hasDistinctTimestamps {
          verifiedSyncedLyrics = parsed
        }
      }

      var extractedPlainLines: [String] = []
      if !plainLyrics.isEmpty {
        extractedPlainLines = plainLyrics.components(separatedBy: "\n")
          .map { $0.trimmingCharacters(in: .whitespaces) }
          .filter { !$0.isEmpty }
      } else if !syncedLRC.isEmpty && verifiedSyncedLyrics.isEmpty {
        extractedPlainLines = syncedLRC.components(separatedBy: "\n")
          .map { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if let closeIdx = trimmed.lastIndex(of: "]") {
              return String(trimmed[trimmed.index(after: closeIdx)...]).trimmingCharacters(in: .whitespaces)
            }
            return trimmed
          }
          .filter { !$0.isEmpty }
      }

      if !verifiedSyncedLyrics.isEmpty || !extractedPlainLines.isEmpty || instrumental {
        DispatchQueue.main.async {
          self.isLoadingLyrics = false
          self.isInstrumental = instrumental
          if self.duration == 0 && trackDuration > 0 {
            self.duration = trackDuration
          }

          if instrumental {
            self.syncedLyrics = []
            self.unsyncedLyrics = []
            self.lyricsStatus = .instrumental
          } else if !verifiedSyncedLyrics.isEmpty {
            self.syncedLyrics = verifiedSyncedLyrics
            self.unsyncedLyrics = []
            self.lyricsStatus = .synced(verifiedSyncedLyrics)
            NSLog(
              "[Harmonotch:Media] Successfully parsed %ld synced lyric lines for %@ - %@",
              verifiedSyncedLyrics.count, track, artist)
          } else if !extractedPlainLines.isEmpty {
            self.syncedLyrics = []
            self.unsyncedLyrics = extractedPlainLines
            self.lyricsStatus = .unsynced(extractedPlainLines)
            NSLog(
              "[Harmonotch:Media] Detected %ld unsynced plain lyric lines for %@ - %@",
              extractedPlainLines.count, track, artist)
          }

          let cleanTrackTitle = self.sanitizeTrackTitle(track)
          let cleanArtistName = self.sanitizeArtistName(artist)
          let cacheKey = "\(cleanTrackTitle.lowercased())--\(cleanArtistName.lowercased())"
          self.lastFetchedTrackKey = cacheKey
          self.lyricsCache[cacheKey] = (
            status: self.lyricsStatus,
            synced: self.syncedLyrics,
            unsynced: self.unsyncedLyrics,
            isInstrumental: self.isInstrumental,
            duration: self.duration
          )
          self.updateCurrentLyric()
        }
        completion(true)
      } else {
        completion(false)
      }
    }.resume()
  }

  private func fetchAppleMusicLocalLyrics(key: String) {
    guard mediaSource == .appleMusic else {
      DispatchQueue.main.async {
        self.isLoadingLyrics = false
        let desc = L10n.Media.lyricsUnavailableDesc
        self.lyricsStatus = .unavailable(desc)
        self.syncedLyrics = []
        self.unsyncedLyrics = []
        self.lyricsCache[key] = (
          status: .unavailable(desc),
          synced: [],
          unsynced: [],
          isInstrumental: false,
          duration: self.duration
        )
      }
      return
    }

    appleScriptQueue.async { [weak self] in
      let script = """
        tell application "Music"
            try
                return lyrics of current track
            on error
                return ""
            end try
        end tell
        """
      if let text = self?.executeAppleScript(script),
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      {
        let lines = text.components(separatedBy: "\n")
          .map { $0.trimmingCharacters(in: .whitespaces) }
          .filter { !$0.isEmpty }
        DispatchQueue.main.async {
          guard let self = self else { return }
          self.isLoadingLyrics = false
          self.syncedLyrics = []
          self.unsyncedLyrics = lines
          self.isInstrumental = false
          self.lyricsStatus = .unsynced(lines)
          self.lastFetchedTrackKey = key
          self.lyricsCache[key] = (
            status: .unsynced(lines),
            synced: [],
            unsynced: lines,
            isInstrumental: false,
            duration: self.duration
          )
          self.updateCurrentLyric()
        }
      } else {
        DispatchQueue.main.async {
          guard let self = self else { return }
          self.isLoadingLyrics = false
          self.syncedLyrics = []
          self.unsyncedLyrics = []
          self.isInstrumental = false
          let desc = L10n.Media.lyricsUnavailableDesc
          self.lyricsStatus = .unavailable(desc)
          self.lastFetchedTrackKey = key
          self.lyricsCache[key] = (
            status: .unavailable(desc),
            synced: [],
            unsynced: [],
            isInstrumental: false,
            duration: self.duration
          )
        }
      }
    }
  }

  private func cachedScript(_ scriptText: String) -> NSAppleScript? {
    if let cached = scriptCache[scriptText] { return cached }
    guard let newScript = NSAppleScript(source: scriptText) else { return nil }
    scriptCache[scriptText] = newScript
    return newScript
  }

  private func executeAppleScript(_ scriptText: String) -> String? {
    var result: String?
    let work = { [weak self] in
      guard let self = self, let scriptObject = self.cachedScript(scriptText) else { return }
      var error: NSDictionary?
      let output = scriptObject.executeAndReturnError(&error)
      if error == nil {
        result = output.stringValue
      } else if let error = error {
        NSLog("[Harmonotch:Media] executeAppleScript error: %@", error)
      }
    }

    if DispatchQueue.getSpecific(key: appleScriptQueueKey) != nil {
      work()
    } else {
      appleScriptQueue.sync(execute: work)
    }
    return result
  }

  private func executeAppleScriptData(_ scriptText: String) -> Data? {
    let work = { [weak self] () -> Data? in
      guard let self = self, let scriptObject = self.cachedScript(scriptText) else { return nil }
      var error: NSDictionary?
      let output = scriptObject.executeAndReturnError(&error)
      guard error == nil else {
        if let error = error {
          NSLog("[Harmonotch:Media] executeAppleScriptData error: %@", error)
        }
        return nil
      }
      return output.data
    }

    if DispatchQueue.getSpecific(key: appleScriptQueueKey) != nil {
      return work()
    }
    return appleScriptQueue.sync(execute: work)
  }

  private func runAppleScriptAsync(_ scriptText: String) {
    appleScriptQueue.async { [weak self] in
      _ = self?.executeAppleScript(scriptText)
    }
  }

  private func formatTime(_ seconds: TimeInterval) -> String {
    let total = max(0, Int(seconds))
    let hours = total / 3600
    let mins = (total % 3600) / 60
    let secs = total % 60
    if hours > 0 {
      return String(format: "%d:%02d:%02d", hours, mins, secs)
    }
    return String(format: "%d:%02d", mins, secs)
  }
}

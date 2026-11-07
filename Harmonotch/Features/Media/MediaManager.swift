import AppKit
import Combine
import Foundation
import SwiftUI

/// Manages media playback state, artwork, lyrics fetching, and the play queue.
final class MediaManager: ObservableObject {
  static let shared = MediaManager()

  @Published var isPlaying: Bool = false
  @Published var mediaSource: MediaSource = .none
  @Published public private(set) var presentation: MediaPresentation? = nil
  @Published var trackTitle: String = ""
  @Published var artistName: String = ""
  @Published var albumName: String = ""
  @Published var duration: TimeInterval = 0
  @Published var playbackPosition: TimeInterval = 0
  @Published var artworkImage: NSImage? = nil
  @Published var artworkAccentColor: NSColor? = nil

  @Published var syncedLyrics: [LyricLine] = [] {
    didSet {
      updatePlaybackTimerState()
    }
  }
  @Published var unsyncedLyrics: [String] = []
  @Published var currentLyricIndex: Int = -1
  @Published var currentLyricText: String = ""
  @Published var isLoadingLyrics: Bool = false
  @Published var isInstrumental: Bool = false
  @Published var lyricsStatus: LyricsStatus = .idle

  /// Play queue for the currently playing track. Filled automatically when track is active.
  @Published var queue: [QueueItem] = []

  var hasActiveTrack: Bool {
    !trackTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  public var hasMediaSession: Bool {
    presentation != nil
  }

  var progress: Double {
    duration > 0 ? min(1.0, max(0.0, playbackPosition / duration)) : 0.0
  }

  var formattedPosition: String {
    TimeFormatting.clock(playbackPosition)
  }

  var formattedDuration: String {
    TimeFormatting.clock(duration)
  }

  var playbackTimer: AnyCancellable?
  var fastPollingTimer: AnyCancellable?
  var currentPlaybackInterval: TimeInterval = 0
  var lastFetchedTrackKey: String = ""
  var cancellables = Set<AnyCancellable>()
  var lastDetectedRawWebTitle: String = ""

  let artworkCache = NSCache<NSString, NSImage>()
  var lyricsCache:
    [String: (
      status: LyricsStatus, synced: [LyricLine], unsynced: [String], isInstrumental: Bool,
      duration: TimeInterval
    )] = [:]

  @Published var webMediaHint: WebMediaProbeError? = nil
  @Published public var includeOtherAudioApps: Bool = UserDefaults.standard[UserDefaultsKeys.includeOtherAudioApps] {
    didSet {
      UserDefaults.standard[UserDefaultsKeys.includeOtherAudioApps] = includeOtherAudioApps
      DispatchQueue.main.async { [weak self] in
        guard let self = self else { return }
        self.handleAudioPresenceApps(AudioProcessPresenceMonitor.shared.activeApps)
      }
    }
  }
  var activeWebTarget: WebMediaSnapshot?
  var localPollPlaying = false
  var lastCommandAt = Date.distantPast
  var expectedPlayingState: Bool = false
  let nowPlayingBridge = NowPlayingBridge()

  var candidateRegistry: [MediaIdentity: MediaCandidate] = [:]
  var currentIdentity: MediaIdentity? = nil
  var systemIdentity: MediaIdentity? = nil
  var userSelectedIdentity: MediaIdentity? = nil
  public internal(set) var mediaGeneration: UInt64 = 0
  var artworkAccentTrackKey = ""

  private init() {
    setupDistributedNotificationObservers()
    setupFastPollingTimer()
    nowPlayingBridge.onState = { [weak self] state in
      self?.handleNowPlayingState(state)
    }
    nowPlayingBridge.start()
    setupAudioPresenceSubscription()
    pollCurrentMediaState()
  }

  /// Called on quit so the perl child does not outlive the app.
  func stop() {
    nowPlayingBridge.stop()
    AudioProcessPresenceMonitor.shared.stop()
  }

  public func openActiveApp() {
    let bundleID = presentation?.app.bundleID ?? ""
    AppLauncher.activateOrOpen(bundleID: bundleID)
  }

  func traceProducer(producer: String, source: MediaSource, title: String, isPlaying: Bool, details: String = "") {
    print("[MediaTrace][\(Date().timeIntervalSince1970)] producer=\(producer) source=\(source.rawValue) title='\(title)' playing=\(isPlaying) \(details)")
  }

  // MARK: - Arbitration (Single Ingestion & Reconcile)

  func ingest(candidate: MediaCandidate) {
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }

      var updated = candidate

      // Command guard: don't let a stale line revert a recent user command
      if Date().timeIntervalSince(self.lastCommandAt) < 1.5,
         self.currentIdentity == candidate.identity,
         candidate.isPlaying != self.expectedPlayingState {
        updated.isPlaying = self.expectedPlayingState
      }

      // Preserve existing artwork if the same track sent a subsequent update without artwork payload
      if updated.artwork == nil,
         let existing = self.candidateRegistry[updated.identity],
         existing.title == updated.title,
         existing.artist == updated.artist {
        updated.artwork = existing.artwork
      }

      // The same track can arrive twice: once from the MediaRemote bridge
      // (which carries the cover) and once from an AppleScript/notification
      // twin. Share the cover so whichever twin wins can draw it.
      if updated.hasMetadata {
        if updated.artwork == nil {
          updated.artwork = self.candidateRegistry.values.first {
            $0.app.bundleID == updated.app.bundleID && $0.title == updated.title
              && $0.artist == updated.artist && $0.artwork != nil
          }?.artwork
        } else {
          for (id, sibling) in self.candidateRegistry where
            sibling.awareness != .presence && sibling.app.bundleID == updated.app.bundleID
              && sibling.title == updated.title && sibling.artist == updated.artist {
            self.candidateRegistry[id]?.artwork = updated.artwork
          }
        }
      }

      // If this candidate has metadata, remove any audioOnly presence candidate for the same app
      if updated.hasMetadata {
        for (id, existing) in self.candidateRegistry where existing.awareness == .presence && existing.app.bundleID == updated.app.bundleID {
          self.candidateRegistry.removeValue(forKey: id)
        }
      }

      // Track playback start timestamp
      if updated.isPlaying {
        if let existing = self.candidateRegistry[updated.identity], existing.isPlaying {
          updated.startedPlayingAt = existing.startedPlayingAt ?? updated.startedPlayingAt
        } else if updated.startedPlayingAt == nil {
          updated.startedPlayingAt = Date().timeIntervalSince1970
        }
      }

      self.candidateRegistry[updated.identity] = updated
      self.reconcile()
    }
  }

  func reconcile() {
    dispatchPrecondition(condition: .onQueue(.main))

    let candidates = MediaSelector.pruneStale(
      candidateRegistry.values.filter { includeOtherAudioApps || $0.hasMetadata }
    )
    let frontmost = NSWorkspace.shared.frontmostApplication?.bundleIdentifier

    guard let winner = MediaSelector.select(
      candidates: candidates,
      previous: currentIdentity,
      system: systemIdentity,
      userSelection: userSelectedIdentity,
      frontmostBundleID: frontmost
    ) else {
      if hasActiveTrack || presentation != nil {
        clearSession()
      }
      return
    }

    applyCandidate(winner)
  }

  public static func isBrowserBundleID(_ bundleID: String) -> Bool {
    BrowserCatalog.isBrowser(bundleID: bundleID)
  }

  private func applyCandidate(_ winner: MediaCandidate) {
    let identityChanged = (currentIdentity != winner.identity)
    let trackChanged = (trackTitle != winner.title || artistName != winner.artist)
    if identityChanged || trackChanged {
      mediaGeneration &+= 1
    }
    let currentGen = mediaGeneration

    currentIdentity = winner.identity
    presentation = MediaPresentation(candidate: winner)
    isPlaying = winner.isPlaying
    mediaSource = Self.mediaSource(for: winner.app.bundleID)
    updatePlaybackTimerState()

    if winner.hasMetadata {
      if winner.position > 0 || trackChanged || identityChanged {
        playbackPosition = winner.position
      }
      if winner.duration > 0 || trackChanged || identityChanged {
        duration = winner.duration
      }
      trackTitle = winner.title
      artistName = winner.artist
      albumName = winner.album

      let resolvedDirectArtwork: NSImage? = {
        if case .data(let data)? = winner.artwork {
          return NSImage(data: data)
        }
        return nil
      }()
      let resolvedURL = resolveBrowserArtworkURL(for: winner)

      if let direct = resolvedDirectArtwork {
        let cacheKey = MediaArtworkCacheKey.make(
          bundleID: winner.app.bundleID,
          title: winner.title,
          artist: winner.artist,
          directURL: resolvedURL
        ) as NSString
        artworkCache.setObject(direct, forKey: cacheKey)
        applyArtwork(direct, generation: currentGen)
      } else if identityChanged || trackChanged {
        // Clear old artwork immediately on track/source switch so stale cover never lingers
        applyArtwork(nil, generation: currentGen)
      }

      if (trackChanged || identityChanged) && !winner.title.isEmpty {
        queue = [QueueItem(title: winner.title, artist: winner.artist)]
        if resolvedDirectArtwork == nil {
          fetchArtworkAsync(for: winner, directURL: resolvedURL, generation: currentGen)
        }
        fetchLyrics(track: winner.title, artist: winner.artist, album: winner.album, duration: winner.duration)
      }
      updateCurrentLyric()
    } else {
      // Audio-only candidate (Zoom, Teams, Game, etc.)
      trackTitle = ""
      artistName = winner.app.displayName
      albumName = ""
      duration = 0
      playbackPosition = 0
      queue = []
      applyArtwork(nil, generation: currentGen)
      updateCurrentLyric()
    }
  }

  public static func mediaSource(for bundleID: String) -> MediaSource {
    let lower = bundleID.lowercased()
    if lower.contains("spotify") { return .spotify }
    if lower.contains("apple.music") || lower == "com.apple.music" { return .appleMusic }
    if BrowserCatalog.isSafari(bundleID: bundleID) { return .safari }
    if BrowserCatalog.isBrowser(bundleID: bundleID) { return .web }
    if lower.contains("quicktime") { return .quicktime }
    if lower.contains("podcasts") { return .podcasts }
    if lower.contains("iina") { return .iina }
    if lower.contains("vlc") { return .vlc }
    return .system
  }

  private func clearSession() {
    mediaGeneration &+= 1
    isPlaying = false
    presentation = nil
    currentIdentity = nil
    mediaSource = .none
    trackTitle = ""
    artistName = ""
    albumName = ""
    self.queue = []
    applyArtwork(nil)
    lastDetectedRawWebTitle = ""
    playbackPosition = 0
    duration = 0
    expectedPlayingState = false
    updatePlaybackTimerState()
    updateCurrentLyric()
  }

  func updatePlaybackTimerState() {
    guard isPlaying else {
      playbackTimer?.cancel()
      playbackTimer = nil
      currentPlaybackInterval = 0
      return
    }

    let targetInterval: TimeInterval = syncedLyrics.isEmpty ? 1.0 : 0.25
    if playbackTimer == nil || currentPlaybackInterval != targetInterval {
      playbackTimer?.cancel()
      currentPlaybackInterval = targetInterval
      playbackTimer = Timer.publish(every: targetInterval, tolerance: targetInterval * 0.1, on: .main, in: .common)
        .autoconnect()
        .sink { [weak self] _ in
          guard let self = self, self.isPlaying else { return }
          self.playbackPosition += targetInterval
          if self.duration > 0 && self.playbackPosition > self.duration {
            self.playbackPosition = self.duration
          }
          if !self.syncedLyrics.isEmpty {
            self.updateCurrentLyric()
          }
        }
    }
  }

  private func setupFastPollingTimer() {
    fastPollingTimer = Timer.publish(every: 4.0, tolerance: 0.5, on: .main, in: .common)
      .autoconnect()
      .sink { [weak self] _ in
        self?.pollCurrentMediaState()
      }
  }

  func pollSoon(after delay: TimeInterval = 0.35) {
    DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
      self?.pollCurrentMediaState()
    }
  }

  /// Sends a command to the MediaRemote bridge; falls back to AppleScript only
  /// when the bridge is missing or does not answer.
  private func sendBridge(
    _ command: NowPlayingCommand,
    target: String?,
    fallback: @escaping () -> Void
  ) {
    nowPlayingBridge.send(command, target: target) { ok in
      guard !ok else { return }
      DispatchQueue.main.async(execute: fallback)
    }
  }

  func playPause() {
    guard presentation?.capabilities.contains(.playPause) ?? true else {
      NSLog("[MediaTrace] Ignoring playPause: capability not supported for %@", currentIdentity?.bundleID ?? "nil")
      return
    }

    let wasPlaying = isPlaying
    expectedPlayingState = !wasPlaying
    lastCommandAt = Date()

    isPlaying = !wasPlaying
    updatePlaybackTimerState()

    let targetBundleID = currentIdentity?.bundleID
    if let id = currentIdentity, var cand = candidateRegistry[id] {
      cand.isPlaying = !wasPlaying
      cand.lastUpdated = Date().timeIntervalSince1970
      candidateRegistry[id] = cand
      reconcile()
    }

    if let id = currentIdentity, let cand = candidateRegistry[id],
       cand.awareness == .script && Self.isBrowserBundleID(cand.app.bundleID) {
      sendWebCommand(wasPlaying ? WebMediaScripts.pauseJS() : WebMediaScripts.playJS())
      pollSoon(after: 0.8)
      return
    }

    sendBridge(.toggle, target: targetBundleID) { [weak self] in
      self?.fallbackPlayPause(wasPlaying: wasPlaying, targetBundleID: targetBundleID)
    }

    pollSoon(after: 0.8)
  }

  func nextTrack() {
    guard presentation?.capabilities.contains(.nextTrack) ?? true else {
      NSLog("[MediaTrace] Ignoring nextTrack: capability not supported for %@", currentIdentity?.bundleID ?? "nil")
      return
    }

    lastCommandAt = Date()
    expectedPlayingState = isPlaying
    let targetBundleID = currentIdentity?.bundleID

    if let id = currentIdentity, let cand = candidateRegistry[id],
       cand.awareness == .script && Self.isBrowserBundleID(cand.app.bundleID) {
      sendWebCommand(WebMediaScripts.nextJS())
      pollSoon(after: 0.8)
      return
    }

    sendBridge(.next, target: targetBundleID) { [weak self] in
      self?.fallbackNext(targetBundleID: targetBundleID)
    }

    pollSoon(after: 0.8)
  }

  func previousTrack() {
    guard presentation?.capabilities.contains(.previousTrack) ?? true else {
      NSLog("[MediaTrace] Ignoring previousTrack: capability not supported for %@", currentIdentity?.bundleID ?? "nil")
      return
    }

    lastCommandAt = Date()
    expectedPlayingState = isPlaying
    let targetBundleID = currentIdentity?.bundleID

    if let id = currentIdentity, let cand = candidateRegistry[id],
       cand.awareness == .script && Self.isBrowserBundleID(cand.app.bundleID) {
      sendWebCommand(WebMediaScripts.previousJS())
      pollSoon(after: 0.8)
      return
    }

    sendBridge(.previous, target: targetBundleID) { [weak self] in
      self?.fallbackPrevious(targetBundleID: targetBundleID)
    }

    pollSoon(after: 0.8)
  }

  func seek(to position: TimeInterval) {
    guard presentation?.capabilities.contains(.seek) ?? true else {
      NSLog("[MediaTrace] Ignoring seek: capability not supported for %@", currentIdentity?.bundleID ?? "nil")
      return
    }

    playbackPosition = position
    let targetBundleID = currentIdentity?.bundleID

    if let id = currentIdentity, let cand = candidateRegistry[id],
       cand.awareness == .script && Self.isBrowserBundleID(cand.app.bundleID) {
      sendWebCommand(WebMediaScripts.seekJS(to: position))
      return
    }

    sendBridge(.seek(position: position), target: targetBundleID) { [weak self] in
      self?.fallbackSeek(position, targetBundleID: targetBundleID)
    }
  }
}

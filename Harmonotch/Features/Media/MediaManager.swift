import AppKit
import Combine
import Foundation
import SwiftUI

typealias CachedLyrics = (
  status: LyricsStatus, synced: [LyricLine], unsynced: [String], isInstrumental: Bool,
  duration: TimeInterval
)

/// Small LRU so long sessions do not keep every track's lyrics in memory.
final class LyricsCache {
  private let capacity: Int
  private var entries: [String: CachedLyrics] = [:]
  private var order: [String] = []

  init(capacity: Int = 50) {
    self.capacity = capacity
  }

  subscript(key: String) -> CachedLyrics? {
    get {
      guard let entry = entries[key] else { return nil }
      touch(key)
      return entry
    }
    set {
      guard let newValue else {
        entries.removeValue(forKey: key)
        order.removeAll { $0 == key }
        return
      }
      entries[key] = newValue
      touch(key)
    }
  }

  private func touch(_ key: String) {
    order.removeAll { $0 == key }
    order.append(key)
    while order.count > capacity {
      entries.removeValue(forKey: order.removeFirst())
    }
  }
}

/// Isolated clock so playback ticks don't re-render every view observing the manager.
final class PlaybackClock: ObservableObject {
  @Published var position: TimeInterval = 0
  @Published var duration: TimeInterval = 0

  var progress: Double {
    duration > 0 ? min(1.0, max(0.0, position / duration)) : 0.0
  }

  var formattedPosition: String { TimeFormatting.clock(position) }
  var formattedDuration: String { TimeFormatting.clock(duration) }
}

/// Small surface used by pill/tab/menu views that don't need every published field.
public struct MediaSummary: Equatable {
  public let isPlaying: Bool
  public let hasMediaSession: Bool
  public let title: String
  public let artist: String
  public let bundleID: String?
  public let hasMetadata: Bool

  public static let empty = MediaSummary(
    isPlaying: false, hasMediaSession: false, title: "", artist: "", bundleID: nil,
    hasMetadata: false)
}

/// Manages media playback state, artwork, lyrics fetching, and the play queue.
final class MediaManager: ObservableObject {
  static let shared = MediaManager()

  @Published var isPlaying: Bool = false
  @Published var mediaSource: MediaSource = .none
  @Published public private(set) var presentation: MediaPresentation? = nil
  @Published var trackTitle: String = ""
  @Published var artistName: String = ""
  @Published var albumName: String = ""
  @Published var summary = MediaSummary.empty
  let playbackClock = PlaybackClock()

  var duration: TimeInterval {
    get { playbackClock.duration }
    set { playbackClock.duration = newValue }
  }

  var playbackPosition: TimeInterval {
    get { playbackClock.position }
    set { playbackClock.position = newValue }
  }
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

  var progress: Double { playbackClock.progress }
  var formattedPosition: String { playbackClock.formattedPosition }
  var formattedDuration: String { playbackClock.formattedDuration }

  var playbackTimer: AnyCancellable?
  var pollWorkItem: DispatchWorkItem?
  var currentPlaybackInterval: TimeInterval = 0
  var isPollInFlight = false
  var lastInteractionAt = Date.distantPast
  var cachedBrowsers: [String] = []
  var lastFetchedTrackKey: String = ""
  var cancellables = Set<AnyCancellable>()
  var lastDetectedRawWebTitle: String = ""

  let artworkCache = NSCache<NSString, NSImage>()
  var lyricsCache = LyricsCache()

  @Published var webMediaHint: WebMediaProbeError? = nil
  @Published public var includeOtherAudioApps: Bool = UserDefaults.standard[UserDefaultsKeys.includeOtherAudioApps] {
    didSet {
      UserDefaults.standard[UserDefaultsKeys.includeOtherAudioApps] = includeOtherAudioApps
      let monitor = AudioProcessPresenceMonitor.shared
      if includeOtherAudioApps {
        monitor.start()
      } else {
        monitor.stop()
      }
      DispatchQueue.main.async { [weak self] in
        guard let self = self else { return }
        self.handleAudioPresenceApps(monitor.activeApps)
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
    artworkCache.countLimit = 30
    artworkCache.totalCostLimit = 64 * 1024 * 1024
    setupDistributedNotificationObservers()
    scheduleNextPoll()
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

  func traceProducer(
    producer: String,
    source: MediaSource,
    title: @autoclosure () -> String,
    isPlaying: Bool,
    details: @autoclosure () -> String = ""
  ) {
    #if DEBUG
      print("[MediaTrace][\(Date().timeIntervalSince1970)] producer=\(producer) source=\(source.rawValue) title='\(title())' playing=\(isPlaying) \(details())")
    #endif
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
      candidateRegistry = Self.prunedCandidateRegistry(
        candidateRegistry, keeping: currentIdentity,
        now: Date().timeIntervalSince1970)
      return
    }

    applyCandidate(winner)
    candidateRegistry = Self.prunedCandidateRegistry(
      candidateRegistry, keeping: currentIdentity,
      now: Date().timeIntervalSince1970)
  }

  public static func isBrowserBundleID(_ bundleID: String) -> Bool {
    BrowserCatalog.isBrowser(bundleID: bundleID)
  }

  /// Drops stale entries so the registry (and any base64 artwork inside it) stays
  /// bounded; the current winner is never pruned.
  static func prunedCandidateRegistry(
    _ registry: [MediaIdentity: MediaCandidate],
    keeping keep: MediaIdentity?,
    now: TimeInterval,
    maxAge: TimeInterval = 120,
    limit: Int = 20
  ) -> [MediaIdentity: MediaCandidate] {
    var result = registry.filter { identity, candidate in
      identity == keep || now - candidate.lastUpdated <= maxAge
    }
    if result.count > limit {
      let dropCount = result.count - limit
      let ordered = result.sorted(by: { a, b in
        let aKeep = a.key == keep
        let bKeep = b.key == keep
        if aKeep != bKeep { return !aKeep }
        return a.value.lastUpdated < b.value.lastUpdated
      })
      for index in 0..<dropCount {
        result.removeValue(forKey: ordered[index].key)
      }
    }
    return result
  }

  /// Position/artwork change every poll; only display-relevant fields count here.
  private func isSameDisplayState(_ old: MediaPresentation?, _ winner: MediaCandidate) -> Bool {
    guard let old else { return false }
    guard old.identity == winner.identity, old.isPlaying == winner.isPlaying else { return false }
    switch (old.kind, winner.hasMetadata) {
    case (.track(let info), true):
      return info.title == winner.title && info.artist == winner.artist
        && info.album == winner.album && info.duration == winner.duration
    case (.audioOnly(let app), false):
      return app.bundleID == winner.app.bundleID && app.displayName == winner.app.displayName
    default:
      return false
    }
  }

  private func applyCandidate(_ winner: MediaCandidate) {
    let identityChanged = (currentIdentity != winner.identity)
    let trackChanged = (trackTitle != winner.title || artistName != winner.artist)
    let newPresentation = MediaPresentation(candidate: winner)
    let newSource = Self.mediaSource(for: winner.app.bundleID)

    // Dedupe: identical polls must not re-publish and re-render.
    if !identityChanged, !trackChanged, isSameDisplayState(presentation, winner),
      isPlaying == winner.isPlaying, mediaSource == newSource,
      albumName == winner.album || !winner.hasMetadata
    {
      if winner.hasMetadata {
        playbackPosition = winner.position
        duration = winner.duration
      }
      return
    }

    if identityChanged || trackChanged {
      mediaGeneration &+= 1
    }
    let currentGen = mediaGeneration

    currentIdentity = winner.identity
    if !isSameDisplayState(presentation, winner) { presentation = newPresentation }
    if isPlaying != winner.isPlaying { isPlaying = winner.isPlaying }
    if mediaSource != newSource { mediaSource = newSource }
    let newSummary = MediaSummary(
      isPlaying: winner.isPlaying,
      hasMediaSession: true,
      title: winner.hasMetadata ? winner.title : "",
      artist: winner.hasMetadata ? winner.artist : winner.app.displayName,
      bundleID: winner.app.bundleID,
      hasMetadata: winner.hasMetadata
    )
    if summary != newSummary { summary = newSummary }
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

      var hasDirectArtwork = false
      if case .data? = winner.artwork { hasDirectArtwork = true }
      let resolvedURL = resolveBrowserArtworkURL(for: winner)

      if !hasDirectArtwork, identityChanged || trackChanged {
        // Clear old artwork immediately on track/source switch so stale cover never lingers
        applyArtwork(nil, generation: currentGen)
      }

      if (trackChanged || identityChanged) && !winner.title.isEmpty {
        queue = [QueueItem(title: winner.title, artist: winner.artist)]
        fetchArtworkAsync(for: winner, directURL: resolvedURL, generation: currentGen)
        fetchLyrics(track: winner.title, artist: winner.artist, album: winner.album, duration: winner.duration)
      } else if artworkImage == nil, winner.artwork != nil {
        fetchArtworkAsync(for: winner, directURL: resolvedURL, generation: currentGen)
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
    if summary != .empty { summary = .empty }
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

  /// Whether the MediaRemote bridge already has a fresh playing state, in which
  /// case probing browsers again only burns CPU.
  var hasValidBridgePlaying: Bool {
    let now = Date().timeIntervalSince1970
    return candidateRegistry.values.contains {
      // Browsers are excluded: tab Position/control for those still lives in the
      // web probe, so skipping it would leave the active tab stale (pause a
      // video in the wrong tab or none at all).
      $0.awareness == .mediaRemote && $0.isPlaying && $0.hasMetadata
        && now - $0.lastUpdated <= 10 && !Self.isBrowserBundleID($0.app.bundleID)
    }
  }

  /// Adaptive polling cadence: fast while something may be changing, slow when idle.
  var nextPollInterval: TimeInterval {
    if isPlaying || hasValidBridgePlaying || Date().timeIntervalSince(lastInteractionAt) < 10 {
      return 4
    }
    if hasActiveTrack || presentation != nil || !cachedBrowsers.isEmpty {
      return 15
    }
    return 30
  }

  func scheduleNextPoll(after delay: TimeInterval? = nil) {
    pollWorkItem?.cancel()
    cachedBrowsers = runningBrowsers()
    let interval = delay ?? nextPollInterval
    let item = DispatchWorkItem { [weak self] in
      self?.pollCurrentMediaState()
    }
    pollWorkItem = item
    DispatchQueue.main.asyncAfter(deadline: .now() + interval, execute: item)
  }

  func pollSoon(after delay: TimeInterval = 0.35) {
    lastInteractionAt = Date()
    scheduleNextPoll(after: delay)
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

    let targetBundle = targetBundleID ?? currentIdentity?.bundleID ?? presentation?.app.bundleID
    if let bundleID = targetBundle, Self.isBrowserBundleID(bundleID) {
      let browserName = BrowserCatalog.entry(forBundleID: bundleID)?.name
      sendWebCommand(wasPlaying ? WebMediaScripts.pauseJS() : WebMediaScripts.playJS(), preferredBrowser: browserName)
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

    let targetBundle = targetBundleID ?? currentIdentity?.bundleID ?? presentation?.app.bundleID
    if let bundleID = targetBundle, Self.isBrowserBundleID(bundleID) {
      let browserName = BrowserCatalog.entry(forBundleID: bundleID)?.name
      sendWebCommand(WebMediaScripts.nextJS(), preferredBrowser: browserName)
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

    let targetBundle = targetBundleID ?? currentIdentity?.bundleID ?? presentation?.app.bundleID
    if let bundleID = targetBundle, Self.isBrowserBundleID(bundleID) {
      let browserName = BrowserCatalog.entry(forBundleID: bundleID)?.name
      sendWebCommand(WebMediaScripts.previousJS(), preferredBrowser: browserName)
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

    let targetBundle = targetBundleID ?? currentIdentity?.bundleID ?? presentation?.app.bundleID
    if let bundleID = targetBundle, Self.isBrowserBundleID(bundleID) {
      let browserName = BrowserCatalog.entry(forBundleID: bundleID)?.name
      sendWebCommand(WebMediaScripts.seekJS(to: position), preferredBrowser: browserName)
      return
    }

    sendBridge(.seek(position: position), target: targetBundleID) { [weak self] in
      self?.fallbackSeek(position, targetBundleID: targetBundleID)
    }
  }
}

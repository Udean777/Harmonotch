import Combine
import Foundation

extension MediaManager {
  // MARK: - Distributed Notifications

  func setupDistributedNotificationObservers() {
    let center = DistributedNotificationCenter.default()

    center.addObserver(
      forName: .spotifyPlaybackStateChanged,
      object: nil,
      queue: .main
    ) { [weak self] notification in
      self?.handleSpotifyNotification(notification)
    }

    center.addObserver(
      forName: .appleMusicPlayerInfo,
      object: nil,
      queue: .main
    ) { [weak self] notification in
      self?.handleAppleMusicNotification(notification)
    }
  }

  func setupAudioPresenceSubscription() {
    AudioProcessPresenceMonitor.shared.$activeApps
      .receive(on: DispatchQueue.main)
      .sink { [weak self] apps in
        self?.handleAudioPresenceApps(apps)
      }
      .store(in: &cancellables)
    if includeOtherAudioApps {
      AudioProcessPresenceMonitor.shared.start()
    }
  }

  func handleAudioPresenceApps(_ apps: [MediaAppInfo]) {
    dispatchPrecondition(condition: .onQueue(.main))
    guard includeOtherAudioApps else {
      for (identity, candidate) in candidateRegistry where candidate.awareness == .presence {
        candidateRegistry.removeValue(forKey: identity)
      }
      reconcile()
      return
    }

    let currentAppBundleIDs = Set(apps.map { $0.bundleID })

    for app in apps {
      // If candidateRegistry already has a candidate with metadata for this app, don't shadow with audioOnly
      let hasRichMeta = candidateRegistry.values.contains { $0.app.bundleID == app.bundleID && $0.hasMetadata }
      if hasRichMeta { continue }

      let identity = MediaIdentity(bundleID: app.bundleID)
      let candidate = MediaCandidate(
        identity: identity,
        app: app,
        isPlaying: true,
        hasMetadata: false,
        awareness: .presence,
        capabilities: .audioOnlyDefault
      )
      ingest(candidate: candidate)
    }

    for (identity, candidate) in candidateRegistry where candidate.awareness == .presence {
      if !currentAppBundleIDs.contains(identity.bundleID) {
        candidateRegistry.removeValue(forKey: identity)
      }
    }
    reconcile()
  }

  func extractDouble(from value: Any?) -> Double? {
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

  func handleSpotifyNotification(_ notification: Notification) {
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
    traceProducer(producer: "SpotifyNotification", source: .spotify, title: title, isPlaying: isNowPlaying, details: "artist='\(artist)'")

    let identity = MediaIdentity(bundleID: "com.spotify.client", contentID: "\(title)|\(artist)")
    let candidate = MediaCandidate(
      identity: identity,
      app: MediaAppInfo.resolve(bundleID: "com.spotify.client"),
      title: title,
      artist: artist,
      album: album,
      duration: durationMs / 1000.0,
      position: positionSec,
      isPlaying: isNowPlaying,
      isMusicApp: true,
      awareness: .mediaRemote,
      capabilities: .standardPlayer
    )
    ingest(candidate: candidate)
  }

  func handleAppleMusicNotification(_ notification: Notification) {
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
    traceProducer(producer: "AppleMusicNotification", source: .appleMusic, title: title, isPlaying: isNowPlaying, details: "artist='\(artist)'")

    let identity = MediaIdentity(bundleID: "com.apple.Music", contentID: "\(title)|\(artist)")
    let candidate = MediaCandidate(
      identity: identity,
      app: MediaAppInfo.resolve(bundleID: "com.apple.Music"),
      title: title,
      artist: artist,
      album: album,
      duration: totalTimeMs / 1000.0,
      position: positionSec,
      isPlaying: isNowPlaying,
      isMusicApp: true,
      awareness: .mediaRemote,
      capabilities: .standardPlayer
    )
    ingest(candidate: candidate)
  }

  // MARK: - MediaRemote bridge

  func handleNowPlayingState(_ state: NowPlayingState) {
    // Called on the bridge queue, so base64 decoding stays off the main thread.
    let artworkData = state.artwork.flatMap { Data(base64Encoded: $0) }
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      guard !state.title.isEmpty else {
        // Empty state line from adapter
        if !state.playing {
          let bundleID = state.source.isEmpty ? "com.apple.NowPlaying" : state.source
          for (id, cand) in self.candidateRegistry where cand.app.bundleID == bundleID && cand.awareness == .mediaRemote {
            self.candidateRegistry.removeValue(forKey: id)
          }
          if let sys = self.systemIdentity, sys.bundleID == bundleID {
            self.systemIdentity = nil
          }
          self.reconcile()
        }
        return
      }

      let bundleID = state.source.isEmpty ? "com.apple.NowPlaying" : state.source
      let identity = MediaIdentity(
        bundleID: bundleID,
        contentID: state.contentID.isEmpty ? "\(state.title)|\(state.artist)" : state.contentID
      )
      let appInfo = MediaAppInfo.resolve(bundleID: bundleID)
      let artworkSource = artworkData.map { MediaArtworkSource.data($0) }

      self.traceProducer(
        producer: "NowPlayingBridge",
        source: Self.mediaSource(for: bundleID),
        title: state.title,
        isPlaying: state.playing,
        details: "artist='\(state.artist)' bundleID='\(bundleID)'"
      )

      let candidate = MediaCandidate(
        identity: identity,
        app: appInfo,
        title: state.title,
        artist: state.artist,
        album: state.album,
        duration: state.duration,
        position: state.elapsed,
        isPlaying: state.playing,
        artwork: artworkSource,
        awareness: .mediaRemote,
        capabilities: .standardPlayer
      )
      // One mediaRemote candidate per app: drop siblings so a stale playing entry cannot linger.
      for (existingID, existingCand) in self.candidateRegistry
      where existingCand.awareness == .mediaRemote
        && existingCand.app.bundleID == bundleID
        && existingID != identity {
        self.candidateRegistry.removeValue(forKey: existingID)
      }

      // Only a playing client can be the system's current player; paused clients
      // are still enumerated and would otherwise win the paused tie-break.
      if state.playing {
        self.systemIdentity = identity
      } else if let sys = self.systemIdentity, sys.bundleID == bundleID {
        self.systemIdentity = nil
      }
      self.ingest(candidate: candidate)
    }
  }
}

extension Notification.Name {
  static let spotifyPlaybackStateChanged = Notification.Name("com.spotify.client.PlaybackStateChanged")
  static let appleMusicPlayerInfo = Notification.Name("com.apple.Music.playerInfo")
}

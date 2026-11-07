import AppKit
import Foundation

extension MediaManager {
  func pollCurrentMediaState() {
    guard !isPollInFlight else { return }
    isPollInFlight = true
    // Skip AppleScript polling while a music app plays through the bridge; web polling still runs otherwise.
    let isMusicAppPlaying = isPlaying && (mediaSource == .spotify || mediaSource == .appleMusic)
    let bridgeValid = hasValidBridgePlaying
    let cachedBrowserList = cachedBrowsers

    AppleScriptRunner.queue.async { [weak self] in
      guard let self = self else {
        DispatchQueue.main.async { [weak self] in
          self?.isPollInFlight = false
          self?.scheduleNextPoll()
        }
        return
      }
      self.localPollPlaying = false
      let localHasTrack =
        self.pollSpotifyState() || self.pollAppleMusicState() || self.pollQuickTimeState()
      // When a local music player is actively playing, web polling is deferred to save CPU
      if isMusicAppPlaying && self.localPollPlaying {
        DispatchQueue.main.async { [weak self] in
          self?.isPollInFlight = false
          self?.reconcile()
          self?.scheduleNextPoll()
        }
        return
      }
      // A fresh bridge state already tells us what is playing; probing tabs is pure cost.
      if !bridgeValid {
        self.pollWebMediaState(localHasTrack: localHasTrack, browsers: cachedBrowserList)
      }
      // Re-run arbitration even when every poll is empty, so a dead client's
      // last playing state cannot stay on screen.
      DispatchQueue.main.async { [weak self] in
        self?.isPollInFlight = false
        self?.reconcile()
        self?.scheduleNextPoll()
      }
    }
  }

  /// Must run on `AppleScriptRunner.queue`. Drops script candidates for an app that is gone.
  func removeScriptCandidates(bundleID: String) {
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      var removed = false
      for (identity, candidate) in self.candidateRegistry
      where candidate.awareness == .script && candidate.app.bundleID == bundleID {
        self.candidateRegistry.removeValue(forKey: identity)
        removed = true
      }
      if removed { self.reconcile() }
    }
  }

  /// Must run on `AppleScriptRunner.queue`. Marks a script-only app as paused instead of
  /// leaving its last playing state stuck in the registry forever.
  func markScriptCandidatesPaused(bundleID: String) {
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      var changed = false
      for (identity, candidate) in self.candidateRegistry
      where candidate.awareness == .script && candidate.app.bundleID == bundleID
        && candidate.isPlaying {
        var paused = candidate
        paused.isPlaying = false
        paused.lastUpdated = Date().timeIntervalSince1970
        self.candidateRegistry[identity] = paused
        changed = true
      }
      if changed { self.reconcile() }
    }
  }

  func pollSpotifyState() -> Bool {
    guard
      !NSRunningApplication.runningApplications(withBundleIdentifier: "com.spotify.client").isEmpty
    else {
      removeScriptCandidates(bundleID: "com.spotify.client")
      return false
    }
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

    guard let result = AppleScriptRunner.execute(spotifyScript), !result.isEmpty else { return false }
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

    let identity = MediaIdentity(bundleID: "com.spotify.client", contentID: "\(title)|\(artist)")
    let candidate = MediaCandidate(
      identity: identity,
      app: MediaAppInfo.resolve(bundleID: "com.spotify.client"),
      title: title,
      artist: artist,
      album: album,
      duration: duration,
      position: pos,
      isPlaying: isPlaying,
      isMusicApp: true,
      awareness: .script,
      capabilities: .standardPlayer
    )
    ingest(candidate: candidate)
    return true
  }

  func pollAppleMusicState() -> Bool {
    guard !NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Music").isEmpty
    else {
      removeScriptCandidates(bundleID: "com.apple.Music")
      return false
    }
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

    guard let result = AppleScriptRunner.execute(musicScript), !result.isEmpty else { return false }
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

    let identity = MediaIdentity(bundleID: "com.apple.Music", contentID: "\(title)|\(artist)")
    let candidate = MediaCandidate(
      identity: identity,
      app: MediaAppInfo.resolve(bundleID: "com.apple.Music"),
      title: title,
      artist: artist,
      album: album,
      duration: duration,
      position: pos,
      isPlaying: isPlaying,
      isMusicApp: true,
      awareness: .script,
      capabilities: .standardPlayer
    )
    ingest(candidate: candidate)
    return true
  }

  func pollQuickTimeState() -> Bool {
    guard
      !NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.QuickTimePlayerX")
        .isEmpty
    else {
      removeScriptCandidates(bundleID: "com.apple.QuickTimePlayerX")
      return false
    }
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

    guard let res = AppleScriptRunner.execute(qtScript), !res.isEmpty else {
      markScriptCandidatesPaused(bundleID: "com.apple.QuickTimePlayerX")
      return false
    }
    let parts = res.components(separatedBy: "|||")
    guard parts.count >= 3 else { return false }
    let name = parts[0]
    let pos = extractDouble(from: parts[1]) ?? 0
    let dur = extractDouble(from: parts[2]) ?? 0
    localPollPlaying = true

    let identity = MediaIdentity(bundleID: "com.apple.QuickTimePlayerX", contentID: "quicktime:\(name)")
    let candidate = MediaCandidate(
      identity: identity,
      app: MediaAppInfo.resolve(bundleID: "com.apple.QuickTimePlayerX"),
      title: name,
      artist: "QuickTime",
      album: "",
      duration: dur,
      position: pos,
      isPlaying: true,
      isMusicApp: false,
      awareness: .script,
      capabilities: .standardPlayer
    )
    ingest(candidate: candidate)
    return true
  }

  func fallbackPlayPause(wasPlaying: Bool, targetBundleID: String?) {
    guard let bundleID = targetBundleID ?? currentIdentity?.bundleID else { return }
    if bundleID == "com.spotify.client" {
      AppleScriptRunner.executeAsync("tell application id \"com.spotify.client\" to playpause")
    } else if bundleID == "com.apple.Music" {
      AppleScriptRunner.executeAsync("tell application id \"com.apple.Music\" to playpause")
    } else if bundleID == "com.apple.QuickTimePlayerX" {
      AppleScriptRunner.executeAsync("tell application \"QuickTime Player\" to playpause document 1")
    } else if Self.isBrowserBundleID(bundleID) {
      let browserName = BrowserCatalog.entry(forBundleID: bundleID)?.name
      sendWebCommand(wasPlaying ? WebMediaScripts.pauseJS() : WebMediaScripts.playJS(), preferredBrowser: browserName)
    }
  }

  func fallbackNext(targetBundleID: String?) {
    guard let bundleID = targetBundleID ?? currentIdentity?.bundleID else { return }
    if bundleID == "com.spotify.client" {
      AppleScriptRunner.executeAsync("tell application id \"com.spotify.client\" to next track")
    } else if bundleID == "com.apple.Music" {
      AppleScriptRunner.executeAsync("tell application id \"com.apple.Music\" to next track")
    } else if Self.isBrowserBundleID(bundleID) {
      let browserName = BrowserCatalog.entry(forBundleID: bundleID)?.name
      sendWebCommand(WebMediaScripts.nextJS(), preferredBrowser: browserName)
    }
  }

  func fallbackPrevious(targetBundleID: String?) {
    guard let bundleID = targetBundleID ?? currentIdentity?.bundleID else { return }
    if bundleID == "com.spotify.client" {
      AppleScriptRunner.executeAsync("tell application id \"com.spotify.client\" to previous track")
    } else if bundleID == "com.apple.Music" {
      AppleScriptRunner.executeAsync("tell application id \"com.apple.Music\" to previous track")
    } else if Self.isBrowserBundleID(bundleID) {
      let browserName = BrowserCatalog.entry(forBundleID: bundleID)?.name
      sendWebCommand(WebMediaScripts.previousJS(), preferredBrowser: browserName)
    }
  }

  func fallbackSeek(_ position: TimeInterval, targetBundleID: String?) {
    guard let bundleID = targetBundleID ?? currentIdentity?.bundleID else { return }
    if bundleID == "com.spotify.client" {
      AppleScriptRunner.executeAsync(
        "tell application id \"com.spotify.client\" to set player position to \(Int(position))")
    } else if bundleID == "com.apple.Music" {
      AppleScriptRunner.executeAsync(
        "tell application id \"com.apple.Music\" to set player position to \(Int(position))")
    } else if Self.isBrowserBundleID(bundleID) {
      let browserName = BrowserCatalog.entry(forBundleID: bundleID)?.name
      sendWebCommand(WebMediaScripts.seekJS(to: position), preferredBrowser: browserName)
    }
  }
}

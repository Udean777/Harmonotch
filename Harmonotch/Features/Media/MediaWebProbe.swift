import AppKit
import Foundation

struct ParsedWebMedia {
  let title: String
  let artist: String
  let source: MediaSource
  let videoId: String?
}

extension MediaManager {
  func isRunning(_ bundleIDs: [String]) -> Bool {
    bundleIDs.contains {
      !NSRunningApplication.runningApplications(withBundleIdentifier: $0).isEmpty
    }
  }

  /// Must run on `AppleScriptRunner.queue`. Reads every media tab of every running browser,
  /// then follows the tab that is really playing.
  func pollWebMediaState(localHasTrack: Bool) {
    let browsers = runningBrowsers()

    guard !browsers.isEmpty else {
      setWebHint(nil)
      if !localHasTrack {
        resetWebMediaState()
      }
      return
    }

    let (snapshots, hint) = probeWebSnapshots(browsers)

    guard let chosen = WebMediaParser.pick(from: snapshots, preferredURL: activeWebTarget?.url)
    else {
      setWebHint(hint)
      if !localHasTrack {
        resetWebMediaState()
      }
      return
    }
    setWebHint(nil)

    // A paused tab must not hide a paused local player that has a track.
    guard !chosen.isPaused || !localHasTrack else { return }
    applyWebSnapshot(chosen)
  }

  func runningBrowsers() -> [String] {
    BrowserCatalog.scriptableEntries
      .filter { isRunning($0.bundleIDs) }
      .map(\.name)
  }

  /// Must run on `AppleScriptRunner.queue`.
  func probeWebSnapshots(_ browsers: [String])
    -> ([WebMediaSnapshot], WebMediaProbeError?)
  {
    var snapshots: [WebMediaSnapshot] = []
    var hint: WebMediaProbeError?
    for browser in browsers {
      guard let output = AppleScriptRunner.execute(WebMediaScripts.probe(browser: browser)) else {
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

  func setWebHint(_ hint: WebMediaProbeError?) {
    DispatchQueue.main.async { [weak self] in
      if self?.webMediaHint != hint { self?.webMediaHint = hint }
    }
  }

  func bundleID(forBrowser browserName: String) -> String {
    BrowserCatalog.primaryBundleID(forBrowserName: browserName)
  }

  func resetWebMediaState() {
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      self.activeWebTarget = nil
      self.lastDetectedRawWebTitle = ""
      for (identity, candidate) in self.candidateRegistry
      where candidate.awareness == .script && BrowserCatalog.isBrowser(bundleID: identity.bundleID) {
        self.candidateRegistry.removeValue(forKey: identity)
      }
      self.reconcile()
    }
  }

  func applyWebSnapshot(_ snapshot: WebMediaSnapshot) {
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

    let bID = bundleID(forBrowser: snapshot.browser)
    let identity = MediaIdentity(
      bundleID: bID,
      contentID: snapshot.url.isEmpty ? videoId : snapshot.url
    )
    let appInfo = MediaAppInfo.resolve(bundleID: bID, preferredName: snapshot.browser)

    let candidate = MediaCandidate(
      identity: identity,
      app: appInfo,
      title: title,
      artist: artist,
      album: "",
      duration: snapshot.duration,
      position: snapshot.currentTime,
      isPlaying: isPlaying,
      isMusicApp: false,
      artwork: artworkURL.map { .url($0) },
      awareness: .script,
      capabilities: .standardPlayer
    )

    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      self.traceProducer(
        producer: "WebSnapshot",
        source: source,
        title: title,
        isPlaying: isPlaying,
        details: "artist='\(artist)' browser='\(snapshot.browser)' url='\(snapshot.url)'"
      )
      self.activeWebTarget = snapshot
      self.ingest(candidate: candidate)
    }
  }

  func parseWebMedia(title: String, url: String) -> ParsedWebMedia? {
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
  func sendWebCommand(_ js: String) {
    AppleScriptRunner.queue.async { [weak self] in
      guard let self = self else { return }
      // The bridge may have been the source, so the tab was never recorded here.
      if self.activeWebTarget == nil {
        let snapshots = self.probeWebSnapshots(self.runningBrowsers()).0
        self.activeWebTarget = WebMediaParser.pick(from: snapshots)
      }
      guard let target = self.activeWebTarget else { return }
      let script = WebMediaScripts.control(browser: target.browser, url: target.url, js: js)
      guard let output = AppleScriptRunner.execute(script) else {
        self.setWebHint(.automationDenied(browser: target.browser))
        return
      }
      if let error = WebMediaParser.error(from: output, browser: target.browser) {
        self.setWebHint(error)
      }
    }
  }
}

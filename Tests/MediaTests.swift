import Foundation

func runMediaTests() {
  // MARK: - LRC

  let lrc = """
    [ar:Artist]
    [00:12.50]First line
    [00:05.00][01:05.00]Repeated
    [00:20.00]
    """
  let lyrics = LRCParser.parse(lrc)
  checkEqual(lyrics.count, 3, "LRC line count")
  checkEqual(lyrics[0].text, "Repeated", "LRC sorted first")
  checkEqual(lyrics[0].time, 5.0, "LRC timestamp")
  checkEqual(lyrics[1].time, 12.5, "LRC second timestamp")
  checkEqual(lyrics[2].time, 65.0, "LRC repeated timestamp")
  checkEqual(LRCParser.parse("[00:01.00]").count, 0, "empty text is skipped")
  checkEqual(LRCParser.parse("not lrc").count, 0, "plain text is skipped")

  // MARK: - Lyrics Sync Validation & Status
  let zeroLrc = "[00:00.00]Line one\n[00:00.00]Line two"
  let parsedZero = LRCParser.parse(zeroLrc)
  let hasDistinct =
    parsedZero.count > 1 && (parsedZero.last?.time ?? 0) > (parsedZero.first?.time ?? 0)
  checkEqual(hasDistinct, false, "zero timestamp LRC is not treated as synced")

  let realLrc = "[00:04.50]Line one\n[00:10.20]Line two"
  let parsedReal = LRCParser.parse(realLrc)
  let hasRealTimestamps =
    parsedReal.count > 1 && (parsedReal.last?.time ?? 0) > (parsedReal.first?.time ?? 0)
  checkEqual(hasRealTimestamps, true, "valid LRC has distinct timestamps")
  checkEqual(
    LyricsStatus.unavailable("none") == LyricsStatus.unavailable("none"), true,
    "LyricsStatus equality")

  // MARK: - Web media

  let paused =
    "1\t2\thttps://www.youtube.com/watch?v=aaaaaaaaaaa\t{\"paused\":true,\"t\":12.5,\"d\":200,\"title\":\"First\",\"artist\":\"A\",\"art\":\"\"}\n"
  let playing =
    "1\t3\thttps://www.youtube.com/watch?v=bbbbbbbbbbb\t{\"paused\":false,\"t\":3,\"d\":180,\"title\":\"Second\",\"artist\":\"B\",\"art\":\"https://x/y.jpg\"}\n"
  let tabs = WebMediaParser.parse(output: paused + playing, browser: "Safari")
  checkEqual(tabs.count, 2, "parses both tabs")
  checkEqual(tabs[1].tabIndex, 3, "tab index parsed")
  checkEqual(tabs[1].artworkURL, "https://x/y.jpg", "artwork parsed")
  checkEqual(WebMediaParser.pick(from: tabs)?.title, "Second", "playing tab beats first tab")
  checkEqual(
    WebMediaParser.pick(from: [tabs[0]], preferredURL: nil)?.title, "First",
    "paused tab with progress is picked")
  checkEqual(
    WebMediaParser.pick(from: [tabs[0], tabs[0]], preferredURL: tabs[0].url)?.title, "First",
    "preferred paused tab kept")

  check(WebMediaParser.parse(output: "", browser: "Safari").isEmpty, "empty output")
  check(
    WebMediaParser.parse(output: "garbage\n1\t2\turl\tnot json\n", browser: "Safari").isEmpty,
    "broken lines skipped")

  let live = WebMediaParser.parse(
    output:
      "1\t1\thttps://www.youtube.com/watch?v=ccccccccccc\t{\"paused\":false,\"t\":5,\"d\":0,\"title\":\"Live\",\"artist\":\"\",\"art\":\"\"}",
    browser: "Safari")
  checkEqual(live.first?.duration, 0, "live stream has zero duration")

  checkEqual(
    WebMediaParser.error(from: "ERR\t-1743\tnot allowed", browser: "Safari"),
    .automationDenied(browser: "Safari"), "automation denied")
  checkEqual(
    WebMediaParser.error(
      from: "ERR\t8\tYou must enable the 'Allow JavaScript from Apple Events' option",
      browser: "Safari"),
    .javascriptDisabled(browser: "Safari"), "javascript disabled")
  check(
    WebMediaParser.error(from: "ERR\t5\tother", browser: "Safari") == nil,
    "unrelated error ignored")

  // MARK: - Now-playing bridge

  func decodeNowPlayingEvent(_ json: String) -> NowPlayingEvent? {
    try? JSONDecoder().decode(NowPlayingEvent.self, from: Data(json.utf8))
  }

  let nowPlayingJSON = """
    {"event":"state","source":"com.spotify.client","title":"Track","artist":"Artist","album":"Album","duration":215.4,"elapsed":42.1,"rate":1.0,"playing":true,"contentID":"abc"}
    """
  if case .state(let state)? = decodeNowPlayingEvent(nowPlayingJSON) {
    checkEqual(state.title, "Track", "now-playing title")
    checkEqual(state.artist, "Artist", "now-playing artist")
    checkEqual(state.duration, 215.4, "now-playing duration")
    checkEqual(state.elapsed, 42.1, "now-playing elapsed")
    checkEqual(state.playing, true, "now-playing playing")
    checkEqual(state.sourceKind, .spotify, "now-playing source")
    check(state.artwork == nil, "now-playing artwork absent")
  } else {
    check(false, "now-playing state decodes")
  }

  let artworkJSON = """
    {"event":"state","source":"com.google.Chrome","title":"Track","artist":"","album":"","duration":0,"elapsed":0,"rate":0,"playing":false,"contentID":"abc","artwork":"AAEC"}
    """
  if case .state(let state)? = decodeNowPlayingEvent(artworkJSON) {
    checkEqual(state.artwork, "AAEC", "now-playing artwork decoded")
    checkEqual(state.sourceKind, .web, "chromium maps to web")
  } else {
    check(false, "now-playing state with artwork decodes")
  }

  // NowPlayingCommand
  checkEqual(NowPlayingCommand.play.commandName, "play", "play command name")
  checkEqual(NowPlayingCommand.seek(position: 42.5).position, 42.5, "seek command position")
  let testCmdMsg = NowPlayingCommandMessage(id: "test-id-123", command: .seek(position: 10.0))
  checkEqual(testCmdMsg.id, "test-id-123", "command message id")
  checkEqual(testCmdMsg.cmd, "seek", "command message cmd")
  checkEqual(testCmdMsg.position, 10.0, "command message position")

  // MARK: - MediaAppInfo Tests

  let spotifyApp = MediaAppInfo.resolve(bundleID: "com.spotify.client")
  checkEqual(spotifyApp.displayName, "Spotify", "Spotify display name")
  checkEqual(spotifyApp.category, .music, "Spotify category")
  checkEqual(spotifyApp.iconSymbolName, "waveform", "Spotify icon symbol")

  let zoomApp = MediaAppInfo.resolve(bundleID: "us.zoom.xos")
  checkEqual(zoomApp.displayName, "Zoom", "Zoom display name")
  checkEqual(zoomApp.category, .call, "Zoom category")
  checkEqual(zoomApp.iconSymbolName, "phone.fill", "Zoom icon symbol")

  let safariApp = MediaAppInfo.resolve(bundleID: "com.apple.Safari")
  checkEqual(safariApp.displayName, "Safari", "Safari display name")
  checkEqual(safariApp.category, .video, "Safari category")

  let genericApp = MediaAppInfo.resolve(
    bundleID: "com.example.customgame", preferredName: "Cool Game")
  checkEqual(genericApp.displayName, "Cool Game", "Generic app preferred name")
  checkEqual(genericApp.category, .general, "Generic app category")

  // MARK: - AudioProcessResolver Tests

  let testSelfPID: pid_t = 99999
  let daemonPID: pid_t = 120
  let safariPID: pid_t = 1000
  let webkitHelperPID: pid_t = 1002
  let chromePID: pid_t = 2000
  let chromeHelperPID: pid_t = 2002

  let mockParentTree: [pid_t: pid_t] = [
    webkitHelperPID: safariPID,
    safariPID: 1,
    chromeHelperPID: chromePID,
    chromePID: 1,
    daemonPID: 1,
  ]

  let mockAppDatabase: [pid_t: (bundleID: String, name: String, isAppBundle: Bool)] = [
    safariPID: ("com.apple.Safari", "Safari", true),
    webkitHelperPID: ("com.apple.WebKit.GPU", "com.apple.WebKit.GPU", false),
    chromePID: ("com.google.Chrome", "Google Chrome", true),
    chromeHelperPID: ("com.google.Chrome.helper", "Google Chrome Helper", false),
    daemonPID: ("com.apple.audio.coreaudiod", "coreaudiod", false),
    testSelfPID: ("com.harmonotch.Harmonotch", "Harmonotch", true),
  ]

  let parentLookup: (pid_t) -> pid_t? = { mockParentTree[$0] }
  let appLookup: (pid_t) -> (bundleID: String, name: String, isAppBundle: Bool)? = {
    mockAppDatabase[$0]
  }

  let selfResolved = AudioProcessResolver.resolveResponsibleApp(
    pid: testSelfPID,
    currentPID: testSelfPID,
    parentLookup: parentLookup,
    appLookup: appLookup
  )
  check(selfResolved == nil, "Self PID must be excluded from audio process resolution")

  let daemonResolved = AudioProcessResolver.resolveResponsibleApp(
    pid: daemonPID,
    currentPID: testSelfPID,
    parentLookup: parentLookup,
    appLookup: appLookup
  )
  check(daemonResolved == nil, "Audio system daemon must be excluded")

  let webkitResolved = AudioProcessResolver.resolveResponsibleApp(
    pid: webkitHelperPID,
    reportedBundleID: "com.apple.WebKit.GPU",
    currentPID: testSelfPID,
    parentLookup: parentLookup,
    appLookup: appLookup
  )
  check(webkitResolved != nil, "WebKit helper must resolve to an app")
  checkEqual(
    webkitResolved?.bundleID, "com.apple.Safari", "WebKit helper bundle resolved to Safari")
  checkEqual(
    webkitResolved?.displayName, "Safari", "WebKit helper name resolved to Safari")

  let chromeResolved = AudioProcessResolver.resolveResponsibleApp(
    pid: chromeHelperPID,
    reportedBundleID: "com.google.Chrome.helper",
    currentPID: testSelfPID,
    parentLookup: parentLookup,
    appLookup: appLookup
  )
  checkEqual(
    chromeResolved?.bundleID, "com.google.Chrome", "Chromium helper resolved to Google Chrome")

  let directSafariResolved = AudioProcessResolver.resolveResponsibleApp(
    pid: safariPID,
    reportedBundleID: "com.apple.Safari",
    currentPID: testSelfPID,
    parentLookup: parentLookup,
    appLookup: appLookup
  )
  checkEqual(directSafariResolved?.bundleID, "com.apple.Safari", "Direct app resolves cleanly")

  // MARK: - AudioProcessPresenceTracker Tests

  var tracker = AudioProcessPresenceTracker(
    startDebounceInterval: 1.5, stopHysteresisInterval: 3.0)
  let baseTime = Date(timeIntervalSince1970: 1000)

  var active = tracker.update(detectedPIDs: [500], now: baseTime)
  check(active.isEmpty, "t=0: candidate must not be active immediately")

  active = tracker.update(detectedPIDs: [500], now: baseTime.addingTimeInterval(1.0))
  check(active.isEmpty, "t=1.0s: candidate still in debounce window")

  active = tracker.update(detectedPIDs: [500], now: baseTime.addingTimeInterval(1.6))
  checkEqual(
    active.contains(500), true, "t=1.6s: candidate confirmed active after 1.5s debounce")

  active = tracker.update(detectedPIDs: [], now: baseTime.addingTimeInterval(2.0))
  checkEqual(active.contains(500), true, "t=2.0s: candidate retained during hysteresis")

  active = tracker.update(detectedPIDs: [], now: baseTime.addingTimeInterval(4.5))
  checkEqual(
    active.contains(500), true, "t=4.5s: candidate retained at 2.9s after last output")

  active = tracker.update(detectedPIDs: [], now: baseTime.addingTimeInterval(4.7))
  checkEqual(
    active.contains(500), false, "t=4.7s: candidate removed after 3.0s hysteresis expires")

  var transientTracker = AudioProcessPresenceTracker(
    startDebounceInterval: 1.5, stopHysteresisInterval: 3.0)
  _ = transientTracker.update(detectedPIDs: [700], now: baseTime)
  _ = transientTracker.update(detectedPIDs: [700], now: baseTime.addingTimeInterval(0.4))
  let transientResult = transientTracker.update(
    detectedPIDs: [], now: baseTime.addingTimeInterval(2.0))
  check(transientResult.isEmpty, "Short audio burst (<1.5s) never becomes active")

  // MARK: - BrowserCatalog (Fase 3.8)

  checkEqual(BrowserCatalog.isSafari(bundleID: "com.apple.Safari"), true, "Safari isSafari")
  checkEqual(
    BrowserCatalog.isSafari(bundleID: "com.apple.WebKit.WebContent"), true,
    "WebKit.WebContent isSafari")
  checkEqual(BrowserCatalog.isSafari(bundleID: "com.google.Chrome"), false, "Chrome is not Safari")
  checkEqual(BrowserCatalog.isBrowser(bundleID: "company.thebrowser.Browser"), true, "Arc isBrowser")
  checkEqual(BrowserCatalog.isBrowser(bundleID: "org.mozilla.firefox"), true, "Firefox isBrowser")
  checkEqual(
    BrowserCatalog.isBrowser(bundleID: "com.spotify.client"), false, "Spotify is not browser")
  checkEqual(BrowserCatalog.scriptKind(forBrowserName: "Safari"), .safari, "Safari scriptKind")
  checkEqual(
    BrowserCatalog.scriptKind(forBrowserName: "Google Chrome"), .chromium, "Chrome scriptKind")
  checkEqual(
    BrowserCatalog.primaryBundleID(forBrowserName: "Arc"), "company.thebrowser.Browser",
    "Arc primaryBundleID")

  // MARK: - Bounded lyrics cache

  let cache = LyricsCache(capacity: 2)
  cache["a"] = (
    status: .unavailable("a"), synced: [], unsynced: [], isInstrumental: false, duration: 1
  )
  cache["b"] = (
    status: .unavailable("b"), synced: [], unsynced: [], isInstrumental: false, duration: 2
  )
  check(cache["a"] != nil, "LRU keeps recently used entry")
  cache["c"] = (
    status: .unavailable("c"), synced: [], unsynced: [], isInstrumental: false, duration: 3
  )
  check(cache["b"] == nil, "LRU evicts least recently used entry")
  check(cache["a"] != nil && cache["c"] != nil, "LRU keeps touched and new entries")

  // MARK: - Candidate registry pruning

  func candidate(bundle: String, title: String, updated: TimeInterval) -> MediaCandidate {
    MediaCandidate(
      identity: MediaIdentity(bundleID: bundle, contentID: title),
      app: MediaAppInfo.resolve(bundleID: bundle),
      title: title,
      artist: "Artist",
      lastUpdated: updated
    )
  }

  let now = TimeInterval(1_000)
  let registry: [MediaIdentity: MediaCandidate] = [
    MediaIdentity(bundleID: "com.app.a", contentID: "old"): candidate(
      bundle: "com.app.a", title: "old", updated: 0),
    MediaIdentity(bundleID: "com.app.b", contentID: "fresh"): candidate(
      bundle: "com.app.b", title: "fresh", updated: 950),
    MediaIdentity(bundleID: "com.app.c", contentID: "current"): candidate(
      bundle: "com.app.c", title: "current", updated: 0),
  ]
  let pruned = MediaManager.prunedCandidateRegistry(
    registry, keeping: MediaIdentity(bundleID: "com.app.c", contentID: "current"),
    now: now, maxAge: 120, limit: 20)
  check(pruned[MediaIdentity(bundleID: "com.app.a", contentID: "old")] == nil, "prune drops stale entry")
  check(pruned[MediaIdentity(bundleID: "com.app.b", contentID: "fresh")] != nil, "prune keeps fresh entry")
  check(
    pruned[MediaIdentity(bundleID: "com.app.c", contentID: "current")] != nil,
    "prune keeps current winner")

  var big: [MediaIdentity: MediaCandidate] = [:]
  for i in 0..<30 {
    let id = MediaIdentity(bundleID: "com.app.x", contentID: "t\(i)")
    big[id] = candidate(bundle: "com.app.x", title: "t\(i)", updated: TimeInterval(900 + i))
  }
  let capped = MediaManager.prunedCandidateRegistry(
    big, keeping: MediaIdentity(bundleID: "com.app.x", contentID: "t29"),
    now: now, maxAge: 1_000, limit: 20)
  checkEqual(capped.count, 20, "prune caps registry size")
  check(capped[MediaIdentity(bundleID: "com.app.x", contentID: "t29")] != nil, "prune cap keeps newest winner")
}

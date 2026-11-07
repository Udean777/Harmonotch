import Foundation

func runMediaSelectionTests() {
  // MARK: - MediaSelector & Presentation Tests

  let spotifyCandidate = MediaCandidate(
    identity: MediaIdentity(bundleID: "com.spotify.client", contentID: "spotify:track:123"),
    app: MediaAppInfo.resolve(bundleID: "com.spotify.client"),
    title: "Song A",
    artist: "Artist A",
    album: "Album A",
    duration: 200,
    position: 45,
    isPlaying: true,
    isMusicApp: true,
    awareness: .mediaRemote,
    startedPlayingAt: 100.0,
    lastUpdated: 110.0
  )

  let youtubeCandidate = MediaCandidate(
    identity: MediaIdentity(
      bundleID: "com.apple.Safari", contentID: "https://youtube.com/watch?v=xyz"),
    app: MediaAppInfo.resolve(bundleID: "com.apple.Safari"),
    title: "Tech Talk Video",
    artist: "YouTuber",
    album: "",
    duration: 600,
    position: 120,
    isPlaying: true,
    isMusicApp: false,
    awareness: .script,
    startedPlayingAt: 105.0,
    lastUpdated: 115.0
  )

  let zoomCandidate = MediaCandidate(
    identity: MediaIdentity(bundleID: "us.zoom.xos", pid: 888),
    app: MediaAppInfo.resolve(bundleID: "us.zoom.xos"),
    title: "",
    artist: "",
    isPlaying: true,
    hasMetadata: false,
    isMusicApp: false,
    awareness: .presence,
    capabilities: .audioOnlyDefault,
    startedPlayingAt: 102.0,
    lastUpdated: 112.0
  )

  var spotifyPaused = spotifyCandidate
  spotifyPaused.isPlaying = false
  let sel1 = MediaSelector.select(candidates: [spotifyPaused, youtubeCandidate])
  checkEqual(sel1?.identity.bundleID, "com.apple.Safari", "Playing YouTube beats paused Spotify")

  var youtubePaused = youtubeCandidate
  youtubePaused.isPlaying = false
  let sel2 = MediaSelector.select(candidates: [spotifyCandidate, youtubePaused])
  checkEqual(sel2?.identity.bundleID, "com.spotify.client", "Playing Spotify beats paused YouTube")

  let sel3 = MediaSelector.select(candidates: [youtubeCandidate, spotifyCandidate])
  checkEqual(
    sel3?.identity.bundleID, "com.spotify.client", "Music app beats video app when both playing")

  let vlcCandidate = MediaCandidate(
    identity: MediaIdentity(bundleID: "org.videolan.vlc", contentID: "movie.mkv"),
    app: MediaAppInfo.resolve(bundleID: "org.videolan.vlc"),
    title: "Movie Clip",
    artist: "VLC",
    isPlaying: true,
    isMusicApp: false,
    startedPlayingAt: 90.0,
    lastUpdated: 110.0
  )
  let sel4 = MediaSelector.select(candidates: [youtubeCandidate, vlcCandidate])
  checkEqual(sel4?.identity.bundleID, "org.videolan.vlc", "Earlier started video app wins")

  var vlcTied = vlcCandidate
  vlcTied.startedPlayingAt = youtubeCandidate.startedPlayingAt
  let sel5 = MediaSelector.select(
    candidates: [youtubeCandidate, vlcTied],
    frontmostBundleID: "com.apple.Safari"
  )
  checkEqual(
    sel5?.identity.bundleID, "com.apple.Safari",
    "Frontmost app breaks tie between playing candidates")

  let sel6 = MediaSelector.select(
    candidates: [spotifyPaused, youtubePaused],
    previous: youtubePaused.identity
  )
  checkEqual(
    sel6?.identity.bundleID, "com.apple.Safari", "Previous candidate sticky when all paused")

  let sel7 = MediaSelector.select(
    candidates: [spotifyPaused, youtubePaused],
    previous: nil,
    system: spotifyPaused.identity
  )
  checkEqual(
    sel7?.identity.bundleID, "com.spotify.client",
    "System player wins tie-break when all paused")

  let sel8 = MediaSelector.select(candidates: [spotifyPaused, zoomCandidate])
  checkEqual(
    sel8?.identity.bundleID, "us.zoom.xos",
    "Playing audio-only presence beats paused metadata")

  let sel9 = MediaSelector.select(candidates: [zoomCandidate, youtubeCandidate])
  checkEqual(
    sel9?.identity.bundleID, "com.apple.Safari",
    "Playing metadata beats playing audio-only")

  let deadSpotify = spotifyCandidate
  let liveYoutube = youtubeCandidate
  let prunedLive = MediaSelector.pruneStale([deadSpotify, liveYoutube], now: 500, maxAge: 6)
  checkEqual(
    prunedLive.contains(where: { $0.identity == deadSpotify.identity }), false,
    "Stale playing bridge candidate is pruned")
  checkEqual(
    prunedLive.contains(where: { $0.identity == liveYoutube.identity }), true,
    "Script candidate is kept")
  let selPrunedWinner = MediaSelector.select(
    candidates: prunedLive, previous: deadSpotify.identity)
  checkEqual(
    selPrunedWinner?.identity.bundleID, "com.apple.Safari",
    "Live player wins after stale player is pruned")

  let teamsCandidate = MediaCandidate(
    identity: MediaIdentity(bundleID: "com.microsoft.teams", pid: 999),
    app: MediaAppInfo.resolve(bundleID: "com.microsoft.teams"),
    isPlaying: true,
    hasMetadata: false,
    startedPlayingAt: 80.0,
    lastUpdated: 100.0
  )
  let sel10 = MediaSelector.select(candidates: [zoomCandidate, teamsCandidate])
  checkEqual(
    sel10?.identity.bundleID, "com.microsoft.teams", "Earlier audio-only presence wins")

  let sel11 = MediaSelector.select(
    candidates: [spotifyCandidate, youtubeCandidate],
    userSelection: youtubeCandidate.identity
  )
  checkEqual(
    sel11?.identity.bundleID, "com.apple.Safari", "User selection respected when playing")

  let sel12 = MediaSelector.select(
    candidates: [youtubePaused, spotifyCandidate],
    userSelection: youtubePaused.identity
  )
  checkEqual(
    sel12?.identity.bundleID, "com.spotify.client",
    "Playing candidate wins even if user selection is paused")

  let trackPresentation = MediaPresentation(candidate: spotifyCandidate)
  checkEqual(trackPresentation.hasMetadata, true, "Track presentation has metadata")
  checkEqual(trackPresentation.title, "Song A", "Track presentation title")
  checkEqual(trackPresentation.artist, "Artist A", "Track presentation artist")
  checkEqual(trackPresentation.isPlaying, true, "Track presentation isPlaying")

  let audioOnlyPresentation = MediaPresentation(candidate: zoomCandidate)
  checkEqual(audioOnlyPresentation.hasMetadata, false, "AudioOnly presentation has no metadata")
  checkEqual(audioOnlyPresentation.title, "", "AudioOnly presentation has empty title")
  checkEqual(
    audioOnlyPresentation.artist, "Zoom", "AudioOnly presentation displays app name as artist")
  checkEqual(
    audioOnlyPresentation.capabilities, .audioOnlyDefault,
    "AudioOnly presentation has openApp capability")

  // MARK: - Paused Spotify does not overwrite playing YouTube
  var registry: [MediaIdentity: MediaCandidate] = [:]
  let ytPlaying = youtubeCandidate
  registry[ytPlaying.identity] = ytPlaying

  let initialWinner = MediaSelector.select(candidates: Array(registry.values), previous: nil)
  checkEqual(
    initialWinner?.identity.bundleID, "com.apple.Safari", "Initial winner is playing YouTube")

  var spotPaused = spotifyCandidate
  spotPaused.isPlaying = false
  registry[spotPaused.identity] = spotPaused

  let reconciledWinner = MediaSelector.select(
    candidates: Array(registry.values),
    previous: initialWinner?.identity
  )
  checkEqual(
    reconciledWinner?.identity.bundleID, "com.apple.Safari",
    "Spotify pause does not hijack UI from playing YouTube")
  checkEqual(reconciledWinner?.isPlaying, true, "Winner remains playing")
  checkEqual(
    reconciledWinner?.title, "Tech Talk Video", "Winner title remains YouTube video title")

  // MARK: - Artwork scoping and localization
  let spotifyArtKey = MediaArtworkCacheKey.make(
    bundleID: "com.spotify.client",
    title: "Shape of You",
    artist: "Ed Sheeran"
  )
  let youtubeArtKey = MediaArtworkCacheKey.make(
    bundleID: "com.apple.Safari",
    title: "Shape of You",
    artist: "Ed Sheeran"
  )
  check(
    spotifyArtKey != youtubeArtKey,
    "Artwork cache keys with identical tracks must be scoped by bundleID")

  let urlArtKey = MediaArtworkCacheKey.make(
    bundleID: "com.apple.Safari",
    title: "Video",
    artist: "Creator",
    directURL: URL(string: "https://example.com/thumb.jpg")
  )
  checkEqual(
    urlArtKey, "com.apple.Safari|https://example.com/thumb.jpg",
    "Artwork cache key with directURL")

  check(L10n.Media.audioPlaying.count > 0, "L10n.Media.audioPlaying not empty")
  checkEqual(L10n.Media.openApp("Zoom"), "Open Zoom", "L10n.Media.openApp formatting")
  checkEqual(
    L10n.Media.appPlayingAudio("Zoom"), "Zoom is playing audio",
    "L10n.Media.appPlayingAudio formatting")

  let mixedPool: [MediaCandidate] = [zoomCandidate, spotifyPaused]
  let onlyMetadataPool = mixedPool.filter { false || $0.hasMetadata }
  checkEqual(
    onlyMetadataPool.count, 1, "Disabling other audio apps filters out audio-only presence")
  checkEqual(
    onlyMetadataPool.first?.identity.bundleID, "com.spotify.client",
    "Only metadata candidate retained")

  // MARK: - Command routing and target messages
  let targetCommand = NowPlayingCommandMessage(
    id: "cmd-1", command: .toggle, target: "com.spotify.client")
  if let data = try? JSONEncoder().encode(targetCommand),
    let json = String(data: data, encoding: .utf8)
  {
    check(
      json.contains("\"target\":\"com.spotify.client\""),
      "Targeted command contains target bundleID")
    check(json.contains("\"cmd\":\"toggle\""), "Targeted command contains cmd")
  } else {
    check(false, "NowPlayingCommandMessage should encode to JSON")
  }

  let untargetedCommand = NowPlayingCommandMessage(id: "cmd-2", command: .next)
  if let data = try? JSONEncoder().encode(untargetedCommand),
    let json = String(data: data, encoding: .utf8)
  {
    check(json.contains("\"cmd\":\"next\""), "Untargeted command contains cmd")
    check(
      !json.contains("\"target\":"), "Untargeted command omits target field or encodes null")
  }

  let seekCommand = NowPlayingCommandMessage(
    id: "cmd-3", command: .seek(position: 42.5), target: "com.apple.Safari")
  if let data = try? JSONEncoder().encode(seekCommand),
    let json = String(data: data, encoding: .utf8)
  {
    check(json.contains("\"cmd\":\"seek\""), "Seek command contains cmd")
    check(json.contains("\"position\":42.5"), "Seek command contains position")
    check(json.contains("\"target\":\"com.apple.Safari\""), "Seek command contains target")
  }

  checkEqual(
    MediaCapabilities.audioOnlyDefault.contains(.playPause), false,
    "AudioOnly lacks playPause capability")
  checkEqual(
    MediaCapabilities.audioOnlyDefault.contains(.nextTrack), false,
    "AudioOnly lacks nextTrack capability")
  checkEqual(
    MediaCapabilities.audioOnlyDefault.contains(.previousTrack), false,
    "AudioOnly lacks previousTrack capability")
  checkEqual(
    MediaCapabilities.audioOnlyDefault.contains(.seek), false, "AudioOnly lacks seek capability"
  )
  checkEqual(
    MediaCapabilities.audioOnlyDefault.contains(.openApp), true,
    "AudioOnly has openApp capability")

  checkEqual(
    MediaCapabilities.standardPlayer.contains(.playPause), true, "Standard player has playPause"
  )
  checkEqual(
    MediaCapabilities.standardPlayer.contains(.nextTrack), true, "Standard player has nextTrack"
  )
  checkEqual(
    MediaCapabilities.standardPlayer.contains(.previousTrack), true,
    "Standard player has previousTrack")
  checkEqual(MediaCapabilities.standardPlayer.contains(.seek), true, "Standard player has seek")
  checkEqual(
    MediaCapabilities.standardPlayer.contains(.openApp), true, "Standard player has openApp")

  var isolatedRegistry: [MediaIdentity: MediaCandidate] = [:]
  var activeCandidate = spotifyCandidate
  activeCandidate.isPlaying = true
  isolatedRegistry[activeCandidate.identity] = activeCandidate
  checkEqual(activeCandidate.isPlaying, true, "Candidate starts playing")

  activeCandidate.isPlaying = false
  isolatedRegistry[activeCandidate.identity] = activeCandidate
  let afterPauseWinner = MediaSelector.select(
    candidates: Array(isolatedRegistry.values), previous: activeCandidate.identity)
  checkEqual(
    afterPauseWinner?.identity.bundleID, "com.spotify.client",
    "Optimistically paused candidate remains active when no other app is playing")
  checkEqual(afterPauseWinner?.isPlaying, false, "Optimistic state reflects paused")

  // MARK: - Firefox / MediaRemote Single-App State & ContentID Transition Tests
  var firefoxRegistry: [MediaIdentity: MediaCandidate] = [:]
  let ffPlayingIdentity = MediaIdentity(
    bundleID: "org.mozilla.firefox", contentID: "video-tab-1")
  let ffPlayingCandidate = MediaCandidate(
    identity: ffPlayingIdentity,
    app: MediaAppInfo.resolve(bundleID: "org.mozilla.firefox"),
    title: "YouTube Video",
    artist: "Firefox Channel",
    duration: 300,
    position: 45,
    isPlaying: true,
    awareness: .mediaRemote,
    capabilities: .standardPlayer,
    startedPlayingAt: 100.0,
    lastUpdated: 110.0
  )
  firefoxRegistry[ffPlayingCandidate.identity] = ffPlayingCandidate
  let ffWinner1 = MediaSelector.select(candidates: Array(firefoxRegistry.values), previous: nil)
  checkEqual(ffWinner1?.identity, ffPlayingIdentity, "Firefox video is winner when playing")
  checkEqual(ffWinner1?.isPlaying, true, "Firefox is playing")

  let ffPausedIdentity = MediaIdentity(
    bundleID: "org.mozilla.firefox", contentID: "video-tab-1-updated")
  let ffPausedCandidate = MediaCandidate(
    identity: ffPausedIdentity,
    app: MediaAppInfo.resolve(bundleID: "org.mozilla.firefox"),
    title: "YouTube Video",
    artist: "Firefox Channel",
    duration: 300,
    position: 45,
    isPlaying: false,
    awareness: .mediaRemote,
    capabilities: .standardPlayer,
    startedPlayingAt: 100.0,
    lastUpdated: 112.0
  )
  for (id, cand) in firefoxRegistry
  where cand.awareness == .mediaRemote && cand.app.bundleID == "org.mozilla.firefox"
    && id != ffPausedCandidate.identity
  {
    firefoxRegistry.removeValue(forKey: id)
  }
  firefoxRegistry[ffPausedCandidate.identity] = ffPausedCandidate
  checkEqual(firefoxRegistry.count, 1, "Only 1 candidate remains in registry for Firefox")
  let ffWinner2 = MediaSelector.select(
    candidates: Array(firefoxRegistry.values), previous: ffPlayingIdentity)
  checkEqual(ffWinner2?.identity, ffPausedIdentity, "Firefox remains active candidate when paused")
  checkEqual(
    ffWinner2?.isPlaying, false,
    "Firefox immediately reflects isPlaying == false without stale shadow")
}

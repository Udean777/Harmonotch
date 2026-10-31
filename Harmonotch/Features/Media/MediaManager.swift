import Foundation
import AppKit
import Combine
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

    @Published var syncedLyrics: [LyricLine] = []
    @Published var currentLyricIndex: Int = -1
    @Published var currentLyricText: String = ""
    @Published var isLoadingLyrics: Bool = false
    @Published var isInstrumental: Bool = false

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

    private let appleScriptQueue = DispatchQueue(label: "com.harmonotch.media.applescript", qos: .utility)
    private let appleScriptQueueKey = DispatchSpecificKey<Void>()
    private let artworkCache = NSCache<NSString, NSImage>()
    private var lyricsCache: [String: (lyrics: [LyricLine], isInstrumental: Bool, duration: TimeInterval)] = [:]

    // Vorssaint NowPlaying adapter background watch process
    private var nowPlayingProcess: Process?
    private var nowPlayingBuffer = Data()
    private var nowPlayingStdin: Pipe?
    private var nowPlayingPID: Int32 = 0
    private var nowPlayingRevision: String?
    private var nowPlayingCanSendDirectly: Bool = false
    private let snapshotQueue = DispatchQueue(label: "harmonotch.nowplaying.snapshot", qos: .userInitiated)
    private var snapshotRefreshWork: DispatchWorkItem?
    private var lastCommandAt = Date.distantPast
    private var expectedPlayingState: Bool = false

    private init() {
        appleScriptQueue.setSpecific(key: appleScriptQueueKey, value: ())
        setupDistributedNotificationObservers()
        startNowPlayingWatchProcess()
        setupFastPollingTimer()
        fetchNowPlayingSnapshot()
    }

    deinit {
        nowPlayingProcess?.terminate()
        nowPlayingProcess = nil
    }

    // MARK: - Vorssaint NowPlaying Integration

    private func resolveNowPlayingAdapterPaths() -> (script: String, library: String)? {
        let fileManager = FileManager.default

        // 1. Installed Vorssaint.app (standard install location on user machine)
        let vorssaintScript = "/Applications/Vorssaint.app/Contents/Resources/now-playing.pl"
        let vorssaintDylib = "/Applications/Vorssaint.app/Contents/Frameworks/libVorssaintNowPlaying.dylib"
        if fileManager.fileExists(atPath: vorssaintScript) && fileManager.fileExists(atPath: vorssaintDylib) {
            return (vorssaintScript, vorssaintDylib)
        }

        // 2. App Bundle resources fallback
        if let resPath = Bundle.main.resourcePath {
            let script = (resPath as NSString).appendingPathComponent("now-playing.pl")
            let dylib = (resPath as NSString).appendingPathComponent("libVorssaintNowPlaying.dylib")
            if fileManager.fileExists(atPath: script) && fileManager.fileExists(atPath: dylib) {
                return (script, dylib)
            }
        }

        return nil
    }

    private func startNowPlayingWatchProcess() {
        guard let paths = resolveNowPlayingAdapterPaths() else {
            NSLog("[Harmonotch:Media] NowPlaying adapter not present on disk.")
            return
        }

        nowPlayingProcess?.terminate()
        nowPlayingProcess = nil

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        // Use `watch_all` so non-music players (Safari, WebKit, Chrome, YouTube, QuickTime, etc.)
        // are included and emit full metadata + playback state snapshots on every change.
        proc.arguments = [paths.script, paths.library, "watch_all"]

        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice
        // The adapter exits as soon as its stdin closes, so keep a pipe open.
        let stdinPipe = Pipe()
        proc.standardInput = stdinPipe
        nowPlayingStdin = stdinPipe

        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let chunk = handle.availableData
            guard !chunk.isEmpty else { return }
            self?.snapshotQueue.async {
                self?.handleNowPlayingChunk(chunk)
            }
        }

        proc.terminationHandler = { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self?.startNowPlayingWatchProcess()
            }
        }

        do {
            try proc.run()
            self.nowPlayingProcess = proc
            NSLog("[Harmonotch:Media] Vorssaint NowPlaying watch_all process started successfully.")
        } catch {
            NSLog("[Harmonotch:Media] Failed to launch now-playing.pl watch_all: %@", error.localizedDescription)
        }
    }

    @discardableResult
    private func sendWatchCommand(_ command: String) -> Bool {
        guard nowPlayingProcess?.isRunning == true,
              nowPlayingCanSendDirectly,
              nowPlayingPID > 0,
              let rev = nowPlayingRevision,
              let stdin = nowPlayingStdin else {
            return false
        }
        let line = "play \(nowPlayingPID) \(rev) \(command)\n"
        guard let data = line.data(using: .utf8) else { return false }
        do {
            try stdin.fileHandleForWriting.write(contentsOf: data)
            return true
        } catch {
            return false
        }
    }

    private func handleNowPlayingChunk(_ chunk: Data) {
        nowPlayingBuffer.append(chunk)

        let newline = UInt8(ascii: "\n")
        while let index = nowPlayingBuffer.firstIndex(of: newline) {
            let lineData = nowPlayingBuffer.subdata(in: 0..<index)
            nowPlayingBuffer.removeSubrange(0...index)

            guard !lineData.isEmpty,
                  let dict = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] else {
                continue
            }

            processNowPlayingPayload(dict)
        }
    }

    private func scheduleSnapshotRefresh() {
        snapshotRefreshWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.fetchNowPlayingSnapshot() }
        snapshotRefreshWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: work)
    }

    func fetchNowPlayingSnapshot(completion: (([String: Any]?) -> Void)? = nil) {
        guard let paths = resolveNowPlayingAdapterPaths() else {
            completion?(nil)
            return
        }

        snapshotQueue.async { [weak self] in
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
            proc.arguments = [paths.script, paths.library, "get"]
            let pipe = Pipe()
            proc.standardOutput = pipe
            proc.standardError = FileHandle.nullDevice

            do {
                try proc.run()
                DispatchQueue.global().asyncAfter(deadline: .now() + 2.0) {
                    if proc.isRunning { proc.terminate() }
                }
                // IMPORTANT: Read pipe data BEFORE waitUntilExit() so large base64 artwork
                // (>64 KB pipe buffer) never deadlocks the child process.
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                proc.waitUntilExit()

                guard !data.isEmpty,
                      let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    completion?(nil)
                    return
                }

                self?.processNowPlayingPayload(dict)
                completion?(dict)
            } catch {
                NSLog("[Harmonotch:Media] Failed to run now-playing.pl get: %@", error.localizedDescription)
                completion?(nil)
            }
        }
    }

    private func processNowPlayingPayload(_ dict: [String: Any]) {
        // Ignore command acknowledgements or adapter errors
        if dict["sent"] != nil || dict["validationRequest"] != nil || dict["error"] != nil {
            return
        }

        if let rawPID = dict["pid"] as? NSNumber {
            nowPlayingPID = rawPID.int32Value
        }
        if let rev = dict["playbackRevision"] as? String {
            nowPlayingRevision = rev
        }
        if let canSend = dict["canSendCommandsDirectly"] as? Bool {
            nowPlayingCanSendDirectly = canSend
        }

        var title = (dict["kMRMediaRemoteNowPlayingInfoTitle"] as? String)
            ?? (dict["title"] as? String) ?? ""
        var artist = (dict["kMRMediaRemoteNowPlayingInfoArtist"] as? String)
            ?? (dict["artist"] as? String) ?? ""
        var album = (dict["kMRMediaRemoteNowPlayingInfoAlbum"] as? String)
            ?? (dict["album"] as? String) ?? ""
        var duration = (dict["kMRMediaRemoteNowPlayingInfoDuration"] as? Double)
            ?? (dict["duration"] as? Double) ?? 0
        var elapsed = (dict["kMRMediaRemoteNowPlayingInfoElapsedTime"] as? Double)
            ?? (dict["elapsed"] as? Double)
            ?? (dict["position"] as? Double) ?? 0
        var bundleId = (dict["displayID"] as? String)
            ?? (dict["bundleIdentifier"] as? String) ?? ""
        let artworkBase64 = (dict["artworkBase64"] as? String)
            ?? (dict["currentArtworkBase64"] as? String)
            ?? (dict["artwork"] as? String)
        let rate = (dict["kMRMediaRemoteNowPlayingInfoPlaybackRate"] as? Double)
        let flag = (dict["isPlaying"] as? Bool)

        var isPlaying: Bool
        if let p = flag, let r = rate {
            isPlaying = p && (r > 0)
        } else if let r = rate {
            isPlaying = r > 0
        } else if let p = flag {
            isPlaying = p
        } else {
            isPlaying = false
        }

        if title.isEmpty, let sources = dict["sources"] as? [[String: Any]] {
            if let active = sources.first(where: { ($0["isPlaying"] as? Bool) == true && ($0["title"] != nil) })
                ?? sources.first(where: { $0["title"] != nil }) {
                title = (active["title"] as? String) ?? ""
                artist = (active["artist"] as? String) ?? ""
                album = (active["album"] as? String) ?? ""
                duration = (active["duration"] as? Double) ?? duration
                elapsed = (active["elapsed"] as? Double) ?? elapsed
                bundleId = (active["bundleIdentifier"] as? String) ?? bundleId
            }
        }

        var playingState = isPlaying
        if Date().timeIntervalSince(lastCommandAt) < 0.45 {
            playingState = expectedPlayingState
        }

        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                if self.isPlaying {
                    self.isPlaying = false
                    self.updatePlaybackTimerState()
                }
                if let sources = dict["sources"] as? [[String: Any]], sources.isEmpty {
                    self.clearSession()
                }
            }
            return
        }

        let source = mapBundleIdentifierToSource(bundleId, title: title)

        var directImage: NSImage? = nil
        if let b64 = artworkBase64, let data = Data(base64Encoded: b64) {
            directImage = NSImage(data: data)
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.updateTrack(
                source: source,
                title: title,
                artist: artist,
                album: album,
                duration: duration,
                position: elapsed,
                isPlaying: playingState,
                directArtwork: directImage
            )
        }
    }

    private func mapBundleIdentifierToSource(_ bundleId: String, title: String) -> MediaSource {
        let lower = bundleId.lowercased()
        if lower.contains("spotify") { return .spotify }
        if lower.contains("music") || lower.contains("itunes") { return .appleMusic }
        if lower.contains("iina") { return .iina }
        if lower.contains("vlc") { return .vlc }
        if lower.contains("quicktime") { return .quicktime }
        if lower.contains("podcasts") { return .podcasts }
        if lower.contains("safari") || lower.contains("webkit") || lower.contains("chrome") || lower.contains("browser") || lower.contains("brave") || lower.contains("edge") || lower.contains("opera") || lower.contains("vivaldi") {
            if title.lowercased().contains("youtube") {
                return .safari
            }
            return .web
        }
        return .system
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
        let positionSec = extractDouble(from: userInfo["Playback Position"])
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
        let positionSec = extractDouble(from: userInfo["Player Position"])
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
            if duration > 0 { self.duration = duration }

            self.trackTitle = title
            self.artistName = artist
            self.albumName = album

            if let direct = directArtwork {
                self.artworkImage = direct
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

    /// Counts consecutive polls that found no media session anywhere.
    /// A paused session is kept; it is dropped only once every source stays empty.
    private var emptySnapshotCount = 0

    private func clearSession() {
        isPlaying = false
        trackTitle = ""
        artistName = ""
        albumName = ""
        artworkImage = nil
        lastDetectedRawWebTitle = ""
        playbackPosition = 0
        duration = 0
        expectedPlayingState = false
        nowPlayingPID = 0
        nowPlayingRevision = nil
        nowPlayingCanSendDirectly = false
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

    // Fast polling: 2.0s interval for fallback when watch_all is not active
    private func setupFastPollingTimer() {
        fastPollingTimer = Timer.publish(every: 2.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                // When watch_all is actively streaming real-time MediaRemote notifications,
                // do not run AppleScript/browser URL polling that could clobber pause state.
                if self.nowPlayingProcess?.isRunning == true {
                    return
                }
                self.pollCurrentMediaState()
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
            currentLyricText = (matchedIndex >= 0 && matchedIndex < syncedLyrics.count) ? syncedLyrics[matchedIndex].text : ""
        }
    }

    func pollCurrentMediaState() {
        // If the Vorssaint NowPlaying adapter is available on this system, it is the single
        // authoritative source of truth for all system players (Safari, Chrome, YouTube, Spotify, Music).
        if resolveNowPlayingAdapterPaths() != nil {
            if nowPlayingProcess?.isRunning != true {
                fetchNowPlayingSnapshot()
            }
            return
        }

        // Query NowPlaying platform snapshot first (catches YouTube WebKit, Chrome, Spotify, etc.)
        fetchNowPlayingSnapshot { [weak self] snapshot in
            guard let self = self else { return }
            // If now-playing provides active session information, it is the ground truth
            if snapshot != nil && self.hasActiveTrack {
                return
            }

            self.appleScriptQueue.async { [weak self] in
                guard let self = self else { return }

                // 1. Spotify
                if !NSRunningApplication.runningApplications(withBundleIdentifier: "com.spotify.client").isEmpty {
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

                    if let result = self.executeAppleScript(spotifyScript), !result.isEmpty {
                        let parts = result.components(separatedBy: "|||")
                        if parts.count >= 6 {
                            let isPlaying = parts[0].lowercased() == "playing"
                            let title = parts[1]
                            let artist = parts[2]
                            let album = parts[3]
                            let duration = self.extractDouble(from: parts[4]) ?? 0
                            let pos = self.extractDouble(from: parts[5]) ?? 0
                            if !title.isEmpty {
                                self.updateTrack(source: .spotify, title: title, artist: artist, album: album, duration: duration, position: pos, isPlaying: isPlaying)
                                return
                            }
                        }
                    }
                }

                // 2. Apple Music
                if !NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Music").isEmpty {
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

                    if let result = self.executeAppleScript(musicScript), !result.isEmpty {
                        let parts = result.components(separatedBy: "|||")
                        if parts.count >= 6 {
                            let isPlaying = parts[0].lowercased() == "playing"
                            let title = parts[1]
                            let artist = parts[2]
                            let album = parts[3]
                            let duration = self.extractDouble(from: parts[4]) ?? 0
                            let pos = self.extractDouble(from: parts[5]) ?? 0
                            if !title.isEmpty {
                                self.updateTrack(source: .appleMusic, title: title, artist: artist, album: album, duration: duration, position: pos, isPlaying: isPlaying)
                                return
                            }
                        }
                    }
                }

                // 3. QuickTime Player
                if !NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.QuickTimePlayerX").isEmpty {
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
                    if let res = self.executeAppleScript(qtScript), !res.isEmpty {
                        let parts = res.components(separatedBy: "|||")
                        if parts.count >= 3 {
                            let name = parts[0]
                            let pos = self.extractDouble(from: parts[1]) ?? 0
                            let dur = self.extractDouble(from: parts[2]) ?? 0
                            self.updateTrack(source: .quicktime, title: name, artist: "QuickTime", album: "", duration: dur, position: pos, isPlaying: true)
                            return
                        }
                    }
                }

                // 4. Web Browsers fallback (only when NowPlaying adapter is unavailable)
                self.pollWebMediaState()
            }
        }
    }

    func pollWebMediaState() {
        if resolveNowPlayingAdapterPaths() != nil {
            return
        }
        if (mediaSource == .spotify || mediaSource == .appleMusic) && isPlaying {
            return
        }

        let isSafariRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Safari").isEmpty
        let isChromeRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: "com.google.Chrome").isEmpty
        let isArcRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: "company.thebrowser.Browser").isEmpty
        let isBraveRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: "com.brave.Browser").isEmpty
        let isEdgeRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: "com.microsoft.edgemac").isEmpty
        let isOperaRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: "com.operasoftware.Opera").isEmpty || !NSRunningApplication.runningApplications(withBundleIdentifier: "com.operasoftware.OperaGX").isEmpty

        guard isSafariRunning || isChromeRunning || isArcRunning || isBraveRunning || isEdgeRunning || isOperaRunning else {
            if mediaSource == .safari || mediaSource == .web {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.isPlaying = false
                    self.lastDetectedRawWebTitle = ""
                    self.updatePlaybackTimerState()
                }
            }
            registerEmptyPoll()
            return
        }

        appleScriptQueue.async { [weak self] in
            guard let self = self else { return }

            // Check Safari
            if isSafariRunning {
                let safariScript = """
                set out to ""
                tell application "Safari"
                    try
                        repeat with w in windows
                            repeat with t in tabs of w
                                set u to URL of t
                                if u contains "youtube.com" or u contains "youtu.be" or u contains "spotify.com" or u contains "soundcloud.com" or u contains "twitch.tv" or u contains "netflix.com" then
                                    set n to name of t
                                    set out to n & "|||" & u & "|||Safari"
                                    exit repeat
                                end if
                            end repeat
                            if out is not "" then exit repeat
                        end repeat
                    on error
                        set out to ""
                    end try
                end tell
                return out
                """

                if let res = self.executeAppleScript(safariScript), !res.isEmpty {
                    self.processWebMediaResult(res)
                    return
                }
            }

            // Check Chromium browsers (Chrome, Arc, Brave, Edge, Opera)
            let chromiumApps = [
                ("Google Chrome", isChromeRunning),
                ("Arc", isArcRunning),
                ("Brave Browser", isBraveRunning),
                ("Microsoft Edge", isEdgeRunning),
                ("Opera", isOperaRunning)
            ]

            for (appName, isRunning) in chromiumApps where isRunning {
                let script = """
                set out to ""
                tell application "\(appName)"
                    try
                        repeat with w in windows
                            repeat with t in tabs of w
                                set u to URL of t
                                if u contains "youtube.com" or u contains "youtu.be" or u contains "spotify.com" or u contains "soundcloud.com" or u contains "twitch.tv" or u contains "netflix.com" then
                                    set n to title of t
                                    set out to n & "|||" & u & "|||\(appName)"
                                    exit repeat
                                end if
                            end repeat
                            if out is not "" then exit repeat
                        end repeat
                    on error
                        set out to ""
                    end try
                end tell
                return out
                """

                if let res = self.executeAppleScript(script), !res.isEmpty {
                    self.processWebMediaResult(res)
                    return
                }
            }

            if self.mediaSource == .safari || self.mediaSource == .web {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.isPlaying = false
                    self.lastDetectedRawWebTitle = ""
                    self.updatePlaybackTimerState()
                }
            }
            self.registerEmptyPoll()
        }
    }

    private func processWebMediaResult(_ result: String) {
        let parts = result.components(separatedBy: "|||")
        guard parts.count >= 2 else { return }

        let rawTitle = parts[0]
        let rawURL = parts[1]

        guard let parsed = parseWebMedia(title: rawTitle, url: rawURL) else { return }

        if (mediaSource == .spotify || mediaSource == .appleMusic) && isPlaying {
            return
        }

        if self.lastDetectedRawWebTitle == rawTitle && self.hasActiveTrack {
            return
        }
        self.lastDetectedRawWebTitle = rawTitle

        resolveWebMetadata(parsedTitle: parsed.title, parsedArtist: parsed.artist, videoId: parsed.videoId) { [weak self] vTitle, vArtist, vDuration, vArtworkURL in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.updateTrack(
                    source: parsed.source,
                    title: vTitle,
                    artist: vArtist,
                    album: "",
                    duration: vDuration,
                    position: 0,
                    isPlaying: true,
                    artworkURL: vArtworkURL
                )
            }
        }
    }

    private func resolveWebMetadata(
        parsedTitle: String,
        parsedArtist: String,
        videoId: String?,
        completion: @escaping (_ verifiedTitle: String, _ verifiedArtist: String, _ duration: TimeInterval, _ artworkURL: URL?) -> Void
    ) {
        var query = parsedTitle
        let isGenericArtist = (parsedArtist.isEmpty || parsedArtist == "YouTube" || parsedArtist == "YouTube Music" || parsedArtist == "Spotify Web")
        if !isGenericArtist {
            query = "\(parsedArtist) \(parsedTitle)"
        }

        let cleanQuery = query
            .replacingOccurrences(of: #"[^\w\s\u00C0-\u024F\u4E00-\u9FFF\u3040-\u30FF\uAC00-\uD7AF]"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let encoded = cleanQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let itunesURL = URL(string: "https://itunes.apple.com/search?term=\(encoded)&entity=song&limit=1") else {
            let fallbackArt = videoId.flatMap { URL(string: "https://img.youtube.com/vi/\($0)/hqdefault.jpg") }
            completion(parsedTitle, parsedArtist, 0, fallbackArt)
            return
        }

        var request = URLRequest(url: itunesURL)
        request.timeoutInterval = 3.5
        request.setValue("Harmonotch macOS Island v1.0", forHTTPHeaderField: "User-Agent")

        URLSession.shared.dataTask(with: request) { data, _, error in
            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let results = json["results"] as? [[String: Any]],
               let first = results.first {

                let trackName = first["trackName"] as? String ?? parsedTitle
                let artistName = first["artistName"] as? String ?? parsedArtist
                let durMillis = (first["trackTimeMillis"] as? Double) ?? 0
                let durSecs = durMillis / 1000.0

                var artURL: URL? = nil
                if let artStr = first["artworkUrl100"] as? String {
                    let highRes = artStr.replacingOccurrences(of: "100x100bb", with: "600x600bb")
                    artURL = URL(string: highRes)
                }

                if artURL == nil, let vid = videoId {
                    artURL = URL(string: "https://img.youtube.com/vi/\(vid)/hqdefault.jpg")
                }

                completion(trackName, artistName, durSecs, artURL)
                return
            }

            let fallbackArt = videoId.flatMap { URL(string: "https://img.youtube.com/vi/\($0)/hqdefault.jpg") }
            completion(parsedTitle, parsedArtist, 0, fallbackArt)
        }.resume()
    }

    private func parseWebMedia(title: String, url: String) -> ParsedWebMedia? {
        var clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return nil }

        // Strip notification badge e.g. (1), (123)
        clean = clean.replacingOccurrences(of: #"^\(\d+\+?\)\s*"#, with: "", options: .regularExpression)

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
            clean = clean.replacingOccurrences(of: #"\s*-\s*YouTube Music\s*$"#, with: "", options: [.regularExpression, .caseInsensitive])
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
            clean = clean.replacingOccurrences(of: #"\s*-\s*YouTube\s*$"#, with: "", options: [.regularExpression, .caseInsensitive])
            if clean.isEmpty || clean.lowercased() == "youtube" {
                return nil
            }
            clean = clean.replacingOccurrences(of: #"\s*[\(\[](?:Official\s*(?:Music\s*)?Video|Official\s*Audio|Official\s*Lyric\s*Video|Lyric\s*Video|Visualizer|Audio|MV|HD|4K|Remastered|Live).*?[\)\]]"#, with: "", options: [.regularExpression, .caseInsensitive])
            clean = clean.replacingOccurrences(of: #"\s*\|\s*Official\s*.*$"#, with: "", options: [.regularExpression, .caseInsensitive])

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
            clean = clean.replacingOccurrences(of: #"\s*\|\s*Spotify\s*$"#, with: "", options: [.regularExpression, .caseInsensitive])
            clean = clean.replacingOccurrences(of: #"\s*-\s*Spotify\s*$"#, with: "", options: [.regularExpression, .caseInsensitive])
            if clean.isEmpty || clean.lowercased().contains("web player") || clean.lowercased() == "spotify" {
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
                    return ParsedWebMedia(title: parts[0].trimmingCharacters(in: .whitespaces), artist: parts[1].trimmingCharacters(in: .whitespaces), source: .web, videoId: nil)
                }
            }

            if clean.contains(" - ") {
                let parts = clean.components(separatedBy: " - ")
                if parts.count >= 2 {
                    return ParsedWebMedia(title: parts[0].trimmingCharacters(in: .whitespaces), artist: parts[1].trimmingCharacters(in: .whitespaces), source: .web, videoId: nil)
                }
            }

            return ParsedWebMedia(title: clean, artist: "Spotify Web", source: .web, videoId: nil)
        }

        return nil
    }

    private var currentAppTarget: String {
        return (mediaSource == .appleMusic) ? "id \"com.apple.Music\"" : "id \"com.spotify.client\""
    }

    func playPause() {
        let wasPlaying = isPlaying
        let targetPlaying = !wasPlaying
        expectedPlayingState = targetPlaying
        lastCommandAt = Date()

        // 1. Instant optimistic update for 0ms visual feedback
        isPlaying = targetPlaying
        updatePlaybackTimerState()

        // 2. Primary: Vorssaint watch_all stdin command or direct MediaRemote command
        var commandSent = sendWatchCommand("toggle")
        if !commandSent {
            commandSent = MediaRemoteController.togglePlayPause(currentlyPlaying: wasPlaying)
        }

        // 3. Fallback ONLY if both watch_all stdin and MediaRemote framework failed
        if !commandSent {
            if mediaSource == .spotify {
                runAppleScriptAsync("tell application id \"com.spotify.client\" to playpause")
            } else if mediaSource == .appleMusic {
                runAppleScriptAsync("tell application id \"com.apple.Music\" to playpause")
            } else if mediaSource == .quicktime {
                runAppleScriptAsync("tell application \"QuickTime Player\" to playpause document 1")
            } else if mediaSource == .safari || mediaSource == .web {
                let js = wasPlaying
                    ? "let v = document.querySelector('video') || document.querySelector('audio'); if (v) v.pause();"
                    : "let v = document.querySelector('video') || document.querySelector('audio'); if (v) v.play();"
                runWebJavaScriptAsync(js)
            }
        }

        // 4. Refresh snapshot if watch_all is not actively streaming
        if nowPlayingProcess?.isRunning != true {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                self?.fetchNowPlayingSnapshot()
            }
        }
    }

    func nextTrack() {
        lastCommandAt = Date()
        expectedPlayingState = isPlaying

        if !sendWatchCommand("next") {
            if !MediaRemoteController.next() {
                if mediaSource == .spotify {
                    runAppleScriptAsync("tell application id \"com.spotify.client\" to next track")
                } else if mediaSource == .appleMusic {
                    runAppleScriptAsync("tell application id \"com.apple.Music\" to next track")
                } else if mediaSource == .safari || mediaSource == .web {
                    sendSystemMediaKey(key: 17) // NX_KEYTYPE_NEXT
                }
            }
        }

        if nowPlayingProcess?.isRunning != true {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                self?.fetchNowPlayingSnapshot()
            }
        }
    }

    func previousTrack() {
        lastCommandAt = Date()
        expectedPlayingState = isPlaying

        if !sendWatchCommand("previous") {
            if !MediaRemoteController.previous() {
                if mediaSource == .spotify {
                    runAppleScriptAsync("tell application id \"com.spotify.client\" to previous track")
                } else if mediaSource == .appleMusic {
                    runAppleScriptAsync("tell application id \"com.apple.Music\" to previous track")
                } else if mediaSource == .safari || mediaSource == .web {
                    sendSystemMediaKey(key: 18) // NX_KEYTYPE_PREVIOUS
                }
            }
        }

        if nowPlayingProcess?.isRunning != true {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                self?.fetchNowPlayingSnapshot()
            }
        }
    }

    func seek(to position: TimeInterval) {
        playbackPosition = position
        if !sendWatchCommand("seek \(position)") {
            if !MediaRemoteController.seek(to: position) {
                if mediaSource == .spotify {
                    runAppleScriptAsync("tell application id \"com.spotify.client\" to set player position to \(Int(position))")
                } else if mediaSource == .appleMusic {
                    runAppleScriptAsync("tell application id \"com.apple.Music\" to set player position to \(Int(position))")
                } else if mediaSource == .safari || mediaSource == .web {
                    runWebJavaScriptAsync("let v = document.querySelector('video') || document.querySelector('audio'); if (v) { v.currentTime = \(position); }")
                }
            }
        }
    }

    private func toggleWebPlayback() {
        playPause()
    }

    private func runWebJavaScriptAsync(_ js: String) {
        appleScriptQueue.async { [weak self] in
            guard let self = self else { return }
            _ = self.runWebJavaScript(js)
        }
    }

    private func runWebJavaScript(_ js: String) -> Bool {
        let escaped = js
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        let safariScript = """
        tell application "Safari"
            try
                repeat with w in windows
                    repeat with t in tabs of w
                        set u to URL of t
                        if u contains "youtube.com" or u contains "youtu.be" or u contains "spotify.com" then
                            do JavaScript "\(escaped)" in t
                            return "ok"
                        end if
                    end repeat
                end repeat
            end try
        end tell
        return ""
        """
        if executeAppleScript(safariScript) == "ok" { return true }

        let chromeScript = """
        tell application "Google Chrome"
            try
                repeat with w in windows
                    repeat with t in tabs of w
                        set u to URL of t
                        if u contains "youtube.com" or u contains "youtu.be" or u contains "spotify.com" then
                            execute t javascript "\(escaped)"
                            return "ok"
                        end if
                    end repeat
                end repeat
            end try
        end tell
        return ""
        """
        return executeAppleScript(chromeScript) == "ok"
    }

    private func sendSystemMediaKey(key: Int32) {
        func postKey(down: Bool) {
            let flags: NSEvent.ModifierFlags = down ? NSEvent.ModifierFlags(rawValue: 0xa00) : NSEvent.ModifierFlags(rawValue: 0xb00)
            let data1 = Int((key << 16) | (down ? 0xa00 : 0xb00))
            let event = NSEvent.otherEvent(
                with: .systemDefined,
                location: .zero,
                modifierFlags: flags,
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                subtype: 8,
                data1: data1,
                data2: -1
            )
            if let cgEvent = event?.cgEvent {
                cgEvent.post(tap: .cghidEventTap)
            }
        }
        postKey(down: true)
        postKey(down: false)
    }

    private func fetchArtworkAsync(source: MediaSource, directURL: URL? = nil) {
        let cacheKey = (directURL?.absoluteString ?? "\(trackTitle)--\(artistName)") as NSString
        if let cached = artworkCache.object(forKey: cacheKey) {
            DispatchQueue.main.async {
                self.artworkImage = cached
            }
            return
        }

        if let direct = directURL {
            URLSession.shared.dataTask(with: direct) { [weak self] data, _, _ in
                if let data = data, let image = NSImage(data: data) {
                    self?.artworkCache.setObject(image, forKey: cacheKey)
                    DispatchQueue.main.async {
                        self?.artworkImage = image
                    }
                }
            }.resume()
            return
        }

        if source == .spotify {
            appleScriptQueue.async { [weak self] in
                let script = "tell application id \"com.spotify.client\" to get artwork url of current track"
                if let urlString = self?.executeAppleScript(script), let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)) {
                    URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
                        if let data = data, let image = NSImage(data: data) {
                            self?.artworkCache.setObject(image, forKey: cacheKey)
                            DispatchQueue.main.async {
                                self?.artworkImage = image
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
                      let image = NSImage(data: data) else { return }
                self.artworkCache.setObject(image, forKey: cacheKey)
                DispatchQueue.main.async {
                    self.artworkImage = image
                }
            }
        }
    }

    private func sanitizeTrackTitle(_ title: String) -> String {
        var clean = title
        clean = clean.replacingOccurrences(of: #"\s*[\(\[](?:feat\.|featuring|with).*?[\)\]]"#, with: "", options: [.regularExpression, .caseInsensitive])
        clean = clean.replacingOccurrences(of: #"\s*[-–—]\s*(?:Remastered|Live|Acoustic|Single|Bonus Track|Radio Edit).*"#, with: "", options: [.regularExpression, .caseInsensitive])
        clean = clean.replacingOccurrences(of: #"\s*[\(\[](?:Remastered|Deluxe|Live|Acoustic|Radio Edit|Bonus).*?[\)\]]"#, with: "", options: [.regularExpression, .caseInsensitive])
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

        if key == lastFetchedTrackKey && !syncedLyrics.isEmpty {
            return
        }

        if let cached = lyricsCache[key] {
            DispatchQueue.main.async {
                self.isLoadingLyrics = false
                self.isInstrumental = cached.isInstrumental
                if self.duration == 0 && cached.duration > 0 {
                    self.duration = cached.duration
                }
                self.syncedLyrics = cached.lyrics
                self.lastFetchedTrackKey = key
                self.updateCurrentLyric()
            }
            return
        }

        DispatchQueue.main.async {
            self.isLoadingLyrics = true
            self.syncedLyrics = []
            self.currentLyricIndex = -1
            self.currentLyricText = ""
            self.isInstrumental = false
        }

        let isGenericArtist = (cleanArtist.isEmpty || cleanArtist == "YouTube" || cleanArtist == "YouTube Music" || cleanArtist == "Spotify Web")

        if !isGenericArtist {
            searchLRCLIB(track: cleanTrack, artist: cleanArtist) { [weak self] success in
                guard let self = self else { return }
                if !success {
                    self.searchLRCLIBGeneral(query: "\(cleanArtist) \(cleanTrack)") { success2 in
                        if !success2 {
                            self.searchLRCLIBGeneral(query: cleanTrack) { success3 in
                                if !success3 {
                                    self.fetchAppleMusicLocalLyrics()
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
                    self.fetchAppleMusicLocalLyrics()
                }
            }
        }
    }

    private func searchLRCLIB(track: String, artist: String, completion: @escaping (Bool) -> Void) {
        var components = URLComponents(string: "https://lrclib.net/api/search")!
        components.queryItems = [
            URLQueryItem(name: "track_name", value: track),
            URLQueryItem(name: "artist_name", value: artist)
        ]

        guard let url = components.url else {
            completion(false)
            return
        }

        performLyricsRequest(url: url, track: track, artist: artist, completion: completion)
    }

    private func searchLRCLIBGeneral(query: String, completion: @escaping (Bool) -> Void) {
        var components = URLComponents(string: "https://lrclib.net/api/search")!
        components.queryItems = [
            URLQueryItem(name: "q", value: query)
        ]

        guard let url = components.url else {
            completion(false)
            return
        }

        performLyricsRequest(url: url, track: query, artist: "", completion: completion)
    }

    private func performLyricsRequest(url: URL, track: String, artist: String, completion: @escaping (Bool) -> Void) {
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
                matchedItem = array.first(where: {
                    if let s = $0["syncedLyrics"] as? String, !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        return true
                    }
                    return false
                }) ?? array.first
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

            if !syncedLRC.isEmpty || !plainLyrics.isEmpty || instrumental {
                DispatchQueue.main.async {
                    self.isLoadingLyrics = false
                    self.isInstrumental = instrumental
                    if self.duration == 0 && trackDuration > 0 {
                        self.duration = trackDuration
                    }
                    if !syncedLRC.isEmpty {
                        self.syncedLyrics = LRCParser.parse(syncedLRC)
                        NSLog("[Harmonotch:Media] Successfully parsed %ld synced lyric lines for %@ - %@", self.syncedLyrics.count, track, artist)
                    } else if !plainLyrics.isEmpty {
                        let lines = plainLyrics.components(separatedBy: "\n")
                            .map { $0.trimmingCharacters(in: .whitespaces) }
                            .filter { !$0.isEmpty }
                        self.syncedLyrics = lines.map { LyricLine(time: 0, text: $0) }
                        NSLog("[Harmonotch:Media] Successfully parsed %ld plain lyric lines for %@ - %@", self.syncedLyrics.count, track, artist)
                    }
                    self.lastFetchedTrackKey = "\(track.lowercased())--\(artist.lowercased())"
                    self.lyricsCache[self.lastFetchedTrackKey] = (self.syncedLyrics, self.isInstrumental, self.duration)
                    self.updateCurrentLyric()
                }
                completion(true)
            } else {
                completion(false)
            }
        }.resume()
    }

    private func fetchAppleMusicLocalLyrics() {
        guard mediaSource == .appleMusic else {
            DispatchQueue.main.async { self.isLoadingLyrics = false }
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
            if let text = self?.executeAppleScript(script), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let lines = text.components(separatedBy: "\n")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                DispatchQueue.main.async {
                    self?.isLoadingLyrics = false
                    self?.syncedLyrics = lines.map { LyricLine(time: 0, text: $0) }
                    self?.updateCurrentLyric()
                }
            } else {
                DispatchQueue.main.async {
                    self?.isLoadingLyrics = false
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
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

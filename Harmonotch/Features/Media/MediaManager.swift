import Foundation
import AppKit
import Combine
import SwiftUI

struct LyricLine: Identifiable, Hashable {
    let id = UUID()
    let time: TimeInterval
    let text: String
}

enum MediaSource: String {
    case spotify = "Spotify"
    case appleMusic = "Apple Music"
    case safari = "YouTube"
    case web = "Web"
    case none = "None"

    var iconName: String {
        switch self {
        case .spotify: return "waveform"
        case .appleMusic: return "apple.logo"
        case .safari: return "play.rectangle.fill"
        case .web: return "globe"
        case .none: return "music.note"
        }
    }

    var brandColor: Color {
        switch self {
        case .spotify: return .green
        case .appleMusic: return .pink
        case .safari: return .red
        case .web: return .blue
        case .none: return .gray
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
        !trackTitle.isEmpty
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
    private var webPollingTimer: AnyCancellable?
    private var lastFetchedTrackKey: String = ""
    private var cancellables = Set<AnyCancellable>()
    private var scriptCache: [String: NSAppleScript] = [:]
    private var lastDetectedRawWebTitle: String = ""

    private let appleScriptQueue = DispatchQueue(label: "com.harmonotch.media.applescript", qos: .utility)
    private let appleScriptQueueKey = DispatchSpecificKey<Void>()
    private let artworkCache = NSCache<NSString, NSImage>()
    private var lyricsCache: [String: (lyrics: [LyricLine], isInstrumental: Bool, duration: TimeInterval)] = [:]

    private init() {
        appleScriptQueue.setSpecific(key: appleScriptQueueKey, value: ())
        setupDistributedNotificationObservers()
        setupWebPollingTimer()
        pollCurrentMediaState()
    }

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
        artworkURL: URL? = nil
    ) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

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

            if trackChanged && !title.isEmpty {
                self.artworkImage = nil
                self.fetchArtworkAsync(source: source, directURL: artworkURL)
                self.fetchLyrics(track: title, artist: artist, album: album, duration: duration)
            }

            self.updateCurrentLyric()
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

    private func setupWebPollingTimer() {
        webPollingTimer = Timer.publish(every: 6.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                if (self.mediaSource == .spotify || self.mediaSource == .appleMusic) && self.isPlaying {
                    return
                }
                self.pollWebMediaState()
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
        appleScriptQueue.async { [weak self] in
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

            if let result = self?.executeAppleScript(spotifyScript), !result.isEmpty {
                let parts = result.components(separatedBy: "|||")
                if parts.count >= 6 {
                    let isPlaying = parts[0].lowercased() == "playing"
                    let title = parts[1]
                    let artist = parts[2]
                    let album = parts[3]
                    let duration = self?.extractDouble(from: parts[4]) ?? 0
                    let pos = self?.extractDouble(from: parts[5]) ?? 0
                    if !title.isEmpty {
                        self?.updateTrack(source: .spotify, title: title, artist: artist, album: album, duration: duration, position: pos, isPlaying: isPlaying)
                        return
                    }
                }
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

            if let result = self?.executeAppleScript(musicScript), !result.isEmpty {
                let parts = result.components(separatedBy: "|||")
                if parts.count >= 6 {
                    let isPlaying = parts[0].lowercased() == "playing"
                    let title = parts[1]
                    let artist = parts[2]
                    let album = parts[3]
                    let duration = self?.extractDouble(from: parts[4]) ?? 0
                    let pos = self?.extractDouble(from: parts[5]) ?? 0
                    if !title.isEmpty {
                        self?.updateTrack(source: .appleMusic, title: title, artist: artist, album: album, duration: duration, position: pos, isPlaying: isPlaying)
                        return
                    }
                }
            }

            self?.pollWebMediaState()
        }
    }

    func pollWebMediaState() {
        if (mediaSource == .spotify || mediaSource == .appleMusic) && isPlaying {
            return
        }

        let isSafariRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Safari").isEmpty
        let isChromeRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: "com.google.Chrome").isEmpty

        guard isSafariRunning || isChromeRunning else {
            if mediaSource == .safari || mediaSource == .web {
                DispatchQueue.main.async {
                    self.isPlaying = false
                    self.lastDetectedRawWebTitle = ""
                    self.updatePlaybackTimerState()
                }
            }
            return
        }

        appleScriptQueue.async { [weak self] in
            guard let self = self else { return }

            if isSafariRunning {
                let safariScript = """
                set out to ""
                tell application "Safari"
                    try
                        repeat with w in windows
                            repeat with t in tabs of w
                                set u to URL of t
                                if u contains "youtube.com" or u contains "youtu.be" or u contains "spotify.com" then
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

            if isChromeRunning {
                let chromeScript = """
                set out to ""
                tell application "Google Chrome"
                    try
                        repeat with w in windows
                            repeat with t in tabs of w
                                set u to URL of t
                                if u contains "youtube.com" or u contains "youtu.be" or u contains "spotify.com" then
                                    set n to title of t
                                    set out to n & "|||" & u & "|||Chrome"
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

                if let res = self.executeAppleScript(chromeScript), !res.isEmpty {
                    self.processWebMediaResult(res)
                    return
                }
            }

            if self.mediaSource == .safari || self.mediaSource == .web {
                DispatchQueue.main.async {
                    self.isPlaying = false
                    self.lastDetectedRawWebTitle = ""
                    self.updatePlaybackTimerState()
                }
            }
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

        // Idempotensi: jika rawTitle yang terdeteksi sama persis dan track sudah aktif, jangan re-trigger!
        if (self.mediaSource == .safari || self.mediaSource == .web) && self.lastDetectedRawWebTitle == rawTitle && self.hasActiveTrack {
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

            // Fallback jika iTunes tidak menemukan hasil
            let fallbackArt = videoId.flatMap { URL(string: "https://img.youtube.com/vi/\($0)/hqdefault.jpg") }
            completion(parsedTitle, parsedArtist, 0, fallbackArt)
        }.resume()
    }

    private func parseWebMedia(title: String, url: String) -> ParsedWebMedia? {
        var clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return nil }

        // Strip counter prefix seperti "(1) "
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

        // 1. YouTube Music: "Title • Artist - YouTube Music"
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

        // 2. Standard YouTube: "Artist - Title (Official Music Video) - YouTube"
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

        // 3. Spotify Web: "Title • Artist | Spotify"
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
        if mediaSource == .safari || mediaSource == .web {
            toggleWebPlayback()
        } else {
            runAppleScriptAsync("tell application \(currentAppTarget) to playpause")
            isPlaying.toggle()
            updatePlaybackTimerState()
        }
    }

    func nextTrack() {
        if mediaSource == .safari || mediaSource == .web {
            sendSystemMediaKey(key: 17) // NX_KEYTYPE_NEXT
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.pollWebMediaState()
            }
        } else {
            runAppleScriptAsync("tell application \(currentAppTarget) to next track")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.pollCurrentMediaState()
            }
        }
    }

    func previousTrack() {
        if mediaSource == .safari || mediaSource == .web {
            sendSystemMediaKey(key: 18) // NX_KEYTYPE_PREVIOUS
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.pollWebMediaState()
            }
        } else {
            runAppleScriptAsync("tell application \(currentAppTarget) to previous track")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.pollCurrentMediaState()
            }
        }
    }

    func seek(to position: TimeInterval) {
        playbackPosition = position
        if mediaSource == .safari || mediaSource == .web {
            let jsSeek = "tell application \"Safari\" to try\nrepeat with w in windows\nrepeat with t in tabs of w\nset u to URL of t\nif u contains \"youtube.com\" or u contains \"spotify.com\" then\ndo JavaScript \"let v = document.querySelector('video') || document.querySelector('audio'); if (v) { v.currentTime = \(position); }\" in t\nreturn\nend if\nend repeat\nend repeat\nend try"
            runAppleScriptAsync(jsSeek)
        } else {
            runAppleScriptAsync("tell application \(currentAppTarget) to set player position to \(Int(position))")
        }
    }

    private func toggleWebPlayback() {
        isPlaying.toggle()
        updatePlaybackTimerState()
        let safariJSScript = """
        tell application "Safari"
            try
                repeat with w in windows
                    repeat with t in tabs of w
                        set u to URL of t
                        if u contains "youtube.com" or u contains "spotify.com" then
                            do JavaScript "let v = document.querySelector('video') || document.querySelector('audio'); if (v) { v.paused ? v.play() : v.pause(); }" in t
                            return "ok"
                        end if
                    end repeat
                end repeat
            on error
                return "err"
            end try
        end tell
        """
        appleScriptQueue.async { [weak self] in
            let res = self?.executeAppleScript(safariJSScript)
            if res != "ok" {
                self?.sendSystemMediaKey(key: 16) // NX_KEYTYPE_PLAY
            }
        }
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
                let script = """
                tell application id "com.apple.Music"
                    try
                        set artData to raw data of artwork 1 of current track
                        return artData
                    on error
                        return ""
                    end try
                end tell
                """
                if let raw = self?.executeAppleScript(script), !raw.isEmpty {
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
            // Tier 1: Search by track_name & artist_name
            searchLRCLIB(track: cleanTrack, artist: cleanArtist) { [weak self] success in
                guard let self = self else { return }
                if !success {
                    // Tier 2: Search with query q=artist+track
                    self.searchLRCLIBGeneral(query: "\(cleanArtist) \(cleanTrack)") { success2 in
                        if !success2 {
                            // Tier 3: Search with cleanTrack alone
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
                        self.syncedLyrics = self.parseLRC(syncedLRC)
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

    private func parseLRC(_ lrc: String) -> [LyricLine] {
        var result: [LyricLine] = []
        let lines = lrc.components(separatedBy: "\n")

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("[") else { continue }

            var remaining = trimmed
            var timestamps: [TimeInterval] = []

            while remaining.hasPrefix("["), let closeIdx = remaining.firstIndex(of: "]") {
                let tag = String(remaining[remaining.index(after: remaining.startIndex)..<closeIdx])
                remaining = String(remaining[remaining.index(after: closeIdx)...]).trimmingCharacters(in: .whitespaces)

                let parts = tag.components(separatedBy: ":")
                if parts.count == 2,
                   let mins = Double(parts[0]),
                   let secs = Double(parts[1]) {
                    timestamps.append(mins * 60.0 + secs)
                }
            }

            let text = remaining.trimmingCharacters(in: .whitespaces)
            if !text.isEmpty {
                for ts in timestamps {
                    result.append(LyricLine(time: ts, text: text))
                }
            }
        }

        return result.sorted(by: { $0.time < $1.time })
    }

    private func executeAppleScript(_ scriptText: String) -> String? {
        var result: String?
        let work = { [weak self] in
            guard let self = self else { return }
            var error: NSDictionary?
            let scriptObject: NSAppleScript
            if let cached = self.scriptCache[scriptText] {
                scriptObject = cached
            } else {
                guard let newScript = NSAppleScript(source: scriptText) else { return }
                self.scriptCache[scriptText] = newScript
                scriptObject = newScript
            }

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

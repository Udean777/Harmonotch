//
//  MediaManager.swift
//  Harmonotch
//

import Foundation
import AppKit
import Combine

struct LyricLine: Identifiable, Hashable {
    let id = UUID()
    let time: TimeInterval
    let text: String
}

enum MediaSource: String {
    case spotify = "Spotify"
    case appleMusic = "Apple Music"
    case none = "None"
}

final class MediaManager: ObservableObject {
    static let shared = MediaManager()

    // MARK: - Published Properties
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

    // MARK: - Private Properties
    private var playbackTimer: AnyCancellable?
    private var lastFetchedTrackKey: String = ""
    private var cancellables = Set<AnyCancellable>()

    private init() {
        setupDistributedNotificationObservers()
        startPeriodicSyncTimer()
        pollCurrentMediaState()
    }

    // MARK: - Distributed Notification Observers (Push Event Driven)
    private func setupDistributedNotificationObservers() {
        let center = DistributedNotificationCenter.default()

        // Spotify Notification
        center.addObserver(
            forName: NSNotification.Name("com.spotify.client.PlaybackStateChanged"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleSpotifyNotification(notification)
        }

        // Apple Music Notification
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
        isPlaying: Bool
    ) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.mediaSource = source
            self.isPlaying = isPlaying

            let trackChanged = (self.trackTitle != title || self.artistName != artist)
            if position > 0 || trackChanged {
                self.playbackPosition = position
            }
            if duration > 0 { self.duration = duration }

            self.trackTitle = title
            self.artistName = artist
            self.albumName = album

            if trackChanged && !title.isEmpty {
                self.fetchArtworkAsync(source: source)
                self.fetchLyrics(track: title, artist: artist, album: album, duration: duration)
            }

            self.updateCurrentLyric()
        }
    }

    // MARK: - Playback Timer & Position Tracking
    private func startPeriodicSyncTimer() {
        playbackTimer = Timer.publish(every: 0.25, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                if self.isPlaying && self.duration > 0 {
                    self.playbackPosition += 0.25
                    if self.playbackPosition > self.duration {
                        self.playbackPosition = self.duration
                    }
                    self.updateCurrentLyric()
                }
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

    // MARK: - Polling Fallback (Bila Aplikasi Dibuka Langsung)
    func pollCurrentMediaState() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            // Cek Spotify via AppleScript
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
                    self?.updateTrack(source: .spotify, title: title, artist: artist, album: album, duration: duration, position: pos, isPlaying: isPlaying)
                    return
                }
            }

            // Cek Apple Music via AppleScript
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
                    self?.updateTrack(source: .appleMusic, title: title, artist: artist, album: album, duration: duration, position: pos, isPlaying: isPlaying)
                }
            }
        }
    }

    private var currentAppTarget: String {
        return (mediaSource == .appleMusic) ? "id \"com.apple.Music\"" : "id \"com.spotify.client\""
    }

    // MARK: - Playback Controls
    func playPause() {
        runAppleScriptAsync("tell application \(currentAppTarget) to playpause")
        isPlaying.toggle()
    }

    func nextTrack() {
        runAppleScriptAsync("tell application \(currentAppTarget) to next track")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.pollCurrentMediaState()
        }
    }

    func previousTrack() {
        runAppleScriptAsync("tell application \(currentAppTarget) to previous track")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.pollCurrentMediaState()
        }
    }

    func seek(to position: TimeInterval) {
        playbackPosition = position
        runAppleScriptAsync("tell application \(currentAppTarget) to set player position to \(Int(position))")
    }

    // MARK: - Artwork Fetching
    private func fetchArtworkAsync(source: MediaSource) {
        if source == .spotify {
            DispatchQueue.global(qos: .utility).async { [weak self] in
                let script = "tell application id \"com.spotify.client\" to get artwork url of current track"
                if let urlString = self?.executeAppleScript(script), let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)) {
                    URLSession.shared.dataTask(with: url) { data, _, _ in
                        if let data = data, let image = NSImage(data: data) {
                            DispatchQueue.main.async {
                                self?.artworkImage = image
                            }
                        }
                    }.resume()
                }
            }
        } else if source == .appleMusic {
            DispatchQueue.global(qos: .utility).async { [weak self] in
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
                    // AppleScript raw artwork fallback
                }
            }
        }
    }

    // MARK: - Track Title & Artist Sanitization
    private func sanitizeTrackTitle(_ title: String) -> String {
        var clean = title
        // Hapus (feat. ...) / [feat. ...]
        clean = clean.replacingOccurrences(of: #"\s*[\(\[](?:feat\.|featuring|with).*?[\)\]]"#, with: "", options: [.regularExpression, .caseInsensitive])
        // Hapus - Remastered / (Remastered) / (Live) / dsb.
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

    // MARK: - Synced Lyrics Fetching (LRCLIB Multi-Tier Search)
    func fetchLyrics(track: String, artist: String, album: String, duration: TimeInterval) {
        let cleanTrack = sanitizeTrackTitle(track)
        let cleanArtist = sanitizeArtistName(artist)
        let key = "\(cleanTrack.lowercased())--\(cleanArtist.lowercased())"

        if key == lastFetchedTrackKey && !syncedLyrics.isEmpty {
            return
        }

        DispatchQueue.main.async {
            self.isLoadingLyrics = true
            self.syncedLyrics = []
            self.currentLyricIndex = -1
            self.currentLyricText = ""
            self.isInstrumental = false
        }

        // Tier 1: Search by track_name & artist_name
        searchLRCLIB(track: cleanTrack, artist: cleanArtist) { [weak self] success in
            guard let self = self else { return }
            if !success {
                // Tier 2: Search with query q=artist+track
                self.searchLRCLIBGeneral(query: "\(cleanArtist) \(cleanTrack)") { success2 in
                    if !success2 {
                        // Tier 3: Apple Music local lyrics fallback
                        self.fetchAppleMusicLocalLyrics()
                    }
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
                // Prioritaskan item yang memiliki syncedLyrics tidak kosong
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

            if !syncedLRC.isEmpty || !plainLyrics.isEmpty || instrumental {
                DispatchQueue.main.async {
                    self.isLoadingLyrics = false
                    self.isInstrumental = instrumental
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

        DispatchQueue.global(qos: .utility).async { [weak self] in
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

    // MARK: - AppleScript Helpers
    private func executeAppleScript(_ scriptText: String) -> String? {
        var result: String?
        let work = {
            var error: NSDictionary?
            if let scriptObject = NSAppleScript(source: scriptText) {
                let output = scriptObject.executeAndReturnError(&error)
                if error == nil {
                    result = output.stringValue
                } else if let error = error {
                    NSLog("[Harmonotch:Media] executeAppleScript error: %@", error)
                }
            }
        }

        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.sync(execute: work)
        }
        return result
    }

    private func runAppleScriptAsync(_ scriptText: String) {
        DispatchQueue.main.async {
            var error: NSDictionary?
            if let scriptObject = NSAppleScript(source: scriptText) {
                scriptObject.executeAndReturnError(&error)
                if let error = error {
                    NSLog("[Harmonotch:Media] AppleScript command '%@' failed: %@", scriptText, error)
                }
            }
        }
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

import Foundation

extension MediaManager {
  func updateCurrentLyric() {
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
      currentLyricText =
        (matchedIndex >= 0 && matchedIndex < syncedLyrics.count)
        ? syncedLyrics[matchedIndex].text : ""
    }
  }

  func sanitizeTrackTitle(_ title: String) -> String {
    var clean = title
    clean = clean.replacingOccurrences(
      of: #"\s*[\(\[](?:feat\.|featuring|with).*?[\)\]]"#, with: "",
      options: [.regularExpression, .caseInsensitive])
    clean = clean.replacingOccurrences(
      of: #"\s*[-–—]\s*(?:Remastered|Live|Acoustic|Single|Bonus Track|Radio Edit).*"#, with: "",
      options: [.regularExpression, .caseInsensitive])
    clean = clean.replacingOccurrences(
      of: #"\s*[\(\[](?:Remastered|Deluxe|Live|Acoustic|Radio Edit|Bonus).*?[\)\]]"#, with: "",
      options: [.regularExpression, .caseInsensitive])
    let trimmed = clean.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? title : trimmed
  }

  func sanitizeArtistName(_ artist: String) -> String {
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

    guard !cleanTrack.isEmpty else {
      DispatchQueue.main.async {
        self.isLoadingLyrics = false
        self.lyricsStatus = .idle
        self.syncedLyrics = []
        self.unsyncedLyrics = []
        self.currentLyricIndex = -1
        self.currentLyricText = ""
        self.isInstrumental = false
      }
      return
    }

    if let cached = lyricsCache[key] {
      DispatchQueue.main.async {
        self.isLoadingLyrics = false
        self.lyricsStatus = cached.status
        self.syncedLyrics = cached.synced
        self.unsyncedLyrics = cached.unsynced
        self.isInstrumental = cached.isInstrumental
        if self.duration == 0 && cached.duration > 0 {
          self.duration = cached.duration
        }
        self.lastFetchedTrackKey = key
        self.updateCurrentLyric()
      }
      return
    }

    if key == lastFetchedTrackKey && lyricsStatus != .idle && lyricsStatus != .loading {
      return
    }

    DispatchQueue.main.async {
      self.isLoadingLyrics = true
      self.lyricsStatus = .loading
      self.syncedLyrics = []
      self.unsyncedLyrics = []
      self.currentLyricIndex = -1
      self.currentLyricText = ""
      self.isInstrumental = false
    }

    let isGenericArtist =
      (cleanArtist.isEmpty || cleanArtist == "YouTube" || cleanArtist == "YouTube Music"
        || cleanArtist == "Spotify Web")

    if !isGenericArtist {
      searchLRCLIB(track: cleanTrack, artist: cleanArtist) { [weak self] success in
        guard let self = self else { return }
        if !success {
          self.searchLRCLIBGeneral(query: "\(cleanArtist) \(cleanTrack)") { success2 in
            if !success2 {
              self.searchLRCLIBGeneral(query: cleanTrack) { success3 in
                if !success3 {
                  self.fetchAppleMusicLocalLyrics(key: key)
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
          self.fetchAppleMusicLocalLyrics(key: key)
        }
      }
    }
  }

  private func searchLRCLIB(track: String, artist: String, completion: @escaping (Bool) -> Void) {
    guard var components = URLComponents(string: "https://lrclib.net/api/search") else {
      completion(false)
      return
    }
    components.queryItems = [
      URLQueryItem(name: "track_name", value: track),
      URLQueryItem(name: "artist_name", value: artist),
    ]

    guard let url = components.url else {
      completion(false)
      return
    }

    performLyricsRequest(url: url, track: track, artist: artist, completion: completion)
  }

  private func searchLRCLIBGeneral(query: String, completion: @escaping (Bool) -> Void) {
    guard var components = URLComponents(string: "https://lrclib.net/api/search") else {
      completion(false)
      return
    }
    components.queryItems = [
      URLQueryItem(name: "q", value: query)
    ]

    guard let url = components.url else {
      completion(false)
      return
    }

    performLyricsRequest(url: url, track: query, artist: "", completion: completion)
  }

  private func performLyricsRequest(
    url: URL, track: String, artist: String, completion: @escaping (Bool) -> Void
  ) {
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

      struct LRCLIBTrackRecord: Decodable {
        let syncedLyrics: String?
        let plainLyrics: String?
        let instrumental: Bool?
        let duration: Double?
      }

      var matchedItem: LRCLIBTrackRecord? = nil

      if let array = try? JSONDecoder().decode([LRCLIBTrackRecord].self, from: data) {
        let currentDuration = self.duration
        if currentDuration > 0 {
          matchedItem = array.first(where: { item in
            guard let s = item.syncedLyrics,
              !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
            let itemDur = item.duration ?? 0
            return itemDur > 0 ? abs(itemDur - currentDuration) <= 15 : true
          })
        }
        if matchedItem == nil {
          matchedItem = array.first(where: {
            guard let s = $0.syncedLyrics else { return false }
            return !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
          })
        }
        if matchedItem == nil {
          matchedItem = array.first(where: {
            let plain = $0.plainLyrics ?? ""
            let instrumental = $0.instrumental ?? false
            return !plain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || instrumental
          }) ?? array.first
        }
      } else if let dict = try? JSONDecoder().decode(LRCLIBTrackRecord.self, from: data) {
        matchedItem = dict
      }

      guard let item = matchedItem else {
        completion(false)
        return
      }

      let instrumental = item.instrumental ?? false
      let syncedLRC = item.syncedLyrics ?? ""
      let plainLyrics = item.plainLyrics ?? ""
      let trackDuration = item.duration ?? 0

      var verifiedSyncedLyrics: [LyricLine] = []
      if !syncedLRC.isEmpty {
        let parsed = LRCParser.parse(syncedLRC)
        let hasDistinctTimestamps = parsed.count > 1 && (parsed.last?.time ?? 0) > (parsed.first?.time ?? 0)
        if hasDistinctTimestamps {
          verifiedSyncedLyrics = parsed
        }
      }

      var extractedPlainLines: [String] = []
      if !plainLyrics.isEmpty {
        extractedPlainLines = plainLyrics.components(separatedBy: "\n")
          .map { $0.trimmingCharacters(in: .whitespaces) }
          .filter { !$0.isEmpty }
      } else if !syncedLRC.isEmpty && verifiedSyncedLyrics.isEmpty {
        extractedPlainLines = syncedLRC.components(separatedBy: "\n")
          .map { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if let closeIdx = trimmed.lastIndex(of: "]") {
              return String(trimmed[trimmed.index(after: closeIdx)...]).trimmingCharacters(in: .whitespaces)
            }
            return trimmed
          }
          .filter { !$0.isEmpty }
      }

      if !verifiedSyncedLyrics.isEmpty || !extractedPlainLines.isEmpty || instrumental {
        DispatchQueue.main.async {
          self.isLoadingLyrics = false
          self.isInstrumental = instrumental
          if self.duration == 0 && trackDuration > 0 {
            self.duration = trackDuration
          }

          if instrumental {
            self.syncedLyrics = []
            self.unsyncedLyrics = []
            self.lyricsStatus = .instrumental
          } else if !verifiedSyncedLyrics.isEmpty {
            self.syncedLyrics = verifiedSyncedLyrics
            self.unsyncedLyrics = []
            self.lyricsStatus = .synced(verifiedSyncedLyrics)
            NSLog(
              "[Harmonotch:Media] Successfully parsed %ld synced lyric lines for %@ - %@",
              verifiedSyncedLyrics.count, track, artist)
          } else if !extractedPlainLines.isEmpty {
            self.syncedLyrics = []
            self.unsyncedLyrics = extractedPlainLines
            self.lyricsStatus = .unsynced(extractedPlainLines)
            NSLog(
              "[Harmonotch:Media] Detected %ld unsynced plain lyric lines for %@ - %@",
              extractedPlainLines.count, track, artist)
          }

          let cleanTrackTitle = self.sanitizeTrackTitle(track)
          let cleanArtistName = self.sanitizeArtistName(artist)
          let cacheKey = "\(cleanTrackTitle.lowercased())--\(cleanArtistName.lowercased())"
          self.lastFetchedTrackKey = cacheKey
          self.lyricsCache[cacheKey] = (
            status: self.lyricsStatus,
            synced: self.syncedLyrics,
            unsynced: self.unsyncedLyrics,
            isInstrumental: self.isInstrumental,
            duration: self.duration
          )
          self.updateCurrentLyric()
        }
        completion(true)
      } else {
        completion(false)
      }
    }.resume()
  }

  private func fetchAppleMusicLocalLyrics(key: String) {
    guard mediaSource == .appleMusic else {
      DispatchQueue.main.async {
        self.isLoadingLyrics = false
        let desc = L10n.Media.lyricsUnavailableDesc
        self.lyricsStatus = .unavailable(desc)
        self.syncedLyrics = []
        self.unsyncedLyrics = []
        self.lyricsCache[key] = (
          status: .unavailable(desc),
          synced: [],
          unsynced: [],
          isInstrumental: false,
          duration: self.duration
        )
      }
      return
    }

    AppleScriptRunner.queue.async { [weak self] in
      let script = """
        tell application "Music"
            try
                return lyrics of current track
            on error
                return ""
            end try
        end tell
        """
      if let text = AppleScriptRunner.execute(script),
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      {
        let lines = text.components(separatedBy: "\n")
          .map { $0.trimmingCharacters(in: .whitespaces) }
          .filter { !$0.isEmpty }
        DispatchQueue.main.async {
          guard let self = self else { return }
          self.isLoadingLyrics = false
          self.syncedLyrics = []
          self.unsyncedLyrics = lines
          self.isInstrumental = false
          self.lyricsStatus = .unsynced(lines)
          self.lastFetchedTrackKey = key
          self.lyricsCache[key] = (
            status: .unsynced(lines),
            synced: [],
            unsynced: lines,
            isInstrumental: false,
            duration: self.duration
          )
          self.updateCurrentLyric()
        }
      } else {
        DispatchQueue.main.async {
          guard let self = self else { return }
          self.isLoadingLyrics = false
          self.syncedLyrics = []
          self.unsyncedLyrics = []
          self.isInstrumental = false
          let desc = L10n.Media.lyricsUnavailableDesc
          self.lyricsStatus = .unavailable(desc)
          self.lastFetchedTrackKey = key
          self.lyricsCache[key] = (
            status: .unavailable(desc),
            synced: [],
            unsynced: [],
            isInstrumental: false,
            duration: self.duration
          )
        }
      }
    }
  }
}

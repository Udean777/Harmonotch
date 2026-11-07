import Foundation

/// Pure deterministic selector that chooses the single active media session
/// among all candidates based on arbitration priority rules.
public struct MediaSelector {

  /// Picks the winner: a playing candidate always beats a paused one. Among paused candidates
  /// the previous winner and system player act as sticky tie-breaks. Nil when empty.
  public static func select(
    candidates: [MediaCandidate],
    previous: MediaIdentity? = nil,
    system: MediaIdentity? = nil,
    userSelection: MediaIdentity? = nil,
    frontmostBundleID: String? = nil
  ) -> MediaCandidate? {
    guard !candidates.isEmpty else { return nil }

    let playing = candidates.filter { $0.isPlaying }

    // Core rule 1: Paused never beats playing from ANY app.
    // If there is at least one playing candidate, the winner MUST be playing.
    if !playing.isEmpty {
      return selectPlaying(
        candidates: playing,
        userSelection: userSelection,
        frontmostBundleID: frontmostBundleID
      )
    }

    // Core rule 2: If all candidates are paused, follow sticky / metadata hierarchy.
    return selectPaused(
      candidates: candidates,
      previous: previous,
      system: system,
      userSelection: userSelection
    )
  }

  /// Drops playing MediaRemote candidates that the bridge stopped refreshing.
  /// A closed tab or quit client never sends a final pause line, so without
  /// this its last "playing" state outranks every player that comes after it.
  public static func pruneStale(
    _ candidates: [MediaCandidate],
    now: TimeInterval = Date().timeIntervalSince1970,
    maxAge: TimeInterval = 6
  ) -> [MediaCandidate] {
    candidates.filter { candidate in
      guard candidate.awareness == .mediaRemote, candidate.isPlaying else { return true }
      return now - candidate.lastUpdated <= maxAge
    }
  }

  // MARK: - Playing Arbitration

  private static func selectPlaying(
    candidates: [MediaCandidate],
    userSelection: MediaIdentity?,
    frontmostBundleID: String?
  ) -> MediaCandidate? {
    // 1. User manual selection (if currently playing)
    if let userSel = userSelection,
       let match = candidates.first(where: { matches(identity: $0.identity, target: userSel) }) {
      return match
    }

    // 2. Candidates with metadata
    let withMetadata = candidates.filter { $0.hasMetadata }
    if !withMetadata.isEmpty {
      // 2a. Music apps playing with metadata win first
      let musicApps = withMetadata.filter { $0.isMusicApp }
      if let bestMusic = pickBest(from: musicApps, frontmostBundleID: frontmostBundleID) {
        return bestMusic
      }

      // 2b. Other apps playing with metadata (e.g. YouTube in browser, VLC, IINA)
      if let bestOther = pickBest(from: withMetadata, frontmostBundleID: frontmostBundleID) {
        return bestOther
      }
    }

    // 3. Audio-only presence candidates playing (e.g. Zoom, Teams, games, system apps)
    let audioOnly = candidates.filter { !$0.hasMetadata }
    return pickBest(from: audioOnly, frontmostBundleID: frontmostBundleID)
  }

  // MARK: - Paused Arbitration

  private static func selectPaused(
    candidates: [MediaCandidate],
    previous: MediaIdentity?,
    system: MediaIdentity?,
    userSelection: MediaIdentity?
  ) -> MediaCandidate? {
    // 1. User manual selection
    if let userSel = userSelection,
       let match = candidates.first(where: { matches(identity: $0.identity, target: userSel) }) {
      return match
    }

    // 2. Previous candidate (sticky paused session)
    if let prev = previous,
       let match = candidates.first(where: { matches(identity: $0.identity, target: prev) }) {
      return match
    }

    // 3. System player as tie-break
    if let sys = system,
       let match = candidates.first(where: { matches(identity: $0.identity, target: sys) }) {
      return match
    }

    // 4. Candidates with metadata (music apps prioritized)
    let withMetadata = candidates.filter { $0.hasMetadata }
    if let bestMusic = withMetadata.filter({ $0.isMusicApp }).max(by: { $0.lastUpdated < $1.lastUpdated }) {
      return bestMusic
    }
    if let bestMeta = withMetadata.max(by: { $0.lastUpdated < $1.lastUpdated }) {
      return bestMeta
    }

    // 5. Fall back to most recently updated candidate
    return candidates.max(by: { $0.lastUpdated < $1.lastUpdated })
  }

  // MARK: - Tie-breaking

  private static func pickBest(
    from pool: [MediaCandidate],
    frontmostBundleID: String?
  ) -> MediaCandidate? {
    guard !pool.isEmpty else { return nil }
    guard pool.count > 1 else { return pool.first }

    return pool.sorted { a, b in
      // Earlier started playing wins
      let aStart = a.startedPlayingAt ?? a.lastUpdated
      let bStart = b.startedPlayingAt ?? b.lastUpdated
      if abs(aStart - bStart) > 0.05 {
        return aStart < bStart
      }

      // Frontmost application wins
      if let frontmost = frontmostBundleID {
        let aFront = a.app.bundleID == frontmost
        let bFront = b.app.bundleID == frontmost
        if aFront != bFront {
          return aFront
        }
      }

      // Most recently updated wins
      return a.lastUpdated > b.lastUpdated
    }.first
  }

  private static func matches(identity: MediaIdentity, target: MediaIdentity) -> Bool {
    if identity == target { return true }
    // Match by bundleID if contentID / pid are not specified
    if target.contentID == nil && target.pid == nil {
      return identity.bundleID == target.bundleID
    }
    return false
  }
}

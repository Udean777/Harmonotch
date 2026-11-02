import Foundation

enum ProcessActivityRanking {
  static let defaultLimit = 3
  /// Entries below this CPU percentage are treated as idle.
  static let minimumPercent = 0.1

  /// Ranks applications by CPU time used between two samples.
  ///
  /// Processes missing from `previous`, with a different start time (PID reuse),
  /// or whose counter went backwards are skipped rather than guessed at.
  static func rank(
    previous: ProcessCounterSample,
    current: ProcessCounterSample,
    limit: Int = defaultLimit
  ) -> [ProcessActivityEntry] {
    let interval = current.takenAt - previous.takenAt
    guard interval > 0, limit > 0 else { return [] }

    var previousByPID: [pid_t: ProcessCounter] = [:]
    for counter in previous.counters { previousByPID[counter.pid] = counter }

    struct Group {
      var name: String
      var rootPID: pid_t
      var deltaNanos: UInt64 = 0
      var processCount = 0
    }
    var groups: [String: Group] = [:]

    for counter in current.counters {
      guard let before = previousByPID[counter.pid],
            before.startTime == counter.startTime,
            counter.cpuTimeNanos >= before.cpuTimeNanos else { continue }
      let delta = counter.cpuTimeNanos - before.cpuTimeNanos
      var group = groups[counter.groupKey] ?? Group(name: counter.name, rootPID: counter.rootPID)
      group.deltaNanos &+= delta
      group.processCount += 1
      if counter.pid == counter.rootPID { group.rootPID = counter.rootPID }
      groups[counter.groupKey] = group
    }

    let entries = groups.compactMap { key, group -> ProcessActivityEntry? in
      let percent = Double(group.deltaNanos) / (interval * 1_000_000_000) * 100
      guard percent >= minimumPercent else { return nil }
      return ProcessActivityEntry(
        groupKey: key,
        name: group.name,
        cpuPercent: percent,
        processCount: group.processCount,
        representativePID: group.rootPID
      )
    }

    return entries
      .sorted {
        if $0.cpuPercent != $1.cpuPercent { return $0.cpuPercent > $1.cpuPercent }
        return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
      }
      .prefix(limit)
      .map { $0 }
  }
}

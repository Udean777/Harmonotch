import Foundation

/// Cumulative CPU time of one process at the moment it was sampled.
struct ProcessCounter: Equatable {
  let pid: pid_t
  /// PID of the application this process belongs to (the process itself for a root app).
  let rootPID: pid_t
  /// Stable key used to group helper processes and multiple instances of one app.
  let groupKey: String
  let name: String
  /// Process start time; a different value for the same PID means the PID was reused.
  let startTime: UInt64
  /// User + system CPU time in nanoseconds since the process started.
  let cpuTimeNanos: UInt64
}

struct ProcessCounterSample: Equatable {
  var counters: [ProcessCounter]
  /// Application-owned processes whose counters could not be read.
  var unreadableCount: Int
  var takenAt: TimeInterval
}

struct ProcessActivityEntry: Equatable, Identifiable {
  var id: String { groupKey }
  let groupKey: String
  let name: String
  /// CPU time used per second of wall time, in percent of one core. Can exceed 100.
  let cpuPercent: Double
  let processCount: Int
  /// A PID that can be used to look up the application icon.
  let representativePID: pid_t
}

struct ProcessActivitySnapshot: Equatable {
  let entries: [ProcessActivityEntry]
  /// Wall time between the two samples the deltas were computed from.
  let samplingInterval: TimeInterval
  /// True when some application processes could not be read.
  let isPartial: Bool
  let refreshedAt: Date
}

protocol ProcessCounterSampling: Sendable {
  func sample() throws -> ProcessCounterSample
}

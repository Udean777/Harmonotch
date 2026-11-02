import AppKit
import Darwin
import Foundation

/// Reads per-process CPU time with `proc_pid_rusage`. Helper processes are
/// attributed to the user-facing application they descend from.
struct SystemProcessCounterSampler: ProcessCounterSampling {
  private static let maxParentDepth = 8

  func sample() throws -> ProcessCounterSample {
    let apps = Self.runningApplications()
    guard !apps.isEmpty else { throw ProcessActivityError.sampleFailed }

    let pids = try Self.allPIDs()
    var parents: [pid_t: pid_t] = [:]
    for pid in pids {
      var info = proc_bsdinfo()
      let size = proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, Int32(MemoryLayout<proc_bsdinfo>.size))
      if size == Int32(MemoryLayout<proc_bsdinfo>.size) {
        parents[pid] = pid_t(info.pbi_ppid)
      }
    }

    var timebase = mach_timebase_info_data_t()
    mach_timebase_info(&timebase)
    let numer = UInt64(timebase.numer)
    let denom = UInt64(max(timebase.denom, 1))

    var counters: [ProcessCounter] = []
    var unreadable = 0

    for pid in pids {
      guard let root = Self.rootApp(for: pid, parents: parents, apps: apps) else { continue }
      guard let usage = Self.rusage(pid) else {
        unreadable += 1
        continue
      }
      let cpuTicks = usage.ri_user_time &+ usage.ri_system_time
      counters.append(
        ProcessCounter(
          pid: pid,
          rootPID: root.pid,
          groupKey: root.key,
          name: root.name,
          startTime: usage.ri_proc_start_abstime,
          cpuTimeNanos: cpuTicks / denom &* numer
        )
      )
    }

    return ProcessCounterSample(
      counters: counters,
      unreadableCount: unreadable,
      takenAt: ProcessInfo.processInfo.systemUptime
    )
  }

  private struct AppRoot {
    let pid: pid_t
    let key: String
    let name: String
  }

  private static func runningApplications() -> [pid_t: AppRoot] {
    let read = {
      var result: [pid_t: AppRoot] = [:]
      for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
        let pid = app.processIdentifier
        guard pid > 0, !app.isTerminated else { continue }
        let name = app.localizedName ?? app.bundleURL?.deletingPathExtension().lastPathComponent ?? "PID \(pid)"
        let key = app.bundleIdentifier ?? "name:\(name)"
        result[pid] = AppRoot(pid: pid, key: key, name: name)
      }
      return result
    }
    return Thread.isMainThread ? read() : DispatchQueue.main.sync(execute: read)
  }

  private static func rootApp(for pid: pid_t, parents: [pid_t: pid_t], apps: [pid_t: AppRoot]) -> AppRoot? {
    var current = pid
    for _ in 0...maxParentDepth {
      if let app = apps[current] { return app }
      guard let parent = parents[current], parent > 1, parent != current else { return nil }
      current = parent
    }
    return nil
  }

  private static func allPIDs() throws -> [pid_t] {
    let estimate = proc_listallpids(nil, 0)
    guard estimate > 0 else { throw ProcessActivityError.sampleFailed }
    var buffer = [pid_t](repeating: 0, count: Int(estimate) + 64)
    let count = proc_listallpids(&buffer, Int32(buffer.count * MemoryLayout<pid_t>.size))
    guard count > 0 else { throw ProcessActivityError.sampleFailed }
    return buffer.prefix(Int(count)).filter { $0 > 0 }
  }

  private static func rusage(_ pid: pid_t) -> rusage_info_v4? {
    var info = rusage_info_v4()
    let status = withUnsafeMutablePointer(to: &info) {
      $0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
        proc_pid_rusage(pid, RUSAGE_INFO_V4, $0)
      }
    }
    return status == 0 ? info : nil
  }
}

extension ProcessActivityMonitor {
  static let shared = ProcessActivityMonitor(sampler: SystemProcessCounterSampler())
}

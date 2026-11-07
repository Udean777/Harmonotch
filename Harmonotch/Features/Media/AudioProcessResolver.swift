import AppKit
import Foundation
import Darwin

public struct AudioProcessResolver {
  public static let maxParentDepth: Int = 4

  public static let excludedProcessNames: Set<String> = [
    "coreaudiod",
    "audioclocksyncd",
    "launchd",
    "kernel_task",
    "controlcenter",
    "systemsoundserverd"
  ]

  public static let excludedBundleIDs: Set<String> = [
    "com.apple.audio.coreaudiod",
    "com.apple.controlcenter",
    "com.apple.systemsoundserverd"
  ]

  /// Queries the parent PID of a given process using sysctl.
  public static func parentPID(of pid: pid_t) -> pid_t? {
    guard pid > 0 else { return nil }

    var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
    var info = kinfo_proc()
    var size = MemoryLayout<kinfo_proc>.stride

    let status = sysctl(&mib, u_int(mib.count), &info, &size, nil, 0)
    guard status == 0, size > 0 else { return nil }

    let ppid = info.kp_eproc.e_ppid
    guard ppid > 0, ppid != pid else { return nil }
    return ppid
  }

  /// Determines if a bundleID represents a helper/secondary process that should be traced to its parent.
  public static func isHelperBundleID(_ bundleID: String) -> Bool {
    let lower = bundleID.lowercased()
    return lower.contains("helper") ||
           lower.contains("webkit") ||
           lower.contains("renderer") ||
           lower.contains("gpu") ||
           lower.contains("plugin")
  }

  /// Resolves the user-facing app behind an audio process. `parentLookup` and `appLookup` exist for tests.
  public static func resolveResponsibleApp(
    pid: pid_t,
    reportedBundleID: String? = nil,
    currentPID: pid_t = getpid(),
    parentLookup: ((pid_t) -> pid_t?)? = nil,
    appLookup: ((pid_t) -> (bundleID: String, name: String, isAppBundle: Bool)?)? = nil
  ) -> MediaAppInfo? {
    guard pid > 0, pid != currentPID else { return nil }

    let getParent = parentLookup ?? { parentPID(of: $0) }
    let getAppInfo = appLookup ?? { defaultAppLookup(pid: $0) }

    var currentTargetPID = pid
    var depth = 0

    // Initial check on the reported bundle ID if provided
    if let reported = reportedBundleID?.trimmingCharacters(in: .whitespacesAndNewlines),
       !reported.isEmpty {
      if excludedBundleIDs.contains(reported.lowercased()) {
        return nil
      }
      // If the reported bundle is a direct app (not helper), resolve it directly
      if !isHelperBundleID(reported),
         let app = getAppInfo(pid), app.isAppBundle {
        return MediaAppInfo.resolve(bundleID: app.bundleID, preferredName: app.name)
      }
    }

    // Traverse parent hierarchy up to maxParentDepth
    while depth <= maxParentDepth && currentTargetPID > 1 {
      if currentTargetPID == currentPID {
        return nil
      }

      if let info = getAppInfo(currentTargetPID) {
        let lowerName = info.name.lowercased()
        let lowerBundle = info.bundleID.lowercased()

        if excludedProcessNames.contains(lowerName) || excludedBundleIDs.contains(lowerBundle) {
          return nil
        }

        // If it's a full .app bundle and not a helper process, this is our responsible app!
        if info.isAppBundle && !isHelperBundleID(info.bundleID) {
          return MediaAppInfo.resolve(bundleID: info.bundleID, preferredName: info.name)
        }
      }

      // Step up to parent process
      guard let ppid = getParent(currentTargetPID), ppid != currentTargetPID else {
        break
      }
      currentTargetPID = ppid
      depth += 1
    }

    // Fallback: If reported bundle ID was given, resolve it even if helper tracing didn't find parent
    if let reported = reportedBundleID?.trimmingCharacters(in: .whitespacesAndNewlines),
       !reported.isEmpty, !excludedBundleIDs.contains(reported.lowercased()) {
      return MediaAppInfo.resolve(bundleID: reported)
    }

    return nil
  }

  private static func defaultAppLookup(pid: pid_t) -> (bundleID: String, name: String, isAppBundle: Bool)? {
    guard let app = NSRunningApplication(processIdentifier: pid) else {
      return nil
    }

    let bundleID = app.bundleIdentifier ?? ""
    let name = app.localizedName ?? ""
    let isApp = app.bundleURL?.pathExtension == "app"

    return (bundleID: bundleID, name: name, isAppBundle: isApp)
  }
}

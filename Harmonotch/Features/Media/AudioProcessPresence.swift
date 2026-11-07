import AppKit
import Combine
import CoreAudio
import Foundation

/// Pure debounce and hysteresis tracker for audio process presence.
public struct AudioProcessPresenceTracker {
  public let startDebounceInterval: TimeInterval
  public let stopHysteresisInterval: TimeInterval

  private(set) public var activeConfirmedPIDs: Set<pid_t> = []
  private var firstSeenTimes: [pid_t: Date] = [:]
  private var lastSeenTimes: [pid_t: Date] = [:]

  public init(
    startDebounceInterval: TimeInterval = 1.5,
    stopHysteresisInterval: TimeInterval = 3.0
  ) {
    self.startDebounceInterval = startDebounceInterval
    self.stopHysteresisInterval = stopHysteresisInterval
  }

  /// Updates the tracker with newly detected PIDs that have active audio output.
  /// Returns the set of PIDs that are confirmed active (after debounce).
  public mutating func update(detectedPIDs: Set<pid_t>, now: Date = Date()) -> Set<pid_t> {
    // 1. Process currently detected PIDs
    for pid in detectedPIDs {
      lastSeenTimes[pid] = now

      if !activeConfirmedPIDs.contains(pid) {
        if let firstSeen = firstSeenTimes[pid] {
          if now.timeIntervalSince(firstSeen) >= startDebounceInterval {
            activeConfirmedPIDs.insert(pid)
          }
        } else {
          firstSeenTimes[pid] = now
        }
      }
    }

    // 2. Process PIDs that were previously detected but not in this sample
    var pidsToRemove: [pid_t] = []
    for pid in activeConfirmedPIDs where !detectedPIDs.contains(pid) {
      if let lastSeen = lastSeenTimes[pid] {
        if now.timeIntervalSince(lastSeen) >= stopHysteresisInterval {
          pidsToRemove.append(pid)
        }
      } else {
        pidsToRemove.append(pid)
      }
    }

    for pid in pidsToRemove {
      activeConfirmedPIDs.remove(pid)
      lastSeenTimes.removeValue(forKey: pid)
      firstSeenTimes.removeValue(forKey: pid)
    }

    // Clean up unconfirmed PIDs that stopped before reaching startDebounceInterval
    firstSeenTimes = firstSeenTimes.filter { pid, seenDate in
      detectedPIDs.contains(pid) || now.timeIntervalSince(seenDate) < 1.0
    }

    return activeConfirmedPIDs
  }

  public mutating func reset() {
    activeConfirmedPIDs.removeAll()
    firstSeenTimes.removeAll()
    lastSeenTimes.removeAll()
  }
}

/// CoreAudio HAL monitor that tracks audio processes and publishes active apps.
public final class AudioProcessPresenceMonitor: ObservableObject {
  public static let shared = AudioProcessPresenceMonitor()

  @Published public private(set) var activeApps: [MediaAppInfo] = []

  private var tracker = AudioProcessPresenceTracker()
  private let queue = DispatchQueue(label: "com.harmonotch.audioprocesspresence", qos: .utility)
  private var tickTimer: Timer?
  private var isListening: Bool = false
  private var listenerBlock: AudioObjectPropertyListenerBlock?

  public init() {}

  deinit {
    stop()
  }

  public func start() {
    queue.async { [weak self] in
      guard let self = self, !self.isListening else { return }
      self.isListening = true
      self.registerCoreAudioListener()

      DispatchQueue.main.async { [weak self] in
        self?.tickTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
          self?.tick()
        }
      }
      self.pollAudioProcesses()
    }
  }

  public func stop() {
    queue.async { [weak self] in
      guard let self = self, self.isListening else { return }
      self.isListening = false
      self.unregisterCoreAudioListener()

      DispatchQueue.main.async {
        self.tickTimer?.invalidate()
        self.tickTimer = nil
      }
    }
  }

  public func tick() {
    queue.async { [weak self] in
      self?.pollAudioProcesses()
    }
  }

  // MARK: - CoreAudio Interop

  private func registerCoreAudioListener() {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioHardwarePropertyProcessObjectList,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )

    let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
      self?.pollAudioProcesses()
    }
    listenerBlock = block

    let status = AudioObjectAddPropertyListenerBlock(
      AudioObjectID(kAudioObjectSystemObject),
      &address,
      queue,
      block
    )

    if status != noErr {
      // In environments where process list listener is restricted, timer polling acts as fallback
      #if DEBUG
        print("[AudioProcessPresence] Process list listener returned status: \(status)")
      #endif
      listenerBlock = nil
    }
  }

  private func unregisterCoreAudioListener() {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioHardwarePropertyProcessObjectList,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )

    guard let listenerBlock else { return }
    _ = AudioObjectRemovePropertyListenerBlock(
      AudioObjectID(kAudioObjectSystemObject),
      &address,
      queue,
      listenerBlock
    )
    self.listenerBlock = nil
  }

  private func pollAudioProcesses() {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioHardwarePropertyProcessObjectList,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )

    var dataSize: UInt32 = 0
    let sizeStatus = AudioObjectGetPropertyDataSize(
      AudioObjectID(kAudioObjectSystemObject),
      &address,
      0,
      nil,
      &dataSize
    )

    guard sizeStatus == noErr, dataSize > 0 else {
      updateActivePIDs(Set())
      return
    }

    let count = Int(dataSize) / MemoryLayout<AudioObjectID>.size
    var processIDs = [AudioObjectID](repeating: 0, count: count)

    let dataStatus = AudioObjectGetPropertyData(
      AudioObjectID(kAudioObjectSystemObject),
      &address,
      0,
      nil,
      &dataSize,
      &processIDs
    )

    guard dataStatus == noErr else {
      updateActivePIDs(Set())
      return
    }

    var runningOutputPIDs = Set<pid_t>()

    for processObj in processIDs {
      if isProcessRunningOutput(processObj) {
        if let pid = pidForProcessObject(processObj) {
          runningOutputPIDs.insert(pid)
        }
      }
    }

    updateActivePIDs(runningOutputPIDs)
  }

  private func isProcessRunningOutput(_ processObj: AudioObjectID) -> Bool {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioProcessPropertyIsRunningOutput,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )

    var isRunning: UInt32 = 0
    var size = UInt32(MemoryLayout<UInt32>.size)

    let status = AudioObjectGetPropertyData(processObj, &address, 0, nil, &size, &isRunning)
    return status == noErr && isRunning > 0
  }

  private func pidForProcessObject(_ processObj: AudioObjectID) -> pid_t? {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioProcessPropertyPID,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )

    var pid: pid_t = 0
    var size = UInt32(MemoryLayout<pid_t>.size)

    let status = AudioObjectGetPropertyData(processObj, &address, 0, nil, &size, &pid)
    guard status == noErr, pid > 0 else { return nil }
    return pid
  }

  private func updateActivePIDs(_ detectedPIDs: Set<pid_t>) {
    let confirmedPIDs = tracker.update(detectedPIDs: detectedPIDs, now: Date())

    var apps: [MediaAppInfo] = []
    var seenBundleIDs = Set<String>()

    for pid in confirmedPIDs {
      if let appInfo = AudioProcessResolver.resolveResponsibleApp(pid: pid) {
        if !seenBundleIDs.contains(appInfo.bundleID) {
          seenBundleIDs.insert(appInfo.bundleID)
          apps.append(appInfo)
        }
      }
    }

    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      if self.activeApps != apps {
        self.activeApps = apps
      }
    }
  }
}

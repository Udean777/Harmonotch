import AudioToolbox
import Combine
import CoreAudio
import Foundation

final class SystemAudioService: ObservableObject {
  static let shared = SystemAudioService()

  static let fullStep: Float = 1.0 / 16.0
  static let fineStep: Float = 1.0 / 64.0
  static let muteThreshold: Float = 0.005

  @Published private(set) var outputVolume: Float?
  @Published private(set) var isMuted: Bool?

  private(set) var isObserving = false
  private var observedDeviceID: AudioObjectID?
  private var registeredSystemSelectors: [AudioObjectPropertySelector] = []
  private var registeredDeviceAddresses: [AudioObjectPropertyAddress] = []
  private var refreshGeneration: UInt64 = 0

  private static let volumeSelectors: [AudioObjectPropertySelector] = [
    kAudioDevicePropertyVolumeScalar,
    kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
  ]

  private static let muteElements: [AudioObjectPropertyElement] = [
    kAudioObjectPropertyElementMain,
    1,
    2,
  ]

  private init() {}

  private var listenerClient: UnsafeMutableRawPointer {
    Unmanaged.passUnretained(self).toOpaque()
  }

  private static let systemListenerCallback: AudioObjectPropertyListenerProc = {
    _, _, _, client in
    guard let client else { return noErr }
    let service = Unmanaged<SystemAudioService>.fromOpaque(client).takeUnretainedValue()
    DispatchQueue.main.async {
      service.handleSystemPropertyChange()
    }
    return noErr
  }

  private static let deviceListenerCallback: AudioObjectPropertyListenerProc = {
    deviceID, _, _, client in
    guard let client else { return noErr }
    let service = Unmanaged<SystemAudioService>.fromOpaque(client).takeUnretainedValue()
    DispatchQueue.main.async {
      service.handleDevicePropertyChange(for: deviceID)
    }
    return noErr
  }

  // MARK: - Observation Lifecycle

  func startObserving() {
    if !Thread.isMainThread {
      DispatchQueue.main.async { [weak self] in self?.startObserving() }
      return
    }
    guard !isObserving else {
      refreshCurrentDeviceState()
      return
    }
    isObserving = true
    installSystemListener(selector: kAudioHardwarePropertyDefaultOutputDevice)
    installSystemListener(selector: kAudioHardwarePropertyDevices)
    refreshCurrentDeviceState()
  }

  func stopObserving() {
    if !Thread.isMainThread {
      DispatchQueue.main.async { [weak self] in self?.stopObserving() }
      return
    }
    guard isObserving else { return }
    isObserving = false
    refreshGeneration &+= 1
    removeDeviceListeners()
    removeSystemListeners()
    outputVolume = nil
    isMuted = nil
  }

  // MARK: - Public Controls

  @discardableResult
  func step(direction: Int, fine: Bool = false) -> Bool {
    guard direction != 0 else { return false }
    guard let deviceID = verifiedActiveDeviceID() else { return false }
    guard let currentVolume = Self.readVolume(for: deviceID) ?? outputVolume else {
      return false
    }
    let currentMuted = Self.readMute(for: deviceID) ?? isMuted ?? false
    let target = Self.targetVolume(
      current: currentVolume,
      muted: currentMuted,
      direction: direction,
      fine: fine
    )

    guard Self.defaultOutputDeviceID() == deviceID else {
      refreshCurrentDeviceState()
      return false
    }
    guard Self.writeVolume(target, for: deviceID) else {
      refreshCurrentDeviceState()
      return false
    }

    let shouldMute = Self.shouldAutoMute(forVolume: target)
    if Self.hasSettableMute(for: deviceID) {
      if shouldMute && !currentMuted {
        _ = Self.writeMute(true, for: deviceID)
      } else if !shouldMute && currentMuted {
        _ = Self.writeMute(false, for: deviceID)
      }
    }

    let actualVolume = Self.readVolume(for: deviceID) ?? target
    let actualMuted = Self.readMute(for: deviceID) ?? (Self.hasSettableMute(for: deviceID) ? shouldMute : nil)
    outputVolume = actualVolume
    isMuted = actualMuted
    return true
  }

  @discardableResult
  func toggleMute() -> Bool {
    guard let deviceID = verifiedActiveDeviceID() else { return false }
    guard let currentMuted = Self.readMute(for: deviceID) ?? isMuted else {
      return false
    }
    let nextMuted = !currentMuted

    guard Self.defaultOutputDeviceID() == deviceID else {
      refreshCurrentDeviceState()
      return false
    }
    guard Self.writeMute(nextMuted, for: deviceID) else {
      refreshCurrentDeviceState()
      return false
    }

    let actualMuted = Self.readMute(for: deviceID) ?? nextMuted
    let actualVolume = Self.readVolume(for: deviceID) ?? outputVolume
    isMuted = actualMuted
    outputVolume = actualVolume
    return true
  }

  // MARK: - Pure Calculation Helpers

  static func targetVolume(
    current: Float,
    muted: Bool,
    direction: Int,
    fine: Bool
  ) -> Float {
    guard current.isFinite else { return 0 }
    let base: Float = muted ? 0 : min(max(current, 0), 1)
    guard direction != 0 else { return base }
    let delta = (direction > 0 ? 1 : -1) * (fine ? fineStep : fullStep)
    return min(1, max(0, base + delta))
  }

  static func shouldAutoMute(forVolume volume: Float) -> Bool {
    guard volume.isFinite else { return true }
    return volume < muteThreshold
  }

  // MARK: - Device & Listener Management

  private func verifiedActiveDeviceID() -> AudioObjectID? {
    guard let liveDeviceID = Self.defaultOutputDeviceID() else {
      if isObserving { refreshCurrentDeviceState() }
      return nil
    }
    if isObserving {
      guard observedDeviceID == liveDeviceID else {
        // Default output changed; never write to the old or unverified device.
        refreshCurrentDeviceState()
        return nil
      }
    }
    return liveDeviceID
  }

  private func handleSystemPropertyChange() {
    guard isObserving else { return }
    refreshCurrentDeviceState()
  }

  private func handleDevicePropertyChange(for deviceID: AudioObjectID) {
    guard isObserving, observedDeviceID == deviceID else { return }
    refreshGeneration &+= 1
    let generation = refreshGeneration
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) { [weak self] in
      guard let self,
        self.isObserving,
        self.observedDeviceID == deviceID,
        self.refreshGeneration == generation
      else { return }
      self.updateCachedControls(for: deviceID)
    }
  }

  private func refreshCurrentDeviceState() {
    let nextDeviceID = Self.defaultOutputDeviceID()
    if observedDeviceID != nextDeviceID {
      removeDeviceListeners()
      if let nextDeviceID {
        subscribeToDevice(nextDeviceID)
      }
    }
    if let nextDeviceID {
      updateCachedControls(for: nextDeviceID)
    } else {
      outputVolume = nil
      isMuted = nil
    }
  }

  private func updateCachedControls(for deviceID: AudioObjectID) {
    guard Self.defaultOutputDeviceID() == deviceID else {
      outputVolume = nil
      isMuted = nil
      return
    }
    let nextVolume = Self.readVolume(for: deviceID)
    let nextMuted = Self.readMute(for: deviceID)
    if outputVolume != nextVolume {
      outputVolume = nextVolume
    }
    if isMuted != nextMuted {
      isMuted = nextMuted
    }
  }

  private func installSystemListener(selector: AudioObjectPropertySelector) {
    var address = AudioObjectPropertyAddress(
      mSelector: selector,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
    let status = AudioObjectAddPropertyListener(
      AudioObjectID(kAudioObjectSystemObject),
      &address,
      Self.systemListenerCallback,
      listenerClient
    )
    if status == noErr {
      registeredSystemSelectors.append(selector)
    }
  }

  private func removeSystemListeners() {
    for selector in registeredSystemSelectors {
      var address = AudioObjectPropertyAddress(
        mSelector: selector,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
      )
      AudioObjectRemovePropertyListener(
        AudioObjectID(kAudioObjectSystemObject),
        &address,
        Self.systemListenerCallback,
        listenerClient
      )
    }
    registeredSystemSelectors.removeAll()
  }

  private func subscribeToDevice(_ deviceID: AudioObjectID) {
    observedDeviceID = deviceID

    for selector in Self.volumeSelectors {
      var address = AudioObjectPropertyAddress(
        mSelector: selector,
        mScope: kAudioObjectPropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain
      )
      guard AudioObjectHasProperty(deviceID, &address) else { continue }
      if AudioObjectAddPropertyListener(
        deviceID,
        &address,
        Self.deviceListenerCallback,
        listenerClient
      ) == noErr {
        registeredDeviceAddresses.append(address)
      }
    }

    for element in Self.muteElements {
      var address = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyMute,
        mScope: kAudioObjectPropertyScopeOutput,
        mElement: element
      )
      guard AudioObjectHasProperty(deviceID, &address) else { continue }
      if AudioObjectAddPropertyListener(
        deviceID,
        &address,
        Self.deviceListenerCallback,
        listenerClient
      ) == noErr {
        registeredDeviceAddresses.append(address)
      }
    }
  }

  private func removeDeviceListeners() {
    if let deviceID = observedDeviceID {
      for var address in registeredDeviceAddresses {
        AudioObjectRemovePropertyListener(
          deviceID,
          &address,
          Self.deviceListenerCallback,
          listenerClient
        )
      }
    }
    observedDeviceID = nil
    registeredDeviceAddresses.removeAll()
  }

  // MARK: - CoreAudio Low-Level Primitives

  static func defaultOutputDeviceID() -> AudioObjectID? {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioHardwarePropertyDefaultOutputDevice,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
    var deviceID = AudioObjectID(kAudioObjectUnknown)
    var size = UInt32(MemoryLayout<AudioObjectID>.size)
    let status = AudioObjectGetPropertyData(
      AudioObjectID(kAudioObjectSystemObject),
      &address,
      0,
      nil,
      &size,
      &deviceID
    )
    guard status == noErr, deviceID != kAudioObjectUnknown, deviceID != 0 else {
      return nil
    }
    return deviceID
  }

  static func readVolume(for deviceID: AudioObjectID) -> Float? {
    for selector in volumeSelectors {
      var address = AudioObjectPropertyAddress(
        mSelector: selector,
        mScope: kAudioObjectPropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain
      )
      guard isPropertySettable(deviceID: deviceID, address: &address) else {
        continue
      }
      var value: Float32 = 0
      var size = UInt32(MemoryLayout<Float32>.size)
      let status = AudioObjectGetPropertyData(
        deviceID,
        &address,
        0,
        nil,
        &size,
        &value
      )
      if status == noErr, value.isFinite {
        return min(1, max(0, value))
      }
    }
    return nil
  }

  static func writeVolume(_ volume: Float, for deviceID: AudioObjectID) -> Bool {
    guard volume.isFinite else { return false }
    let clamped = Float32(min(1, max(0, volume)))
    for selector in volumeSelectors {
      var address = AudioObjectPropertyAddress(
        mSelector: selector,
        mScope: kAudioObjectPropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain
      )
      guard isPropertySettable(deviceID: deviceID, address: &address) else {
        continue
      }
      var nextVolume = clamped
      let status = AudioObjectSetPropertyData(
        deviceID,
        &address,
        0,
        nil,
        UInt32(MemoryLayout<Float32>.size),
        &nextVolume
      )
      if status == noErr {
        return true
      }
    }
    return false
  }

  static func hasSettableMute(for deviceID: AudioObjectID) -> Bool {
    for element in muteElements {
      var address = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyMute,
        mScope: kAudioObjectPropertyScopeOutput,
        mElement: element
      )
      if isPropertySettable(deviceID: deviceID, address: &address) {
        return true
      }
    }
    return false
  }

  static func readMute(for deviceID: AudioObjectID) -> Bool? {
    for element in muteElements {
      var address = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyMute,
        mScope: kAudioObjectPropertyScopeOutput,
        mElement: element
      )
      guard isPropertySettable(deviceID: deviceID, address: &address) else {
        continue
      }
      var value: UInt32 = 0
      var size = UInt32(MemoryLayout<UInt32>.size)
      let status = AudioObjectGetPropertyData(
        deviceID,
        &address,
        0,
        nil,
        &size,
        &value
      )
      if status == noErr {
        return value != 0
      }
    }
    return nil
  }

  static func writeMute(_ muted: Bool, for deviceID: AudioObjectID) -> Bool {
    var wroteAny = false
    for element in muteElements {
      var address = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyMute,
        mScope: kAudioObjectPropertyScopeOutput,
        mElement: element
      )
      guard isPropertySettable(deviceID: deviceID, address: &address) else {
        continue
      }
      var value: UInt32 = muted ? 1 : 0
      let status = AudioObjectSetPropertyData(
        deviceID,
        &address,
        0,
        nil,
        UInt32(MemoryLayout<UInt32>.size),
        &value
      )
      if status == noErr {
        wroteAny = true
      }
    }
    return wroteAny
  }

  private static func isPropertySettable(
    deviceID: AudioObjectID,
    address: inout AudioObjectPropertyAddress
  ) -> Bool {
    guard AudioObjectHasProperty(deviceID, &address) else { return false }
    var settable = DarwinBoolean(false)
    guard AudioObjectIsPropertySettable(deviceID, &address, &settable) == noErr else {
      return false
    }
    return settable.boolValue
  }
}

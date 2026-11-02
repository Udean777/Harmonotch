import AppKit
import AudioToolbox
import CoreAudio
import Foundation

final class AudioVolumeController {
  static let shared = AudioVolumeController()

  var onVolumeChange: ((Float, Bool) -> Void)?

  private var defaultOutputDeviceID: AudioDeviceID = 0
  private var listenerBlock: AudioObjectPropertyListenerBlock?
  private var systemListenerBlock: AudioObjectPropertyListenerBlock?
  private var feedbackSound: NSSound?

  init() {
    setupFeedbackSound()
    updateDefaultDevice()
    attachSystemListener()
  }

  deinit {
    detachListeners()
  }

  // MARK: - Feedback Sound

  private func setupFeedbackSound() {
    let path = "/System/Library/LoginPlugins/BezelServices.loginPlugin/Contents/Resources/volume.aiff"
    if FileManager.default.fileExists(atPath: path) {
      feedbackSound = NSSound(contentsOfFile: path, byReference: true)
    } else {
      feedbackSound = NSSound(named: "Pop")
    }
  }

  func playFeedbackSoundIfNeeded() {
    let appPref = UserDefaults.standard.object(forKey: UserDefaultsKeys.volumeFeedbackSound)
    if let enabled = appPref as? Bool, !enabled {
      return
    }

    // Check macOS user preference: "Play sound on volume change"
    let feedbackEnabled: Bool = {
      if let globalDomain = UserDefaults.standard.persistentDomain(forName: UserDefaults.globalDomain),
        let pref = globalDomain["com.apple.sound.beep.feedback"] as? Int
      {
        return pref == 1
      }
      return true
    }()

    guard feedbackEnabled else { return }
    feedbackSound?.stop()
    feedbackSound?.play()
  }

  // MARK: - Default Output Device

  func updateDefaultDevice() {
    detachDeviceListener()

    var deviceID = AudioDeviceID(0)
    var size = UInt32(MemoryLayout<AudioDeviceID>.size)
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioHardwarePropertyDefaultOutputDevice,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )

    let status = AudioObjectGetPropertyData(
      AudioObjectID(kAudioObjectSystemObject),
      &address,
      0,
      nil,
      &size,
      &deviceID
    )

    if status == noErr && deviceID != kAudioObjectUnknown {
      defaultOutputDeviceID = deviceID
      attachDeviceListener()
    } else {
      defaultOutputDeviceID = 0
    }
  }

  // MARK: - Get / Set Volume

  func getVolume() -> Float {
    guard defaultOutputDeviceID != 0 else { return 0.0 }

    // 1. Try VirtualMainVolume
    var virtualAddress = AudioObjectPropertyAddress(
      mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
      mScope: kAudioDevicePropertyScopeOutput,
      mElement: kAudioObjectPropertyElementMain
    )

    if AudioObjectHasProperty(defaultOutputDeviceID, &virtualAddress) {
      var volume: Float32 = 0.0
      var size = UInt32(MemoryLayout<Float32>.size)
      let status = AudioObjectGetPropertyData(
        defaultOutputDeviceID,
        &virtualAddress,
        0,
        nil,
        &size,
        &volume
      )
      if status == noErr {
        return max(0.0, min(1.0, volume))
      }
    }

    // 2. Try VolumeScalar on Main element
    var scalarAddress = AudioObjectPropertyAddress(
      mSelector: kAudioDevicePropertyVolumeScalar,
      mScope: kAudioDevicePropertyScopeOutput,
      mElement: kAudioObjectPropertyElementMain
    )

    if AudioObjectHasProperty(defaultOutputDeviceID, &scalarAddress) {
      var volume: Float32 = 0.0
      var size = UInt32(MemoryLayout<Float32>.size)
      let status = AudioObjectGetPropertyData(
        defaultOutputDeviceID,
        &scalarAddress,
        0,
        nil,
        &size,
        &volume
      )
      if status == noErr {
        return max(0.0, min(1.0, volume))
      }
    }

    // 3. Fallback: query channels (1, 2)
    let channels = getChannelCount(deviceID: defaultOutputDeviceID)
    if channels > 0 {
      var volumes: [Float32] = []
      for channel in 1...channels {
        var chAddress = AudioObjectPropertyAddress(
          mSelector: kAudioDevicePropertyVolumeScalar,
          mScope: kAudioDevicePropertyScopeOutput,
          mElement: AudioObjectPropertyElement(channel)
        )
        if AudioObjectHasProperty(defaultOutputDeviceID, &chAddress) {
          var chVol: Float32 = 0.0
          var size = UInt32(MemoryLayout<Float32>.size)
          if AudioObjectGetPropertyData(defaultOutputDeviceID, &chAddress, 0, nil, &size, &chVol) == noErr {
            volumes.append(chVol)
          }
        }
      }
      if !volumes.isEmpty {
        let avg = volumes.reduce(0.0, +) / Float32(volumes.count)
        return max(0.0, min(1.0, avg))
      }
    }

    return 0.0
  }

  @discardableResult
  func setVolume(_ volume: Float) -> Bool {
    guard defaultOutputDeviceID != 0 else { return false }
    var targetVolume = max(0.0, min(1.0, volume))
    let size = UInt32(MemoryLayout<Float32>.size)

    var handled = false

    // 1. Try VirtualMainVolume
    var virtualAddress = AudioObjectPropertyAddress(
      mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
      mScope: kAudioDevicePropertyScopeOutput,
      mElement: kAudioObjectPropertyElementMain
    )

    var isSettable: DarwinBoolean = false
    if AudioObjectHasProperty(defaultOutputDeviceID, &virtualAddress),
      AudioObjectIsPropertySettable(defaultOutputDeviceID, &virtualAddress, &isSettable) == noErr,
      isSettable.boolValue
    {
      let status = AudioObjectSetPropertyData(
        defaultOutputDeviceID,
        &virtualAddress,
        0,
        nil,
        size,
        &targetVolume
      )
      if status == noErr {
        handled = true
      }
    }

    // 2. Try VolumeScalar on Main element
    var scalarAddress = AudioObjectPropertyAddress(
      mSelector: kAudioDevicePropertyVolumeScalar,
      mScope: kAudioDevicePropertyScopeOutput,
      mElement: kAudioObjectPropertyElementMain
    )

    var scalarSettable: DarwinBoolean = false
    if AudioObjectHasProperty(defaultOutputDeviceID, &scalarAddress),
      AudioObjectIsPropertySettable(defaultOutputDeviceID, &scalarAddress, &scalarSettable) == noErr,
      scalarSettable.boolValue
    {
      let status = AudioObjectSetPropertyData(
        defaultOutputDeviceID,
        &scalarAddress,
        0,
        nil,
        size,
        &targetVolume
      )
      if status == noErr {
        handled = true
      }
    }

    // 3. Fallback: Write to channels 1...N
    let channels = getChannelCount(deviceID: defaultOutputDeviceID)
    if channels > 0 {
      for channel in 1...channels {
        var chAddress = AudioObjectPropertyAddress(
          mSelector: kAudioDevicePropertyVolumeScalar,
          mScope: kAudioDevicePropertyScopeOutput,
          mElement: AudioObjectPropertyElement(channel)
        )
        var chSettable: DarwinBoolean = false
        if AudioObjectHasProperty(defaultOutputDeviceID, &chAddress),
          AudioObjectIsPropertySettable(defaultOutputDeviceID, &chAddress, &chSettable) == noErr,
          chSettable.boolValue
        {
          if AudioObjectSetPropertyData(defaultOutputDeviceID, &chAddress, 0, nil, size, &targetVolume) == noErr {
            handled = true
          }
        }
      }
    }

    // If volume was adjusted while muted, unmute automatically (same as macOS behavior)
    if isMuted && targetVolume > 0 {
      setMuted(false)
    }

    return handled
  }

  // MARK: - Mute

  var isMuted: Bool {
    guard defaultOutputDeviceID != 0 else { return false }
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioDevicePropertyMute,
      mScope: kAudioDevicePropertyScopeOutput,
      mElement: kAudioObjectPropertyElementMain
    )

    var muteValue: UInt32 = 0
    var size = UInt32(MemoryLayout<UInt32>.size)
    let status = AudioObjectGetPropertyData(
      defaultOutputDeviceID,
      &address,
      0,
      nil,
      &size,
      &muteValue
    )
    return status == noErr && muteValue != 0
  }

  @discardableResult
  func setMuted(_ muted: Bool) -> Bool {
    guard defaultOutputDeviceID != 0 else { return false }
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioDevicePropertyMute,
      mScope: kAudioDevicePropertyScopeOutput,
      mElement: kAudioObjectPropertyElementMain
    )

    var muteValue: UInt32 = muted ? 1 : 0
    let size = UInt32(MemoryLayout<UInt32>.size)

    let status = AudioObjectSetPropertyData(
      defaultOutputDeviceID,
      &address,
      0,
      nil,
      size,
      &muteValue
    )
    return status == noErr
  }

  func toggleMute() {
    setMuted(!isMuted)
  }

  // MARK: - Listeners

  private func attachSystemListener() {
    var defaultDeviceAddress = AudioObjectPropertyAddress(
      mSelector: kAudioHardwarePropertyDefaultOutputDevice,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )

    let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
      DispatchQueue.main.async {
        self?.updateDefaultDevice()
        if let self = self {
          self.onVolumeChange?(self.getVolume(), self.isMuted)
        }
      }
    }
    self.systemListenerBlock = block

    AudioObjectAddPropertyListenerBlock(
      AudioObjectID(kAudioObjectSystemObject),
      &defaultDeviceAddress,
      DispatchQueue.main,
      block
    )
  }

  private func attachDeviceListener() {
    guard defaultOutputDeviceID != 0 else { return }

    var address = AudioObjectPropertyAddress(
      mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
      mScope: kAudioDevicePropertyScopeOutput,
      mElement: kAudioObjectPropertyElementMain
    )

    let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
      DispatchQueue.main.async {
        guard let self = self else { return }
        self.onVolumeChange?(self.getVolume(), self.isMuted)
      }
    }
    self.listenerBlock = block

    AudioObjectAddPropertyListenerBlock(
      defaultOutputDeviceID,
      &address,
      DispatchQueue.main,
      block
    )
  }

  private func detachDeviceListener() {
    guard defaultOutputDeviceID != 0, let block = listenerBlock else { return }
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
      mScope: kAudioDevicePropertyScopeOutput,
      mElement: kAudioObjectPropertyElementMain
    )
    AudioObjectRemovePropertyListenerBlock(
      defaultOutputDeviceID,
      &address,
      DispatchQueue.main,
      block
    )
    listenerBlock = nil
  }

  private func detachListeners() {
    detachDeviceListener()
    if let block = systemListenerBlock {
      var defaultDeviceAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultOutputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
      )
      AudioObjectRemovePropertyListenerBlock(
        AudioObjectID(kAudioObjectSystemObject),
        &defaultDeviceAddress,
        DispatchQueue.main,
        block
      )
      systemListenerBlock = nil
    }
  }

  // MARK: - Channel Helpers

  private func getChannelCount(deviceID: AudioDeviceID) -> UInt32 {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioDevicePropertyStreamConfiguration,
      mScope: kAudioDevicePropertyScopeOutput,
      mElement: kAudioObjectPropertyElementMain
    )
    guard AudioObjectHasProperty(deviceID, &address) else { return 0 }

    var dataSize: UInt32 = 0
    guard AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &dataSize) == noErr, dataSize > 0 else {
      return 0
    }

    let bufferListPointer = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: Int(dataSize))
    defer { bufferListPointer.deallocate() }

    guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &dataSize, bufferListPointer) == noErr else {
      return 0
    }

    var channels: UInt32 = 0
    let count = Int(bufferListPointer.pointee.mNumberBuffers)
    withUnsafePointer(to: &bufferListPointer.pointee.mBuffers) { ptr in
      let bufferArray = UnsafeBufferPointer(start: ptr, count: count)
      for buffer in bufferArray {
        channels += buffer.mNumberChannels
      }
    }
    return channels
  }
}

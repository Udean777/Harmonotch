import Foundation

enum VolumeMediaKey: Int32, Equatable {
  case volumeUp = 0
  case volumeDown = 1
  case mute = 7
}

struct VolumeKeyRouter: Equatable {
  enum Action: Equatable {
    case passThrough
    case consume
    case step(Int)
    case toggleMute
  }

  static let keyDownState = 0x0a
  static let keyUpState = 0x0b
  static let defaultNativeWindowDuration: TimeInterval = 1.6

  var windowDuration: TimeInterval = VolumeKeyRouter.defaultNativeWindowDuration
  private(set) var held: Set<Int32> = []
  private(set) var nativeOwnsUntil: TimeInterval = -.infinity

  func blocksCustomHUD(_ now: TimeInterval) -> Bool {
    now < nativeOwnsUntil
  }

  mutating func markSystemOwnership(now: TimeInterval) {
    held.removeAll()
    extendNativeWindow(now: now)
  }

  mutating func reset() {
    held.removeAll()
    nativeOwnsUntil = -.infinity
  }

  mutating func handle(
    keyCode: Int32,
    state: Int,
    isRepeat: Bool,
    enabled: Bool,
    canHandle: Bool,
    hasVolume: Bool,
    hasMute: Bool,
    option: Bool,
    shift: Bool,
    commandOrControl: Bool,
    now: TimeInterval
  ) -> Action {
    guard let key = VolumeMediaKey(rawValue: keyCode) else {
      return .passThrough
    }

    if state == Self.keyUpState {
      return held.remove(keyCode) != nil ? .consume : .passThrough
    }

    guard state == Self.keyDownState else {
      return .passThrough
    }

    let ownsPress = held.contains(keyCode)
    if isRepeat && !ownsPress {
      extendNativeWindow(now: now)
      return .passThrough
    }

    let deviceSupportsKey = (key == .mute) ? hasMute : hasVolume
    let modifiersAllowed = !commandOrControl && (!option || shift)
    let allowedForApp =
      enabled
      && canHandle
      && !blocksCustomHUD(now)
      && modifiersAllowed
      && deviceSupportsKey

    guard allowedForApp else {
      if ownsPress {
        return .consume
      }
      extendNativeWindow(now: now)
      return .passThrough
    }

    held.insert(keyCode)
    switch key {
    case .mute:
      return isRepeat ? .consume : .toggleMute
    case .volumeUp:
      return .step(1)
    case .volumeDown:
      return .step(-1)
    }
  }

  private mutating func extendNativeWindow(now: TimeInterval) {
    let candidate = now + windowDuration
    if candidate > nativeOwnsUntil {
      nativeOwnsUntil = candidate
    }
  }

  static func parseSystemDefined(data1: Int) -> (keyCode: Int32, state: Int, isRepeat: Bool) {
    let keyCode = Int32((data1 >> 16) & 0xffff)
    let state = (data1 >> 8) & 0xff
    let isRepeat = (data1 & 1) != 0
    return (keyCode, state, isRepeat)
  }

  static func isFineStep(option: Bool, shift: Bool) -> Bool {
    option && shift
  }

  static func playsFeedback(setting: Bool, option: Bool, shift: Bool) -> Bool {
    shift && !option ? !setting : setting
  }

  static func volumeSymbol(level: Double, muted: Bool) -> String {
    if muted || level < 0.005 {
      return "speaker.slash.fill"
    }
    if level < 0.33 {
      return "speaker.wave.1.fill"
    }
    if level < 0.66 {
      return "speaker.wave.2.fill"
    }
    return "speaker.wave.3.fill"
  }
}

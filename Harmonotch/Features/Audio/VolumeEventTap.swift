import AppKit
import ApplicationServices
import Foundation

extension VolumeHUDController {
  func start() {
    guard
      UserDefaults.standard[UserDefaultsKeys.volumeHUDEnabled],
      AXIsProcessTrusted(),
      isSessionActive
    else {
      stop()
      return
    }

    if let tap {
      if !CGEvent.tapIsEnabled(tap: tap) {
        CGEvent.tapEnable(tap: tap, enable: true)
      }
      if CGEvent.tapIsEnabled(tap: tap) {
        isTapActive = true
        return
      }
      removeTap()
    }

    guard let systemDefinedType = CGEventType(rawValue: Self.systemDefinedEventTypeRawValue) else {
      return
    }

    let callback: CGEventTapCallBack = { _, type, event, userInfo in
      guard let userInfo else { return Unmanaged.passUnretained(event) }
      let controller = Unmanaged<VolumeHUDController>
        .fromOpaque(userInfo)
        .takeUnretainedValue()
      return controller.handleEvent(type: type, event: event)
    }

    guard
      let createdTap = CGEvent.tapCreate(
        tap: .cgSessionEventTap,
        place: .headInsertEventTap,
        options: .defaultTap,
        eventsOfInterest: CGEventMask(1 << systemDefinedType.rawValue),
        callback: callback,
        userInfo: Unmanaged.passUnretained(self).toOpaque()
      )
    else {
      isTapActive = false
      return
    }

    tap = createdTap
    runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, createdTap, 0)
    if let runLoopSource {
      CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
    }
    CGEvent.tapEnable(tap: createdTap, enable: true)
    isTapActive = CGEvent.tapIsEnabled(tap: createdTap)
  }

  func stop() {
    removeTap()
    router.reset()
    NotchViewModel.shared.dismissVolumeNotice()
  }

  func removeTap() {
    if let tap {
      CGEvent.tapEnable(tap: tap, enable: false)
    }
    if let runLoopSource {
      CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
    }
    if let tap {
      CFMachPortInvalidate(tap)
    }
    tap = nil
    runLoopSource = nil
    isTapActive = false
  }

  func handleEvent(
    type: CGEventType,
    event: CGEvent
  ) -> Unmanaged<CGEvent>? {
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
      router.markSystemOwnership(now: Self.now())
      if isSessionActive,
        UserDefaults.standard[UserDefaultsKeys.volumeHUDEnabled],
        AXIsProcessTrusted(),
        let tap
      {
        CGEvent.tapEnable(tap: tap, enable: true)
        if CGEvent.tapIsEnabled(tap: tap) {
          isTapActive = true
          return Unmanaged.passUnretained(event)
        }
      }
      DispatchQueue.main.async { [weak self] in
        self?.syncWithPreferences()
      }
      return Unmanaged.passUnretained(event)
    }

    guard type.rawValue == Self.systemDefinedEventTypeRawValue else {
      return Unmanaged.passUnretained(event)
    }
    if Self.isOwnPostedEvent(event) {
      return Unmanaged.passUnretained(event)
    }
    guard
      let nsEvent = NSEvent(cgEvent: event),
      nsEvent.subtype.rawValue == 8
    else {
      return Unmanaged.passUnretained(event)
    }

    let parsed = VolumeKeyRouter.parseSystemDefined(data1: nsEvent.data1)
    let flags = event.flags
    let option = flags.contains(.maskAlternate)
    let shift = flags.contains(.maskShift)
    let commandOrControl = flags.contains(.maskCommand) || flags.contains(.maskControl)

    let audio = SystemAudioService.shared
    let enabled = UserDefaults.standard[UserDefaultsKeys.volumeHUDEnabled]
    let canHandle =
      isSessionActive
      && AXIsProcessTrusted()
      && !NotchWindowController.shared.isNotchHidden

    let now = Self.now()
    if parsed.state == VolumeKeyRouter.keyDownState && Self.isOSDUIHelperVisible() {
      router.markSystemOwnership(now: now)
    }

    let action = router.handle(
      keyCode: parsed.keyCode,
      state: parsed.state,
      isRepeat: parsed.isRepeat,
      enabled: enabled,
      canHandle: canHandle,
      hasVolume: audio.outputVolume != nil,
      hasMute: audio.isMuted != nil,
      option: option,
      shift: shift,
      commandOrControl: commandOrControl,
      now: now
    )

    switch action {
    case .passThrough:
      return Unmanaged.passUnretained(event)

    case .consume:
      return nil

    case .step(let direction):
      let fine = VolumeKeyRouter.isFineStep(option: option, shift: shift)
      let cachedVolume = audio.outputVolume ?? 0
      let cachedMuted = audio.isMuted ?? false
      let expectedTarget = SystemAudioService.targetVolume(
        current: cachedVolume,
        muted: cachedMuted,
        direction: direction,
        fine: fine
      )
      let fallbackEvent = event.copy()
      let isRepeat = parsed.isRepeat
      let keyCode = parsed.keyCode

      DispatchQueue.main.async { [weak self] in
        self?.executeAppVolumeStep(
          direction: direction,
          fine: fine,
          option: option,
          shift: shift,
          expectedTarget: expectedTarget,
          isRepeat: isRepeat,
          keyCode: keyCode,
          fallbackEvent: fallbackEvent
        )
      }
      return nil

    case .toggleMute:
      let fallbackEvent = event.copy()
      let isRepeat = parsed.isRepeat
      let keyCode = parsed.keyCode

      DispatchQueue.main.async { [weak self] in
        self?.executeAppMuteToggle(
          isRepeat: isRepeat,
          keyCode: keyCode,
          fallbackEvent: fallbackEvent
        )
      }
      return nil
    }
  }

  static func postSyntheticRelease(keyCode: Int32) {
    let event = NSEvent.otherEvent(
      with: .systemDefined,
      location: .zero,
      modifierFlags: NSEvent.ModifierFlags(rawValue: 0xB00),
      timestamp: 0,
      windowNumber: 0,
      context: nil,
      subtype: 8,
      data1: Int(keyCode << 16) | 0xB00,
      data2: -1
    )?.cgEvent
    event?.setIntegerValueField(.eventSourceUserData, value: postedEventMarker)
    event?.post(tap: .cgSessionEventTap)
  }
}

import AppKit
import ApplicationServices
import Combine
import Foundation

final class VolumeHUDController: ObservableObject {
  static let shared = VolumeHUDController()

  static let postedEventMarker: Int64 = 0x484D564C
  static let systemDefinedEventTypeRawValue: UInt32 = 14
  private static let legacyReplaceVolumeHUDKey = "Harmonotch_ReplaceVolumeHUD"

  @Published private(set) var isEnabled = false
  @Published private(set) var isAccessibilityGranted = false
  @Published private(set) var isTapActive = false

  private var tap: CFMachPort?
  private var runLoopSource: CFRunLoopSource?
  private(set) var router = VolumeKeyRouter()
  private var isSessionActive = true
  private var workspaceObservers: [NSObjectProtocol] = []
  private var appActiveObserver: NSObjectProtocol?
  private var permissionPollTimer: Timer?
  private var didPromptAccessibilityThisSession = false

  var hasHeldKey: Bool {
    !router.held.isEmpty
  }

  private init() {
    migrateLegacyPreferenceIfNeeded()
    isEnabled = UserDefaults.standard[UserDefaultsKeys.volumeHUDEnabled]
    isAccessibilityGranted = AXIsProcessTrusted()
    registerSessionObservers()
  }

  deinit {
    permissionPollTimer?.invalidate()
    for observer in workspaceObservers {
      NSWorkspace.shared.notificationCenter.removeObserver(observer)
    }
    if let appActiveObserver {
      NotificationCenter.default.removeObserver(appActiveObserver)
    }
  }

  static func now() -> TimeInterval {
    ProcessInfo.processInfo.systemUptime
  }

  static func isOwnPostedEvent(_ event: CGEvent) -> Bool {
    event.getIntegerValueField(.eventSourceUserData) == postedEventMarker
  }

  static func isOSDUIHelperVisible() -> Bool {
    guard
      let windowList = CGWindowListCopyWindowInfo(
        [.optionOnScreenOnly, .excludeDesktopElements],
        kCGNullWindowID
      ) as? [[String: Any]]
    else {
      return false
    }
    for info in windowList {
      if let owner = info[kCGWindowOwnerName as String] as? String, owner == "OSDUIHelper" {
        return true
      }
    }
    return false
  }

  private static let volumeFeedback = NSSound(
    contentsOfFile: "/System/Library/LoginPlugins/BezelServices.loginPlugin/Contents/Resources/volume.aiff",
    byReference: true
  )

  static func systemFeedbackEnabled() -> Bool {
    CFPreferencesGetAppBooleanValue(
      "com.apple.sound.beep.feedback" as CFString,
      kCFPreferencesAnyApplication,
      nil
    )
  }

  static func shouldPlayFeedback(option: Bool, shift: Bool) -> Bool {
    VolumeKeyRouter.playsFeedback(
      setting: systemFeedbackEnabled(),
      option: option,
      shift: shift
    )
  }

  private static func playVolumeFeedback() {
    volumeFeedback?.stop()
    volumeFeedback?.play()
  }

  func canShowCustomHUD(now: TimeInterval = VolumeHUDController.now()) -> Bool {
    guard isTapActive && !router.blocksCustomHUD(now) && !NotchWindowController.shared.isNotchHidden else {
      return false
    }
    if Self.isOSDUIHelperVisible() {
      router.markSystemOwnership(now: now)
      return false
    }
    return true
  }

  func setEnabled(_ enabled: Bool, promptIfUntrusted: Bool = true) {
    UserDefaults.standard[UserDefaultsKeys.volumeHUDEnabled] = enabled
    syncWithPreferences()
    if enabled && !AXIsProcessTrusted() && promptIfUntrusted {
      requestAccessibilityPermission(resetStaleEntry: true)
    }
  }

  /// Resets the stale TCC entry of ad-hoc builds so the System Settings switch is valid again.
  func requestAccessibilityPermission(resetStaleEntry: Bool = true, openSettings: Bool = true) {
    let bundleID = Bundle.main.bundleIdentifier ?? "com.ssajudn.Harmonotch"
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      if resetStaleEntry && !AXIsProcessTrusted() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
        process.arguments = ["reset", "Accessibility", bundleID]
        try? process.run()
        process.waitUntilExit()
      }
      DispatchQueue.main.async {
        let options =
          [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        if openSettings {
          if let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
          ) {
            NSWorkspace.shared.open(url)
          }
        }
        self?.syncWithPreferences()
      }
    }
  }

  static func openAccessibilitySettings() {
    shared.requestAccessibilityPermission(resetStaleEntry: true, openSettings: true)
  }

  private func migrateLegacyPreferenceIfNeeded() {
    let defaults = UserDefaults.standard
    guard !defaults.contains(UserDefaultsKeys.volumeHUDEnabled) else { return }
    if defaults.object(forKey: Self.legacyReplaceVolumeHUDKey) as? Bool == true {
      defaults[UserDefaultsKeys.volumeHUDEnabled] = true
    }
  }

  // MARK: - Lifecycle & Preferences

  func syncWithPreferences() {
    if !Thread.isMainThread {
      DispatchQueue.main.async { [weak self] in self?.syncWithPreferences() }
      return
    }

    let enabled = UserDefaults.standard[UserDefaultsKeys.volumeHUDEnabled]
    let trusted = AXIsProcessTrusted()

    if isEnabled != enabled { isEnabled = enabled }
    if isAccessibilityGranted != trusted { isAccessibilityGranted = trusted }

    updatePermissionPolling(enabled: enabled, trusted: trusted)

    if enabled && trusted && isSessionActive {
      SystemAudioService.shared.startObserving()
      start()
    } else {
      stop()
      SystemAudioService.shared.stopObserving()
      if enabled && !trusted && isSessionActive && !didPromptAccessibilityThisSession {
        didPromptAccessibilityThisSession = true
        requestAccessibilityPermission(resetStaleEntry: true, openSettings: true)
      }
    }
  }

  private func updatePermissionPolling(enabled: Bool, trusted: Bool) {
    let shouldPoll = enabled && !trusted && isSessionActive
    if shouldPoll {
      guard permissionPollTimer == nil else { return }
      let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
        guard let self else { return }
        let nowTrusted = AXIsProcessTrusted()
        if nowTrusted != self.isAccessibilityGranted {
          self.syncWithPreferences()
        }
      }
      timer.tolerance = 0.3
      RunLoop.main.add(timer, forMode: .common)
      permissionPollTimer = timer
    } else {
      permissionPollTimer?.invalidate()
      permissionPollTimer = nil
    }
  }

  func start() {
    if !Thread.isMainThread {
      DispatchQueue.main.async { [weak self] in self?.start() }
      return
    }

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
    if !Thread.isMainThread {
      DispatchQueue.main.async { [weak self] in self?.stop() }
      return
    }
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

  // MARK: - Event Tap Handling

  private func handleEvent(
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

  private func executeAppVolumeStep(
    direction: Int,
    fine: Bool,
    option: Bool,
    shift: Bool,
    expectedTarget: Float,
    isRepeat: Bool,
    keyCode: Int32,
    fallbackEvent: CGEvent?
  ) {
    let audio = SystemAudioService.shared
    if audio.step(direction: direction, fine: fine) {
      if Self.shouldPlayFeedback(option: option, shift: shift) {
        Self.playVolumeFeedback()
      }
      let resolvedVolume = Double(audio.outputVolume ?? expectedTarget)
      let resolvedMuted =
        audio.isMuted ?? SystemAudioService.shouldAutoMute(forVolume: Float(resolvedVolume))
      NotchViewModel.shared.showVolumeNotice(
        level: resolvedVolume,
        muted: resolvedMuted,
        isRepeat: isRepeat
      )
    } else {
      handleWriteFailureFallback(keyCode: keyCode, fallbackEvent: fallbackEvent)
    }
  }

  private func executeAppMuteToggle(
    isRepeat: Bool,
    keyCode: Int32,
    fallbackEvent: CGEvent?
  ) {
    let audio = SystemAudioService.shared
    if audio.toggleMute() {
      // Like macOS, the mute key clicks only when it unmutes.
      if audio.isMuted == false && Self.shouldPlayFeedback(option: false, shift: false) {
        Self.playVolumeFeedback()
      }
      let resolvedMuted = audio.isMuted ?? false
      let resolvedVolume = Double(audio.outputVolume ?? 0)
      NotchViewModel.shared.showVolumeNotice(
        level: resolvedVolume,
        muted: resolvedMuted,
        isRepeat: isRepeat
      )
    } else {
      handleWriteFailureFallback(keyCode: keyCode, fallbackEvent: fallbackEvent)
    }
  }

  private func handleWriteFailureFallback(keyCode: Int32, fallbackEvent: CGEvent?) {
    let deviceID = SystemAudioService.defaultOutputDeviceID() ?? 0
    NSLog(
      "[Harmonotch:Audio] Fallback to native volume handler for keyCode: %d (device: %u, reason: CoreAudio write failed)",
      keyCode,
      deviceID
    )
    router.markSystemOwnership(now: Self.now())
    NotchViewModel.shared.dismissVolumeNotice()

    if let fallbackEvent {
      fallbackEvent.setIntegerValueField(.eventSourceUserData, value: Self.postedEventMarker)
      fallbackEvent.post(tap: .cgSessionEventTap)
      Self.postSyntheticRelease(keyCode: keyCode)
    }
  }

  private static func postSyntheticRelease(keyCode: Int32) {
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

  // MARK: - Session Activity

  private func registerSessionObservers() {
    let center = NSWorkspace.shared.notificationCenter

    workspaceObservers.append(
      center.addObserver(
        forName: NSWorkspace.screensDidSleepNotification,
        object: nil,
        queue: .main
      ) { [weak self] _ in
        guard let self else { return }
        self.isSessionActive = false
        self.stop()
        self.updatePermissionPolling(enabled: self.isEnabled, trusted: self.isAccessibilityGranted)
      }
    )

    workspaceObservers.append(
      center.addObserver(
        forName: NSWorkspace.screensDidWakeNotification,
        object: nil,
        queue: .main
      ) { [weak self] _ in
        guard let self else { return }
        self.isSessionActive = true
        self.syncWithPreferences()
      }
    )

    workspaceObservers.append(
      center.addObserver(
        forName: NSWorkspace.sessionDidResignActiveNotification,
        object: nil,
        queue: .main
      ) { [weak self] _ in
        guard let self else { return }
        self.isSessionActive = false
        self.stop()
        self.updatePermissionPolling(enabled: self.isEnabled, trusted: self.isAccessibilityGranted)
      }
    )

    workspaceObservers.append(
      center.addObserver(
        forName: NSWorkspace.sessionDidBecomeActiveNotification,
        object: nil,
        queue: .main
      ) { [weak self] _ in
        guard let self else { return }
        self.isSessionActive = true
        self.syncWithPreferences()
      }
    )

    appActiveObserver = NotificationCenter.default.addObserver(
      forName: NSApplication.didBecomeActiveNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      self?.syncWithPreferences()
    }
  }
}

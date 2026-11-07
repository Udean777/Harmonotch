import AppKit
import ApplicationServices
import Combine
import Foundation

final class VolumeHUDController: ObservableObject {
  static let shared = VolumeHUDController()

  static let postedEventMarker: Int64 = 0x484D564C
  static let systemDefinedEventTypeRawValue: UInt32 = 14
  private static let legacyReplaceVolumeHUDKey = "Harmonotch_ReplaceVolumeHUD"

  @Published var isEnabled = false
  @Published var isAccessibilityGranted = false
  @Published var isTapActive = false

  var tap: CFMachPort?
  var runLoopSource: CFRunLoopSource?
  var router = VolumeKeyRouter()
  var isSessionActive = true
  private var workspaceObservers: [NSObjectProtocol] = []
  private var appActiveObserver: NSObjectProtocol?
  var permissionPollTimer: Timer?
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
    contentsOfFile:
      "/System/Library/LoginPlugins/BezelServices.loginPlugin/Contents/Resources/volume.aiff",
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

  static func playVolumeFeedback() {
    volumeFeedback?.stop()
    volumeFeedback?.play()
  }

  func canShowCustomHUD(now: TimeInterval = VolumeHUDController.now()) -> Bool {
    guard isTapActive && !router.blocksCustomHUD(now) && !NotchWindowController.shared.isNotchHidden
    else {
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

  private func migrateLegacyPreferenceIfNeeded() {
    let defaults = UserDefaults.standard
    guard !defaults.contains(UserDefaultsKeys.volumeHUDEnabled) else { return }
    if defaults.object(forKey: Self.legacyReplaceVolumeHUDKey) as? Bool == true {
      defaults[UserDefaultsKeys.volumeHUDEnabled] = true
    }
  }

  // MARK: - Lifecycle & Preferences

  func syncWithPreferences() {
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
        requestAccessibilityPermission(resetStaleEntry: true)
      }
    }
  }

  // MARK: - Volume Actions & Fallback

  func executeAppVolumeStep(
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

  func executeAppMuteToggle(
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

  func handleWriteFailureFallback(keyCode: Int32, fallbackEvent: CGEvent?) {
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
        queue: nil
      ) { [weak self] _ in
        DispatchQueue.main.async {
          guard let self else { return }
          self.isSessionActive = false
          self.stop()
          self.updatePermissionPolling(
            enabled: self.isEnabled, trusted: self.isAccessibilityGranted)
        }
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

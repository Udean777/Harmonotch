import AppKit
import Combine
import Foundation

final class VolumeManager: ObservableObject {
  static let shared = VolumeManager()

  @Published var currentVolume: Float = 0.5
  @Published var isMuted: Bool = false
  @Published var isHUDVisible: Bool = false
  @Published var hasAccessibilityPermission: Bool = false
  @Published var isEnabled: Bool {
    didSet {
      UserDefaults.standard.set(isEnabled, forKey: UserDefaultsKeys.replaceVolumeHUD)
      applyEnabledState()
    }
  }
  @Published var isFeedbackSoundEnabled: Bool {
    didSet {
      UserDefaults.standard.set(isFeedbackSoundEnabled, forKey: UserDefaultsKeys.volumeFeedbackSound)
    }
  }

  static let normalStep: Float = 1.0 / 16.0
  static let fineStep: Float = 1.0 / 64.0

  private let audioController = AudioVolumeController.shared
  let interceptor = VolumeKeyInterceptor()
  private var dismissTimer: Timer?
  private var permissionTimer: Timer?
  private var cancellables = Set<AnyCancellable>()

  private init() {
    let saved = UserDefaults.standard.object(forKey: UserDefaultsKeys.replaceVolumeHUD)
    self.isEnabled = saved == nil ? true : UserDefaults.standard.bool(forKey: UserDefaultsKeys.replaceVolumeHUD)

    let soundSaved = UserDefaults.standard.object(forKey: UserDefaultsKeys.volumeFeedbackSound)
    self.isFeedbackSoundEnabled = soundSaved == nil ? true : UserDefaults.standard.bool(forKey: UserDefaultsKeys.volumeFeedbackSound)

    self.currentVolume = audioController.getVolume()
    self.isMuted = audioController.isMuted
    self.hasAccessibilityPermission = AXIsProcessTrusted()

    setupAudioCallbacks()
    setupInterceptorCallbacks()

    NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
      .sink { [weak self] _ in
        self?.checkAccessibilityPermission()
      }
      .store(in: &cancellables)
  }

  // MARK: - Setup

  private func setupAudioCallbacks() {
    audioController.onVolumeChange = { [weak self] newVol, muted in
      guard let self = self else { return }
      let volumeChanged = abs(self.currentVolume - newVol) > 0.001
      let muteChanged = self.isMuted != muted

      self.currentVolume = newVol
      self.isMuted = muted

      if self.isEnabled && (volumeChanged || muteChanged) {
        self.showHUD()
      }
    }
  }

  private func setupInterceptorCallbacks() {
    interceptor.onAction = { [weak self] action in
      DispatchQueue.main.async {
        guard let self = self else { return }
        switch action {
        case .up(let fine):
          self.volumeUp(fine: fine)
        case .down(let fine):
          self.volumeDown(fine: fine)
        case .mute:
          self.toggleMute()
        }
      }
    }
  }

  // MARK: - Start / Stop

  func start() {
    let trusted = AXIsProcessTrusted()
    hasAccessibilityPermission = trusted
    currentVolume = audioController.getVolume()
    isMuted = audioController.isMuted
    NSLog("[Harmonotch:Volume] VolumeManager.start() - isEnabled: %d, AXIsProcessTrusted: %d", isEnabled ? 1 : 0, trusted ? 1 : 0)

    if isEnabled {
      applyEnabledState()
    }

    startPermissionWatcher()
  }

  func stop() {
    interceptor.stop()
    dismissTimer?.invalidate()
    dismissTimer = nil
    permissionTimer?.invalidate()
    permissionTimer = nil
  }

  private func applyEnabledState() {
    if isEnabled {
      hasAccessibilityPermission = AXIsProcessTrusted()
      if hasAccessibilityPermission {
        _ = interceptor.start()
      }
    } else {
      interceptor.stop()
    }
  }

  private func startPermissionWatcher() {
    permissionTimer?.invalidate()
    permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
      guard let self = self else { return }
      let trusted = AXIsProcessTrusted()
      DispatchQueue.main.async {
        if self.hasAccessibilityPermission != trusted {
          self.hasAccessibilityPermission = trusted
          NSLog("[Harmonotch:Volume] Accessibility trust changed to: %d", trusted ? 1 : 0)
        }
        if trusted && self.isEnabled && !self.interceptor.isRunning {
          _ = self.interceptor.start()
        }
      }
    }
  }

  func toggleEnabled() {
    isEnabled.toggle()
  }

  func toggleFeedbackSound() {
    isFeedbackSoundEnabled.toggle()
  }

  // MARK: - Accessibility Permissions

  func openAccessibilityPreferences() {
    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
      NSWorkspace.shared.open(url)
    }
  }

  @discardableResult
  func checkAccessibilityPermission() -> Bool {
    let trusted = AXIsProcessTrusted()
    hasAccessibilityPermission = trusted
    if trusted && isEnabled && !interceptor.isRunning {
      _ = interceptor.start()
    }
    return trusted
  }

  func requestAccessibilityPermission() {
    let checkOptPrompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString
    let options = [checkOptPrompt: true] as CFDictionary
    let trusted = AXIsProcessTrustedWithOptions(options)
    hasAccessibilityPermission = trusted
    if trusted && isEnabled {
      _ = interceptor.start()
    }
  }

  // MARK: - Volume Control Actions

  func setVolume(to volume: Float) {
    let target = max(0.0, min(1.0, volume))
    audioController.setVolume(target)
    currentVolume = audioController.getVolume()
    isMuted = audioController.isMuted
    showHUD()
  }

  func volumeUp(fine: Bool = false) {
    let step = fine ? Self.fineStep : Self.normalStep
    let target = min(1.0, currentVolume + step)
    audioController.setVolume(target)
    currentVolume = audioController.getVolume()
    isMuted = audioController.isMuted
    audioController.playFeedbackSoundIfNeeded()
    showHUD()
  }

  func volumeDown(fine: Bool = false) {
    let step = fine ? Self.fineStep : Self.normalStep
    let target = max(0.0, currentVolume - step)
    audioController.setVolume(target)
    currentVolume = audioController.getVolume()
    isMuted = audioController.isMuted
    audioController.playFeedbackSoundIfNeeded()
    showHUD()
  }

  func toggleMute() {
    audioController.toggleMute()
    isMuted = audioController.isMuted
    currentVolume = audioController.getVolume()
    showHUD()
  }

  // MARK: - HUD Presentation

  func showHUD() {
    isHUDVisible = true
    dismissTimer?.invalidate()
    dismissTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in
      DispatchQueue.main.async {
        self?.isHUDVisible = false
      }
    }
  }
}

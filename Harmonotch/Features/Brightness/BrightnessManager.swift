import AppKit
import Combine
import Foundation

final class BrightnessManager: ObservableObject {
  static let shared = BrightnessManager()

  @Published var currentBrightness: Float = 0.5
  @Published var isHUDVisible: Bool = false
  @Published var isEnabled: Bool {
    didSet {
      UserDefaults.standard.set(isEnabled, forKey: UserDefaultsKeys.replaceBrightnessHUD)
      if isEnabled {
        startBrightnessMonitor()
      } else {
        stopBrightnessMonitor()
        hideHUD()
      }
    }
  }

  static let normalStep: Float = 1.0 / 16.0
  static let fineStep: Float = 1.0 / 64.0

  private let controller = DisplayBrightnessController.shared
  private var dismissTimer: Timer?
  private var monitorTimer: Timer?
  private var cancellables = Set<AnyCancellable>()

  private init() {
    let saved = UserDefaults.standard.object(forKey: UserDefaultsKeys.replaceBrightnessHUD)
    self.isEnabled = saved == nil ? true : UserDefaults.standard.bool(forKey: UserDefaultsKeys.replaceBrightnessHUD)
    self.currentBrightness = controller.getBrightness()

    setupInterceptorCallbacks()
  }

  // MARK: - Setup

  private func setupInterceptorCallbacks() {
    VolumeManager.shared.interceptor.onBrightnessAction = { [weak self] action in
      DispatchQueue.main.async {
        guard let self = self, self.isEnabled else { return }
        switch action {
        case .up(let fine):
          self.brightnessUp(fine: fine)
        case .down(let fine):
          self.brightnessDown(fine: fine)
        }
      }
    }
  }

  func start() {
    setupInterceptorCallbacks()
    currentBrightness = controller.getBrightness()
    if isEnabled {
      startBrightnessMonitor()
    }
  }

  func stop() {
    stopBrightnessMonitor()
    dismissTimer?.invalidate()
    dismissTimer = nil
  }

  func toggleEnabled() {
    isEnabled.toggle()
  }

  // MARK: - System Brightness Monitor (100ms background polling)

  private func startBrightnessMonitor() {
    monitorTimer?.invalidate()
    monitorTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
      guard let self = self, self.isEnabled else { return }
      let live = self.controller.getBrightness()
      if abs(live - self.currentBrightness) > 0.005 {
        DispatchQueue.main.async {
          self.currentBrightness = live
          self.showHUD()
        }
      }
    }
  }

  private func stopBrightnessMonitor() {
    monitorTimer?.invalidate()
    monitorTimer = nil
  }

  // MARK: - Brightness Actions

  func setBrightness(to value: Float) {
    let target = max(0.0, min(1.0, value))
    controller.setBrightness(target)
    currentBrightness = controller.getBrightness()
    if isEnabled {
      showHUD()
    }
  }

  func brightnessUp(fine: Bool = false) {
    let step = fine ? Self.fineStep : Self.normalStep
    let newBrightness = min(1.0, currentBrightness + step)
    setBrightness(to: newBrightness)
  }

  func brightnessDown(fine: Bool = false) {
    let step = fine ? Self.fineStep : Self.normalStep
    let newBrightness = max(0.0, currentBrightness - step)
    setBrightness(to: newBrightness)
  }

  // MARK: - HUD Display

  func showHUD() {
    guard isEnabled else { return }
    isHUDVisible = true
    scheduleDismiss()
  }

  func hideHUD() {
    isHUDVisible = false
    dismissTimer?.invalidate()
    dismissTimer = nil
  }

  private func scheduleDismiss() {
    dismissTimer?.invalidate()
    dismissTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in
      DispatchQueue.main.async {
        self?.isHUDVisible = false
      }
    }
  }
}

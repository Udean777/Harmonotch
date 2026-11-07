import Combine
import CoreGraphics
import Foundation

final class SystemBrightnessService: ObservableObject {
  static let shared = SystemBrightnessService()

  @Published private(set) var currentBrightness: Float = 0.5

  private typealias GetLinearBrightnessFunc = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
  private typealias SetLinearBrightnessFunc = @convention(c) (CGDirectDisplayID, Float) -> Int32

  private var getBrightnessFn: GetLinearBrightnessFunc?
  private var setBrightnessFn: SetLinearBrightnessFunc?
  private var refreshTimer: Timer?
  private var isObserving = false

  private init() {
    loadDisplayServices()
    refreshBrightness()
  }

  private func loadDisplayServices() {
    guard let handle = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY) else {
      return
    }
    if let getSym = dlsym(handle, "DisplayServicesGetLinearBrightness") {
      getBrightnessFn = unsafeBitCast(getSym, to: GetLinearBrightnessFunc.self)
    }
    if let setSym = dlsym(handle, "DisplayServicesSetLinearBrightness") {
      setBrightnessFn = unsafeBitCast(setSym, to: SetLinearBrightnessFunc.self)
    }
  }

  func refreshBrightness() {
    var value: Float = 0
    if let getFn = getBrightnessFn {
      let status = getFn(CGMainDisplayID(), &value)
      if status == 0, value.isFinite {
        let clamped = min(1, max(0, value))
        if abs(currentBrightness - clamped) > 0.001 {
          currentBrightness = clamped
        }
      }
    }
  }

  @discardableResult
  func setBrightness(_ target: Float) -> Bool {
    guard target.isFinite else { return false }
    let clamped = min(1, max(0, target))
    currentBrightness = clamped
    guard let setFn = setBrightnessFn else { return false }
    let status = setFn(CGMainDisplayID(), clamped)
    return status == 0
  }

  func step(direction: Int, fine: Bool = false) {
    let delta: Float = (direction > 0 ? 1 : -1) * (fine ? (1.0 / 64.0) : (1.0 / 16.0))
    setBrightness(currentBrightness + delta)
  }

  func startObserving() {
    refreshBrightness()
    guard !isObserving else { return }
    isObserving = true
    refreshTimer?.invalidate()
    refreshTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
      self?.refreshBrightness()
    }
  }

  func stopObserving() {
    isObserving = false
    refreshTimer?.invalidate()
    refreshTimer = nil
  }
}

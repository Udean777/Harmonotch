import Cocoa
import CoreGraphics

private typealias DisplayServicesGetBrightnessFunc = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
private typealias DisplayServicesSetBrightnessFunc = @convention(c) (CGDirectDisplayID, Float) -> Int32
private typealias DisplayServicesCanChangeBrightnessFunc = @convention(c) (CGDirectDisplayID) -> Bool

final class DisplayBrightnessController {
  static let shared = DisplayBrightnessController()

  private var getBrightnessFunc: DisplayServicesGetBrightnessFunc?
  private var setBrightnessFunc: DisplayServicesSetBrightnessFunc?
  private var canChangeBrightnessFunc: DisplayServicesCanChangeBrightnessFunc?
  private var frameworkHandle: UnsafeMutableRawPointer?

  init() {
    loadDisplayServices()
  }

  deinit {
    if let handle = frameworkHandle {
      dlclose(handle)
    }
  }

  private func loadDisplayServices() {
    let path = "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices"
    guard let handle = dlopen(path, RTLD_LAZY) else {
      NSLog("[Harmonotch:Brightness] Failed to load DisplayServices.framework")
      return
    }
    self.frameworkHandle = handle

    if let sym = dlsym(handle, "DisplayServicesGetBrightness") {
      getBrightnessFunc = unsafeBitCast(sym, to: DisplayServicesGetBrightnessFunc.self)
    }
    if let sym = dlsym(handle, "DisplayServicesSetBrightness") {
      setBrightnessFunc = unsafeBitCast(sym, to: DisplayServicesSetBrightnessFunc.self)
    }
    if let sym = dlsym(handle, "DisplayServicesCanChangeBrightness") {
      canChangeBrightnessFunc = unsafeBitCast(sym, to: DisplayServicesCanChangeBrightnessFunc.self)
    }
  }

  func canChangeBrightness(displayID: CGDirectDisplayID = CGMainDisplayID()) -> Bool {
    if let canChange = canChangeBrightnessFunc {
      return canChange(displayID)
    }
    return getBrightnessFunc != nil && setBrightnessFunc != nil
  }

  func getBrightness(displayID: CGDirectDisplayID = CGMainDisplayID()) -> Float {
    guard let getBrightness = getBrightnessFunc else { return 0.5 }
    var val: Float = 0.0
    let res = getBrightness(displayID, &val)
    if res == 0 {
      return max(0.0, min(1.0, val))
    }
    return 0.5
  }

  @discardableResult
  func setBrightness(_ value: Float, displayID: CGDirectDisplayID = CGMainDisplayID()) -> Bool {
    guard let setBrightness = setBrightnessFunc else { return false }
    let clamped = max(0.0, min(1.0, value))
    let res = setBrightness(displayID, clamped)
    return res == 0
  }
}

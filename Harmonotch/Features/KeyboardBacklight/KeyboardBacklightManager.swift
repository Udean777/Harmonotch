import Combine
import Darwin
import Foundation

/// Keyboard backlight level through CoreBrightness' private
/// `KeyboardBrightnessClient`, the only way to reach the built-in keyboard
/// light without simulating F5/F6 through Accessibility.
final class KeyboardBacklightManager: ObservableObject {
  static let shared = KeyboardBacklightManager()

  @Published private(set) var isSupported = false
  @Published private(set) var brightness: Double = 0

  private static let coreBrightness: UnsafeMutableRawPointer? = dlopen(
    "/System/Library/PrivateFrameworks/CoreBrightness.framework/CoreBrightness",
    RTLD_NOW)

  private let client: NSObject?
  private let keyboardID: UInt64?

  private typealias FloatGetter = @convention(c) (AnyObject, Selector, UInt64) -> Float
  private typealias BoolGetter = @convention(c) (AnyObject, Selector, UInt64) -> Bool
  private typealias BrightnessSetter =
    @convention(c) (AnyObject, Selector, Float, UInt64) -> Bool

  private init() {
    guard Self.coreBrightness != nil,
      let type = NSClassFromString("KeyboardBrightnessClient") as? NSObject.Type
    else {
      client = nil
      keyboardID = nil
      return
    }

    let instance = type.init()
    client = instance

    let idsSelector = NSSelectorFromString("copyKeyboardBacklightIDs")
    guard instance.responds(to: idsSelector),
      let ids = instance.perform(idsSelector)?.takeRetainedValue() as? [NSNumber]
    else {
      keyboardID = nil
      return
    }

    let builtInSelector = NSSelectorFromString("isKeyboardBuiltIn:")
    var builtInID: UInt64?
    if instance.responds(to: builtInSelector) {
      let builtIn = unsafeBitCast(instance.method(for: builtInSelector), to: BoolGetter.self)
      // A closure here crashed the optimized build, a plain loop is fine.
      for id in ids where builtIn(instance, builtInSelector, id.uint64Value) {
        builtInID = id.uint64Value
        break
      }
    } else if let first = ids.first {
      builtInID = first.uint64Value
    }

    keyboardID = builtInID
    isSupported = builtInID != nil
    refresh()
  }

  /// Re-reads the level, which the ambient light sensor can change on its own.
  func refresh() {
    guard let client, let keyboardID else { return }
    let selector = NSSelectorFromString("brightnessForKeyboard:")
    let getter = unsafeBitCast(client.method(for: selector), to: FloatGetter.self)
    brightness = Double(getter(client, selector, keyboardID))
  }

  func setBrightness(_ value: Double) {
    let level = Float(min(1, max(0, value)))
    brightness = Double(level)
    guard let client, let keyboardID else { return }
    let selector = NSSelectorFromString("setBrightness:forKeyboard:")
    let setter = unsafeBitCast(client.method(for: selector), to: BrightnessSetter.self)
    _ = setter(client, selector, level, keyboardID)
  }
}

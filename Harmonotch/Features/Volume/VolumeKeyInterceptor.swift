import AppKit
import CoreGraphics
import Foundation

enum VolumeAction {
  case up(fine: Bool)
  case down(fine: Bool)
  case mute
}

enum BrightnessAction {
  case up(fine: Bool)
  case down(fine: Bool)
}

final class VolumeKeyInterceptor {
  var onAction: ((VolumeAction) -> Void)?
  var onBrightnessAction: ((BrightnessAction) -> Void)?

  // MARK: - Media Key Tap (Main RunLoop, NX_SYSDEFINED)
  private var mediaTap: CFMachPort?
  private var mediaRunLoopSource: CFRunLoopSource?

  // MARK: - Function Key Tap (Dedicated Background Thread, keyDown/keyUp for F1/F2)
  private var functionKeyTap: CFMachPort?
  private var functionKeyRunLoop: CFRunLoop?
  private var functionKeyThread: Thread?
  private let lock = NSLock()
  private var shouldStopFunctionKeyThread = false

  private enum NXKeyType {
    static let soundUp: Int32 = 0
    static let soundDown: Int32 = 1
    static let brightnessUp: Int32 = 2
    static let brightnessDown: Int32 = 3
    static let mute: Int32 = 7
  }

  private enum BrightnessKeyCode {
    static let increase = 144
    static let decrease = 145
    static let f2 = 120
    static let f1 = 122
    static let f15 = 113
    static let f14 = 107

    static func isBrightnessKeyCode(_ code: Int) -> Bool {
      return code == increase || code == decrease || code == f2 || code == f1 || code == f15 || code == f14
    }

    static func isIncrease(_ code: Int) -> Bool {
      return code == increase || code == f2 || code == f15
    }
  }

  deinit {
    stop()
  }

  // MARK: - Lifecycle

  @discardableResult
  func start() -> Bool {
    guard mediaTap == nil else { return true }
    guard AXIsProcessTrusted() else { return false }
    NSLog("[Harmonotch:Volume] Starting VolumeKeyInterceptor, AXIsProcessTrusted: 1")

    installMediaKeyTap()
    if mediaTap != nil {
      installFunctionKeyTap()
    }
    return isRunning
  }

  func stop() {
    stopMediaKeyTap()
    stopFunctionKeyTap()
    NSLog("[Harmonotch:Volume] VolumeKeyInterceptor stopped")
  }

  var isRunning: Bool {
    mediaTap != nil
  }

  // MARK: - Media Key Tap (NX_SYSDEFINED 1 << 14)

  private func installMediaKeyTap() {
    let mask: CGEventMask = 1 << 14  // NX_SYSDEFINED

    let callback: CGEventTapCallBack = { (_, type, event, refcon) -> Unmanaged<CGEvent>? in
      guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
      let interceptor = Unmanaged<VolumeKeyInterceptor>.fromOpaque(refcon).takeUnretainedValue()

      if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let tap = interceptor.mediaTap, AXIsProcessTrusted() {
          CGEvent.tapEnable(tap: tap, enable: true)
        }
        return Unmanaged.passUnretained(event)
      }

      return interceptor.processMediaEvent(event)
    }

    let userInfo = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

    guard let tap = CGEvent.tapCreate(
      tap: .cgSessionEventTap,
      place: .headInsertEventTap,
      options: .defaultTap,
      eventsOfInterest: mask,
      callback: callback,
      userInfo: userInfo
    ) else {
      NSLog("[Harmonotch:Volume] Failed to create .cgSessionEventTap for media keys.")
      return
    }

    self.mediaTap = tap
    let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
    self.mediaRunLoopSource = source
    CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
    CGEvent.tapEnable(tap: tap, enable: true)
    NSLog("[Harmonotch:Volume] Media key tap installed and enabled")
  }

  private func stopMediaKeyTap() {
    if let tap = mediaTap {
      CGEvent.tapEnable(tap: tap, enable: false)
      CFMachPortInvalidate(tap)
      mediaTap = nil
    }
    if let source = mediaRunLoopSource {
      CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
      mediaRunLoopSource = nil
    }
  }

  fileprivate func processMediaEvent(_ event: CGEvent) -> Unmanaged<CGEvent>? {
    guard let nsEvent = NSEvent(cgEvent: event),
      nsEvent.type == .systemDefined,
      nsEvent.subtype.rawValue == 8
    else {
      return Unmanaged.passUnretained(event)
    }

    let data1 = nsEvent.data1
    let keyCode = Int32((data1 >> 16) & 0xFFFF)
    let state = (data1 >> 8) & 0xFF
    let isKeyDown = (state == 0x0A)
    let isRepeat = (data1 & 0x1) != 0

    let isSoundKey = (keyCode == NXKeyType.soundUp || keyCode == NXKeyType.soundDown || keyCode == NXKeyType.mute)
    let isBrightnessKey = (keyCode == NXKeyType.brightnessUp || keyCode == NXKeyType.brightnessDown)

    guard isSoundKey || isBrightnessKey else {
      return Unmanaged.passUnretained(event)
    }

    if isKeyDown || isRepeat {
      let isShift = event.flags.contains(.maskShift)
      let isOption = event.flags.contains(.maskAlternate)
      let isFine = isShift && isOption

      if isSoundKey {
        let action: VolumeAction?
        switch keyCode {
        case NXKeyType.soundUp:
          action = .up(fine: isFine)
        case NXKeyType.soundDown:
          action = .down(fine: isFine)
        case NXKeyType.mute:
          action = .mute
        default:
          action = nil
        }

        if let action = action {
          NSLog("[Harmonotch:Volume] Intercepted volume action: %@", String(describing: action))
          onAction?(action)
        }
      } else if isBrightnessKey {
        let action: BrightnessAction?
        switch keyCode {
        case NXKeyType.brightnessUp:
          action = .up(fine: isFine)
        case NXKeyType.brightnessDown:
          action = .down(fine: isFine)
        default:
          action = nil
        }

        if let action = action {
          NSLog("[Harmonotch:Volume] Intercepted brightness action: %@", String(describing: action))
          onBrightnessAction?(action)
        }
      }
    }

    // Always swallow intercepted media keys to suppress native macOS HUDs
    return nil
  }

  // MARK: - Function Key Tap (Background Thread for keyDown / keyUp)

  private func installFunctionKeyTap() {
    lock.lock()
    shouldStopFunctionKeyThread = false
    lock.unlock()

    let thread = Thread { [weak self] in
      self?.runFunctionKeyTapLoop()
    }
    thread.name = "com.harmonotch.FunctionKeyInterceptor"
    thread.qualityOfService = .userInteractive
    self.functionKeyThread = thread
    thread.start()
  }

  private func stopFunctionKeyTap() {
    lock.lock()
    shouldStopFunctionKeyThread = true
    let runLoop = functionKeyRunLoop
    let tap = functionKeyTap
    lock.unlock()

    if let tap = tap {
      CGEvent.tapEnable(tap: tap, enable: false)
    }
    if let runLoop = runLoop {
      CFRunLoopStop(runLoop)
    }
  }

  private func runFunctionKeyTapLoop() {
    autoreleasepool {
      let runLoop = CFRunLoopGetCurrent()
      lock.lock()
      guard !shouldStopFunctionKeyThread else {
        lock.unlock()
        return
      }
      self.functionKeyRunLoop = runLoop
      lock.unlock()

      let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)

      let callback: CGEventTapCallBack = { (_, type, event, refcon) -> Unmanaged<CGEvent>? in
        guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
        let interceptor = Unmanaged<VolumeKeyInterceptor>.fromOpaque(refcon).takeUnretainedValue()

        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
          interceptor.lock.lock()
          if let tap = interceptor.functionKeyTap, AXIsProcessTrusted() {
            CGEvent.tapEnable(tap: tap, enable: true)
          }
          interceptor.lock.unlock()
          return Unmanaged.passUnretained(event)
        }

        return interceptor.processFunctionKeyEvent(type: type, event: event)
      }

      let userInfo = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

      guard let tap = CGEvent.tapCreate(
        tap: .cgSessionEventTap,
        place: .headInsertEventTap,
        options: .defaultTap,
        eventsOfInterest: mask,
        callback: callback,
        userInfo: userInfo
      ) else {
        NSLog("[Harmonotch:Volume] Failed to create .cgSessionEventTap for function keys")
        return
      }

      lock.lock()
      self.functionKeyTap = tap
      lock.unlock()

      let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
      CFRunLoopAddSource(runLoop, source, .commonModes)
      CGEvent.tapEnable(tap: tap, enable: true)

      NSLog("[Harmonotch:Volume] Function key tap loop running on background thread")
      CFRunLoopRun()

      CGEvent.tapEnable(tap: tap, enable: false)
      CFRunLoopRemoveSource(runLoop, source, .commonModes)
      CFMachPortInvalidate(tap)

      lock.lock()
      self.functionKeyTap = nil
      self.functionKeyRunLoop = nil
      self.functionKeyThread = nil
      lock.unlock()
    }
  }

  fileprivate func processFunctionKeyEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
    guard type == .keyDown || type == .keyUp else {
      return Unmanaged.passUnretained(event)
    }

    let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
    guard BrightnessKeyCode.isBrightnessKeyCode(keyCode) else {
      return Unmanaged.passUnretained(event)
    }

    if type == .keyDown {
      let isShift = event.flags.contains(.maskShift)
      let isOption = event.flags.contains(.maskAlternate)
      let isFine = isShift && isOption

      let isIncrease = BrightnessKeyCode.isIncrease(keyCode)
      let action: BrightnessAction = isIncrease ? .up(fine: isFine) : .down(fine: isFine)
      NSLog("[Harmonotch:Volume] Intercepted function key brightness: %ld, action: %@", keyCode, String(describing: action))
      onBrightnessAction?(action)
    }

    // Swallow F1/F2 brightness events to prevent native HUD
    return nil
  }
}

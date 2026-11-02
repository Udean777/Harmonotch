import AppKit
import Combine
import Darwin
import SwiftUI

final class PassThroughHostingView<Content: View>: NSHostingView<Content> {
  private var trackingArea: NSTrackingArea?

  override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
    true
  }

  override func updateTrackingAreas() {
    super.updateTrackingAreas()
    if let existing = trackingArea {
      removeTrackingArea(existing)
    }
    let newArea = NSTrackingArea(
      rect: bounds,
      options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect],
      owner: self,
      userInfo: nil
    )
    addTrackingArea(newArea)
    trackingArea = newArea
  }

  override func mouseMoved(with event: NSEvent) {
    super.mouseMoved(with: event)
  }

  override func hitTest(_ point: NSPoint) -> NSView? {
    let notchVM = NotchViewModel.shared
    let isExpanded = notchVM.isExpanded
    let geometry = notchVM.geometry
    let isMediaPlaying =
      MediaManager.shared.isPlaying
      && MediaManager.shared.hasActiveTrack
      && !AdzanPlayer.shared.isPlaying
    let leftContentExpansion: CGFloat = {
      if isMediaPlaying {
        return notchVM.isCompanionEnabled ? NotchLayout.mediaLeftExpansion : 0
      }
      return notchVM.isLeftCompanionVisible ? NotchLayout.companionExpansion : 0
    }()

    let topY = bounds.height
    let currentWidth: CGFloat
    let currentHeight: CGFloat

    if isExpanded {
      currentWidth = NotchLayout.expandedWidth
      let topClearance = geometry.hasHardwareNotch ? (geometry.physicalNotchHeight + 4) : 8
      currentHeight = topClearance + NotchLayout.expandedHitAreaHeight
    } else {
      currentWidth =
        geometry.collapsedWidth(
          isHovered: notchVM.isHovered,
          isMediaPlaying: isMediaPlaying
        ) + leftContentExpansion
      currentHeight = geometry.collapsedHeight
    }

    let leftExpansionOffset =
      !isExpanded && leftContentExpansion > 0
      ? -(leftContentExpansion / 2)
      : 0
    let minX = (bounds.width - currentWidth) / 2 + leftExpansionOffset
    let maxX = minX + currentWidth
    let topInset = geometry.hasHardwareNotch ? 0 : NotchLayout.floatingTopInset
    let minY = topY - topInset - currentHeight
    let maxY = topY - topInset

    let isInsideNotchRadius =
      (point.x >= minX && point.x <= maxX && point.y >= (minY - 2) && point.y <= maxY)

    if isInsideNotchRadius {
      // Intercept events to prevent menu bar slide-down.
      return super.hitTest(point) ?? self
    }

    // Pass through to menu bar when outside notch.
    return nil
  }
}

/// Overlay Space that anchors notch across Desktop Spaces and Fullscreen.
private final class NotchOverlaySpace {
  private typealias ConnectionID = UInt32
  private typealias CreateFunction = @convention(c) (ConnectionID, Int32, CFDictionary?) -> UInt64
  private typealias SpacesFunction = @convention(c) (ConnectionID, CFArray) -> Int32
  private typealias WindowsFunction = @convention(c) (ConnectionID, CFArray, CFArray) -> Void
  private typealias DestroyFunction = @convention(c) (ConnectionID, UInt64) -> Void

  private struct Bridge {
    let connection: ConnectionID
    let create: CreateFunction
    let show: SpacesFunction
    let hide: SpacesFunction
    let add: WindowsFunction
    let remove: WindowsFunction
    let destroy: DestroyFunction
  }

  private static let bridge: Bridge? = {
    func symbol(_ name: String) -> UnsafeMutableRawPointer? {
      dlsym(UnsafeMutableRawPointer(bitPattern: -2), name)
    }
    guard let main = symbol("CGSMainConnectionID"),
      let create = symbol("CGSSpaceCreate"),
      let show = symbol("CGSShowSpaces"),
      let hide = symbol("CGSHideSpaces"),
      let add = symbol("CGSAddWindowsToSpaces"),
      let remove = symbol("CGSRemoveWindowsFromSpaces"),
      let destroy = symbol("CGSSpaceDestroy")
    else { return nil }
    let connection = unsafeBitCast(main, to: (@convention(c) () -> ConnectionID).self)()
    guard connection != 0 else { return nil }
    return Bridge(
      connection: connection,
      create: unsafeBitCast(create, to: CreateFunction.self),
      show: unsafeBitCast(show, to: SpacesFunction.self),
      hide: unsafeBitCast(hide, to: SpacesFunction.self),
      add: unsafeBitCast(add, to: WindowsFunction.self),
      remove: unsafeBitCast(remove, to: WindowsFunction.self),
      destroy: unsafeBitCast(destroy, to: DestroyFunction.self)
    )
  }()

  private let bridge: Bridge
  private let space: UInt64
  private var windows = Set<Int>()
  private var closed = false

  init?() {
    guard let bridge = Self.bridge else { return nil }
    let space = bridge.create(bridge.connection, 1, nil)
    guard space != 0 else { return nil }
    self.bridge = bridge
    self.space = space
    _ = bridge.show(bridge.connection, [NSNumber(value: space)] as CFArray)
  }

  deinit {
    close()
  }

  func add(_ window: NSWindow) {
    guard !closed, window.windowNumber > 0, windows.insert(window.windowNumber).inserted else {
      return
    }
    bridge.add(
      bridge.connection,
      [NSNumber(value: window.windowNumber)] as CFArray,
      [NSNumber(value: space)] as CFArray
    )
  }

  func close() {
    guard !closed else { return }
    closed = true
    if !windows.isEmpty {
      bridge.remove(
        bridge.connection,
        windows.map { NSNumber(value: $0) } as CFArray,
        [NSNumber(value: space)] as CFArray
      )
      windows.removeAll()
    }
    _ = bridge.hide(bridge.connection, [NSNumber(value: space)] as CFArray)
    bridge.destroy(bridge.connection, space)
  }
}

/// Borderless panel that always sits flush against the top screen edge (both on
/// notched Macs and as a replacement notch on non-notched displays) and never
/// hides when switching windows or deactivating the app.
private final class NotchPanel: NSPanel {
  var allowsOrderOut = false

  override var canBecomeKey: Bool { false }
  override var canBecomeMain: Bool { false }

  @objc func _hasActiveAppearanceIgnoringKeyFocus() -> Bool { true }

  override func accessibilitySubrole() -> NSAccessibility.Subrole? { .unknown }

  override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
    frameRect
  }

  override func orderOut(_ sender: Any?) {
    guard allowsOrderOut else { return }
    super.orderOut(sender)
  }
}

final class NotchWindowController: ObservableObject {
  static let shared = NotchWindowController()

  @Published var isNotchHidden: Bool {
    didSet {
      UserDefaults.standard.set(isNotchHidden, forKey: UserDefaultsKeys.isNotchHidden)
    }
  }

  private var panel: NotchPanel?
  private let overlaySpace = NotchOverlaySpace()
  private var cancellables = Set<AnyCancellable>()
  private var outsideClickMonitor: Any?

  // Fixed size prevents Auto Layout constraint loop.
  static let canvasWidth: CGFloat = 660
  static let canvasHeight: CGFloat = 620

  init() {
    self.isNotchHidden = UserDefaults.standard.bool(forKey: UserDefaultsKeys.isNotchHidden)
  }

  func setupAndShowWindow() {
    guard let screen = NSScreen.main else { return }
    NotchViewModel.shared.updateGeometry(for: screen)

    let frame = calculateFixedFrame(for: screen)

    let notchPanel = NotchPanel(
      contentRect: frame,
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )

    notchPanel.level = .statusBar + 2
    notchPanel.isOpaque = false
    notchPanel.backgroundColor = .clear
    notchPanel.hasShadow = false
    notchPanel.isMovable = false
    notchPanel.isMovableByWindowBackground = false
    notchPanel.isReleasedWhenClosed = false
    notchPanel.hidesOnDeactivate = false
    notchPanel.animationBehavior = .none
    notchPanel.collectionBehavior = [
      .canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle,
    ]

    let hostingView = PassThroughHostingView(rootView: NotchContainerView())
    notchPanel.contentView = hostingView

    overlaySpace?.add(notchPanel)
    self.panel = notchPanel

    NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
      .receive(on: DispatchQueue.main)
      .sink { [weak self] _ in
        guard let self = self, let screen = self.panel?.screen ?? NSScreen.main else { return }
        NotchViewModel.shared.updateGeometry(for: screen)
        self.panel?.setFrame(self.calculateFixedFrame(for: screen), display: true)
      }
      .store(in: &cancellables)

    NotificationCenter.default.publisher(
      for: NSWindow.didChangeScreenNotification, object: notchPanel
    )
    .receive(on: DispatchQueue.main)
    .sink { [weak self] _ in
      guard let self = self, let panel = self.panel, let screen = panel.screen else { return }
      NotchViewModel.shared.updateGeometry(for: screen)
    }
    .store(in: &cancellables)

    if !isNotchHidden {
      notchPanel.allowsOrderOut = false
      notchPanel.orderFrontRegardless()
    } else {
      notchPanel.allowsOrderOut = true
    }

    let appActivationEvents = Publishers.Merge(
      NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification),
      NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)
    )
    let workspaceEvents = Publishers.Merge3(
      NSWorkspace.shared.notificationCenter.publisher(
        for: NSWorkspace.activeSpaceDidChangeNotification),
      NSWorkspace.shared.notificationCenter.publisher(
        for: NSWorkspace.didActivateApplicationNotification),
      NSWorkspace.shared.notificationCenter.publisher(
        for: NSWorkspace.didDeactivateApplicationNotification)
    )

    Publishers.Merge(appActivationEvents, workspaceEvents)
      .receive(on: DispatchQueue.main)
      .sink { [weak self] _ in
        guard let self = self, let panel = self.panel, !self.isNotchHidden else { return }
        panel.allowsOrderOut = false
        if !panel.isVisible {
          panel.orderFrontRegardless()
        }
      }
      .store(in: &cancellables)

    // Collapse drawer on outside click.
    outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [
      .leftMouseDown, .rightMouseDown,
    ]) { [weak self] _ in
      guard let self = self, let panel = self.panel, NotchViewModel.shared.isExpanded else {
        return
      }
      let mouseLocation = NSEvent.mouseLocation
      let windowPoint = panel.convertPoint(fromScreen: mouseLocation)
      if let contentView = panel.contentView, contentView.hitTest(windowPoint) != nil {
        return
      }
      NotchViewModel.shared.collapse()
    }
  }

  private func calculateFixedFrame(for screen: NSScreen) -> NSRect {
    let width = Self.canvasWidth
    let height = Self.canvasHeight

    let x = screen.frame.origin.x + (screen.frame.width - width) / 2
    let y = screen.frame.maxY - height

    return NSRect(x: x, y: y, width: width, height: height)
  }

  func toggleNotchHidden() {
    isNotchHidden.toggle()
    if isNotchHidden {
      panel?.allowsOrderOut = true
      panel?.orderOut(nil)
    } else {
      panel?.allowsOrderOut = false
      panel?.orderFrontRegardless()
    }
  }
}

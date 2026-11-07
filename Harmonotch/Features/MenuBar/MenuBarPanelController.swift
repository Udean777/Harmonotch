import AppKit
import Combine
import SwiftUI

private final class MenuBarPanel: NSPanel {
  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { false }
}

/// NSHostingView subclass that keeps hit-testing aligned with the measured dashboard card.
private final class MenuBarHostingView<Content: View>: NSHostingView<Content> {
  /// The actual rendered height of the dashboard card. Updated via PreferenceKey.
  var cardHeight: CGFloat = MenuBarPanelController.panelInitialHeight {
    didSet {
      window?.invalidateShadow()
    }
  }

  override func hitTest(_ point: NSPoint) -> NSView? {
    // Convert from superview (window's flipped content area) coordinates to our own.
    let local = convert(point, from: superview)
    // The card is top-aligned; anything below cardHeight is transparent padding.
    if local.y > cardHeight + 1 { return nil }
    return super.hitTest(point)
  }
}

final class MenuBarPanelController: NSObject {
  static let shared = MenuBarPanelController()

  /// Temporary height used before the dashboard reports its natural content height.
  static let panelInitialHeight: CGFloat = 300

  private var panel: NSPanel?
  private var hostingView: MenuBarHostingView<MenuBarDashboardView>?
  private var measuredPanelHeight: CGFloat = panelInitialHeight
  private let viewModel = MenuBarDashboardViewModel()
  private var globalEventMonitor: Any?
  private var localEventMonitor: Any?
  private weak var currentStatusButton: NSStatusBarButton?
  private var cancellables = Set<AnyCancellable>()

  var isVisible: Bool {
    panel?.isVisible ?? false
  }

  private override init() {
    super.init()
    observeLayoutAndLifecycle()
    viewModel.onCardHeightChanged = { [weak self] height in
      guard height > 0, height.isFinite else { return }
      self?.hostingView?.cardHeight = height
      self?.resizePanel(to: height)
    }
  }

  private func observeLayoutAndLifecycle() {
    let triggers: [AnyPublisher<Void, Never>] = [
      UpdateManager.shared.$state.map { _ in () }.eraseToAnyPublisher(),
      MediaManager.shared.$trackTitle.map { _ in () }.eraseToAnyPublisher(),
      AdzanPlayer.shared.$isPlaying.map { _ in () }.eraseToAnyPublisher(),
      BatteryMonitor.shared.$state.map { _ in () }.eraseToAnyPublisher(),
      LanguageManager.shared.$currentLanguage.map { _ in () }.eraseToAnyPublisher(),
      AIAgentQuotaService.shared.$agents.map { _ in () }.eraseToAnyPublisher(),
      AIAgentQuotaService.shared.$isScanning.map { _ in () }.eraseToAnyPublisher(),
    ]

    Publishers.MergeMany(triggers)
      .receive(on: DispatchQueue.main)
      .sink { [weak self] _ in
        guard let self, self.isVisible else { return }
        self.panel?.invalidateShadow()
      }
      .store(in: &cancellables)
  }

  func toggle(relativeTo button: NSStatusBarButton) {
    if isVisible {
      close()
    } else {
      show(relativeTo: button)
    }
  }

  func show(relativeTo button: NSStatusBarButton) {
    self.currentStatusButton = button

    let panel = getOrCreatePanel()

    positionPanel(panel, relativeTo: button, height: measuredPanelHeight)

    panel.alphaValue = 0
    NSApp.activate(ignoringOtherApps: true)
    panel.makeKeyAndOrderFront(nil)
    panel.makeFirstResponder(panel.contentView)
    viewModel.panelDidOpen()

    NSAnimationContext.runAnimationGroup { context in
      context.duration = 0.16
      context.timingFunction = CAMediaTimingFunction(name: .easeOut)
      panel.animator().alphaValue = 1.0
    }

    setupDismissMonitors()
  }

  func close() {
    guard let panel = panel, panel.isVisible else { return }

    removeDismissMonitors()
    // Stop demand-driven sampling as soon as the user dismisses the panel.
    viewModel.panelDidClose()

    NSAnimationContext.runAnimationGroup(
      { context in
        context.duration = 0.12
        context.timingFunction = CAMediaTimingFunction(name: .easeIn)
        panel.animator().alphaValue = 0.0
      },
      completionHandler: { [weak self] in
        self?.panel?.orderOut(nil)
      })
  }

  private func getOrCreatePanel() -> NSPanel {
    if let existing = panel {
      return existing
    }

    let dashboardView = MenuBarDashboardView(
      viewModel: viewModel,
      onClose: { [weak self] in
        self?.close()
      })

    let hv = MenuBarHostingView(rootView: dashboardView)
    // The panel frame follows the measured dashboard content height.
    hv.sizingOptions = []
    self.hostingView = hv

    let newPanel = MenuBarPanel(
      contentRect: NSRect(
        x: 0, y: 0,
        width: MenuBarDashboardViewModel.panelWidth,
        height: self.measuredPanelHeight
      ),
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )

    newPanel.isFloatingPanel = true
    newPanel.level = .statusBar
    newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    newPanel.backgroundColor = .clear
    newPanel.isOpaque = false
    newPanel.hasShadow = true
    newPanel.isMovableByWindowBackground = false
    newPanel.contentView = hv

    self.panel = newPanel
    return newPanel
  }

  /// Positions the panel so its top edge is flush below the status-bar button.
  private func positionPanel(
    _ panel: NSPanel,
    relativeTo button: NSStatusBarButton,
    height: CGFloat
  ) {
    guard let window = button.window else { return }

    let buttonBounds = button.bounds
    let buttonScreenRect = window.convertToScreen(button.convert(buttonBounds, to: nil))
    let screen = window.screen ?? NSScreen.main
    let visibleFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)

    let panelWidth = MenuBarDashboardViewModel.panelWidth
    let frame = MenuBarPanelLayout.frame(
      buttonRect: buttonScreenRect,
      visibleFrame: visibleFrame,
      height: height,
      width: panelWidth
    )

    panel.setFrame(frame, display: false)
  }

  private func resizePanel(to height: CGFloat) {
    measuredPanelHeight = height
    guard let panel = panel, panel.isVisible, let button = currentStatusButton else { return }

    let targetFrame = frame(for: panel, relativeTo: button, height: height)
    guard abs(panel.frame.height - height) > 0.5 || panel.frame.origin != targetFrame.origin else { return }

    // If the panel is still fading in, apply the target frame immediately without animating.
    if panel.alphaValue < 0.95 {
      panel.setFrame(targetFrame, display: false)
      hostingView?.cardHeight = height
      return
    }

    hostingView?.cardHeight = max(panel.frame.height, height)

    NSAnimationContext.runAnimationGroup { context in
      context.duration = 0.14
      context.timingFunction = CAMediaTimingFunction(name: .easeOut)
      panel.animator().setFrame(targetFrame, display: true)
    } completionHandler: { [weak self, weak panel] in
      self?.hostingView?.cardHeight = height
      panel?.invalidateShadow()
    }
  }

  private func frame(
    for panel: NSPanel,
    relativeTo button: NSStatusBarButton,
    height: CGFloat
  ) -> NSRect {
    guard let window = button.window else { return panel.frame }

    let buttonBounds = button.bounds
    let buttonScreenRect = window.convertToScreen(button.convert(buttonBounds, to: nil))
    let screen = window.screen ?? NSScreen.main
    let visibleFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)

    return MenuBarPanelLayout.frame(
      buttonRect: buttonScreenRect,
      visibleFrame: visibleFrame,
      height: height,
      width: MenuBarDashboardViewModel.panelWidth
    )
  }

  private func setupDismissMonitors() {
    removeDismissMonitors()

    globalEventMonitor = NSEvent.addGlobalMonitorForEvents(
      matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
    ) { [weak self] _ in
      self?.close()
    }

    localEventMonitor = NSEvent.addLocalMonitorForEvents(
      matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown, .keyDown]
    ) { [weak self] event in
      guard let self = self, let panel = self.panel, panel.isVisible else { return event }

      if event.type == .keyDown, event.keyCode == 53 {
        self.close()
        return nil
      }

      let clickLocation = event.locationInWindow
      let clickScreenPoint: NSPoint
      if let eventWindow = event.window {
        clickScreenPoint =
          eventWindow.convertToScreen(NSRect(origin: clickLocation, size: .zero)).origin
      } else {
        clickScreenPoint = NSEvent.mouseLocation
      }

      if let button = self.currentStatusButton, let btnWin = button.window {
        let btnRect = btnWin.convertToScreen(button.convert(button.bounds, to: nil))
        if NSPointInRect(clickScreenPoint, btnRect) {
          return event
        }
      }

      // Only dismiss for clicks in the transparent area (below actual card) or completely outside.
      if !NSPointInRect(clickScreenPoint, panel.frame) {
        self.close()
      } else if let hv = self.hostingView {
        // Convert screen point into hosting-view local coords and check against card.
        let windowPoint = panel.convertPoint(fromScreen: clickScreenPoint)
        let hvPoint = hv.convert(windowPoint, from: nil)
        if hvPoint.y > hv.cardHeight + 1 {
          self.close()
        }
      }

      return event
    }
  }

  private func removeDismissMonitors() {
    if let monitor = globalEventMonitor {
      NSEvent.removeMonitor(monitor)
      globalEventMonitor = nil
    }
    if let monitor = localEventMonitor {
      NSEvent.removeMonitor(monitor)
      localEventMonitor = nil
    }
  }
}

import AppKit
import SwiftUI
import Combine

final class MenuBarPanelController: NSObject {
    static let shared = MenuBarPanelController()

    private var panel: NSPanel?
    private var globalEventMonitor: Any?
    private var localEventMonitor: Any?
    private weak var currentStatusButton: NSStatusBarButton?
    private var cancellables = Set<AnyCancellable>()

    var isVisible: Bool {
        panel?.isVisible ?? false
    }

    private override init() {
        super.init()
        observeUpdateState()
    }

    private func observeUpdateState() {
        UpdateManager.shared.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self, let panel = self.panel, panel.isVisible, let button = self.currentStatusButton else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    self.positionPanel(panel, relativeTo: button)
                }
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

        positionPanel(panel, relativeTo: button)

        panel.alphaValue = 0
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

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

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.12
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0.0
        }, completionHandler: { [weak self] in
            self?.panel?.orderOut(nil)
        })
    }

    private func getOrCreatePanel() -> NSPanel {
        if let existing = panel {
            return existing
        }

        let popupView = MenuBarPopupView(onClose: { [weak self] in
            self?.close()
        })

        let hostingView = NSHostingView(rootView: popupView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false

        let newPanel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 480),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        newPanel.isFloatingPanel = true
        newPanel.level = .statusBar
        newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        newPanel.backgroundColor = .clear
        newPanel.isOpaque = false
        newPanel.hasShadow = false
        newPanel.isMovableByWindowBackground = false
        newPanel.contentView = hostingView

        self.panel = newPanel
        return newPanel
    }

    private func positionPanel(_ panel: NSPanel, relativeTo button: NSStatusBarButton) {
        guard let window = button.window else { return }

        let buttonBounds = button.bounds
        let buttonScreenRect = window.convertToScreen(button.convert(buttonBounds, to: nil))

        let panelWidth: CGFloat = 320
        let fittingSize = panel.contentView?.fittingSize ?? NSSize(width: panelWidth, height: 480)
        let panelHeight = max(fittingSize.height, 350)

        var x = buttonScreenRect.midX - (panelWidth / 2)

        if let screen = window.screen ?? NSScreen.main {
            let screenFrame = screen.visibleFrame
            if x + panelWidth > screenFrame.maxX - 10 {
                x = screenFrame.maxX - panelWidth - 10
            }
            if x < screenFrame.minX + 10 {
                x = screenFrame.minX + 10
            }
        }

        let y = buttonScreenRect.minY - panelHeight - 6

        panel.setFrame(NSRect(x: x, y: y, width: panelWidth, height: panelHeight), display: true)
    }

    private func setupDismissMonitors() {
        removeDismissMonitors()

        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] _ in
            self?.close()
        }

        localEventMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] event in
            guard let self = self, let panel = self.panel, panel.isVisible else { return event }

            let clickLocation = event.locationInWindow
            let clickScreenPoint: NSPoint
            if let eventWindow = event.window {
                clickScreenPoint = eventWindow.convertToScreen(NSRect(origin: clickLocation, size: .zero)).origin
            } else {
                clickScreenPoint = NSEvent.mouseLocation
            }

            if let button = self.currentStatusButton, let btnWin = button.window {
                let btnRect = btnWin.convertToScreen(button.convert(button.bounds, to: nil))
                if NSPointInRect(clickScreenPoint, btnRect) {
                    return event
                }
            }

            if !NSPointInRect(clickScreenPoint, panel.frame) {
                self.close()
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

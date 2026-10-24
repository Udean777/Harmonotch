import AppKit
import SwiftUI
import Combine

final class PassThroughHostingView<Content: View>: NSHostingView<Content> {
    override func hitTest(_ point: NSPoint) -> NSView? {
        let isExpanded = NotchViewModel.shared.isExpanded
        let geometry = NotchViewModel.shared.geometry
        let activeNotchHeight = geometry.hasHardwareNotch ? geometry.physicalNotchHeight : 0

        if !isExpanded {
            let collapsedHeight = (NotchViewModel.shared.selectedTab == .media && MediaManager.shared.hasActiveTrack && !MediaManager.shared.currentLyricText.isEmpty)
                ? NotchLayout.collapsedLyricHeight
                : NotchLayout.collapsedPillHeight
            let pillBottomFromTop: CGFloat = activeNotchHeight + collapsedHeight + 2
            if point.y < (bounds.height - pillBottomFromTop) {
                return nil
            }

            let pillWidth: CGFloat = geometry.physicalNotchWidth + 2
            let minX = (bounds.width - pillWidth) / 2
            let maxX = minX + pillWidth
            if point.x < minX || point.x > maxX {
                return nil
            }
        } else {
            let maxDrawerBottomFromTop = activeNotchHeight + NotchLayout.expandedHitAreaHeight
            if point.y < (bounds.height - maxDrawerBottomFromTop) {
                return nil
            }
        }
        return super.hitTest(point)
    }
}

final class NotchWindowController: ObservableObject {
    static let shared = NotchWindowController()

    @Published var isNotchHidden: Bool {
        didSet {
            UserDefaults.standard.set(isNotchHidden, forKey: "Harmonotch_IsNotchHidden")
        }
    }

    private var panel: NSPanel?
    private var cancellables = Set<AnyCancellable>()

    // Fixed canvas size; a resizing canvas triggers an Auto Layout constraint loop
    static let canvasWidth: CGFloat = 560
    static let canvasHeight: CGFloat = 520

    init() {
        self.isNotchHidden = UserDefaults.standard.bool(forKey: "Harmonotch_IsNotchHidden")
    }

    func setupAndShowWindow() {
        guard let screen = NSScreen.main else { return }
        NotchViewModel.shared.updateGeometry(for: screen)

        let frame = calculateFixedFrame(for: screen)

        let notchPanel = NSPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        notchPanel.level = .mainMenu + 3
        notchPanel.isOpaque = false
        notchPanel.backgroundColor = .clear
        notchPanel.hasShadow = false
        notchPanel.isMovable = false
        notchPanel.isReleasedWhenClosed = false
        notchPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]

        let hostingView = PassThroughHostingView(rootView: NotchContainerView())
        notchPanel.contentView = hostingView

        self.panel = notchPanel

        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self, let screen = self.panel?.screen ?? NSScreen.main else { return }
                NotchViewModel.shared.updateGeometry(for: screen)
                self.panel?.setFrame(self.calculateFixedFrame(for: screen), display: true)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSWindow.didChangeScreenNotification, object: notchPanel)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self, let panel = self.panel, let screen = panel.screen else { return }
                NotchViewModel.shared.updateGeometry(for: screen)
            }
            .store(in: &cancellables)

        if !isNotchHidden {
            notchPanel.orderFrontRegardless()
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
            panel?.orderOut(nil)
        } else {
            panel?.orderFrontRegardless()
        }
    }

}

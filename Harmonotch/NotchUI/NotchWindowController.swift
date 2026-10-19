//
//  NotchWindowController.swift
//  Harmonotch
//

import AppKit
import SwiftUI
import Combine

final class PassThroughHostingView<Content: View>: NSHostingView<Content> {
    override func hitTest(_ point: NSPoint) -> NSView? {
        let isExpanded = NotchViewModel.shared.isExpanded
        let geometry = NotchGeometry.current()
        let activeNotchHeight = geometry.hasHardwareNotch ? geometry.physicalNotchHeight : 0

        // Saat kondisi kuncup (collapsed): Ekstensi persis selebar notch fisik
        if !isExpanded {
            // Tinggi dari atas layar: notch fisik (37.5) + ekstensi (26) + buffer (2) = ~66 pt
            let pillBottomFromTop: CGFloat = activeNotchHeight + 28
            if point.y < (bounds.height - pillBottomFromTop) {
                return nil // Di bawah ekstensi notch -> tembus 100%
            }

            // Lebar tepat seukuran notch fisik (208 pt di MacBook Air)
            let pillWidth: CGFloat = geometry.physicalNotchWidth + 2
            let minX = (bounds.width - pillWidth) / 2
            let maxX = minX + pillWidth
            if point.x < minX || point.x > maxX {
                return nil // Menu kiri & status bar kanan tembus 100%
            }
        } else {
            // Saat expanded: jika klik di bawah batas drawer (misal sisa canvas), tembuskan ke desktop
            let maxDrawerBottomFromTop: CGFloat = activeNotchHeight + 350
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

    // Canvas tetap yang stabil untuk mencegah Auto Layout constraint loop
    static let canvasWidth: CGFloat = 560
    static let canvasHeight: CGFloat = 400

    init() {
        self.isNotchHidden = UserDefaults.standard.bool(forKey: "Harmonotch_IsNotchHidden")
    }

    func setupAndShowWindow() {
        guard let screen = NSScreen.main else { return }

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

        // Dengarkan perubahan monitor / resolusi layar
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self, let screen = NSScreen.main else { return }
                self.panel?.setFrame(self.calculateFixedFrame(for: screen), display: true)
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

    func toggleVisibility() {
        guard let panel = panel else {
            setupAndShowWindow()
            return
        }
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            panel.orderFrontRegardless()
        }
    }
}

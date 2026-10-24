import AppKit

enum NotchLayout {
    static let collapsedPillHeight: CGFloat = 26
    static let collapsedLyricHeight: CGFloat = 64
    static let expandedPrayerHeight: CGFloat = 272
    static let expandedAdzanHeight: CGFloat = 325
    static let expandedBatteryHeight: CGFloat = 395
    static let expandedMediaHeight: CGFloat = 288
    static let expandedMediaTrackHeight: CGFloat = 350
    static let expandedHitAreaHeight: CGFloat = 450
}

struct NotchGeometry: Equatable {
    let hasHardwareNotch: Bool
    let physicalNotchWidth: CGFloat
    let physicalNotchHeight: CGFloat
    let leftMargin: CGFloat
    let rightMargin: CGFloat
    let screenFrame: NSRect

    static func current(for screen: NSScreen? = NSScreen.main) -> NotchGeometry {
        guard let screen = screen else {
            return NotchGeometry(
                hasHardwareNotch: false,
                physicalNotchWidth: 210,
                physicalNotchHeight: 0,
                leftMargin: 0,
                rightMargin: 0,
                screenFrame: .zero
            )
        }

        if let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
            let width = right.minX - left.maxX
            let height = left.height

            return NotchGeometry(
                hasHardwareNotch: true,
                physicalNotchWidth: width > 0 ? width : 208,
                physicalNotchHeight: height > 0 ? height : 37.5,
                leftMargin: left.maxX,
                rightMargin: right.minX,
                screenFrame: screen.frame
            )
        } else {
            return NotchGeometry(
                hasHardwareNotch: false,
                physicalNotchWidth: 220,
                physicalNotchHeight: 0,
                leftMargin: 0,
                rightMargin: 0,
                screenFrame: screen.frame
            )
        }
    }
}

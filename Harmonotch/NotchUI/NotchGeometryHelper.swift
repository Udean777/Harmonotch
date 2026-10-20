import AppKit

struct NotchGeometry {
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
                physicalNotchHeight: 32,
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
            // Monitor eksternal atau Mac tanpa notch fisik
            return NotchGeometry(
                hasHardwareNotch: false,
                physicalNotchWidth: 220,
                physicalNotchHeight: 32,
                leftMargin: 0,
                rightMargin: 0,
                screenFrame: screen.frame
            )
        }
    }
}

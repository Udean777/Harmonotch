import AppKit
import SwiftUI

enum NotchLayout {
  static let collapsedPillHeight: CGFloat = 28
  static let collapsedWingWidth: CGFloat = 68
  static let noNotchPillWidth: CGFloat = 154
  static let hoverWingExpansion: CGFloat = 2
  static let companionExpansion: CGFloat = 28
  static let maxShoulder: CGFloat = 10
  static let wingInnerInset: CGFloat = 3
  static let expandedWidth: CGFloat = 560
  static let expandedHorizontalInset: CGFloat = 20
  static let expandedContentWidth: CGFloat = expandedWidth - (expandedHorizontalInset * 2)
  static let expandedBottomInset: CGFloat = 14
  static let expandedPrayerHeight: CGFloat = 195
  static let expandedAdzanHeight: CGFloat = 205
  static let expandedBatteryHeight: CGFloat = 200
  static let expandedMediaHeight: CGFloat = 180
  static let expandedMediaTrackHeight: CGFloat = 230
  static let expandedHitAreaHeight: CGFloat = 260

  static func shoulder(height: CGFloat) -> CGFloat {
    min(maxShoulder, max(0, height * 0.16))
  }

  static func surfaceRadius(height: CGFloat, isExpanded: Bool = false) -> CGFloat {
    if isExpanded {
      return 22
    }
    return min(24, max(8, height * 0.34))
  }

  static func wingOuterInset(height: CGFloat) -> CGFloat {
    max(12, shoulder(height: height) + 9)
  }
}

/// Dynamic Island / Notch silhouette hanging from the top screen edge (y = 0),
/// with concave top shoulders that flare into the bezel and convex bottom corners.
struct NotchShape: Shape {
  var radius: CGFloat
  var shoulder: CGFloat

  var animatableData: AnimatablePair<CGFloat, CGFloat> {
    get { AnimatablePair(radius, shoulder) }
    set {
      radius = newValue.first
      shoulder = newValue.second
    }
  }

  static func island(height: CGFloat, isExpanded: Bool) -> NotchShape {
    NotchShape(
      radius: NotchLayout.surfaceRadius(height: height, isExpanded: isExpanded),
      shoulder: NotchLayout.shoulder(height: height)
    )
  }

  func path(in rect: CGRect) -> Path {
    let clampedShoulder = min(max(0, shoulder), rect.height * 0.25, rect.width / 4)
    let bottom = min(
      max(0, radius), rect.height / 2, max(0, (rect.width - clampedShoulder * 2) / 2))
    let tangent: CGFloat = 0.55228475

    var path = Path()
    path.move(to: CGPoint(x: 0, y: 0))
    path.addLine(to: CGPoint(x: rect.width, y: 0))
    path.addCurve(
      to: CGPoint(x: rect.width - clampedShoulder, y: clampedShoulder),
      control1: CGPoint(x: rect.width - clampedShoulder * tangent, y: 0),
      control2: CGPoint(x: rect.width - clampedShoulder, y: clampedShoulder * (1 - tangent))
    )
    path.addLine(to: CGPoint(x: rect.width - clampedShoulder, y: rect.height - bottom))
    path.addCurve(
      to: CGPoint(x: rect.width - clampedShoulder - bottom, y: rect.height),
      control1: CGPoint(x: rect.width - clampedShoulder, y: rect.height - bottom * (1 - tangent)),
      control2: CGPoint(x: rect.width - clampedShoulder - bottom * (1 - tangent), y: rect.height)
    )
    path.addLine(to: CGPoint(x: clampedShoulder + bottom, y: rect.height))
    path.addCurve(
      to: CGPoint(x: clampedShoulder, y: rect.height - bottom),
      control1: CGPoint(x: clampedShoulder + bottom * (1 - tangent), y: rect.height),
      control2: CGPoint(x: clampedShoulder, y: rect.height - bottom * (1 - tangent))
    )
    path.addLine(to: CGPoint(x: clampedShoulder, y: clampedShoulder))
    path.addCurve(
      to: .zero,
      control1: CGPoint(x: clampedShoulder, y: clampedShoulder * (1 - tangent)),
      control2: CGPoint(x: clampedShoulder * tangent, y: 0)
    )
    path.closeSubpath()
    return path
  }
}

/// Border path that leaves the top screen edge (y = 0) open so no stroke line
/// is drawn across the screen bezel or hardware camera housing.
struct NotchOpenBorderShape: Shape {
  var radius: CGFloat
  var shoulder: CGFloat

  var animatableData: AnimatablePair<CGFloat, CGFloat> {
    get { AnimatablePair(radius, shoulder) }
    set {
      radius = newValue.first
      shoulder = newValue.second
    }
  }

  func path(in rect: CGRect) -> Path {
    let clampedShoulder = min(max(0, shoulder), rect.height * 0.25, rect.width / 4)
    let bottom = min(
      max(0, radius), rect.height / 2, max(0, (rect.width - clampedShoulder * 2) / 2))
    let tangent: CGFloat = 0.55228475

    var path = Path()
    path.move(to: CGPoint(x: 0, y: 0))
    path.addCurve(
      to: CGPoint(x: clampedShoulder, y: clampedShoulder),
      control1: CGPoint(x: clampedShoulder * tangent, y: 0),
      control2: CGPoint(x: clampedShoulder, y: clampedShoulder * (1 - tangent))
    )
    path.addLine(to: CGPoint(x: clampedShoulder, y: rect.height - bottom))
    path.addCurve(
      to: CGPoint(x: clampedShoulder + bottom, y: rect.height),
      control1: CGPoint(x: clampedShoulder, y: rect.height - bottom * (1 - tangent)),
      control2: CGPoint(x: clampedShoulder + bottom * (1 - tangent), y: rect.height)
    )
    path.addLine(to: CGPoint(x: rect.width - clampedShoulder - bottom, y: rect.height))
    path.addCurve(
      to: CGPoint(x: rect.width - clampedShoulder, y: rect.height - bottom),
      control1: CGPoint(x: rect.width - clampedShoulder - bottom * (1 - tangent), y: rect.height),
      control2: CGPoint(x: rect.width - clampedShoulder, y: rect.height - bottom * (1 - tangent))
    )
    path.addLine(to: CGPoint(x: rect.width - clampedShoulder, y: clampedShoulder))
    path.addCurve(
      to: CGPoint(x: rect.width, y: 0),
      control1: CGPoint(x: rect.width - clampedShoulder, y: clampedShoulder * (1 - tangent)),
      control2: CGPoint(x: rect.width - clampedShoulder * tangent, y: 0)
    )
    return path
  }
}

struct NotchGeometry: Equatable {
  let hasHardwareNotch: Bool
  let physicalNotchWidth: CGFloat
  let physicalNotchHeight: CGFloat
  let leftMargin: CGFloat
  let rightMargin: CGFloat
  let screenFrame: NSRect

  var collapsedHeight: CGFloat {
    hasHardwareNotch
      ? physicalNotchHeight : max(NotchLayout.collapsedPillHeight, physicalNotchHeight)
  }

  func collapsedWidth(isHovered: Bool) -> CGFloat {
    let hoverExtra = isHovered ? NotchLayout.hoverWingExpansion : 0
    if hasHardwareNotch {
      return physicalNotchWidth + 2 * (NotchLayout.collapsedWingWidth + hoverExtra)
    } else {
      return NotchLayout.noNotchPillWidth + 2 * hoverExtra
    }
  }

  static func current(for screen: NSScreen? = NSScreen.main) -> NotchGeometry {
    guard let screen = screen else {
      return NotchGeometry(
        hasHardwareNotch: false,
        physicalNotchWidth: NotchLayout.noNotchPillWidth,
        physicalNotchHeight: NotchLayout.collapsedPillHeight,
        leftMargin: 0,
        rightMargin: 0,
        screenFrame: .zero
      )
    }

    if let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
      let width = right.minX - left.maxX
      let height = max(left.height, screen.safeAreaInsets.top)

      return NotchGeometry(
        hasHardwareNotch: true,
        physicalNotchWidth: width > 0 ? width : 208,
        physicalNotchHeight: height > 0 ? height : 37.5,
        leftMargin: left.maxX,
        rightMargin: right.minX,
        screenFrame: screen.frame
      )
    } else {
      let menuBarHeight = max(0, screen.frame.maxY - screen.visibleFrame.maxY)
      let virtualHeight =
        menuBarHeight >= 22 ? min(menuBarHeight, 34) : NotchLayout.collapsedPillHeight

      return NotchGeometry(
        hasHardwareNotch: false,
        physicalNotchWidth: NotchLayout.noNotchPillWidth,
        physicalNotchHeight: virtualHeight,
        leftMargin: 0,
        rightMargin: 0,
        screenFrame: screen.frame
      )
    }
  }
}

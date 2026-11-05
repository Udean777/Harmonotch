
struct NotchWingWidths: Equatable {
  var left: CGFloat = 0
  var right: CGFloat = 0
}
import AppKit
import SwiftUI

enum NotchLayout {
  static let collapsedPillHeight: CGFloat = 28
  static let collapsedWingWidth: CGFloat = 68
  static let mediaWingWidth: CGFloat = 42
  static let noNotchPillWidth: CGFloat = 154
  static let hoverWingExpansion: CGFloat = 2
  static let companionExpansion: CGFloat = 28
  static let mediaLeftExpansion: CGFloat = 28
  static let maxShoulder: CGFloat = 10
  static let wingInnerInset: CGFloat = 3
  /// Left hover zone on non-notched displays, as a fraction of pill width.
  static let leftHoverFraction: CGFloat = 0.45
  /// Gap between the virtual (non-notched) pill and the top screen edge.
  static let floatingTopInset: CGFloat = 2
  /// Slimmer pill height used on displays without a hardware notch.
  static let floatingPillHeight: CGFloat = 24
  static let floatingWingSpacing: CGFloat = 12

  static let floatingCornerRadius: CGFloat = 8

  static func floatingRadius(height: CGFloat, isExpanded: Bool) -> CGFloat {
    isExpanded ? 22 : floatingCornerRadius
  }
  static let expandedWidth: CGFloat = 460
  static let expandedHorizontalInset: CGFloat = 24
  static let expandedContentWidth: CGFloat = expandedWidth - (expandedHorizontalInset * 2)
  static let expandedBottomInset: CGFloat = 16
  static let expandedPrayerHeight: CGFloat = 185
  static let expandedAdzanHeight: CGFloat = 195
  static let expandedBatteryHeight: CGFloat = 185
  static let expandedAIHeight: CGFloat = 240
  static let minAIHeight: CGFloat = 180
  static let maxAIHeight: CGFloat = 350
  static let expandedMediaHeight: CGFloat = 190
  static let expandedMediaTrackHeight: CGFloat = 360
  static let expandedHitAreaHeight: CGFloat = 280

  static func dynamicAIHeight(
    modelCount: Int,
    hasMultipleProviders: Bool = true,
    isAntigravitySetup: Bool = false
  ) -> CGFloat {
    let headerHeight: CGFloat = 34
    let selectorHeight: CGFloat = hasMultipleProviders ? 32 : 0

    if isAntigravitySetup {
      return min(headerHeight + selectorHeight + 205, maxAIHeight)
    }

    if modelCount == 0 {
      return headerHeight + selectorHeight + 115
    }

    let clampedRows = min(max(modelCount, 1), 5)
    let rowHeight: CGFloat = 36
    let modelsHeight = CGFloat(clampedRows) * rowHeight
    let cardPadding: CGFloat = 20
    let cardHeaderHeight: CGFloat = 26
    let total = headerHeight + selectorHeight + cardPadding + cardHeaderHeight + modelsHeight + 10
    return min(max(total, minAIHeight), maxAIHeight)
  }

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
/// In floating mode (no hardware notch) it renders as a detached rounded pill.
struct NotchShape: Shape {
  var radius: CGFloat
  var shoulder: CGFloat
  var isFloating: Bool = false

  var animatableData: AnimatablePair<CGFloat, CGFloat> {
    get { AnimatablePair(radius, shoulder) }
    set {
      radius = newValue.first
      shoulder = newValue.second
    }
  }

  static func island(height: CGFloat, isExpanded: Bool, isFloating: Bool = false) -> NotchShape {
    if isFloating {
      return NotchShape(
        radius: NotchLayout.floatingRadius(height: height, isExpanded: isExpanded),
        shoulder: 0,
        isFloating: true
      )
    }
    return NotchShape(
      radius: NotchLayout.surfaceRadius(height: height, isExpanded: isExpanded),
      shoulder: NotchLayout.shoulder(height: height)
    )
  }

  func path(in rect: CGRect) -> Path {
    if isFloating {
      // Detached pill: squarish rounded ends matching Apple squircle styling.
      return RoundedRectangle(
        cornerRadius: min(radius, rect.height / 2, rect.width / 2),
        style: .continuous
      ).path(in: rect)
    }

    let clampedShoulder = min(max(0, shoulder), rect.height * 0.25, rect.width / 4)
    let bottom = min(
      max(0, radius), rect.height / 2, max(0, (rect.width - clampedShoulder * 2) / 2))
    let tangent: CGFloat = 0.55228475
    let oneMinusTangent: CGFloat = 1 - tangent

    var path = Path()
    path.move(to: CGPoint(x: 0, y: 0))
    path.addLine(to: CGPoint(x: rect.width, y: 0))
    path.addCurve(
      to: CGPoint(x: rect.width - clampedShoulder, y: clampedShoulder),
      control1: CGPoint(x: rect.width - clampedShoulder * tangent, y: 0),
      control2: CGPoint(x: rect.width - clampedShoulder, y: clampedShoulder * oneMinusTangent)
    )
    path.addLine(to: CGPoint(x: rect.width - clampedShoulder, y: rect.height - bottom))
    path.addCurve(
      to: CGPoint(x: rect.width - clampedShoulder - bottom, y: rect.height),
      control1: CGPoint(x: rect.width - clampedShoulder, y: rect.height - bottom * oneMinusTangent),
      control2: CGPoint(x: rect.width - clampedShoulder - bottom * oneMinusTangent, y: rect.height)
    )
    path.addLine(to: CGPoint(x: clampedShoulder + bottom, y: rect.height))
    path.addCurve(
      to: CGPoint(x: clampedShoulder, y: rect.height - bottom),
      control1: CGPoint(x: clampedShoulder + bottom * oneMinusTangent, y: rect.height),
      control2: CGPoint(x: clampedShoulder, y: rect.height - bottom * oneMinusTangent)
    )
    path.addLine(to: CGPoint(x: clampedShoulder, y: clampedShoulder))
    path.addCurve(
      to: .zero,
      control1: CGPoint(x: clampedShoulder, y: clampedShoulder * oneMinusTangent),
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
  var isFloating: Bool = false

  var animatableData: AnimatablePair<CGFloat, CGFloat> {
    get { AnimatablePair(radius, shoulder) }
    set {
      radius = newValue.first
      shoulder = newValue.second
    }
  }

  func path(in rect: CGRect) -> Path {
    if isFloating {
      return RoundedRectangle(
        cornerRadius: min(radius, rect.height / 2, rect.width / 2),
        style: .continuous
      ).path(in: rect)
    }

    let clampedShoulder = min(max(0, shoulder), rect.height * 0.25, rect.width / 4)
    let bottom = min(
      max(0, radius), rect.height / 2, max(0, (rect.width - clampedShoulder * 2) / 2))
    let tangent: CGFloat = 0.55228475
    let oneMinusTangent: CGFloat = 1 - tangent

    var path = Path()
    path.move(to: CGPoint(x: 0, y: 0))
    path.addCurve(
      to: CGPoint(x: clampedShoulder, y: clampedShoulder),
      control1: CGPoint(x: clampedShoulder * tangent, y: 0),
      control2: CGPoint(x: clampedShoulder, y: clampedShoulder * oneMinusTangent)
    )
    path.addLine(to: CGPoint(x: clampedShoulder, y: rect.height - bottom))
    path.addCurve(
      to: CGPoint(x: clampedShoulder + bottom, y: rect.height),
      control1: CGPoint(x: clampedShoulder, y: rect.height - bottom * oneMinusTangent),
      control2: CGPoint(x: clampedShoulder + bottom * oneMinusTangent, y: rect.height)
    )
    path.addLine(to: CGPoint(x: rect.width - clampedShoulder - bottom, y: rect.height))
    path.addCurve(
      to: CGPoint(x: rect.width - clampedShoulder, y: rect.height - bottom),
      control1: CGPoint(x: rect.width - clampedShoulder - bottom * oneMinusTangent, y: rect.height),
      control2: CGPoint(x: rect.width - clampedShoulder, y: rect.height - bottom * oneMinusTangent)
    )
    path.addLine(to: CGPoint(x: rect.width - clampedShoulder, y: clampedShoulder))
    path.addCurve(
      to: CGPoint(x: rect.width, y: 0),
      control1: CGPoint(x: rect.width - clampedShoulder, y: clampedShoulder * oneMinusTangent),
      control2: CGPoint(x: rect.width - clampedShoulder * tangent, y: 0)
    )
    return path
  }
}

extension NotchShape {
  var openBorder: NotchOpenBorderShape {
    NotchOpenBorderShape(
      radius: radius,
      shoulder: shoulder,
      isFloating: isFloating
    )
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
      ? physicalNotchHeight : NotchLayout.floatingPillHeight
  }

  func collapsedWingWidths(
    isHovered: Bool,
    isMediaPlaying: Bool = false,
    leftExtra: CGFloat = 0,
    measured: NotchWingWidths = NotchWingWidths()
  ) -> (left: CGFloat, right: CGFloat) {
    let hoverExtra = isHovered ? NotchLayout.hoverWingExpansion : 0
    let baseWing = isMediaPlaying ? NotchLayout.mediaWingWidth : NotchLayout.collapsedWingWidth
    let left = max(baseWing + leftExtra, measured.left) + hoverExtra
    let right = max(baseWing, measured.right) + hoverExtra
    return (left, right)
  }

  func collapsedWidth(
    isHovered: Bool,
    isMediaPlaying: Bool = false,
    leftExtra: CGFloat = 0,
    measured: NotchWingWidths = NotchWingWidths()
  ) -> CGFloat {
    let wings = collapsedWingWidths(
      isHovered: isHovered,
      isMediaPlaying: isMediaPlaying,
      leftExtra: leftExtra,
      measured: measured
    )
    let hoverExtra = isHovered ? NotchLayout.hoverWingExpansion : 0
    if hasHardwareNotch {
      return physicalNotchWidth + wings.left + wings.right
    } else {
      let contentWidth = wings.left + wings.right + NotchLayout.floatingWingSpacing
      let baseWidth: CGFloat =
        isMediaPlaying
        ? NotchLayout.noNotchPillWidth - 2
          * (NotchLayout.collapsedWingWidth - NotchLayout.mediaWingWidth)
        : NotchLayout.noNotchPillWidth
      return max(baseWidth + 2 * hoverExtra, contentWidth)
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

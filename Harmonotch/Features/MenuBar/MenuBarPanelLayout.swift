import CoreGraphics

enum MenuBarPanelLayout {
  static let edgeInset: CGFloat = 10
  static let gap: CGFloat = 6

  /// Returns a frame for a panel top-anchored just below the status-bar button.
  /// The panel height follows the dashboard's measured content height.
  static func frame(
    buttonRect: CGRect,
    visibleFrame: CGRect,
    height: CGFloat,
    width: CGFloat
  ) -> CGRect {
    let minX = visibleFrame.minX + edgeInset
    let maxX = max(minX, visibleFrame.maxX - width - edgeInset)
    let x = min(max(buttonRect.midX - (width / 2), minX), maxX)

    // Keep the top edge pinned below the button so additional content grows downward.
    let topEdge = buttonRect.minY - gap
    let y = topEdge - height

    return CGRect(x: x, y: y, width: width, height: height)
  }
}

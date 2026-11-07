import AppKit
import Foundation

func runGeometryTests() {
  // MARK: - Notch geometry

  let notched = NotchGeometry(
    hasHardwareNotch: true, physicalNotchWidth: 200, physicalNotchHeight: 32,
    leftMargin: 0, rightMargin: 0, screenFrame: .zero)
  checkEqual(notched.collapsedWidth(isHovered: false), 336, "default notched width")
  checkEqual(
    notched.collapsedWidth(
      isHovered: false, measured: NotchWingWidths(left: 90, right: 70)),
    360, "notch expands to fit wider content")

  let floating = NotchGeometry(
    hasHardwareNotch: false, physicalNotchWidth: 154, physicalNotchHeight: 24,
    leftMargin: 0, rightMargin: 0, screenFrame: .zero)
  checkEqual(floating.collapsedWidth(isHovered: false), 154, "floating pill keeps base width")
  check(
    floating.collapsedWidth(
      isHovered: false, measured: NotchWingWidths(left: 300, right: 300)) > 154,
    "floating pill grows past base width when content needs it")
}

import SwiftUI

/// Pure Black Surface for Harmonotch Dynamic Island.
/// Full OLED pure black (#000000) with no liquid glass, no gradients, and no translucency.
/// Features a subtle hairline border matching Apple's hardware notch bezel.
struct PureBlackSurface: View {
  @ObservedObject private var themeManager = ThemeManager.shared
  let shape: NotchShape
  let isExpanded: Bool

  var body: some View {
    shape
      .fill(AppTheme.surfaceBackground)
      .preferredColorScheme(themeManager.colorScheme)
  }
}

struct HarmonotchSurface: View {
  let shape: NotchShape
  let isExpanded: Bool

  var body: some View {
    PureBlackSurface(shape: shape, isExpanded: isExpanded)
  }
}

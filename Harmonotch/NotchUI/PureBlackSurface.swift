import SwiftUI

/// Pure Black Surface for Harmonotch Dynamic Island.
/// Full OLED pure black (#000000) with no liquid glass, no gradients, and no translucency.
/// Features a subtle hairline border matching Apple's hardware notch bezel.
struct PureBlackSurface: View {
  @ObservedObject private var themeManager = ThemeManager.shared
  let shape: NotchShape
  let isExpanded: Bool

  private var openBorder: NotchOpenBorderShape {
    NotchOpenBorderShape(
      radius: shape.radius,
      shoulder: shape.shoulder,
      isFloating: shape.isFloating
    )
  }

  var body: some View {
    ZStack {
      // Pure solid fill keeps the notch surface opaque in every palette.
      // Catppuccin uses color here, while monochrome remains black or white.
      shape
        .fill(AppTheme.surfaceBackground)

      // The border keeps the notch silhouette distinct from the menu bar.
      openBorder
        .stroke(AppTheme.surfaceBorder, lineWidth: 0.8)
    }
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

import SwiftUI

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

import SwiftUI

/// Accessible focus styling for clickable dashboard items and icon-only buttons
struct DashboardFocusRing: ViewModifier {
  @FocusState.Binding var isFocused: Bool
  var cornerRadius: CGFloat = 8

  func body(content: Content) -> some View {
    content
      .focusable()
      .focused($isFocused)
      .overlay(
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
          .stroke(isFocused ? AppTheme.accentCyan : Color.clear, lineWidth: 2)
          .padding(isFocused ? -2 : 0)
      )
  }
}

extension View {
  func dashboardFocusable(isFocused: FocusState<Bool>.Binding, cornerRadius: CGFloat = 8) -> some View {
    self.modifier(DashboardFocusRing(isFocused: isFocused, cornerRadius: cornerRadius))
  }
}

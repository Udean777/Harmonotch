import SwiftUI

struct NotchChip<Content: View>: View {
    var cornerRadius: CGFloat = 6
    var horizontalPadding: CGFloat = 7
    var verticalPadding: CGFloat = 4
    var tint: Color?
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(tint ?? AppTheme.badgeBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(AppTheme.cardBorder, lineWidth: 0.5)
            )
    }
}

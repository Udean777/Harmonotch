import SwiftUI

extension MediaDrawerView {
  /// Queue view: song list when present, empty UI when queue not found.
  @ViewBuilder
  var queueContent: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 6) {
        Image(systemName: "list.number")
          .font(.system(size: 10, weight: .semibold))
          .foregroundColor(AppTheme.textSecondary)
        Text(L10n.Media.queueTitle)
          .font(.system(size: 11, weight: .bold, design: .rounded))
          .foregroundColor(AppTheme.textPrimary)
        Spacer(minLength: 4)
      }

      if mediaManager.queue.isEmpty {
        VStack(alignment: .leading, spacing: 6) {
          Image(systemName: "text.bubble")
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(AppTheme.textTertiary)
          Text(L10n.Media.queueEmpty)
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(AppTheme.textSecondary)
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
      } else {
        ForEach(Array(mediaManager.queue.enumerated()), id: \.element.id) { index, item in
          HStack(spacing: 8) {
            Text("\(index + 1)")
              .font(.system(size: 9.5, weight: .medium, design: .rounded))
              .foregroundColor(AppTheme.textTertiary)
              .frame(width: 16, alignment: .leading)

            VStack(alignment: .leading, spacing: 1) {
              Text(item.title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(AppTheme.textPrimary)
                .lineLimit(1)
              Text(item.artist.isEmpty ? L10n.Media.nowPlaying : item.artist)
                .font(.system(size: 8.5, weight: .medium))
                .foregroundColor(AppTheme.textSecondary)
                .lineLimit(1)
            }

            Spacer(minLength: 4)
          }
          .padding(.vertical, 3)
        }
      }
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 8)
    .background(
      RoundedRectangle(cornerRadius: 10, style: .continuous)
        .fill(AppTheme.cardBackground)
        .overlay(
          RoundedRectangle(cornerRadius: 10, style: .continuous)
            .stroke(AppTheme.cardBorder, lineWidth: 0.6)
        )
    )
  }
}

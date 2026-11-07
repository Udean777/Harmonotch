import SwiftUI

extension MediaDrawerView {
  @ViewBuilder
  var lyricsContent: some View {
    VStack(alignment: .leading, spacing: 8) {
      switch mediaManager.lyricsStatus {
      case .synced(let lines):
        if lines.isEmpty {
          unavailableLyricsUI
        } else {
          ExpandedLyricsView(mediaAccentColor: mediaAccentColor)
        }

      case .unsynced(let lines):
        if lines.isEmpty {
          unavailableLyricsUI
        } else {
          ExpandedLyricsView(mediaAccentColor: mediaAccentColor)
        }

      case .loading:
        HStack(spacing: 8) {
          ProgressView()
            .controlSize(.small)
          Text(L10n.Media.loadingLyrics)
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(AppTheme.textSecondary)
          Spacer(minLength: 4)
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)

      case .instrumental:
        HStack(spacing: 10) {
          ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
              .fill(AppTheme.accentCyan.opacity(0.12))
              .frame(width: 28, height: 28)
            Image(systemName: "music.quarternote.3")
              .font(.system(size: 12, weight: .semibold))
              .foregroundColor(AppTheme.accentCyan)
          }
          VStack(alignment: .leading, spacing: 1.5) {
            Text(L10n.Media.instrumental)
              .font(.system(size: 11, weight: .bold, design: .rounded))
              .foregroundColor(AppTheme.textPrimary)
            Text(L10n.Media.instrumentalDesc)
              .font(.system(size: 9.5, weight: .medium))
              .foregroundColor(AppTheme.textSecondary)
              .lineLimit(2)
          }
          Spacer(minLength: 4)
        }
        .padding(.vertical, 6)

      case .unavailable, .idle:
        unavailableLyricsUI
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

  @ViewBuilder
  var unavailableLyricsUI: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 8) {
        Image(systemName: "exclamationmark.triangle.fill")
          .font(.system(size: 10, weight: .bold))
          .foregroundColor(AppTheme.accentAmber)
        Text(L10n.Media.lyricsNotFound)
          .font(.system(size: 10, weight: .medium))
          .foregroundColor(AppTheme.textSecondary)
      }

      Button(action: {
        mediaManager.refetchLyrics()
      }) {
        HStack(spacing: 5) {
          Image(systemName: "arrow.triangle.2.circlepath")
            .font(.system(size: 9, weight: .semibold))
          Text(L10n.Media.syncLyrics)
            .font(.system(size: 9.5, weight: .semibold))
        }
        .foregroundColor(mediaAccentColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
          RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(mediaAccentColor.opacity(0.15))
        )
        .overlay(
          RoundedRectangle(cornerRadius: 6, style: .continuous)
            .stroke(mediaAccentColor.opacity(0.5), lineWidth: 0.5)
        )
      }
      .buttonStyle(.plain)

      Text(L10n.Media.lyricsUnavailableDesc)
        .font(.system(size: 9, weight: .medium))
        .foregroundColor(AppTheme.textTertiary)
        .lineLimit(2)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(.vertical, 8)
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

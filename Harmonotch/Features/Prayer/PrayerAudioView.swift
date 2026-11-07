import SwiftUI

extension MediaDrawerView {
  // MARK: - Prayer Audio Mode View

  var prayerAudioView: some View {
    VStack(spacing: 12) {
      HStack(alignment: .center, spacing: 14) {
        ZStack {
          RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(AppTheme.cardBackground)
            .frame(width: 56, height: 56)

          Image(systemName: "speaker.wave.3.fill")
            .font(.system(size: 22, weight: .bold))
            .foregroundColor(AppTheme.accentAmber)
        }
        .overlay(
          RoundedRectangle(cornerRadius: 12, style: .continuous)
            .stroke(AppTheme.cardBorder, lineWidth: 0.8)
        )

        VStack(alignment: .leading, spacing: 3) {
          HStack(spacing: 6) {
            Circle()
              .fill(AppTheme.accentAmber)
              .frame(width: 6, height: 6)

            Text(L10n.Prayer.audioAdzanTitle)
              .font(.system(size: 11, weight: .bold))
              .foregroundColor(AppTheme.accentAmber)
          }

          Text(L10n.Prayer.localizedPrayerName(adzanPlayer.playingPrayerName))
            .font(.system(size: 16, weight: .bold, design: .rounded))
            .foregroundColor(AppTheme.textPrimary)
            .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        HStack(spacing: 8) {
          Button(action: {
            adzanPlayer.isMuted.toggle()
          }) {
            Image(systemName: adzanPlayer.isMuted ? "bell.slash.fill" : "bell.fill")
              .font(.system(size: 13, weight: .semibold))
              .foregroundColor(adzanPlayer.isMuted ? AppTheme.textTertiary : AppTheme.accentAmber)
              .frame(width: 34, height: 34)
              .background(AppTheme.badgeBackground)
              .clipShape(Circle())
              .overlay(Circle().stroke(AppTheme.cardBorder, lineWidth: 0.6))
          }
          .buttonStyle(.plain)

          Button(action: {
            adzanPlayer.stop()
          }) {
            HStack(spacing: 5) {
              Image(systemName: "stop.fill")
                .font(.system(size: 11, weight: .bold))
              Text(L10n.Prayer.stop)
                .font(.system(size: 12, weight: .bold))
            }
            .foregroundColor(AppTheme.accentRed)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(AppTheme.accentRed.opacity(0.14))
            .cornerRadius(8)
            .overlay(
              RoundedRectangle(cornerRadius: 8).stroke(AppTheme.accentRed.opacity(0.3), lineWidth: 0.8))
          }
          .buttonStyle(.plain)
        }
      }

      HStack(spacing: 8) {
        ForEach(prayerManager.prayerItems) { item in
          PrayerCardView(item: item)
        }
      }
    }
  }
}

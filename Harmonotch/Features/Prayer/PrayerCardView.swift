import SwiftUI

struct PrayerCardView: View {
  let item: PrayerScheduleItem

  private var isHighlighted: Bool {
    item.isNext || item.isCurrent
  }

  var body: some View {
    VStack(spacing: 5) {
      ZStack {
        Circle()
          .fill(backgroundCircleColor)
          .frame(width: 26, height: 26)

        Image(systemName: item.iconName)
          .font(.system(size: 11.5, weight: isHighlighted ? .semibold : .regular))
          .foregroundColor(iconColor)
      }

      VStack(spacing: 1.5) {
        if item.isCurrent {
          Text(L10n.Prayer.currentBadge)
            .font(.system(size: 7.5, weight: .bold))
            .foregroundColor(AppTheme.accentGreen)
            .tracking(0.3)
        } else if item.isNext {
          Text(L10n.Prayer.nextBadge)
            .font(.system(size: 7.5, weight: .bold))
            .foregroundColor(AppTheme.accentAmber)
            .tracking(0.3)
        }

        Text(item.name)
          .font(.system(size: 11, weight: isHighlighted ? .bold : .medium))
          .foregroundColor(isHighlighted ? AppTheme.textPrimary : AppTheme.textSecondary)
          .lineLimit(1)
      }

      Text(item.timeString)
        .font(.system(size: 12.5, weight: isHighlighted ? .bold : .semibold, design: .rounded))
        .monospacedDigit()
        .foregroundColor(isHighlighted ? AppTheme.accentAmber : AppTheme.textTertiary)
        .lineLimit(1)
    }
    .padding(.horizontal, 6)
    .padding(.vertical, 8)
    .frame(maxWidth: .infinity)
    .background(
      RoundedRectangle(cornerRadius: 10, style: .continuous)
        .fill(cardBackgroundColor)
        .shadow(color: Color.black.opacity(isHighlighted ? (AppTheme.isDark ? 0.30 : 0.08) : 0), radius: 2, x: 0, y: 1)
        .overlay(
          RoundedRectangle(cornerRadius: 10, style: .continuous)
            .stroke(cardBorderColor, lineWidth: isHighlighted ? 0.8 : 0.5)
        )
    )
  }

  private var cardBackgroundColor: Color {
    if isHighlighted {
      return AppTheme.tabActiveBackground
    } else {
      return AppTheme.cardBackground
    }
  }

  private var cardBorderColor: Color {
    if item.isCurrent {
      return AppTheme.accentGreen.opacity(0.50)
    } else if item.isNext {
      return AppTheme.accentAmber.opacity(0.50)
    } else {
      return AppTheme.cardBorder
    }
  }

  private var backgroundCircleColor: Color {
    if item.isCurrent {
      return AppTheme.accentGreen.opacity(0.14)
    } else if item.isNext {
      return AppTheme.accentAmber.opacity(0.14)
    } else {
      return AppTheme.badgeBackground
    }
  }

  private var iconColor: Color {
    if item.isCurrent {
      return AppTheme.accentGreen
    } else if item.isNext {
      return AppTheme.accentAmber
    } else {
      return AppTheme.textSecondary
    }
  }
}

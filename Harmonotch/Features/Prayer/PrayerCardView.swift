import SwiftUI

struct PrayerCardView: View {
    let item: PrayerScheduleItem
    @ObservedObject var languageManager = LanguageManager.shared
    @ObservedObject var themeManager = ThemeManager.shared

    var body: some View {
        VStack(spacing: 5) {
            ZStack {
                Circle()
                    .fill(backgroundCircleColor)
                    .frame(width: 26, height: 26)

                Image(systemName: item.iconName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(iconColor)
            }

            Text(item.name)
                .font(.system(size: 11, weight: item.isNext || item.isCurrent ? .bold : .medium))
                .foregroundColor(AppTheme.textPrimary)
                .lineLimit(1)

            Text(item.timeString)
                .font(.system(size: 12.5, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(item.isNext || item.isCurrent ? Color.white : AppTheme.textSecondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(cardBackgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(cardBorderColor, lineWidth: item.isNext || item.isCurrent ? 1 : 0.5)
                )
        )
    }

    private var cardBackgroundColor: Color {
        if item.isNext || item.isCurrent {
            return Color.white.opacity(0.10)
        } else {
            return AppTheme.cardBackground
        }
    }

    private var cardBorderColor: Color {
        if item.isNext || item.isCurrent {
            return Color.white.opacity(0.40)
        } else {
            return AppTheme.cardBorder
        }
    }

    private var backgroundCircleColor: Color {
        if item.isNext || item.isCurrent {
            return Color.white.opacity(0.16)
        } else {
            return AppTheme.badgeBackground
        }
    }

    private var iconColor: Color {
        if item.isNext || item.isCurrent {
            return Color.white
        } else {
            return AppTheme.textSecondary
        }
    }
}

extension Color {
    static var amberCustom: Color {
        AppTheme.accentAmber
    }
}

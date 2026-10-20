import SwiftUI

struct PrayerCardView: View {
    let item: PrayerScheduleItem
    @ObservedObject var languageManager = LanguageManager.shared
    @ObservedObject var themeManager = ThemeManager.shared

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(backgroundCircleColor)
                    .frame(width: 28, height: 28)

                Image(systemName: item.iconName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(iconColor)
            }

            VStack(spacing: 1) {
                Text(item.name)
                    .font(.system(size: 11, weight: item.isNext || item.isCurrent ? .bold : .medium))
                    .foregroundColor(AppTheme.textPrimary)

                Text(item.arabicName)
                    .font(.system(size: 9))
                    .foregroundColor(AppTheme.textTertiary)
            }

            Text(item.timeString)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(item.isNext ? AppTheme.accentGreen : (item.isCurrent ? AppTheme.accentAmber : AppTheme.textPrimary))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(item.isNext ? AppTheme.accentGreen.opacity(0.16) : (item.isCurrent ? AppTheme.accentAmber.opacity(0.16) : AppTheme.cardBackground))
                )

            if item.isNext {
                Text(L10n.Prayer.nextBadge)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(AppTheme.accentGreen)
                    .textCase(.uppercase)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(AppTheme.accentGreen.opacity(0.18)))
            } else if item.isCurrent {
                Text(L10n.Prayer.currentBadge)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(AppTheme.accentAmber)
                    .textCase(.uppercase)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(AppTheme.accentAmber.opacity(0.18)))
            } else {
                Text(" ")
                    .font(.system(size: 8))
                    .padding(.vertical, 1)
            }
        }
        .frame(width: 76)
        .padding(.vertical, 8)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(.ultraThinMaterial)

                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(cardBackgroundColor)

                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(cardBorderStroke, lineWidth: item.isNext || item.isCurrent ? 1.0 : 0.7)
            }
        )
        .shadow(
            color: item.isNext
                ? AppTheme.accentGreen.opacity(AppTheme.isDark ? 0.30 : 0.18)
                : (item.isCurrent ? AppTheme.accentAmber.opacity(AppTheme.isDark ? 0.28 : 0.16) : (AppTheme.isDark ? Color.clear : Color.black.opacity(0.04))),
            radius: item.isNext || item.isCurrent ? 4 : 2,
            x: 0,
            y: 1.5
        )
    }

    private var cardBackgroundColor: LinearGradient {
        if item.isNext {
            return LinearGradient(
                colors: [AppTheme.accentGreen.opacity(0.20), AppTheme.accentGreen.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else if item.isCurrent {
            return LinearGradient(
                colors: [AppTheme.accentAmber.opacity(0.18), AppTheme.accentAmber.opacity(0.06)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: AppTheme.isDark
                    ? [Color.white.opacity(0.08), Color.white.opacity(0.03)]
                    : [Color.white.opacity(0.60), Color.white.opacity(0.25)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var cardBorderStroke: LinearGradient {
        if item.isNext {
            return LinearGradient(
                colors: [AppTheme.accentGreen.opacity(0.85), AppTheme.accentGreen.opacity(0.25)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else if item.isCurrent {
            return LinearGradient(
                colors: [AppTheme.accentAmber.opacity(0.85), AppTheme.accentAmber.opacity(0.25)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: AppTheme.isDark
                    ? [Color.white.opacity(0.28), Color.white.opacity(0.06)]
                    : [Color.white.opacity(0.85), Color.black.opacity(0.06)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var backgroundCircleColor: Color {
        if item.isNext {
            return AppTheme.accentGreen.opacity(0.22)
        } else if item.isCurrent {
            return AppTheme.accentAmber.opacity(0.22)
        } else {
            return AppTheme.badgeBackground
        }
    }

    private var iconColor: Color {
        if item.isNext {
            return AppTheme.accentGreen
        } else if item.isCurrent {
            return AppTheme.accentAmber
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

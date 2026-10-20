import SwiftUI
import AppKit

struct BatteryDrawerView: View {
    @ObservedObject var batteryMonitor = BatteryMonitor.shared
    @ObservedObject var languageManager = LanguageManager.shared
    @ObservedObject var themeManager = ThemeManager.shared
    @State private var isRefreshing: Bool = false

    var body: some View {
        VStack(spacing: 10) {
            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(batteryAccentColor.opacity(AppTheme.isDark ? 0.18 : 0.12))
                        .frame(width: 42, height: 42)

                    Image(systemName: batteryIconName)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(batteryAccentColor)
                        .symbolEffect(.pulse, isActive: batteryMonitor.isCharging)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(batteryMonitor.currentCapacity)%")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.textPrimary)

                        if batteryMonitor.isCharging {
                            Text(L10n.Battery.charging)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(AppTheme.accentGreen)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(AppTheme.accentGreen.opacity(0.18)))
                        } else if batteryMonitor.isPluggedIn {
                            Text(L10n.Battery.connected)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(AppTheme.accentCyan)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(AppTheme.accentCyan.opacity(0.18)))
                        }
                    }

                    Text(batteryMonitor.timeRemainingFormatted)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppTheme.textSecondary)
                }

                Spacer()

                HStack(spacing: 5) {
                    Image(systemName: batteryMonitor.isPluggedIn ? "bolt.fill" : "batteryblock.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(batteryMonitor.isPluggedIn ? AppTheme.accentGreen : AppTheme.textTertiary)

                    Text(powerSourceLabel)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(AppTheme.textPrimary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(.ultraThinMaterial)
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(AppTheme.badgeBackground)
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: AppTheme.isDark
                                        ? [Color.white.opacity(0.25), Color.white.opacity(0.05)]
                                        : [Color.white.opacity(0.8), Color.black.opacity(0.05)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.6
                            )
                    }
                )
            }
            .padding(.horizontal, 16)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppTheme.cardBorder)
                        .frame(height: 5)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [batteryAccentColor.opacity(0.85), batteryAccentColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(
                            width: max(8, geo.size.width * CGFloat(batteryMonitor.currentCapacity) / 100.0),
                            height: 5
                        )
                }
            }
            .frame(height: 5)
            .padding(.horizontal, 16)

            HStack(spacing: 8) {
                BatteryStatCard(
                    icon: "heart.fill",
                    iconColor: AppTheme.accentGreen,
                    title: L10n.Battery.healthTitle,
                    value: "\(batteryMonitor.healthPercent)%",
                    subtext: L10n.Battery.conditionNormal
                )

                BatteryStatCard(
                    icon: "arrow.triangle.2.circlepath",
                    iconColor: AppTheme.accentCyan,
                    title: L10n.Battery.cycleTitle,
                    value: "\(batteryMonitor.cycleCount)",
                    subtext: "\(L10n.Battery.maxPrefix)\(batteryMonitor.maxCycleCount)"
                )

                BatteryStatCard(
                    icon: "gauge.with.needle.fill",
                    iconColor: AppTheme.accentAmber,
                    title: L10n.Battery.capacityTitle,
                    value: batteryMonitor.nominalCapacity > 0 ? "\(batteryMonitor.nominalCapacity) mAh" : "-",
                    subtext: batteryMonitor.designCapacity > 0 ? "\(L10n.Battery.designPrefix)\(batteryMonitor.designCapacity)" : "-"
                )

                BatteryStatCard(
                    icon: batteryMonitor.isPluggedIn ? "powerplug.fill" : "bolt.batteryblock",
                    iconColor: batteryMonitor.isPluggedIn ? AppTheme.accentGreen : AppTheme.textSecondary,
                    title: L10n.Battery.powerSourceTitle,
                    value: batteryMonitor.isPluggedIn ? L10n.Battery.powerAC : L10n.Battery.powerBattery,
                    subtext: batteryMonitor.adapterWatts != nil ? "\(batteryMonitor.adapterWatts!)W" : L10n.Battery.internalBattery
                )
            }
            .padding(.horizontal, 16)

            Divider()
                .background(AppTheme.divider)
                .padding(.horizontal, 16)

            HStack(spacing: 12) {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        isRefreshing = true
                    }
                    batteryMonitor.refreshBatteryInfo()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        isRefreshing = false
                    }
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11, weight: .semibold))
                            .rotationEffect(.degrees(isRefreshing ? 360 : 0))

                        Text(L10n.Battery.refreshData)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(AppTheme.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(AppTheme.badgeBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(AppTheme.cardBorder, lineWidth: 0.5)
                    )
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)

                Spacer()

                Button(action: {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.battery") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 10))
                        Text(L10n.Battery.batterySettings)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(AppTheme.accentAmber)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(AppTheme.badgeBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(AppTheme.cardBorder, lineWidth: 0.5)
                    )
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .frame(width: 540)
    }

    private var powerSourceLabel: String {
        if batteryMonitor.isPluggedIn {
            if let watts = batteryMonitor.adapterWatts {
                return L10n.Battery.acAdapterWatts(watts)
            }
            return L10n.Battery.acAdapter
        }
        return L10n.Battery.internalBattery
    }

    private var batteryIconName: String {
        let cap = batteryMonitor.currentCapacity
        if batteryMonitor.isCharging {
            if cap >= 90 { return "battery.100.bolt" }
            if cap >= 60 { return "battery.75.bolt" }
            if cap >= 35 { return "battery.50.bolt" }
            return "battery.25.bolt"
        } else {
            if cap >= 90 { return "battery.100" }
            if cap >= 60 { return "battery.75" }
            if cap >= 35 { return "battery.50" }
            if cap >= 10 { return "battery.25" }
            return "battery.0"
        }
    }

    private var batteryAccentColor: Color {
        if batteryMonitor.isCharging {
            return AppTheme.accentGreen
        }
        let cap = batteryMonitor.currentCapacity
        if cap > 20 {
            return AppTheme.accentGreen
        } else if cap > 10 {
            return AppTheme.accentAmber
        } else {
            return AppTheme.accentRed
        }
    }
}

struct BatteryStatCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String
    let subtext: String

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(AppTheme.isDark ? 0.16 : 0.12))
                    .frame(width: 26, height: 26)

                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(iconColor)
            }

            VStack(spacing: 2) {
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(AppTheme.textSecondary)
                    .lineLimit(1)

                Text(value)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(1)
            }

            Text(subtext)
                .font(.system(size: 8, weight: .semibold))
                .foregroundColor(iconColor)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(
                    Capsule()
                        .fill(iconColor.opacity(AppTheme.isDark ? 0.14 : 0.10))
                )
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(.ultraThinMaterial)

                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: AppTheme.isDark
                                ? [Color.white.opacity(0.08), Color.white.opacity(0.03)]
                                : [Color.white.opacity(0.60), Color.white.opacity(0.25)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: AppTheme.isDark
                                ? [Color.white.opacity(0.28), Color.white.opacity(0.06)]
                                : [Color.white.opacity(0.85), Color.black.opacity(0.06)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.7
                    )
            }
        )
        .shadow(
            color: AppTheme.isDark ? Color.clear : Color.black.opacity(0.04),
            radius: 2,
            x: 0,
            y: 1
        )
    }
}

import SwiftUI

struct BatteryDrawerView: View {
  @ObservedObject var batteryMonitor = BatteryMonitor.shared
  @ObservedObject var chargeLimiter = BatteryChargeLimiter.shared
  @ObservedObject var languageManager = LanguageManager.shared

  var body: some View {
    VStack(spacing: 12) {
      VStack(spacing: 8) {
        HStack(alignment: .center, spacing: 10) {
          Image(systemName: batteryIconName)
            .font(.system(size: 20, weight: .bold))
            .foregroundColor(batteryAccentColor)
            .symbolEffect(.pulse, isActive: batteryMonitor.isCharging)

          Text("\(batteryMonitor.currentCapacity)%")
            .font(.system(size: 22, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundColor(AppTheme.textPrimary)

          Text(batteryMonitor.timeRemainingFormatted)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(AppTheme.textSecondary)
            .lineLimit(1)

          Spacer(minLength: 4)

          HStack(spacing: 5) {
            Image(systemName: batteryMonitor.isPluggedIn ? "bolt.fill" : "batteryblock.fill")
              .font(.system(size: 10, weight: .bold))
              .foregroundColor(.white)

            Text(powerSourceLabel)
              .font(.system(size: 11, weight: .semibold))
              .foregroundColor(AppTheme.textPrimary)
              .lineLimit(1)
          }
          .padding(.horizontal, 10)
          .padding(.vertical, 4)
          .background(
            Capsule()
              .fill(AppTheme.badgeBackground)
              .overlay(
                Capsule()
                  .stroke(AppTheme.cardBorder, lineWidth: 0.6)
              )
          )
        }

        GeometryReader { geo in
          ZStack(alignment: .leading) {
            Capsule()
              .fill(AppTheme.cardBorder)
              .frame(height: 5)

            Capsule()
              .fill(batteryProgressColor)
              .frame(
                width: max(6, geo.size.width * CGFloat(batteryMonitor.currentCapacity) / 100.0),
                height: 5
              )
          }
        }
        .frame(height: 5)
      }

      HStack(spacing: 8) {
        BatteryStatCard(
          icon: "heart.fill",
          iconColor: healthAccentColor,
          title: L10n.Battery.healthTitle,
          value: "\(batteryMonitor.healthPercent)%"
        )

        BatteryStatCard(
          icon: "arrow.triangle.2.circlepath",
          iconColor: AppTheme.accentCyan,
          title: L10n.Battery.cycleTitle,
          value: "\(batteryMonitor.cycleCount)"
        )

        BatteryStatCard(
          icon: "bolt.batteryblock.fill",
          iconColor: AppTheme.accentAmber,
          title: batteryMonitor.isPluggedIn ? L10n.Dashboard.adapter : L10n.Dashboard.powerSource,
          value: batteryMonitor.isPluggedIn
            ? (batteryMonitor.adapterWatts.map { "\($0)W AC" } ?? "AC") : L10n.Battery.internalBattery
        )
      }

      ClamshellCardView()
    }
    .frame(width: NotchLayout.expandedContentWidth, alignment: .top)
  }

  private var healthAccentColor: Color {
    if batteryMonitor.healthPercent >= 80 {
      return AppTheme.accentGreen
    }
    if batteryMonitor.healthPercent >= 50 {
      return AppTheme.accentAmber
    }
    return AppTheme.accentRed
  }

  private var powerSourceLabel: String {
    if chargeLimiter.isEnabled && chargeLimiter.isChargingInhibited {
      return L10n.Battery.chargeLimitStatusBypass
    }
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
    // Only battery.100.bolt exists in SF Symbols; lower bolt variants are not available.
    if batteryMonitor.isCharging && cap >= 90 { return "battery.100.bolt" }
    if cap >= 60 { return "battery.75" }
    if cap >= 35 { return "battery.50" }
    if cap >= 10 { return "battery.25" }
    return "battery.0"
  }

  private var batteryAccentColor: Color {
    .white
  }

  private var batteryProgressColor: Color {
    if batteryMonitor.isCharging || batteryMonitor.currentCapacity >= 35 {
      return AppTheme.accentGreen
    }
    if batteryMonitor.currentCapacity >= 15 {
      return AppTheme.accentAmber
    }
    return AppTheme.accentRed
  }
}

struct BatteryStatCard: View {
  let icon: String
  let iconColor: Color
  let title: String
  let value: String

  var body: some View {
    HStack(spacing: 7) {
      Image(systemName: icon)
        .font(.system(size: 12, weight: .semibold))
        .foregroundColor(iconColor)

      Text(title)
        .font(.system(size: 11, weight: .medium))
        .foregroundColor(AppTheme.textSecondary)
        .lineLimit(1)

      Spacer(minLength: 4)

      Text(value)
        .font(.system(size: 12, weight: .bold, design: .rounded))
        .monospacedDigit()
        .foregroundColor(AppTheme.textPrimary)
        .lineLimit(1)
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 8)
    .frame(maxWidth: .infinity)
    .background(
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .fill(AppTheme.cardBackground)
        .overlay(
          RoundedRectangle(cornerRadius: 8, style: .continuous)
            .stroke(AppTheme.cardBorder, lineWidth: 0.5)
        )
    )
  }
}

struct ClamshellCardView: View {
  @ObservedObject var clamshell = ClamshellManager.shared

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: "display.2")
        .font(.system(size: 13, weight: .semibold))
        .foregroundColor(accentColor)

      Text(L10n.Clamshell.title)
        .font(.system(size: 12, weight: .bold))
        .foregroundColor(AppTheme.textPrimary)
        .lineLimit(1)

      statusBadge

      Spacer(minLength: 4)

      if !clamshell.isSudoConfigured {
        Button(action: {
          clamshell.setupPasswordlessSudo { _ in }
        }) {
          HStack(spacing: 4) {
            Image(systemName: "key.fill")
              .font(.system(size: 9))
            Text(
              clamshell.isPerformingSetup
                ? L10n.Clamshell.authorizing : L10n.Clamshell.setupPermission
            )
            .font(.system(size: 10, weight: .semibold))
            .lineLimit(1)
          }
          .foregroundColor(AppTheme.accentCyan)
          .padding(.horizontal, 8)
          .padding(.vertical, 3)
          .background(AppTheme.accentCyan.opacity(0.14))
          .cornerRadius(5)
        }
        .buttonStyle(.plain)
        .disabled(clamshell.isPerformingSetup)
      }

      Toggle("", isOn: $clamshell.isArmed)
        .toggleStyle(.switch)
        .labelsHidden()
        .scaleEffect(0.82)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .background(
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .fill(AppTheme.cardBackground)
        .overlay(
          RoundedRectangle(cornerRadius: 8, style: .continuous)
            .stroke(AppTheme.cardBorder, lineWidth: 0.5)
        )
    )
  }

  private var accentColor: Color {
    switch clamshell.currentState {
    case .active:
      return AppTheme.accentGreen
    case .standby:
      return AppTheme.accentAmber
    case .pausedLowBattery:
      return AppTheme.accentRed
    case .off:
      return AppTheme.textTertiary
    }
  }

  @ViewBuilder
  private var statusBadge: some View {
    HStack(spacing: 4) {
      Image(systemName: statusIconName)
        .font(.system(size: 8, weight: .bold))
        .foregroundColor(accentColor)

      Text(statusTitle)
        .font(.system(size: 9, weight: .bold))
        .foregroundColor(accentColor)
    }
    .padding(.horizontal, 6)
    .padding(.vertical, 2)
    .background(
      Capsule()
        .fill(accentColor.opacity(0.15))
    )
  }

  private var statusIconName: String {
    switch clamshell.currentState {
    case .active:
      return "checkmark.circle.fill"
    case .standby:
      return "clock.badge.fill"
    case .pausedLowBattery:
      return "exclamationmark.triangle.fill"
    case .off:
      return "circle"
    }
  }

  private var statusTitle: String {
    switch clamshell.currentState {
    case .active:
      return L10n.Clamshell.active
    case .standby:
      return L10n.Clamshell.standby
    case .pausedLowBattery:
      return L10n.Clamshell.pausedLowBattery
    case .off:
      return L10n.Clamshell.off
    }
  }
}

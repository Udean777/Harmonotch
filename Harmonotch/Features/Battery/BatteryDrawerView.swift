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
              .foregroundColor(batteryMonitor.isPluggedIn ? AppTheme.accentGreen : AppTheme.textSecondary)

            Text(powerSourceLabel)
              .font(.system(size: 11, weight: .semibold))
              .foregroundColor(AppTheme.textPrimary)
              .lineLimit(1)
          }
          .padding(.horizontal, 9)
          .padding(.vertical, 4)
          .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
              .fill(AppTheme.badgeBackground)
              .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
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

      if chargeLimiter.shouldShowChargeToFullNow {
        chargeToFullBanner
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
    }
    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: chargeLimiter.shouldShowChargeToFullNow)
    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: chargeLimiter.isHoldingAtLimit)
    .frame(width: NotchLayout.expandedContentWidth, alignment: .top)
  }

  @ViewBuilder
  private var chargeToFullBanner: some View {
    HStack(spacing: 9) {
      Image(systemName: chargeLimiter.isHoldingAtLimit ? "powerplug.fill" : "bolt.badge.clock.fill")
        .font(.system(size: 12, weight: .semibold))
        .foregroundColor(chargeLimiter.isHoldingAtLimit ? AppTheme.accentCyan : AppTheme.accentAmber)

      VStack(alignment: .leading, spacing: 1.5) {
        Text(chargeLimiter.isHoldingAtLimit
          ? L10n.Battery.holdingAtLimit(chargeLimiter.targetThreshold)
          : L10n.Battery.chargingToLimit(chargeLimiter.targetThreshold)
        )
        .font(.system(size: 11, weight: .bold))
        .foregroundColor(AppTheme.textPrimary)

        Text(chargeLimiter.isHoldingAtLimit
          ? L10n.Battery.holdingAtLimitDesc
          : L10n.Battery.chargingToLimitDesc
        )
        .font(.system(size: 9.5))
        .foregroundColor(AppTheme.textSecondary)
        .lineLimit(1)
      }

      Spacer(minLength: 4)

      Button(action: {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
          chargeLimiter.chargeToFullNow()
        }
      }) {
        HStack(spacing: 4) {
          Image(systemName: "bolt.fill")
            .font(.system(size: 9, weight: .bold))
          Text(L10n.Battery.chargeToFullNow)
            .font(.system(size: 10, weight: .semibold, design: .rounded))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 9)
        .padding(.vertical, 4.5)
        .background(AppTheme.accentGreen)
        .cornerRadius(6)
        .overlay(
          RoundedRectangle(cornerRadius: 6, style: .continuous)
            .stroke(Color.white.opacity(0.2), lineWidth: 0.6)
        )
      }
      .buttonStyle(.plain)
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 7)
    .background(
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .fill(AppTheme.cardBackground)
        .overlay(
          RoundedRectangle(cornerRadius: 8, style: .continuous)
            .stroke(AppTheme.cardBorder, lineWidth: 0.5)
        )
    )
    .transition(.opacity.combined(with: .scale(scale: 0.98)))
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
    batteryMonitor.isCharging ? AppTheme.accentGreen : AppTheme.textPrimary
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

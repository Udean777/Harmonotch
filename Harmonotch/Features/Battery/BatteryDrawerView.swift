import SwiftUI

struct BatteryDrawerView: View {
  @ObservedObject var batteryMonitor = BatteryMonitor.shared
  @ObservedObject var chargeLimiter = BatteryChargeLimiter.shared
  @ObservedObject var clamshell = ClamshellManager.shared

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

      clamshellCard
    }
    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: chargeLimiter.isHoldingAtLimit)
    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: clamshell.currentState)
    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: clamshell.isSudoConfigured)
    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: clamshell.setupFailed)
    .frame(width: NotchLayout.expandedContentWidth, alignment: .top)
  }

  @ViewBuilder
  private var clamshellCard: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 8) {
        Image(systemName: clamshellIconName)
          .font(.system(size: 12, weight: .semibold))
          .foregroundColor(clamshellAccentColor)

        VStack(alignment: .leading, spacing: 1.5) {
          HStack(spacing: 6) {
            Text(L10n.Clamshell.title)
              .font(.system(size: 11, weight: .bold))
              .foregroundColor(AppTheme.textPrimary)

            Text(clamshellStatusLabel)
              .font(.system(size: 9.5, weight: .semibold))
              .foregroundColor(clamshellAccentColor)
              .padding(.horizontal, 6)
              .padding(.vertical, 1.5)
              .background(
                Capsule()
                  .fill(clamshellAccentColor.opacity(0.14))
              )
          }

          Text(clamshellDetailText)
            .font(.system(size: 9.5))
            .foregroundColor(AppTheme.textSecondary)
            .lineLimit(1)
        }

        Spacer(minLength: 4)

        if !clamshell.isSudoConfigured {
          if clamshell.isPerformingSetup {
            HStack(spacing: 5) {
              ProgressView()
                .controlSize(.mini)
              Text(L10n.Clamshell.authorizing)
                .font(.system(size: 9.5, weight: .medium))
                .foregroundColor(AppTheme.textSecondary)
            }
          } else {
            Button(action: {
              clamshell.setupPasswordlessSudo { _ in }
            }) {
              HStack(spacing: 4) {
                Image(systemName: "lock.open.fill")
                  .font(.system(size: 9, weight: .bold))
                Text(L10n.Clamshell.setupPermission)
                  .font(.system(size: 10, weight: .semibold, design: .rounded))
              }
              .foregroundColor(.white)
              .padding(.horizontal, 8)
              .padding(.vertical, 4)
              .background(AppTheme.accentCyan)
              .cornerRadius(6)
            }
            .buttonStyle(.plain)
          }
        }

        Toggle("", isOn: $clamshell.isArmed)
          .labelsHidden()
          .toggleStyle(.switch)
          .controlSize(.mini)
          .disabled(clamshell.isPerformingSetup)
      }

      if clamshell.setupFailed && !clamshell.isPerformingSetup {
        HStack(spacing: 4) {
          Image(systemName: "exclamationmark.triangle.fill")
            .font(AppTypography.micro())
          Text(L10n.Clamshell.setupFailedMessage)
            .font(AppTypography.caption2(.medium))
            .lineLimit(1)
        }
        .foregroundColor(AppTheme.accentRed)
      }
    }
    .cardChrome(cornerRadius: 8, horizontalPadding: 10, verticalPadding: 7, lineWidth: 0.5)
  }

  private var clamshellStatusLabel: String {
    ClamshellPresentation.statusLabel(for: clamshell.currentState)
  }

  private var clamshellIconName: String {
    ClamshellPresentation.iconName(for: clamshell.currentState)
  }

  private var clamshellAccentColor: Color {
    ClamshellPresentation.accentColor(for: clamshell.currentState)
  }

  private var clamshellDetailText: String {
    if !clamshell.hasExternalDisplay {
      return L10n.Clamshell.noExternalDisplay
    }
    let displayName = clamshell.externalDisplayName.isEmpty
      ? L10n.Clamshell.active
      : clamshell.externalDisplayName
    if !batteryMonitor.isPluggedIn {
      return "\(displayName) • \(L10n.Clamshell.powerAdapterWarning)"
    }
    return "\(displayName) • \(L10n.Clamshell.batteryProtectionNote)"
  }

  private var healthAccentColor: Color {
    BatteryPresentation.healthColor(percent: batteryMonitor.healthPercent)
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
    BatteryPresentation.iconName(
      capacity: batteryMonitor.currentCapacity,
      isCharging: batteryMonitor.isCharging
    )
  }

  private var batteryAccentColor: Color {
    batteryMonitor.isCharging ? AppTheme.accentGreen : AppTheme.textPrimary
  }

  private var batteryProgressColor: Color {
    BatteryPresentation.progressColor(
      capacity: batteryMonitor.currentCapacity,
      isCharging: batteryMonitor.isCharging
    )
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
        .font(AppTypography.body(.semibold))
        .foregroundColor(iconColor)

      Text(title)
        .font(AppTypography.subheadline(.medium))
        .foregroundColor(AppTheme.textSecondary)
        .lineLimit(1)

      Spacer(minLength: 4)

      Text(value)
        .font(AppTypography.body(.bold, design: .rounded))
        .monospacedDigit()
        .foregroundColor(AppTheme.textPrimary)
        .lineLimit(1)
    }
    .frame(maxWidth: .infinity)
    .cardChrome(cornerRadius: 8, horizontalPadding: 10, verticalPadding: 8, lineWidth: 0.5)
  }
}

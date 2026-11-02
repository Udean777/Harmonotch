import SwiftUI

struct DashboardBatterySection: View {
  @ObservedObject private var batteryMonitor = BatteryMonitor.shared
  @ObservedObject private var chargeLimiter = BatteryChargeLimiter.shared
  @ObservedObject private var themeManager = ThemeManager.shared
  @ObservedObject private var languageManager = LanguageManager.shared

  var body: some View {
    switch batteryMonitor.state {
    case .loaded(let reading, _):
      loadedView(reading)
    case .loading, .idle:
      DashboardCard {
        message(icon: "battery.0", title: L10n.Dashboard.readingBattery, detail: nil)
      }
    case .unavailable(let reason):
      DashboardCard {
        message(icon: "powerplug", title: L10n.Dashboard.batteryUnavailable, detail: reason)
      }
    case .failed(let reason):
      DashboardCard {
        message(icon: "exclamationmark.triangle", title: L10n.Dashboard.batteryUnavailable, detail: reason)
      }
    case .empty, .permissionRequired, .permissionDenied:
      DashboardCard {
        message(icon: "battery.0", title: L10n.Dashboard.batteryUnavailable, detail: nil)
      }
    }
  }

  private func loadedView(_ reading: BatteryReading) -> some View {
    VStack(spacing: 8) {
      heroBatteryCard(reading)

      chargeLimitCard(reading)

      HStack(spacing: 6) {
        statCard(
          icon: "heart.fill",
          color: healthColor(for: reading.healthPercent),
          title: L10n.Battery.healthTitle,
          value: reading.healthPercent.map { "\($0)%" } ?? L10n.Dashboard.notAvailable
        )

        statCard(
          icon: "arrow.triangle.2.circlepath",
          color: AppTheme.accentCyan,
          title: L10n.Battery.cycleTitle,
          value: reading.cycleCount.map(String.init) ?? L10n.Dashboard.notAvailable
        )

        statCard(
          icon: "bolt.batteryblock.fill",
          color: AppTheme.accentAmber,
          title: L10n.Dashboard.powerSource,
          value: compactPowerSource(for: reading)
        )
      }

      DashboardCard {
        VStack(alignment: .leading, spacing: 5) {
          if reading.isPluggedIn {
            row(L10n.Dashboard.adapter, reading.adapterWatts.map { "\($0) W" })
          }
          row(L10n.Battery.capacityTitle, reading.nominalCapacity.map { "\($0) mAh" })
          row(L10n.Dashboard.designCapacity, reading.designCapacity.map { "\($0) mAh" })
          row(L10n.Dashboard.designCycles, reading.designCycleCount.map(String.init))

          if let volts = reading.voltageVolts {
            row(L10n.Dashboard.voltage, String(format: "%.2f V", volts))
          }
          if let amps = reading.amperageAmps {
            row(L10n.Dashboard.current, String(format: "%.2f A", amps))
          }
          if let watts = reading.powerWatts {
            row(L10n.Dashboard.power, String(format: "%.1f W", watts))
          }
          if let celsius = reading.temperatureCelsius {
            row(L10n.Dashboard.temperature, String(format: "%.1f °C", celsius))
          }
        }
      }

      footerBar(for: reading)
    }
  }

  private func heroBatteryCard(_ reading: BatteryReading) -> some View {
    DashboardCard {
      VStack(spacing: 8) {
        HStack(alignment: .center, spacing: 8) {
          Image(systemName: icon(for: reading))
            .font(.system(size: 18, weight: .bold))
            .foregroundColor(reading.isCharging ? AppTheme.accentGreen : AppTheme.textPrimary)
            .accessibilityHidden(true)

          Text("\(reading.capacity)%")
            .font(.system(size: 20, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundColor(AppTheme.textPrimary)

          Text(BatteryMonitor.localizedTimeEstimate(reading.timeEstimate))
            .font(.system(size: 10.5, weight: .medium))
            .foregroundColor(AppTheme.textSecondary)
            .lineLimit(1)

          Spacer(minLength: 4)

          HStack(spacing: 4) {
            Image(systemName: reading.isPluggedIn ? "bolt.fill" : "batteryblock.fill")
              .font(.system(size: 8.5, weight: .bold))
              .foregroundColor(reading.isPluggedIn ? AppTheme.accentGreen : AppTheme.textSecondary)
              .accessibilityHidden(true)

            Text(statusText(for: reading))
              .font(.system(size: 9.5, weight: .semibold))
              .foregroundColor(AppTheme.textPrimary)
              .lineLimit(1)
          }
          .padding(.horizontal, 8)
          .padding(.vertical, 3)
          .background(
            Capsule()
              .fill(AppTheme.badgeBackground)
              .overlay(Capsule().stroke(AppTheme.cardBorder, lineWidth: 0.5))
          )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
          "\(reading.capacity) percent, \(BatteryMonitor.localizedTimeEstimate(reading.timeEstimate)), \(statusText(for: reading))"
        )

        GeometryReader { geo in
          ZStack(alignment: .leading) {
            Capsule()
              .fill(AppTheme.cardBorder)
              .frame(height: 5)

            Capsule()
              .fill(progressColor(for: reading))
              .frame(
                width: max(5, geo.size.width * CGFloat(reading.capacity) / 100.0),
                height: 5
              )
          }
        }
        .frame(height: 5)
      }
    }
  }

  private func statCard(icon: String, color: Color, title: String, value: String) -> some View {
    VStack(alignment: .leading, spacing: 3) {
      HStack(spacing: 4) {
        Image(systemName: icon)
          .font(.system(size: 9.5, weight: .semibold))
          .foregroundColor(color)
          .accessibilityHidden(true)

        Text(title)
          .font(.system(size: 9, weight: .medium))
          .foregroundColor(AppTheme.textSecondary)
          .lineLimit(1)
      }

      Text(value)
        .font(.system(size: 12, weight: .bold, design: .rounded))
        .monospacedDigit()
        .foregroundColor(AppTheme.textPrimary)
        .lineLimit(1)
    }
    .padding(.horizontal, 9)
    .padding(.vertical, 7)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: 9, style: .continuous)
        .fill(AppTheme.cardBackground)
        .overlay(
          RoundedRectangle(cornerRadius: 9, style: .continuous)
            .stroke(AppTheme.cardBorder, lineWidth: 0.5)
        )
    )
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(title): \(value)")
  }

  private func footerBar(for reading: BatteryReading) -> some View {
    let stale = reading.isStale()
    return VStack(alignment: .leading, spacing: 4) {
      if let error = batteryMonitor.refreshError {
        Label(
          "\(L10n.Dashboard.batteryShowingLastReading) \(error)",
          systemImage: "exclamationmark.triangle.fill"
        )
        .font(.system(size: 9, weight: .medium))
        .foregroundColor(AppTheme.accentAmber)
        .fixedSize(horizontal: false, vertical: true)
      } else if stale {
        Label(L10n.Dashboard.batteryStale, systemImage: "clock.badge.exclamationmark")
          .font(.system(size: 9, weight: .medium))
          .foregroundColor(AppTheme.accentAmber)
      }

      HStack {
        Text(L10n.Dashboard.batteryUpdated(Self.relativeTime(reading.refreshedAt)))
          .font(.system(size: 9, weight: .medium))
          .foregroundColor(AppTheme.textTertiary)

        Spacer()

        Button {
          batteryMonitor.refreshBatteryInfo()
        } label: {
          HStack(spacing: 4) {
            Image(systemName: "arrow.clockwise")
              .font(.system(size: 9, weight: .bold))
            Text(L10n.Dashboard.batteryRefresh)
              .font(.system(size: 9, weight: .semibold))
          }
          .foregroundColor(AppTheme.textSecondary)
          .padding(.horizontal, 8)
          .padding(.vertical, 3.5)
          .background(
            Capsule()
              .fill(AppTheme.badgeBackground)
              .overlay(Capsule().stroke(AppTheme.cardBorder, lineWidth: 0.5))
          )
        }
        .buttonStyle(.plain)
        .disabled(batteryMonitor.isRefreshing)
        .accessibilityLabel(L10n.Dashboard.batteryRefresh)
      }
    }
  }

  private func row(_ title: String, _ value: String?) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 8) {
      Text(title)
        .font(.system(size: 10, weight: .medium))
        .foregroundColor(AppTheme.textSecondary)
        .lineLimit(1)

      Spacer(minLength: 4)

      Text(value ?? L10n.Dashboard.notAvailable)
        .font(.system(size: 10.5, weight: .semibold, design: .rounded))
        .monospacedDigit()
        .foregroundColor(value == nil ? AppTheme.textTertiary : AppTheme.textPrimary)
        .lineLimit(1)
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(title): \(value ?? L10n.Dashboard.notAvailable)")
  }

  private func message(icon: String, title: String, detail: String?) -> some View {
    HStack(spacing: 9) {
      Image(systemName: icon)
        .font(.system(size: 14, weight: .semibold))
        .foregroundColor(AppTheme.textTertiary)
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(.system(size: 11, weight: .semibold))
          .foregroundColor(AppTheme.textSecondary)

        if let detail {
          Text(detail)
            .font(.system(size: 9.5))
            .foregroundColor(AppTheme.textTertiary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }

      Spacer(minLength: 4)
    }
  }

  private func statusText(for reading: BatteryReading) -> String {
    if reading.isCharging { return L10n.Battery.charging }
    if reading.isPluggedIn { return L10n.Battery.connected }
    return L10n.Battery.onBattery
  }

  private func compactPowerSource(for reading: BatteryReading) -> String {
    switch reading.powerSource {
    case .ac:
      return reading.adapterWatts.map { "\($0)W AC" } ?? L10n.Battery.acAdapter
    case .battery:
      return L10n.Battery.internalBattery
    case .unknown:
      return L10n.Dashboard.notAvailable
    }
  }

  private func progressColor(for reading: BatteryReading) -> Color {
    if reading.isCharging || reading.capacity >= 35 { return AppTheme.accentGreen }
    if reading.capacity >= 15 { return AppTheme.accentAmber }
    return AppTheme.accentRed
  }

  private func healthColor(for percent: Int?) -> Color {
    guard let percent else { return AppTheme.textTertiary }
    if percent >= 80 { return AppTheme.accentGreen }
    if percent >= 50 { return AppTheme.accentAmber }
    return AppTheme.accentRed
  }

  private func icon(for reading: BatteryReading) -> String {
    if reading.isCharging && reading.capacity >= 90 { return "battery.100.bolt" }
    if reading.capacity >= 60 { return "battery.75" }
    if reading.capacity >= 35 { return "battery.50" }
    if reading.capacity >= 10 { return "battery.25" }
    return "battery.0"
  }

  private static let enRelativeFormatter: RelativeDateTimeFormatter = {
    let formatter = RelativeDateTimeFormatter()
    formatter.locale = Locale(identifier: "en")
    formatter.unitsStyle = .short
    return formatter
  }()

  private static let idRelativeFormatter: RelativeDateTimeFormatter = {
    let formatter = RelativeDateTimeFormatter()
    formatter.locale = Locale(identifier: "id")
    formatter.unitsStyle = .short
    return formatter
  }()

  private static func relativeTime(_ date: Date) -> String {
    let formatter = LanguageManager.shared.currentLanguage == .english
      ? enRelativeFormatter
      : idRelativeFormatter
    return formatter.localizedString(for: date, relativeTo: Date())
  }

  // MARK: - Charge Limit Card

  private func chargeLimitCard(_ reading: BatteryReading) -> some View {
    DashboardCard {
      VStack(alignment: .leading, spacing: 9) {
        // Header row
        HStack(alignment: .center, spacing: 8) {
          Image(systemName: chargeLimiter.isLimitActive ? "bolt.badge.checkmark" : "bolt.shield")
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(chargeLimiter.isLimitActive ? AppTheme.accentGreen : AppTheme.textSecondary)

          VStack(alignment: .leading, spacing: 1.5) {
            Text(L10n.Battery.chargeLimitTitle)
              .font(.system(size: 12, weight: .bold, design: .rounded))
              .foregroundColor(AppTheme.textPrimary)

            Text(L10n.Battery.chargeLimitDescription(for: chargeLimiter.targetThreshold))
              .font(.system(size: 9.5))
              .foregroundColor(AppTheme.textSecondary)
              .lineLimit(1)
          }

          Spacer(minLength: 4)

          chargeLimitStatusBadge(reading: reading)
        }

        // Custom Percentage Selector: 80% to 100% (Full)
        HStack(spacing: 5) {
          ForEach(ChargeLimitPolicy.availableThresholds, id: \.self) { threshold in
            let isSelected = chargeLimiter.targetThreshold == threshold
            Button(action: {
              withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                chargeLimiter.targetThreshold = threshold
              }
            }) {
              VStack(spacing: 2) {
                Text(threshold == 100 ? "100%" : "\(threshold)%")
                  .font(.system(size: 10.5, weight: isSelected ? .bold : .medium, design: .rounded))
                if threshold == 100 {
                  Text(L10n.Battery.fullCharge100)
                    .font(.system(size: 7.5, weight: .regular))
                }
              }
              .foregroundColor(isSelected ? .white : AppTheme.textSecondary)
              .frame(maxWidth: .infinity)
              .padding(.vertical, 5)
              .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                  .fill(isSelected
                    ? (threshold == 100 ? Color.white.opacity(0.18) : AppTheme.accentGreen.opacity(0.85))
                    : Color.white.opacity(0.05)
                  )
              )
              .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                  .stroke(isSelected
                    ? (threshold == 100 ? Color.white.opacity(0.4) : AppTheme.accentGreen)
                    : Color.white.opacity(0.08),
                    lineWidth: 0.8
                  )
              )
            }
            .buttonStyle(.plain)
          }
        }

        // Native limit indicator or Helper setup if needed
        if chargeLimiter.hasNativeLimit && chargeLimiter.targetThreshold == (chargeLimiter.nativeLimitValue ?? 80) {
          HStack(spacing: 6) {
            Image(systemName: "checkmark.shield.fill")
              .font(.system(size: 10))
              .foregroundColor(AppTheme.accentGreen)

            Text(L10n.Battery.nativeLimitActive)
              .font(.system(size: 9, weight: .medium))
              .foregroundColor(AppTheme.textSecondary)

            Spacer()

            Button(action: {
              if let url = URL(string: "x-apple.systempreferences:com.apple.Battery-Settings.extension") {
                NSWorkspace.shared.open(url)
              }
            }) {
              HStack(spacing: 3) {
                Image(systemName: "gearshape")
                  .font(.system(size: 8))
                Text("Settings")
                  .font(.system(size: 8.5, weight: .medium))
              }
              .foregroundColor(AppTheme.textSecondary)
              .padding(.horizontal, 6)
              .padding(.vertical, 2.5)
              .background(Color.white.opacity(0.06))
              .cornerRadius(4)
            }
            .buttonStyle(.plain)
          }
          .padding(.horizontal, 4)
          .padding(.top, 1)
        } else if chargeLimiter.isLimitActive && !chargeLimiter.isSudoConfigured {
          HStack(spacing: 8) {
            Image(systemName: "lock.shield")
              .font(.system(size: 11))
              .foregroundColor(AppTheme.accentAmber)

            Text(L10n.Battery.chargeLimitSetupDesc)
              .font(.system(size: 9))
              .foregroundColor(AppTheme.textSecondary)
              .lineLimit(2)
              .frame(maxWidth: .infinity, alignment: .leading)

            if chargeLimiter.isPerformingSetup {
              ProgressView()
                .controlSize(.small)
            } else {
              Button(action: {
                chargeLimiter.setupPasswordlessSudo { _ in }
              }) {
                Text(L10n.Battery.chargeLimitSetupAction)
                  .font(.system(size: 9.5, weight: .semibold))
                  .foregroundColor(.white)
                  .padding(.horizontal, 8)
                  .padding(.vertical, 3)
                  .background(AppTheme.accentAmber.opacity(0.8))
                  .cornerRadius(5)
              }
              .buttonStyle(.plain)
            }
          }
          .padding(7)
          .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
              .fill(AppTheme.accentAmber.opacity(0.08))
              .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                  .stroke(AppTheme.accentAmber.opacity(0.20), lineWidth: 0.6)
              )
          )
          .transition(.opacity)
        }
      }
    }
  }

  private func chargeLimitStatusBadge(reading: BatteryReading) -> some View {
    let (text, color, icon): (String, Color, String) = {
      if !reading.isPluggedIn {
        return (L10n.Battery.onBattery, AppTheme.textSecondary, "battery.0")
      } else if !chargeLimiter.isLimitActive {
        return (L10n.Battery.fullCharge100, AppTheme.textTertiary, "bolt.fill")
      } else if chargeLimiter.isChargingInhibited || (chargeLimiter.hasNativeLimit && reading.capacity >= chargeLimiter.targetThreshold && !reading.isCharging) {
        return (L10n.Battery.chargeLimitStatusBypass, AppTheme.accentCyan, "bolt.fill")
      } else if reading.isCharging {
        return ("\(chargeLimiter.targetThreshold)%", AppTheme.accentAmber, "bolt.badge.clock.fill")
      } else {
        return ("\(chargeLimiter.targetThreshold)%", AppTheme.accentGreen, "checkmark.circle.fill")
      }
    }()

    return HStack(spacing: 4) {
      Image(systemName: icon)
        .font(.system(size: 8.5))
      Text(text)
        .font(.system(size: 9, weight: .bold, design: .rounded))
    }
    .foregroundColor(color)
    .padding(.horizontal, 6)
    .padding(.vertical, 2.5)
    .background(
      Capsule(style: .continuous)
        .fill(color.opacity(0.12))
        .overlay(
          Capsule(style: .continuous)
            .stroke(color.opacity(0.25), lineWidth: 0.6)
        )
    )
  }
}

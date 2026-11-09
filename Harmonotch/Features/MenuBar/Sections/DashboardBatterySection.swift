import SwiftUI

struct DashboardBatterySection: View {
  @ObservedObject private var batteryMonitor = BatteryMonitor.shared
  @State private var showTechnicalDetails = false

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
        VStack(alignment: .leading, spacing: 6) {
          row(L10n.Battery.healthTitle, L10n.Battery.healthCondition(reading.healthPercent))

          if reading.isPluggedIn {
            row(L10n.Dashboard.adapter, reading.adapterWatts.map { "\($0) W" } ?? L10n.Battery.connected)
          }

          if let celsius = reading.temperatureCelsius {
            row(L10n.Dashboard.temperature, L10n.Battery.temperatureWithStatus(celsius))
          }

          Divider()
            .background(AppTheme.divider)
            .padding(.vertical, 2)

          Button {
            withAnimation(.easeInOut(duration: 0.16)) {
              showTechnicalDetails.toggle()
            }
          } label: {
            HStack(spacing: 5) {
              Text(L10n.Battery.technicalDetailsToggle(expanded: showTechnicalDetails))
                .font(AppTypography.caption2(.semibold))
                .foregroundColor(AppTheme.accentCyan)

              Spacer()

              Image(systemName: showTechnicalDetails ? "chevron.up" : "chevron.down")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(AppTheme.accentCyan)
            }
            .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .accessibilityLabel(L10n.Battery.technicalDetailsToggle(expanded: showTechnicalDetails))

          if showTechnicalDetails {
            VStack(alignment: .leading, spacing: 5) {
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
            }
            .padding(.top, 2)
            .transition(.opacity)
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
            .font(.system(size: 13, weight: .bold))
            .foregroundColor(reading.isCharging ? AppTheme.accentGreen : AppTheme.textPrimary)
            .accessibilityHidden(true)

          Text("\(reading.capacity)%")
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundColor(AppTheme.textPrimary)

          Text(BatteryMonitor.localizedTimeEstimate(reading.timeEstimate))
            .font(AppTypography.caption2(.medium))
            .foregroundColor(AppTheme.textSecondary)
            .lineLimit(1)

          Spacer(minLength: 4)

          HStack(spacing: 4) {
            Image(systemName: reading.isPluggedIn ? "bolt.fill" : "batteryblock.fill")
              .font(.system(size: 8.5, weight: .bold))
              .foregroundColor(reading.isPluggedIn ? AppTheme.accentGreen : AppTheme.textSecondary)
              .accessibilityHidden(true)

            Text(statusText(for: reading))
              .font(AppTypography.micro(.semibold))
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
          .font(AppTypography.micro(.semibold))
          .foregroundColor(color)
          .accessibilityHidden(true)

        Text(title)
          .font(AppTypography.micro(.medium))
          .foregroundColor(AppTheme.textSecondary)
          .lineLimit(1)
      }

      Text(value)
        .font(AppTypography.footnote(.bold, design: .rounded))
        .monospacedDigit()
        .foregroundColor(AppTheme.textPrimary)
        .lineLimit(1)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .cardChrome(cornerRadius: 8, horizontalPadding: 8, verticalPadding: 6, lineWidth: 0.5)
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
        .font(.system(size: 10.5, weight: .medium))
        .foregroundColor(AppTheme.accentAmber)
        .fixedSize(horizontal: false, vertical: true)
      } else if stale {
        Label(L10n.Dashboard.batteryStale, systemImage: "clock.badge.exclamationmark")
          .font(.system(size: 10.5, weight: .medium))
          .foregroundColor(AppTheme.accentAmber)
      }

      HStack {
        Text(L10n.Dashboard.batteryUpdated(TimeFormatting.relativeText(for: reading.refreshedAt)))
          .font(.system(size: 10, weight: .medium))
          .foregroundColor(AppTheme.textTertiary)

        Spacer()

        Button {
          batteryMonitor.refreshBatteryInfo()
        } label: {
          HStack(spacing: 4) {
            Image(systemName: "arrow.clockwise")
              .font(.system(size: 10, weight: .bold))
            Text(L10n.Dashboard.batteryRefresh)
              .font(.system(size: 10, weight: .semibold))
          }
          .foregroundColor(AppTheme.textSecondary)
          .padding(.horizontal, 9)
          .padding(.vertical, 4)
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
        .font(AppTypography.caption2(.medium))
        .foregroundColor(AppTheme.textSecondary)
        .lineLimit(1)

      Spacer(minLength: 4)

      Text(value ?? L10n.Dashboard.notAvailable)
        .font(AppTypography.caption2(.semibold, design: .rounded))
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
    BatteryPresentation.progressColor(capacity: reading.capacity, isCharging: reading.isCharging)
  }

  private func healthColor(for percent: Int?) -> Color {
    BatteryPresentation.healthColor(percent: percent)
  }

  private func icon(for reading: BatteryReading) -> String {
    BatteryPresentation.iconName(capacity: reading.capacity, isCharging: reading.isCharging)
  }
}

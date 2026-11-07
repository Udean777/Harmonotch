import SwiftUI

struct PrayerSummaryCard: View {
  @ObservedObject private var prayerManager = PrayerManager.shared

  private var prayerState: DashboardDataState<PrayerScheduleItem> {
    if let next = prayerManager.nextPrayerItem {
      return .loaded(next, refreshedAt: Date())
    }
    return .unavailable(L10n.Dashboard.prayerUnavailable)
  }

  var body: some View {
    DashboardCard(minHeight: 76, alignment: .topLeading) {
      VStack(alignment: .leading, spacing: 5) {
        HStack(spacing: 5) {
          Image(systemName: "moon.stars.fill")
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(AppTheme.accentAmber)
            .accessibilityHidden(true)

          Text(L10n.Menu.nextPrayer)
            .font(.system(size: 9, weight: .bold))
            .tracking(0.4)
            .foregroundColor(AppTheme.textTertiary)
            .textCase(.uppercase)
            .lineLimit(1)

          Spacer(minLength: 2)

          Image(systemName: "chevron.right")
            .font(.system(size: 8, weight: .bold))
            .foregroundColor(AppTheme.textTertiary)
            .accessibilityHidden(true)
        }

        switch prayerState {
        case .loaded(let prayer, _):
          HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text(prayer.name)
              .font(.system(size: 18, weight: .bold))
              .foregroundColor(AppTheme.textPrimary)
              .lineLimit(1)

            Text(prayer.timeString)
              .font(.system(size: 13, weight: .bold, design: .rounded))
              .monospacedDigit()
              .foregroundColor(AppTheme.accentAmber)
              .lineLimit(1)
          }

          HStack(spacing: 4) {
            TimelineView(.periodic(from: .now, by: 30)) { context in
              Text(TimeFormatting.countdownText(to: prayer.time, now: context.date))
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(AppTheme.textSecondary)
                .lineLimit(1)
            }

            if !prayerManager.currentLocationName.isEmpty {
              Text("• \(prayerManager.currentLocationName)")
                .font(.system(size: 9.5, weight: .regular))
                .foregroundColor(AppTheme.textTertiary)
                .lineLimit(1)
            }
          }
        case .loading, .idle:
          Text(L10n.Dashboard.loading)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(AppTheme.textSecondary)
        default:
          Text(L10n.Dashboard.prayerUnavailable)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(AppTheme.textSecondary)
            .lineLimit(2)
        }
      }
    }
  }
}

struct BatterySummaryCard: View {
  @ObservedObject private var batteryMonitor = BatteryMonitor.shared

  var body: some View {
    DashboardCard(minHeight: 76, alignment: .topLeading) {
      VStack(alignment: .leading, spacing: 5) {
        HStack(spacing: 5) {
          Image(systemName: "bolt.batteryblock.fill")
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(AppTheme.accentGreen)
            .accessibilityHidden(true)

          Text(L10n.Dashboard.battery)
            .font(.system(size: 9, weight: .bold))
            .tracking(0.4)
            .foregroundColor(AppTheme.textTertiary)
            .textCase(.uppercase)
            .lineLimit(1)

          Spacer(minLength: 2)

          Image(systemName: "chevron.right")
            .font(.system(size: 8, weight: .bold))
            .foregroundColor(AppTheme.textTertiary)
            .accessibilityHidden(true)
        }

        switch batteryMonitor.state {
        case .loaded(let snapshot, _):
          HStack(alignment: .firstTextBaseline, spacing: 5) {
            Image(
              systemName: BatteryPresentation.iconName(
                capacity: snapshot.capacity,
                isCharging: snapshot.isCharging
              )
            )
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(snapshot.isCharging ? AppTheme.accentGreen : AppTheme.textPrimary)

            Text("\(snapshot.capacity)%")
              .font(.system(size: 18, weight: .bold, design: .rounded))
              .monospacedDigit()
              .foregroundColor(AppTheme.textPrimary)
          }

          Text(BatteryMonitor.localizedTimeEstimate(snapshot.timeEstimate))
            .font(.system(size: 9.5, weight: .medium))
            .foregroundColor(AppTheme.textSecondary)
            .lineLimit(1)
        case .loading, .idle:
          HStack(spacing: 5) {
            ProgressView()
              .scaleEffect(0.55)
              .frame(width: 12, height: 12)
            Text(L10n.Dashboard.readingBattery)
              .font(.system(size: 10, weight: .medium))
              .foregroundColor(AppTheme.textSecondary)
              .lineLimit(1)
          }
        case .unavailable(let message), .failed(let message):
          HStack(spacing: 4) {
            Image(systemName: "powerplug.fill")
              .font(.system(size: 11, weight: .semibold))
              .foregroundColor(AppTheme.textTertiary)
            Text(message)
              .font(.system(size: 10, weight: .medium))
              .foregroundColor(AppTheme.textSecondary)
              .lineLimit(2)
          }
        default:
          Text(L10n.Dashboard.batteryUnavailable)
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(AppTheme.textSecondary)
        }
      }
    }
  }
}

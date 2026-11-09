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
        SummaryCardHeader(
          icon: "moon.stars.fill",
          iconColor: AppTheme.accentAmber,
          title: L10n.Menu.nextPrayer
        )

        switch prayerState {
        case .loaded(let prayer, _):
          HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text(prayer.name)
              .font(AppTypography.subheadline(.bold))
              .foregroundColor(AppTheme.textPrimary)
              .lineLimit(1)

            Text(prayer.timeString)
              .font(AppTypography.subheadline(.bold, design: .rounded))
              .monospacedDigit()
              .foregroundColor(AppTheme.accentAmber)
              .lineLimit(1)
          }

          HStack(spacing: 4) {
            TimelineView(.periodic(from: .now, by: 30)) { context in
              Text(TimeFormatting.countdownText(to: prayer.time, now: context.date))
                .font(AppTypography.caption2(.medium))
                .foregroundColor(AppTheme.textSecondary)
                .lineLimit(1)
            }

            if !prayerManager.currentLocationName.isEmpty {
              Text("• \(prayerManager.currentLocationName)")
                .font(AppTypography.micro(.regular))
                .foregroundColor(AppTheme.textTertiary)
                .lineLimit(1)
            }
          }
        case .loading, .idle:
          Text(L10n.Dashboard.loading)
            .font(AppTypography.caption(.semibold))
            .foregroundColor(AppTheme.textSecondary)
        default:
          Text(L10n.Dashboard.prayerUnavailable)
            .font(AppTypography.caption(.semibold))
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
        SummaryCardHeader(
          icon: "bolt.batteryblock.fill",
          iconColor: AppTheme.accentGreen,
          title: L10n.Dashboard.battery
        )

        switch batteryMonitor.state {
        case .loaded(let snapshot, _):
          HStack(alignment: .firstTextBaseline, spacing: 5) {
            Image(
              systemName: BatteryPresentation.iconName(
                capacity: snapshot.capacity,
                isCharging: snapshot.isCharging
              )
            )
            .font(.system(size: 13, weight: .bold))
            .foregroundColor(snapshot.isCharging ? AppTheme.accentGreen : AppTheme.textPrimary)

            Text("\(snapshot.capacity)%")
              .font(AppTypography.subheadline(.bold, design: .rounded))
              .monospacedDigit()
              .foregroundColor(AppTheme.textPrimary)
          }

          Text(BatteryMonitor.localizedTimeEstimate(snapshot.timeEstimate))
            .font(AppTypography.caption2(.medium))
            .foregroundColor(AppTheme.textSecondary)
            .lineLimit(1)
        case .loading, .idle:
          HStack(spacing: 5) {
            ProgressView()
              .scaleEffect(0.55)
              .frame(width: 12, height: 12)
            Text(L10n.Dashboard.readingBattery)
              .font(AppTypography.caption2(.medium))
              .foregroundColor(AppTheme.textSecondary)
              .lineLimit(1)
          }
        case .unavailable(let message), .failed(let message):
          HStack(spacing: 4) {
            Image(systemName: "powerplug.fill")
              .font(.system(size: 10, weight: .semibold))
              .foregroundColor(AppTheme.textTertiary)
            Text(message)
              .font(AppTypography.caption2(.medium))
              .foregroundColor(AppTheme.textSecondary)
              .lineLimit(2)
          }
        default:
          Text(L10n.Dashboard.batteryUnavailable)
            .font(AppTypography.caption2(.medium))
            .foregroundColor(AppTheme.textSecondary)
        }
      }
    }
  }
}

private struct SummaryCardHeader: View {
  let icon: String
  let iconColor: Color
  let title: String

  var body: some View {
    HStack(spacing: 5) {
      Image(systemName: icon)
        .font(.system(size: 10, weight: .semibold))
        .foregroundColor(iconColor)
        .accessibilityHidden(true)

      Text(title)
        .font(.system(size: 10, weight: .bold))
        .tracking(0.3)
        .foregroundColor(AppTheme.textTertiary)
        .textCase(.uppercase)
        .lineLimit(1)

      Spacer(minLength: 2)

      Image(systemName: "chevron.right")
        .font(.system(size: 8, weight: .bold))
        .foregroundColor(AppTheme.textTertiary)
        .accessibilityHidden(true)
    }
  }
}

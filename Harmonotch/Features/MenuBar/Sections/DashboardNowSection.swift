import AppKit
import SwiftUI

struct DashboardNowSection: View {
  @ObservedObject private var batteryMonitor = BatteryMonitor.shared
  @ObservedObject private var prayerManager = PrayerManager.shared
  @ObservedObject private var adzanPlayer = AdzanPlayer.shared
  @ObservedObject private var mediaManager = MediaManager.shared
  @ObservedObject private var clamshellManager = ClamshellManager.shared
  @ObservedObject private var updateManager = UpdateManager.shared
  @ObservedObject private var themeManager = ThemeManager.shared
  @ObservedObject private var languageManager = LanguageManager.shared

  var onSelectTab: (DashboardTab) -> Void

  var body: some View {
    VStack(spacing: 8) {
      if shouldShowUpdateBanner {
        updateBannerSection
      }

      heroCard

      clamshellQuickRow

      if adzanPlayer.isPlaying {
        adzanBannerRow
      } else if mediaManager.hasActiveTrack {
        mediaQuickRow
      }
    }
  }

  private var heroCard: some View {
    HStack(alignment: .top, spacing: 8) {
      Button {
        onSelectTab(.prayer)
      } label: {
        prayerSummaryCard
      }
      .buttonStyle(.plain)
      .accessibilityLabel("\(L10n.Menu.nextPrayer), \(L10n.Dashboard.prayerTab)")

      Button {
        onSelectTab(.battery)
      } label: {
        batterySummaryCard
      }
      .buttonStyle(.plain)
      .accessibilityLabel("\(L10n.Dashboard.battery), \(L10n.Dashboard.batteryTab)")
    }
  }

  private var prayerSummaryCard: some View {
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
            Text(countdownText(to: prayer.time, now: context.date))
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
    .padding(10)
    .frame(maxWidth: .infinity, minHeight: 76, alignment: .topLeading)
    .background(
      RoundedRectangle(cornerRadius: 10, style: .continuous)
        .fill(AppTheme.cardBackground)
        .overlay(
          RoundedRectangle(cornerRadius: 10, style: .continuous)
            .stroke(AppTheme.cardBorder, lineWidth: 0.6)
        )
    )
  }

  private var batterySummaryCard: some View {
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

      switch batteryState {
      case .loaded(let snapshot, _):
        HStack(alignment: .firstTextBaseline, spacing: 5) {
          Image(systemName: batteryIcon(for: snapshot))
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
    .padding(10)
    .frame(maxWidth: .infinity, minHeight: 76, alignment: .topLeading)
    .background(
      RoundedRectangle(cornerRadius: 10, style: .continuous)
        .fill(AppTheme.cardBackground)
        .overlay(
          RoundedRectangle(cornerRadius: 10, style: .continuous)
            .stroke(AppTheme.cardBorder, lineWidth: 0.6)
        )
    )
  }

  private var clamshellQuickRow: some View {
    DashboardCard {
      HStack(spacing: 8) {
        ZStack {
          RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(AppTheme.badgeBackground)
            .frame(width: 26, height: 26)

          Image(systemName: "display.2")
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(clamshellAccentColor)
            .accessibilityHidden(true)
        }

        VStack(alignment: .leading, spacing: 1.5) {
          HStack(spacing: 5) {
            Text(L10n.Clamshell.title)
              .font(.system(size: 11, weight: .bold))
              .foregroundColor(AppTheme.textPrimary)

            HStack(spacing: 3) {
              Image(systemName: clamshellStatusIcon)
                .font(.system(size: 7, weight: .bold))
                .accessibilityHidden(true)
              Text(clamshellStatusTitle)
                .font(.system(size: 8, weight: .bold))
            }
            .foregroundColor(clamshellAccentColor)
            .padding(.horizontal, 5)
            .padding(.vertical, 1.5)
            .background(Capsule().fill(clamshellAccentColor.opacity(0.14)))
          }

          Text(
            clamshellManager.hasExternalDisplay
              ? (clamshellManager.externalDisplayName.isEmpty
                ? L10n.Clamshell.externalDisplayLabel : clamshellManager.externalDisplayName)
              : L10n.Clamshell.noExternalDisplay
          )
          .font(.system(size: 9, weight: .medium))
          .foregroundColor(AppTheme.textSecondary)
          .lineLimit(1)
        }

        Spacer(minLength: 4)

        Toggle("", isOn: $clamshellManager.isArmed)
          .toggleStyle(.switch)
          .labelsHidden()
          .scaleEffect(0.75)
          .accessibilityLabel(L10n.Menu.clamshellToggle)
      }
    }
  }

  private var adzanBannerRow: some View {
    DashboardCard {
      HStack(spacing: 8) {
        Image(systemName: "speaker.wave.3.fill")
          .font(.system(size: 12, weight: .semibold))
          .foregroundColor(AppTheme.accentAmber)

        VStack(alignment: .leading, spacing: 1) {
          Text(
            adzanPlayer.playingPrayerName.isEmpty
              ? L10n.Prayer.adzanActive : adzanPlayer.playingPrayerName
          )
          .font(.system(size: 10.5, weight: .bold))
          .foregroundColor(AppTheme.textPrimary)
          .lineLimit(1)

          Text(L10n.Prayer.adzanActive)
            .font(.system(size: 9, weight: .medium))
            .foregroundColor(AppTheme.textSecondary)
            .lineLimit(1)
        }

        Spacer(minLength: 4)

        Button {
          adzanPlayer.stop()
        } label: {
          Image(systemName: "stop.fill")
            .font(.system(size: 9.5, weight: .bold))
            .foregroundColor(AppTheme.accentRed)
            .frame(width: 24, height: 24)
            .background(AppTheme.badgeBackground)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(
              RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(AppTheme.cardBorder, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.Prayer.stopAudio)
      }
    }
  }

  private var mediaQuickRow: some View {
    DashboardCard {
      HStack(spacing: 8) {
        Group {
          if let art = mediaManager.artworkImage {
            Image(nsImage: art)
              .resizable()
              .aspectRatio(contentMode: .fill)
              .frame(width: 28, height: 28)
              .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
          } else {
            ZStack {
              RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(AppTheme.badgeBackground)
                .frame(width: 28, height: 28)

              Image(systemName: mediaManager.mediaSource.iconName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(AppTheme.accentCyan)
            }
          }
        }
        .accessibilityHidden(true)

        VStack(alignment: .leading, spacing: 1) {
          Text(mediaManager.trackTitle)
            .font(.system(size: 10.5, weight: .bold))
            .foregroundColor(AppTheme.textPrimary)
            .lineLimit(1)

          Text(mediaManager.artistName.isEmpty ? L10n.Media.nowPlaying : mediaManager.artistName)
            .font(.system(size: 9, weight: .medium))
            .foregroundColor(AppTheme.textSecondary)
            .lineLimit(1)
        }

        Spacer(minLength: 4)

        HStack(spacing: 4) {
          mediaControlButton(icon: "backward.fill", label: L10n.Media.previousTrack) {
            mediaManager.previousTrack()
          }

          mediaControlButton(
            icon: mediaManager.isPlaying ? "pause.fill" : "play.fill",
            color: mediaManager.isPlaying ? AppTheme.accentAmber : AppTheme.accentGreen,
            label: mediaManager.isPlaying ? L10n.Media.pause : L10n.Media.play
          ) {
            mediaManager.playPause()
          }

          mediaControlButton(icon: "forward.fill", label: L10n.Media.nextTrack) {
            mediaManager.nextTrack()
          }
        }
      }
    }
  }

  private func mediaControlButton(
    icon: String,
    color: Color = AppTheme.textPrimary,
    label: String,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      Image(systemName: icon)
        .font(.system(size: 9, weight: .bold))
        .foregroundColor(color)
        .frame(width: 24, height: 24)
        .background(AppTheme.badgeBackground)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(
          RoundedRectangle(cornerRadius: 6, style: .continuous)
            .stroke(AppTheme.cardBorder, lineWidth: 0.5)
        )
    }
    .buttonStyle(.plain)
    .accessibilityLabel(label)
  }

  private var clamshellAccentColor: Color {
    switch clamshellManager.currentState {
    case .active: return AppTheme.accentGreen
    case .standby: return AppTheme.accentAmber
    case .pausedLowBattery: return AppTheme.accentRed
    case .off: return AppTheme.textTertiary
    }
  }

  private var clamshellStatusIcon: String {
    switch clamshellManager.currentState {
    case .active: return "checkmark.circle.fill"
    case .standby: return "clock.badge.fill"
    case .pausedLowBattery: return "exclamationmark.triangle.fill"
    case .off: return "circle"
    }
  }

  private var clamshellStatusTitle: String {
    switch clamshellManager.currentState {
    case .active: return L10n.Clamshell.active
    case .standby: return L10n.Clamshell.standby
    case .pausedLowBattery: return L10n.Clamshell.pausedLowBattery
    case .off: return L10n.Clamshell.off
    }
  }

  private var prayerState: DashboardDataState<PrayerScheduleItem> {
    if let next = prayerManager.nextPrayerItem {
      return .loaded(next, refreshedAt: Date())
    }
    return .unavailable(L10n.Dashboard.prayerUnavailable)
  }

  private var batteryState: DashboardDataState<BatteryReading> {
    batteryMonitor.state
  }

  private func batteryIcon(for snapshot: BatteryReading) -> String {
    if snapshot.isCharging && snapshot.capacity >= 90 { return "battery.100.bolt" }
    if snapshot.capacity >= 60 { return "battery.75" }
    if snapshot.capacity >= 35 { return "battery.50" }
    if snapshot.capacity >= 10 { return "battery.25" }
    return "battery.0"
  }

  private func countdownText(to prayerTime: Date, now: Date) -> String {
    let remainingMinutes = Int(ceil(max(0, prayerTime.timeIntervalSince(now)) / 60))
    return L10n.Dashboard.countdown(
      hours: remainingMinutes / 60,
      minutes: remainingMinutes % 60
    )
  }

  private var shouldShowUpdateBanner: Bool {
    switch updateManager.state {
    case .available, .downloading, .installing, .readyToQuit, .failed:
      return true
    default:
      return false
    }
  }

  @ViewBuilder
  private var updateBannerSection: some View {
    switch updateManager.state {
    case .available(let version):
      HStack(spacing: 8) {
        Image(systemName: "arrow.down.circle.fill")
          .font(.system(size: 16))
          .foregroundColor(AppTheme.accentCyan)

        VStack(alignment: .leading, spacing: 1) {
          Text(L10n.Update.available)
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(AppTheme.textPrimary)
          Text("v\(version)")
            .font(.system(size: 9.5, weight: .medium, design: .rounded))
            .foregroundColor(AppTheme.textSecondary)
        }

        Spacer()

        Button(action: {
          updateManager.downloadAndInstallUpdate()
        }) {
          Text(L10n.Update.updateNow)
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(Color.black)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Capsule().fill(AppTheme.accentAmber))
        }
        .buttonStyle(.plain)
      }
      .padding(8)
      .background(
        RoundedRectangle(cornerRadius: 9, style: .continuous)
          .fill(AppTheme.badgeBackground)
          .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
              .stroke(AppTheme.cardBorder, lineWidth: 0.8)
          )
      )

    case .downloading(let progress):
      VStack(spacing: 5) {
        HStack(spacing: 6) {
          ProgressView()
            .scaleEffect(0.5)
            .frame(width: 12, height: 12)

          Text(L10n.Update.downloading)
            .font(.system(size: 10.5, weight: .medium))
            .foregroundColor(AppTheme.textPrimary)

          Spacer()

          if let progress = progress {
            Text("\(Int(progress * 100))%")
              .font(.system(size: 10, weight: .bold, design: .monospaced))
              .foregroundColor(AppTheme.textSecondary)
          }
        }

        if let progress = progress {
          ProgressView(value: progress)
            .progressViewStyle(.linear)
            .tint(AppTheme.accentCyan)
            .scaleEffect(y: 0.8)
        } else {
          ProgressView()
            .progressViewStyle(.linear)
            .tint(AppTheme.accentCyan)
            .scaleEffect(y: 0.8)
        }
      }
      .padding(8)
      .background(
        RoundedRectangle(cornerRadius: 9, style: .continuous)
          .fill(AppTheme.cardBackground)
          .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
              .stroke(AppTheme.cardBorder, lineWidth: 0.5)
          )
      )

    case .installing:
      HStack(spacing: 8) {
        ProgressView()
          .scaleEffect(0.6)
          .frame(width: 16, height: 16)

        Text(L10n.Update.installing)
          .font(.system(size: 10.5, weight: .medium))
          .foregroundColor(AppTheme.textPrimary)

        Spacer()
      }
      .padding(8)
      .background(
        RoundedRectangle(cornerRadius: 9, style: .continuous)
          .fill(AppTheme.cardBackground)
          .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
              .stroke(AppTheme.cardBorder, lineWidth: 0.5)
          )
      )

    case .readyToQuit(let version):
      VStack(alignment: .leading, spacing: 6) {
        HStack(spacing: 6) {
          Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 14))
            .foregroundColor(AppTheme.accentGreen)

          Text(L10n.Update.readyToQuitTitle(version: version))
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(AppTheme.textPrimary)
        }

        Text(L10n.Update.readyToQuitSubtitle)
          .font(.system(size: 9.5))
          .foregroundColor(AppTheme.textSecondary)
          .fixedSize(horizontal: false, vertical: true)

        HStack(spacing: 8) {
          Button(action: {
            updateManager.quitAfterUpdate(relaunch: true)
          }) {
            HStack(spacing: 4) {
              Image(systemName: "arrow.clockwise")
                .font(.system(size: 9, weight: .bold))
              Text(L10n.Update.restartApp)
                .font(.system(size: 10, weight: .bold))
            }
            .foregroundColor(Color.black)
            .accessibilityLabel(L10n.Update.restartApp)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 5)
            .background(Capsule().fill(AppTheme.accentAmber))
          }
          .buttonStyle(.plain)

          Button(action: {
            updateManager.quitAfterUpdate(relaunch: false)
          }) {
            HStack(spacing: 4) {
              Image(systemName: "power")
                .font(.system(size: 9, weight: .bold))
              Text(L10n.Update.quitApp)
                .font(.system(size: 10, weight: .semibold))
            }
            .foregroundColor(AppTheme.textPrimary)
            .accessibilityLabel(L10n.Update.quitApp)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 5)
            .background(Capsule().fill(AppTheme.badgeBackground))
            .overlay(
              Capsule().stroke(AppTheme.cardBorder, lineWidth: 0.5)
            )
          }
          .buttonStyle(.plain)
        }
        .padding(.top, 2)
      }
      .padding(10)
      .background(
        RoundedRectangle(cornerRadius: 9, style: .continuous)
          .fill(AppTheme.badgeBackground)
          .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
              .stroke(AppTheme.cardBorder, lineWidth: 0.8)
          )
      )

    case .failed(let message):
      HStack(spacing: 8) {
        Image(systemName: "exclamationmark.circle.fill")
          .font(.system(size: 14))
          .foregroundColor(AppTheme.accentAmber)

        VStack(alignment: .leading, spacing: 1) {
          Text(L10n.Update.downloadFailedTitle)
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(AppTheme.textPrimary)
          Text(message)
            .font(.system(size: 8.5))
            .foregroundColor(AppTheme.textSecondary)
            .lineLimit(1)
        }

        Spacer()

        Button(action: {
          updateManager.downloadAndInstallUpdate()
        }) {
          Text(L10n.Update.retry)
            .font(.system(size: 9.5, weight: .semibold))
            .foregroundColor(AppTheme.accentCyan)
            .accessibilityLabel(L10n.Update.retry)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(AppTheme.accentCyan.opacity(0.15)))
        }
        .buttonStyle(.plain)
      }
      .padding(8)
      .background(
        RoundedRectangle(cornerRadius: 9, style: .continuous)
          .fill(AppTheme.cardBackground)
          .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
              .stroke(AppTheme.cardBorder, lineWidth: 0.5)
          )
      )

    default:
      EmptyView()
    }
  }
}

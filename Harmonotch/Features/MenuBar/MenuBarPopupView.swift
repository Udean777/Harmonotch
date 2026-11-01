import AppKit
import ServiceManagement
import SwiftUI

struct MenuBarPopupView: View {
  var onClose: () -> Void

  @ObservedObject var notchVM = NotchViewModel.shared
  @ObservedObject var notchWindowController = NotchWindowController.shared
  @ObservedObject var prayerManager = PrayerManager.shared
  @ObservedObject var adzanPlayer = AdzanPlayer.shared
  @ObservedObject var mediaManager = MediaManager.shared
  @ObservedObject var clamshellManager = ClamshellManager.shared
  @ObservedObject var languageManager = LanguageManager.shared
  @ObservedObject var themeManager = ThemeManager.shared
  @ObservedObject var updateManager = UpdateManager.shared

  @State private var isLaunchAtLogin: Bool = (SMAppService.mainApp.status == .enabled)

  var body: some View {
    VStack(spacing: 8) {
      headerSection

      if shouldShowUpdateBanner {
        updateBannerSection
      }

      Divider()
        .background(AppTheme.divider)

      clamshellSection

      prayerSection

      if mediaManager.hasActiveTrack {
        mediaSection
      }

      notchActionsSection

      Divider()
        .background(AppTheme.divider)

      preferencesSection

      Divider()
        .background(AppTheme.divider)

      footerSection
    }
    .padding(12)
    .frame(width: 320)
    .background(
      ZStack {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .fill(Color.black)

        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .stroke(Color.white.opacity(0.12), lineWidth: 1)
      }
    )
    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
  }

  private var headerSection: some View {
    HStack(spacing: 10) {
      Group {
        if let nsImage = NSImage(named: "AppLogo") ?? NSImage(named: NSImage.applicationIconName)
          ?? NSApplication.shared.applicationIconImage
        {
          Image(nsImage: nsImage)
            .resizable()
        } else {
          Image("AppLogo")
            .resizable()
        }
      }
      .aspectRatio(contentMode: .fit)
      .frame(width: 26, height: 26)
      .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 6, style: .continuous)
          .stroke(Color.white.opacity(0.15), lineWidth: 0.8)
      )

      HStack(spacing: 5) {
        Text("Harmonotch")
          .font(.system(size: 13, weight: .bold))
          .foregroundColor(AppTheme.textPrimary)

        if updateManager.hasUpdate {
          Image(systemName: "sparkles")
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(AppTheme.accentAmber)
        }
      }

      Spacer()

      Button(action: onClose) {
        Image(systemName: "xmark.circle.fill")
          .font(.system(size: 14))
          .foregroundColor(AppTheme.textTertiary)
      }
      .buttonStyle(.plain)
    }
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
          .fill(Color.white.opacity(0.12))
          .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
              .stroke(Color.white.opacity(0.2), lineWidth: 0.8)
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
            .foregroundColor(.green)

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
          .fill(Color.white.opacity(0.08))
          .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
              .stroke(Color.white.opacity(0.18), lineWidth: 0.8)
          )
      )

    case .failed(let message):
      HStack(spacing: 8) {
        Image(systemName: "exclamationmark.circle.fill")
          .font(.system(size: 14))
          .foregroundColor(.orange)

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

  private var clamshellSection: some View {
    VStack(spacing: 6) {
      HStack(spacing: 8) {
        ZStack {
          RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(AppTheme.badgeBackground)
            .frame(width: 28, height: 28)

          Image(systemName: "display.2")
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(clamshellAccentColor)
        }

        VStack(alignment: .leading, spacing: 2) {
          HStack(spacing: 6) {
            Text(L10n.Clamshell.title)
              .font(.system(size: 11, weight: .bold))
              .foregroundColor(AppTheme.textPrimary)

            HStack(spacing: 3) {
              Image(systemName: clamshellStatusIcon)
                .font(.system(size: 7, weight: .bold))
              Text(clamshellStatusTitle)
                .font(.system(size: 8, weight: .bold))
            }
            .foregroundColor(clamshellAccentColor)
            .padding(.horizontal, 5)
            .padding(.vertical, 1.5)
            .background(
              Capsule()
                .fill(clamshellAccentColor.opacity(0.14))
            )
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

        Spacer()

        Toggle("", isOn: $clamshellManager.isArmed)
          .toggleStyle(.switch)
          .labelsHidden()
          .scaleEffect(0.78)
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
  }

  private var clamshellAccentColor: Color {
    switch clamshellManager.currentState {
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

  private var clamshellStatusIcon: String {
    switch clamshellManager.currentState {
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

  private var clamshellStatusTitle: String {
    switch clamshellManager.currentState {
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

  private var prayerSection: some View {
    VStack(spacing: 6) {
      HStack(spacing: 8) {
        ZStack {
          RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(AppTheme.badgeBackground)
            .frame(width: 28, height: 28)

          Image(systemName: "moon.stars.fill")
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(AppTheme.accentAmber)
        }

        VStack(alignment: .leading, spacing: 2) {
          if let next = prayerManager.nextPrayerItem {
            HStack(spacing: 5) {
              Text(L10n.Menu.nextPrayer + ":")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(AppTheme.textSecondary)

              Text(next.name)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(AppTheme.textPrimary)

              Text(next.timeString)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(AppTheme.accentAmber)
            }

            let diff = next.time.timeIntervalSince(Date())
            if diff > 0 {
              let mins = Int(diff / 60)
              Text("\(mins / 60)h \(mins % 60)m")
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(AppTheme.textTertiary)
            }
          } else {
            Text(L10n.Drawer.prayerTab)
              .font(.system(size: 11, weight: .bold))
              .foregroundColor(AppTheme.textPrimary)
          }
        }

        Spacer()

        HStack(spacing: 4) {
          Button(action: {
            if adzanPlayer.isPlaying {
              adzanPlayer.stop()
            } else {
              adzanPlayer.testPlay()
            }
          }) {
            Image(systemName: adzanPlayer.isPlaying ? "stop.fill" : "play.fill")
              .font(.system(size: 10, weight: .bold))
              .foregroundColor(adzanPlayer.isPlaying ? AppTheme.accentRed : AppTheme.accentGreen)
              .frame(width: 24, height: 24)
              .background(AppTheme.badgeBackground)
              .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
              .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                  .stroke(AppTheme.cardBorder, lineWidth: 0.5)
              )
          }
          .buttonStyle(.plain)

          Button(action: {
            adzanPlayer.isMuted.toggle()
          }) {
            Image(systemName: adzanPlayer.isMuted ? "bell.slash.fill" : "bell.fill")
              .font(.system(size: 10, weight: .bold))
              .foregroundColor(adzanPlayer.isMuted ? AppTheme.accentRed : AppTheme.accentAmber)
              .frame(width: 24, height: 24)
              .background(AppTheme.badgeBackground)
              .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
              .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                  .stroke(AppTheme.cardBorder, lineWidth: 0.5)
              )
          }
          .buttonStyle(.plain)
        }
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
  }

  private var mediaSection: some View {
    HStack(spacing: 8) {
      ZStack {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
          .fill(AppTheme.badgeBackground)
          .frame(width: 26, height: 26)

        Image(systemName: "music.note")
          .font(.system(size: 11, weight: .semibold))
          .foregroundColor(AppTheme.accentCyan)
      }

      VStack(alignment: .leading, spacing: 1) {
        Text(mediaManager.trackTitle)
          .font(.system(size: 10, weight: .bold))
          .foregroundColor(AppTheme.textPrimary)
          .lineLimit(1)

        Text(mediaManager.artistName.isEmpty ? L10n.Media.nowPlaying : mediaManager.artistName)
          .font(.system(size: 9, weight: .regular))
          .foregroundColor(AppTheme.textSecondary)
          .lineLimit(1)
      }

      Spacer()

      Button(action: {
        mediaManager.playPause()
      }) {
        Image(systemName: mediaManager.isPlaying ? "pause.fill" : "play.fill")
          .font(.system(size: 10, weight: .bold))
          .foregroundColor(mediaManager.isPlaying ? AppTheme.accentAmber : AppTheme.accentGreen)
          .frame(width: 24, height: 24)
          .background(AppTheme.badgeBackground)
          .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
          .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
              .stroke(AppTheme.cardBorder, lineWidth: 0.5)
          )
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
  }

  private var notchActionsSection: some View {
    HStack(spacing: 8) {
      Button(action: {
        notchVM.toggleExpanded()
      }) {
        HStack(spacing: 5) {
          Image(
            systemName: notchVM.isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill"
          )
          .font(.system(size: 10, weight: .semibold))
          .foregroundColor(AppTheme.accentCyan)

          Text(notchVM.isExpanded ? L10n.Menu.closeDrawer : L10n.Menu.openDrawer)
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(AppTheme.textPrimary)
            .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(AppTheme.badgeBackground)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay(
          RoundedRectangle(cornerRadius: 7, style: .continuous)
            .stroke(AppTheme.cardBorder, lineWidth: 0.5)
        )
      }
      .buttonStyle(.plain)

      Button(action: {
        notchWindowController.toggleNotchHidden()
      }) {
        HStack(spacing: 5) {
          Image(systemName: notchWindowController.isNotchHidden ? "eye.fill" : "eye.slash.fill")
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(AppTheme.accentAmber)

          Text(notchWindowController.isNotchHidden ? L10n.Menu.showNotch : L10n.Menu.hideNotch)
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(AppTheme.textPrimary)
            .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(AppTheme.badgeBackground)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay(
          RoundedRectangle(cornerRadius: 7, style: .continuous)
            .stroke(AppTheme.cardBorder, lineWidth: 0.5)
        )
      }
      .buttonStyle(.plain)
    }
  }

  private var preferencesSection: some View {
    VStack(spacing: 6) {
      HStack(spacing: 6) {
        HStack(spacing: 4) {
          Image(systemName: "globe")
            .font(.system(size: 9))
            .foregroundColor(AppTheme.textSecondary)
          Text(L10n.Menu.languageMenu)
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(AppTheme.textSecondary)
        }

        Spacer()

        HStack(spacing: 2) {
          ForEach(AppLanguage.allCases) { lang in
            Button(action: {
              languageManager.currentLanguage = lang
            }) {
              Text(lang.displayName)
                .font(
                  .system(
                    size: 9, weight: languageManager.currentLanguage == lang ? .bold : .medium)
                )
                .foregroundColor(
                  languageManager.currentLanguage == lang ? Color.black : AppTheme.textSecondary
                )
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(
                  Capsule()
                    .fill(
                      languageManager.currentLanguage == lang ? AppTheme.accentCyan : Color.clear)
                )
            }
            .buttonStyle(.plain)
          }
        }
        .padding(2)
        .background(
          Capsule()
            .fill(AppTheme.badgeBackground)
        )
      }

      HStack(spacing: 6) {
        HStack(spacing: 4) {
          Image(systemName: "arrow.up.forward.app")
            .font(.system(size: 9))
            .foregroundColor(AppTheme.textSecondary)
          Text(L10n.Menu.launchAtLogin)
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(AppTheme.textSecondary)
        }

        Spacer()

        Toggle("", isOn: $isLaunchAtLogin)
          .toggleStyle(.switch)
          .labelsHidden()
          .scaleEffect(0.68)
          .onChange(of: isLaunchAtLogin) { _, newValue in
            do {
              if newValue {
                try SMAppService.mainApp.register()
              } else {
                try SMAppService.mainApp.unregister()
              }
            } catch {
              isLaunchAtLogin = (SMAppService.mainApp.status == .enabled)
            }
          }
      }

      HStack(spacing: 6) {
        HStack(spacing: 4) {
          Image(systemName: "face.smiling")
            .font(.system(size: 9))
            .foregroundColor(AppTheme.textSecondary)
          Text(L10n.Menu.companionToggle)
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(AppTheme.textSecondary)
        }

        Spacer()

        Toggle("", isOn: $notchVM.isCompanionEnabled)
          .toggleStyle(.switch)
          .labelsHidden()
          .scaleEffect(0.68)
      }
    }
  }

  private var footerSection: some View {
    HStack(spacing: 8) {
      Text("v\(updateManager.currentVersion)")
        .font(.system(size: 9, weight: .semibold, design: .rounded))
        .foregroundColor(AppTheme.textTertiary)

      Spacer()

      Button(action: {
        updateManager.checkForUpdates(isUserInitiated: true)
      }) {
        Image(systemName: "arrow.clockwise")
          .font(.system(size: 10, weight: .medium))
          .foregroundColor(AppTheme.textSecondary)
      }
      .buttonStyle(.plain)
      .help(L10n.Menu.checkForUpdates)

      Button(action: {
        AboutWindowController.shared.show()
      }) {
        Image(systemName: "info.circle")
          .font(.system(size: 10, weight: .medium))
          .foregroundColor(AppTheme.textSecondary)
      }
      .buttonStyle(.plain)
      .help(L10n.Menu.aboutHarmonotch)

      Button(action: {
        NSApplication.shared.terminate(nil)
      }) {
        Image(systemName: "power")
          .font(.system(size: 10, weight: .bold))
          .foregroundColor(AppTheme.textSecondary)
      }
      .buttonStyle(.plain)
      .help(L10n.Menu.quit)
    }
  }
}

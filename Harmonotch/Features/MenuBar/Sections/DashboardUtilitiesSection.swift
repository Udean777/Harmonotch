import AppKit
import ServiceManagement
import SwiftUI

struct DashboardUtilitiesSection: View {
  @ObservedObject private var notchVM = NotchViewModel.shared
  @ObservedObject private var notchWindowController = NotchWindowController.shared
  @ObservedObject private var mediaManager = MediaManager.shared
  @ObservedObject private var clamshellManager = ClamshellManager.shared
  @ObservedObject private var languageManager = LanguageManager.shared
  @ObservedObject private var themeManager = ThemeManager.shared
  @State private var isLaunchAtLogin = (SMAppService.mainApp.status == .enabled)

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      clamshellCard

      if mediaManager.hasActiveTrack {
        mediaCard
      }

      HStack(spacing: 8) {
        notchDrawerButton
        notchVisibilityButton
      }

      DashboardCard {
        VStack(spacing: 7) {
          languageRow
          Divider().background(AppTheme.divider)
          launchAtLoginRow
          Divider().background(AppTheme.divider)
          companionRow
        }
      }
    }
  }

  private var clamshellCard: some View {
    DashboardCard {
      HStack(spacing: 8) {
        ZStack {
          RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(AppTheme.badgeBackground)
            .frame(width: 28, height: 28)

          Image(systemName: "display.2")
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(clamshellAccentColor)
            .accessibilityHidden(true)
        }

        VStack(alignment: .leading, spacing: 2) {
          HStack(spacing: 6) {
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

        if !clamshellManager.isSudoConfigured {
          Button {
            clamshellManager.setupPasswordlessSudo { _ in }
          } label: {
            HStack(spacing: 3) {
              Image(systemName: "key.fill")
                .font(.system(size: 8.5))
              Text(
                clamshellManager.isPerformingSetup
                  ? L10n.Clamshell.authorizing : L10n.Clamshell.setupPermission
              )
              .font(.system(size: 9, weight: .semibold))
              .lineLimit(1)
            }
            .foregroundColor(AppTheme.accentCyan)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(AppTheme.accentCyan.opacity(0.14)))
          }
          .buttonStyle(.plain)
          .disabled(clamshellManager.isPerformingSetup)
          .accessibilityLabel(L10n.Clamshell.setupPermission)
        }

        Toggle("", isOn: $clamshellManager.isArmed)
          .toggleStyle(.switch)
          .labelsHidden()
          .scaleEffect(0.75)
          .accessibilityLabel(L10n.Menu.clamshellToggle)
      }
    }
  }

  private var mediaCard: some View {
    DashboardCard {
      VStack(spacing: 8) {
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
                  .font(.system(size: 12, weight: .semibold))
                  .foregroundColor(AppTheme.accentCyan)
              }
            }
          }
          .accessibilityHidden(true)

          VStack(alignment: .leading, spacing: 1) {
            Text(mediaManager.trackTitle)
              .font(.system(size: 11, weight: .bold))
              .foregroundColor(AppTheme.textPrimary)
              .lineLimit(1)

            Text(mediaManager.artistName.isEmpty ? L10n.Media.nowPlaying : mediaManager.artistName)
              .font(.system(size: 9.5, weight: .regular))
              .foregroundColor(AppTheme.textSecondary)
              .lineLimit(1)
          }

          Spacer(minLength: 4)

          HStack(spacing: 4) {
            Button(action: {
              mediaManager.previousTrack()
            }) {
              Image(systemName: "backward.fill")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(AppTheme.textPrimary)
                .frame(width: 24, height: 24)
                .background(AppTheme.badgeBackground)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                  RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(AppTheme.cardBorder, lineWidth: 0.5)
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.Media.previousTrack)

            Button(action: {
              mediaManager.playPause()
            }) {
              Image(systemName: mediaManager.isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(mediaManager.isPlaying ? AppTheme.accentAmber : AppTheme.accentGreen)
                .frame(width: 26, height: 26)
                .background(AppTheme.badgeBackground)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                  RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(AppTheme.cardBorder, lineWidth: 0.5)
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(mediaManager.isPlaying ? L10n.Media.pause : L10n.Media.play)

            Button(action: {
              mediaManager.nextTrack()
            }) {
              Image(systemName: "forward.fill")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(AppTheme.textPrimary)
                .frame(width: 24, height: 24)
                .background(AppTheme.badgeBackground)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                  RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(AppTheme.cardBorder, lineWidth: 0.5)
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.Media.nextTrack)
          }
        }

        if mediaManager.duration > 0 {
          HStack(spacing: 6) {
            Text(mediaManager.formattedPosition)
              .font(.system(size: 8.5, weight: .medium, design: .monospaced))
              .monospacedDigit()
              .foregroundColor(AppTheme.textTertiary)

            GeometryReader { geo in
              ZStack(alignment: .leading) {
                Capsule()
                  .fill(AppTheme.cardBorder)
                  .frame(height: 4)

                Capsule()
                  .fill(AppTheme.accentCyan)
                  .frame(width: max(4, geo.size.width * CGFloat(mediaManager.progress)), height: 4)
              }
              .contentShape(Rectangle())
              .gesture(
                DragGesture(minimumDistance: 0)
                  .onEnded { value in
                    let pct = max(0.0, min(1.0, Double(value.location.x / geo.size.width)))
                    let targetSeconds = pct * mediaManager.duration
                    mediaManager.seek(to: targetSeconds)
                  }
              )
            }
            .frame(height: 4)

            Text(mediaManager.formattedDuration)
              .font(.system(size: 8.5, weight: .medium, design: .monospaced))
              .monospacedDigit()
              .foregroundColor(AppTheme.textTertiary)
          }
          .accessibilityElement(children: .ignore)
          .accessibilityLabel("Playback progress: \(mediaManager.formattedPosition) of \(mediaManager.formattedDuration)")
        }
      }
    }
  }

  private var notchDrawerButton: some View {
    Button(action: {
      notchVM.toggleExpanded()
    }) {
      HStack(spacing: 5) {
        Image(
          systemName: notchVM.isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill"
        )
        .font(.system(size: 10, weight: .semibold))
        .foregroundColor(AppTheme.accentCyan)
        .accessibilityHidden(true)

        Text(notchVM.isExpanded ? L10n.Menu.closeDrawer : L10n.Menu.openDrawer)
          .font(.system(size: 10, weight: .semibold))
          .foregroundColor(AppTheme.textPrimary)
          .lineLimit(1)
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 7)
      .background(
        RoundedRectangle(cornerRadius: 8, style: .continuous)
          .fill(AppTheme.cardBackground)
          .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
              .stroke(AppTheme.cardBorder, lineWidth: 0.6)
          )
      )
    }
    .buttonStyle(.plain)
    .accessibilityLabel(notchVM.isExpanded ? L10n.Menu.closeDrawer : L10n.Menu.openDrawer)
  }

  private var notchVisibilityButton: some View {
    Button(action: {
      notchWindowController.toggleNotchHidden()
    }) {
      HStack(spacing: 5) {
        Image(
          systemName: notchWindowController.isNotchHidden ? "eye.fill" : "eye.slash.fill"
        )
        .font(.system(size: 10, weight: .semibold))
        .foregroundColor(AppTheme.accentAmber)
        .accessibilityHidden(true)

        Text(
          notchWindowController.isNotchHidden
            ? L10n.Menu.showNotch : L10n.Menu.hideNotch
        )
        .font(.system(size: 10, weight: .semibold))
        .foregroundColor(AppTheme.textPrimary)
        .lineLimit(1)
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 7)
      .background(
        RoundedRectangle(cornerRadius: 8, style: .continuous)
          .fill(AppTheme.cardBackground)
          .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
              .stroke(AppTheme.cardBorder, lineWidth: 0.6)
          )
      )
    }
    .buttonStyle(.plain)
    .accessibilityLabel(notchWindowController.isNotchHidden ? L10n.Menu.showNotch : L10n.Menu.hideNotch)
  }

  private var languageRow: some View {
    HStack(spacing: 6) {
      HStack(spacing: 5) {
        Image(systemName: "globe")
          .font(.system(size: 9.5))
          .foregroundColor(AppTheme.textSecondary)
          .accessibilityHidden(true)
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
                .system(size: 9, weight: languageManager.currentLanguage == lang ? .bold : .medium)
              )
              .foregroundColor(
                languageManager.currentLanguage == lang
                  ? (themeManager.isDarkMode ? Color.black : Color.white) : AppTheme.textSecondary
              )
              .padding(.horizontal, 8)
              .padding(.vertical, 3)
              .background(
                Capsule()
                  .fill(languageManager.currentLanguage == lang ? AppTheme.accentCyan : Color.clear)
              )
          }
          .buttonStyle(.plain)
          .accessibilityLabel(lang.displayName)
        }
      }
      .padding(2)
      .background(Capsule().fill(AppTheme.badgeBackground))
    }
  }

  private var launchAtLoginRow: some View {
    HStack(spacing: 6) {
      HStack(spacing: 5) {
        Image(systemName: "arrow.up.forward.app")
          .font(.system(size: 9.5))
          .foregroundColor(AppTheme.textSecondary)
          .accessibilityHidden(true)
        Text(L10n.Menu.launchAtLogin)
          .font(.system(size: 10, weight: .medium))
          .foregroundColor(AppTheme.textSecondary)
      }

      Spacer()

      Toggle("", isOn: $isLaunchAtLogin)
        .toggleStyle(.switch)
        .labelsHidden()
        .scaleEffect(0.72)
        .accessibilityLabel(L10n.Menu.launchAtLogin)
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
  }

  private var companionRow: some View {
    HStack(spacing: 6) {
      HStack(spacing: 5) {
        Image(systemName: "face.smiling")
          .font(.system(size: 9.5))
          .foregroundColor(AppTheme.textSecondary)
          .accessibilityHidden(true)
        Text(L10n.Menu.companionToggle)
          .font(.system(size: 10, weight: .medium))
          .foregroundColor(AppTheme.textSecondary)
      }

      Spacer()

      Toggle("", isOn: $notchVM.isCompanionEnabled)
        .toggleStyle(.switch)
        .labelsHidden()
        .scaleEffect(0.72)
        .accessibilityLabel(L10n.Menu.companionToggle)
    }
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
}

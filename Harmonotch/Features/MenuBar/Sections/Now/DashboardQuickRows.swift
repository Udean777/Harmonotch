import AppKit
import SwiftUI

struct AdzanBannerRow: View {
  @ObservedObject private var adzanPlayer = AdzanPlayer.shared

  var body: some View {
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
}

struct MediaQuickRow: View {
  @ObservedObject private var mediaManager = MediaManager.shared

  var body: some View {
    DashboardCard {
      HStack(spacing: 8) {
        Group {
          if let art = mediaManager.artworkImage {
            Image(nsImage: art)
              .resizable()
              .aspectRatio(contentMode: .fill)
              .frame(width: 28, height: 28)
              .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
          } else if let appIcon = mediaManager.presentation?.app.appIcon {
            ZStack {
              RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(AppTheme.badgeBackground)
                .frame(width: 28, height: 28)

              Image(nsImage: appIcon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 20, height: 20)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            }
          } else {
            ZStack {
              RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(AppTheme.badgeBackground)
                .frame(width: 28, height: 28)

              Image(systemName: mediaManager.presentation?.app.iconSymbolName ?? mediaManager.mediaSource.iconName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(AppTheme.accentCyan)
            }
          }
        }
        .accessibilityHidden(true)

        VStack(alignment: .leading, spacing: 1) {
          Text(mediaManager.presentation?.hasMetadata == true ? mediaManager.trackTitle : L10n.Media.audioPlaying)
            .font(.system(size: 10.5, weight: .bold))
            .foregroundColor(AppTheme.textPrimary)
            .lineLimit(1)

          Text(mediaManager.presentation?.hasMetadata == true
            ? (mediaManager.artistName.isEmpty ? L10n.Media.nowPlaying : mediaManager.artistName)
            : (mediaManager.presentation?.app.displayName ?? ""))
            .font(.system(size: 9, weight: .medium))
            .foregroundColor(AppTheme.textSecondary)
            .lineLimit(1)
        }

        Spacer(minLength: 4)

        HStack(spacing: 4) {
          if mediaManager.presentation?.capabilities.contains(.previousTrack) == true {
            mediaControlButton(icon: "backward.fill", label: L10n.Media.previousTrack) {
              mediaManager.previousTrack()
            }
          }

          if mediaManager.presentation?.capabilities.contains(.playPause) == true {
            mediaControlButton(
              icon: mediaManager.isPlaying ? "pause.fill" : "play.fill",
              color: mediaManager.isPlaying ? AppTheme.accentAmber : AppTheme.accentGreen,
              label: mediaManager.isPlaying ? L10n.Media.pause : L10n.Media.play
            ) {
              mediaManager.playPause()
            }
          }

          if mediaManager.presentation?.capabilities.contains(.nextTrack) == true {
            mediaControlButton(icon: "forward.fill", label: L10n.Media.nextTrack) {
              mediaManager.nextTrack()
            }
          }

          if mediaManager.presentation?.capabilities.contains(.openApp) == true && mediaManager.presentation?.hasMetadata == false {
            mediaControlButton(icon: "arrow.up.forward.app", label: L10n.Media.openApp(mediaManager.presentation?.app.displayName ?? "")) {
              mediaManager.openActiveApp()
            }
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
}

struct VolumeHUDQuickRow: View {
  @ObservedObject private var volumeHUD = VolumeHUDController.shared

  var body: some View {
    DashboardCard {
      HStack(spacing: 8) {
        ZStack {
          RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(AppTheme.badgeBackground)
            .frame(width: 28, height: 28)

          Image(
            systemName: volumeHUD.isEnabled
              ? (volumeHUD.isTapActive ? "speaker.wave.2.fill" : "exclamationmark.triangle.fill")
              : "speaker.wave.2"
          )
          .font(.system(size: 11, weight: .semibold))
          .foregroundColor(
            volumeHUD.isEnabled
              ? (volumeHUD.isTapActive ? AppTheme.accentGreen : AppTheme.accentAmber)
              : AppTheme.textTertiary
          )
        }
        .accessibilityHidden(true)

        VStack(alignment: .leading, spacing: 1) {
          Text(L10n.Menu.volumeHUDToggle)
            .font(.system(size: 10.5, weight: .bold))
            .foregroundColor(AppTheme.textPrimary)
            .lineLimit(1)

          Text(
            volumeHUD.isEnabled
              ? (volumeHUD.isTapActive
                ? L10n.Volume.statusActive
                : L10n.Volume.statusNeedsPermission)
              : L10n.Volume.statusDisabled
          )
          .font(.system(size: 9, weight: .medium))
          .foregroundColor(
            volumeHUD.isEnabled && !volumeHUD.isTapActive
              ? AppTheme.accentAmber
              : AppTheme.textSecondary
          )
          .lineLimit(1)
        }

        Spacer(minLength: 4)

        if volumeHUD.isEnabled && !volumeHUD.isAccessibilityGranted {
          Button {
            VolumeHUDController.openAccessibilitySettings()
          } label: {
            Text(L10n.Volume.grantPermissionAction)
              .font(.system(size: 9.5, weight: .bold))
              .foregroundColor(Color.black)
              .padding(.horizontal, 8)
              .padding(.vertical, 4)
              .background(Capsule().fill(AppTheme.accentAmber))
          }
          .buttonStyle(.plain)
        }

        Toggle(
          "",
          isOn: Binding(
            get: { volumeHUD.isEnabled },
            set: { volumeHUD.setEnabled($0, promptIfUntrusted: true) }
          )
        )
        .labelsHidden()
        .toggleStyle(.switch)
        .controlSize(.mini)
      }
    }
  }
}

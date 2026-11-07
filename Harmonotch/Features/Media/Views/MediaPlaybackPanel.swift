import AppKit
import SwiftUI

extension MediaDrawerView {
  // MARK: - Media Playback View

  var mediaPlaybackView: some View {
    VStack(spacing: 12) {
      HStack(alignment: .center, spacing: 14) {
        ZStack {
          if let art = mediaManager.artworkImage {
            Image(nsImage: art)
              .resizable()
              .aspectRatio(contentMode: .fill)
              .frame(width: 64, height: 64)
              .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
          } else if let appIcon = mediaManager.presentation?.app.appIcon {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
              .fill(AppTheme.badgeBackground)
              .frame(width: 64, height: 64)
              .overlay(
                Image(nsImage: appIcon)
                  .resizable()
                  .aspectRatio(contentMode: .fit)
                  .frame(width: 48, height: 48)
                  .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
              )
          } else {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
              .fill(Color(red: 0.12, green: 0.12, blue: 0.12))
              .frame(width: 64, height: 64)
              .overlay(
                Image(systemName: mediaManager.presentation?.app.iconSymbolName ?? mediaManager.mediaSource.iconName)
                  .font(.system(size: 26))
                  .foregroundColor(.white.opacity(0.85))
              )
          }
        }
        .overlay(
          RoundedRectangle(cornerRadius: 12, style: .continuous)
            .stroke(Color.white.opacity(0.14), lineWidth: 0.8)
        )

        VStack(alignment: .leading, spacing: 3) {
          HStack(spacing: 5) {
            Image(systemName: mediaManager.presentation?.app.iconSymbolName ?? mediaManager.mediaSource.iconName)
              .font(.system(size: 9.5, weight: .semibold))
            Text(mediaManager.presentation?.app.displayName ?? mediaManager.mediaSource.rawValue)
              .font(.system(size: 9.5, weight: .semibold))

            if mediaManager.isPlaying {
              Image(systemName: "waveform")
                .font(.system(size: 8.5))
                .symbolEffect(.variableColor.iterative.reversing)
                .foregroundColor(mediaAccentColor)
            }
          }
          .foregroundColor(AppTheme.textSecondary)
          .padding(.horizontal, 6)
          .padding(.vertical, 2.5)
          .background(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
              .fill(AppTheme.badgeBackground)
          )

          Text(mediaManager.trackTitle)
            .font(.system(size: 15, weight: .bold, design: .rounded))
            .foregroundColor(AppTheme.textPrimary)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
            .id(mediaManager.trackTitle)
            .transition(.opacity)

          Text(mediaManager.artistName.isEmpty ? L10n.Media.nowPlaying : mediaManager.artistName)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(AppTheme.textSecondary)
            .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        HStack(spacing: 10) {
          if mediaManager.presentation?.capabilities.contains(.previousTrack) ?? true {
            Button(action: {
              mediaManager.previousTrack()
            }) {
              Image(systemName: "backward.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(mediaAccentColor)
                .frame(width: 34, height: 34)
                .background(AppTheme.badgeBackground)
                .clipShape(Circle())
                .overlay(Circle().stroke(AppTheme.cardBorder, lineWidth: 0.6))
            }
            .buttonStyle(.plain)
          }

          if mediaManager.presentation?.capabilities.contains(.playPause) ?? true {
            Button(action: {
              mediaManager.playPause()
            }) {
              Image(systemName: mediaManager.isPlaying ? "pause.fill" : "play.fill")
                .contentTransition(.symbolEffect(.replace))
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.black)
                .frame(width: 42, height: 42)
                .background(mediaAccentColor)
                .clipShape(Circle())
                .shadow(color: Color.black.opacity(AppTheme.isDark ? 0.35 : 0.12), radius: 2.5, x: 0, y: 1.5)
            }
            .buttonStyle(.plain)
          }

          if mediaManager.presentation?.capabilities.contains(.nextTrack) ?? true {
            Button(action: {
              mediaManager.nextTrack()
            }) {
              Image(systemName: "forward.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(mediaAccentColor)
                .frame(width: 34, height: 34)
                .background(AppTheme.badgeBackground)
                .clipShape(Circle())
                .overlay(Circle().stroke(AppTheme.cardBorder, lineWidth: 0.6))
            }
            .buttonStyle(.plain)
          }
        }

        HStack(spacing: 8) {
          Button(action: {
            selectPanel(.lyrics)
          }) {
            Image(systemName: isLyricsShown ? "text.quote" : "text.bubble")
              .font(.system(size: 11, weight: .semibold))
              .foregroundColor(isLyricsShown ? AppTheme.accentCyan : AppTheme.textSecondary)
              .frame(width: 32, height: 32)
              .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                  .fill(isLyricsShown ? AppTheme.accentCyan.opacity(0.15) : AppTheme.badgeBackground)
              )
              .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                  .stroke(isLyricsShown ? AppTheme.accentCyan.opacity(0.5) : AppTheme.cardBorder, lineWidth: 0.5)
              )
          }
          .buttonStyle(.plain)
          .help(isLyricsShown ? L10n.Media.hideLyrics : L10n.Media.showLyrics)

          Button(action: {
            selectPanel(.queue)
          }) {
            Image(systemName: isQueueShown ? "list.below.rectangle" : "list.number")
              .font(.system(size: 11, weight: .semibold))
              .foregroundColor(isQueueShown ? AppTheme.accentCyan : AppTheme.textSecondary)
              .frame(width: 32, height: 32)
              .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                  .fill(isQueueShown ? AppTheme.accentCyan.opacity(0.15) : AppTheme.badgeBackground)
              )
              .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                  .stroke(isQueueShown ? AppTheme.accentCyan.opacity(0.5) : AppTheme.cardBorder, lineWidth: 0.5)
              )
          }
          .buttonStyle(.plain)
          .help(isQueueShown ? L10n.Media.hideQueue : L10n.Media.showQueue)
        }
      }

      HStack(spacing: 8) {
        Text(mediaManager.formattedPosition)
          .font(.system(size: 9.5, weight: .medium, design: .monospaced))
          .monospacedDigit()
          .foregroundColor(AppTheme.textTertiary)

        GeometryReader { geo in
          ZStack(alignment: .leading) {
            Capsule()
              .fill(AppTheme.cardBorder)
              .frame(height: 5)

            Capsule()
              .fill(mediaAccentColor)
              .frame(width: max(5, geo.size.width * CGFloat(mediaManager.progress)), height: 5)
          }
        }
        .frame(height: 5)

        Text(mediaManager.formattedDuration)
          .font(.system(size: 9.5, weight: .medium, design: .monospaced))
          .monospacedDigit()
          .foregroundColor(AppTheme.textTertiary)
      }

      switch activePanel {
      case .some(.lyrics):
        lyricsContent.transition(NotchMotion.drawer)
      case .some(.queue):
        queueContent.transition(NotchMotion.drawer)
      case .none:
        EmptyView()
      }
    }
  }

  // MARK: - Audio Only Mode View

  func audioOnlyPlaybackView(appInfo: MediaAppInfo) -> some View {
    VStack(spacing: 12) {
      HStack(alignment: .center, spacing: 14) {
        ZStack {
          if let appIcon = appInfo.appIcon {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
              .fill(AppTheme.badgeBackground)
              .frame(width: 64, height: 64)
              .overlay(
                Image(nsImage: appIcon)
                  .resizable()
                  .aspectRatio(contentMode: .fit)
                  .frame(width: 48, height: 48)
                  .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
              )
          } else {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
              .fill(AppTheme.badgeBackground)
              .frame(width: 64, height: 64)
              .overlay(
                Image(systemName: appInfo.iconSymbolName)
                  .font(.system(size: 26))
                  .foregroundColor(.white.opacity(0.85))
              )
          }
        }
        .overlay(
          RoundedRectangle(cornerRadius: 12, style: .continuous)
            .stroke(Color.white.opacity(0.14), lineWidth: 0.8)
        )

        VStack(alignment: .leading, spacing: 3) {
          HStack(spacing: 5) {
            Image(systemName: appInfo.iconSymbolName)
              .font(.system(size: 9.5, weight: .semibold))
            Text(appInfo.displayName)
              .font(.system(size: 9.5, weight: .semibold))

            if mediaManager.isPlaying {
              Image(systemName: "waveform")
                .font(.system(size: 8.5))
                .symbolEffect(.variableColor.iterative.reversing)
                .foregroundColor(mediaAccentColor)
            }
          }
          .foregroundColor(AppTheme.textSecondary)
          .padding(.horizontal, 6)
          .padding(.vertical, 2.5)
          .background(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
              .fill(AppTheme.badgeBackground)
          )

          Text(L10n.Media.audioPlaying)
            .font(.system(size: 15, weight: .bold, design: .rounded))
            .foregroundColor(AppTheme.textPrimary)
            .lineLimit(1)

          Text(appInfo.displayName)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(AppTheme.textSecondary)
            .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        HStack(spacing: 10) {
          if mediaManager.presentation?.capabilities.contains(.playPause) == true {
            Button(action: {
              mediaManager.playPause()
            }) {
              Image(systemName: mediaManager.isPlaying ? "pause.fill" : "play.fill")
                .contentTransition(.symbolEffect(.replace))
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.black)
                .frame(width: 38, height: 38)
                .background(mediaAccentColor)
                .clipShape(Circle())
                .shadow(color: Color.black.opacity(AppTheme.isDark ? 0.35 : 0.12), radius: 2.5, x: 0, y: 1.5)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(mediaManager.isPlaying ? L10n.Media.pause : L10n.Media.play)
          }

          Button(action: {
            mediaManager.openActiveApp()
          }) {
            HStack(spacing: 5) {
              Image(systemName: "arrow.up.forward.app")
                .font(.system(size: 11, weight: .semibold))
              Text(L10n.Media.openApp(appInfo.displayName))
                .font(.system(size: 11.5, weight: .semibold))
                .lineLimit(1)
            }
            .foregroundColor(AppTheme.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(AppTheme.badgeBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
              RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(AppTheme.cardBorder, lineWidth: 0.6)
            )
          }
          .buttonStyle(.plain)
          .accessibilityLabel(L10n.Media.openApp(appInfo.displayName))
        }
      }
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(L10n.Media.appPlayingAudio(appInfo.displayName))
  }
}

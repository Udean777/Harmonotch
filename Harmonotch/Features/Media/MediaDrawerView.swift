import AppKit
import SwiftUI

struct MediaDrawerView: View {
  @ObservedObject var mediaManager = MediaManager.shared
  @ObservedObject var adzanPlayer = AdzanPlayer.shared
  @ObservedObject var prayerManager = PrayerManager.shared
  @ObservedObject var languageManager = LanguageManager.shared

  private enum MediaPanel: Equatable {
    case lyrics
    case queue
  }

  @State private var activePanel: MediaPanel?

  private var isLyricsShown: Bool { activePanel == .lyrics }
  private var isQueueShown: Bool { activePanel == .queue }

  private var mediaAccentColor: Color {
    mediaManager.artworkAccentColor.map(Color.init(nsColor:)) ?? .white
  }

  /// Whether lyrics are available for display (synced or plain text).
  private var lyricsAvailable: Bool {
    switch mediaManager.lyricsStatus {
    case .synced(let lines): return !lines.isEmpty
    case .unsynced(let lines): return !lines.isEmpty
    default: return false
    }
  }

  var body: some View {
    VStack(spacing: 8) {
      if adzanPlayer.isPlaying {
        prayerAudioView.transition(NotchMotion.drawer)
      } else if mediaManager.hasActiveTrack {
        mediaPlaybackView.transition(NotchMotion.drawer)
      } else {
        emptyAudioView.transition(NotchMotion.drawer)
      }
      if let hint = mediaManager.webMediaHint {
        webHintBanner(hint)
      }
    }
    .frame(width: NotchLayout.expandedContentWidth, alignment: .top)
    .animation(NotchMotion.content, value: mediaManager.hasActiveTrack)
    .animation(NotchMotion.content, value: adzanPlayer.isPlaying)
    .animation(NotchMotion.fade, value: mediaManager.trackTitle)
    .animation(NotchMotion.fade, value: mediaManager.artworkImage != nil)
    .animation(NotchMotion.quick, value: mediaManager.isPlaying)
    .animation(NotchMotion.content, value: activePanel)
    .onAppear {
      mediaManager.pollCurrentMediaState()
      autoShowLyricsIfAvailable()
    }
    .onChange(of: mediaManager.trackTitle) { _, _ in
      autoShowLyricsIfAvailable()
    }
  }

  private func autoShowLyricsIfAvailable() {
    // Auto-select lyrics only if user hasn't chosen a panel yet.
    if activePanel == nil && lyricsAvailable {
      activePanel = .lyrics
    }
  }

  private func selectPanel(_ panel: MediaPanel) {
    withAnimation(NotchMotion.content) {
      activePanel = (activePanel == panel) ? nil : panel
    }
  }

  private func webHintBanner(_ hint: WebMediaProbeError) -> some View {
    let message: String
    switch hint {
    case .javascriptDisabled(let browser):
      message = L10n.Media.javascriptDisabledHint(browser: browser)
    case .automationDenied(let browser):
      message = L10n.Media.automationDeniedHint(browser: browser)
    }
    return HStack(spacing: 6) {
      Image(systemName: "exclamationmark.triangle.fill")
        .font(.system(size: 10, weight: .bold))
      Text(message)
        .font(.system(size: 10, weight: .medium))
        .lineLimit(2)
    }
    .foregroundColor(.white.opacity(0.85))
    .padding(.horizontal, 10)
    .padding(.vertical, 6)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.white.opacity(0.08))
    .cornerRadius(8)
  }

  // MARK: - Prayer Audio Mode View

  private var prayerAudioView: some View {
    VStack(spacing: 12) {
      HStack(alignment: .center, spacing: 14) {
        ZStack {
          RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(AppTheme.cardBackground)
            .frame(width: 56, height: 56)

          Image(systemName: "speaker.wave.3.fill")
            .font(.system(size: 22, weight: .bold))
            .foregroundColor(AppTheme.accentAmber)
        }
        .overlay(
          RoundedRectangle(cornerRadius: 12, style: .continuous)
            .stroke(AppTheme.cardBorder, lineWidth: 0.8)
        )

        VStack(alignment: .leading, spacing: 3) {
          HStack(spacing: 6) {
            Circle()
              .fill(AppTheme.accentAmber)
              .frame(width: 6, height: 6)

            Text(L10n.Prayer.audioAdzanTitle)
              .font(.system(size: 11, weight: .bold))
              .foregroundColor(AppTheme.accentAmber)
          }

          Text(L10n.Prayer.localizedPrayerName(adzanPlayer.playingPrayerName))
            .font(.system(size: 16, weight: .bold, design: .rounded))
            .foregroundColor(AppTheme.textPrimary)
            .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        HStack(spacing: 8) {
          Button(action: {
            adzanPlayer.isMuted.toggle()
          }) {
            Image(systemName: adzanPlayer.isMuted ? "bell.slash.fill" : "bell.fill")
              .font(.system(size: 13, weight: .semibold))
              .foregroundColor(adzanPlayer.isMuted ? AppTheme.textTertiary : AppTheme.accentAmber)
              .frame(width: 34, height: 34)
              .background(AppTheme.badgeBackground)
              .clipShape(Circle())
              .overlay(Circle().stroke(AppTheme.cardBorder, lineWidth: 0.6))
          }
          .buttonStyle(.plain)

          Button(action: {
            adzanPlayer.stop()
          }) {
            HStack(spacing: 5) {
              Image(systemName: "stop.fill")
                .font(.system(size: 11, weight: .bold))
              Text(L10n.Prayer.stop)
                .font(.system(size: 12, weight: .bold))
            }
            .foregroundColor(AppTheme.accentRed)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(AppTheme.accentRed.opacity(0.14))
            .cornerRadius(8)
            .overlay(
              RoundedRectangle(cornerRadius: 8).stroke(AppTheme.accentRed.opacity(0.3), lineWidth: 0.8))
          }
          .buttonStyle(.plain)
        }
      }

      HStack(spacing: 8) {
        ForEach(prayerManager.prayerItems) { item in
          PrayerCardView(item: item)
        }
      }
    }
  }

  // MARK: - Media Playback View

  private var mediaPlaybackView: some View {
    VStack(spacing: 12) {
      HStack(alignment: .center, spacing: 14) {
        ZStack {
          if let art = mediaManager.artworkImage {
            Image(nsImage: art)
              .resizable()
              .aspectRatio(contentMode: .fill)
              .frame(width: 64, height: 64)
              .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
          } else {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
              .fill(Color(red: 0.12, green: 0.12, blue: 0.12))
              .frame(width: 64, height: 64)
              .overlay(
                Image(systemName: mediaManager.mediaSource.iconName)
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
            Image(systemName: mediaManager.mediaSource.iconName)
              .font(.system(size: 9.5, weight: .semibold))
            Text(mediaManager.mediaSource.rawValue)
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

  /// Lyrics view: shows lyrics when available, sync button on failure,
  /// honest empty state when lyrics cannot be shown.
  @ViewBuilder
  private var lyricsContent: some View {
    VStack(alignment: .leading, spacing: 8) {
      switch mediaManager.lyricsStatus {
      case .synced(let lines):
        if lines.isEmpty {
          unavailableLyricsUI
        } else {
          ExpandedLyricsView(mediaAccentColor: mediaAccentColor)
        }

      case .unsynced(let lines):
        if lines.isEmpty {
          unavailableLyricsUI
        } else {
          ExpandedLyricsView(mediaAccentColor: mediaAccentColor)
        }

      case .loading:
        HStack(spacing: 8) {
          ProgressView()
            .controlSize(.small)
          Text(L10n.Media.loadingLyrics)
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(AppTheme.textSecondary)
          Spacer(minLength: 4)
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)

      case .instrumental:
        HStack(spacing: 10) {
          ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
              .fill(AppTheme.accentCyan.opacity(0.12))
              .frame(width: 28, height: 28)
            Image(systemName: "music.quarternote.3")
              .font(.system(size: 12, weight: .semibold))
              .foregroundColor(AppTheme.accentCyan)
          }
          VStack(alignment: .leading, spacing: 1.5) {
            Text(L10n.Media.instrumental)
              .font(.system(size: 11, weight: .bold, design: .rounded))
              .foregroundColor(AppTheme.textPrimary)
            Text(L10n.Media.instrumentalDesc)
              .font(.system(size: 9.5, weight: .medium))
              .foregroundColor(AppTheme.textSecondary)
              .lineLimit(2)
          }
          Spacer(minLength: 4)
        }
        .padding(.vertical, 6)

      case .unavailable, .idle:
        unavailableLyricsUI
      }
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 8)
    .background(
      RoundedRectangle(cornerRadius: 10, style: .continuous)
        .fill(AppTheme.cardBackground)
        .overlay(
          RoundedRectangle(cornerRadius: 10, style: .continuous)
            .stroke(AppTheme.cardBorder, lineWidth: 0.6)
        )
    )
  }

  /// Unavailable lyrics UI with sync button and honest message.
  @ViewBuilder
  private var unavailableLyricsUI: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 8) {
        Image(systemName: "exclamationmark.triangle.fill")
          .font(.system(size: 10, weight: .bold))
          .foregroundColor(AppTheme.accentAmber)
        Text(L10n.Media.lyricsNotFound)
          .font(.system(size: 10, weight: .medium))
          .foregroundColor(AppTheme.textSecondary)
      }

      Button(action: {
        mediaManager.refetchLyrics()
      }) {
        HStack(spacing: 5) {
          Image(systemName: "arrow.triangle.2.circlepath")
            .font(.system(size: 9, weight: .semibold))
          Text(L10n.Media.syncLyrics)
            .font(.system(size: 9.5, weight: .semibold))
        }
        .foregroundColor(mediaAccentColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
          RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(mediaAccentColor.opacity(0.15))
        )
        .overlay(
          RoundedRectangle(cornerRadius: 6, style: .continuous)
            .stroke(mediaAccentColor.opacity(0.5), lineWidth: 0.5)
        )
      }
      .buttonStyle(.plain)

      Text(L10n.Media.lyricsUnavailableDesc)
        .font(.system(size: 9, weight: .medium))
        .foregroundColor(AppTheme.textTertiary)
        .lineLimit(2)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(.vertical, 8)
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  /// Queue view: song list when present, empty UI when queue not found.
  @ViewBuilder
  private var queueContent: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 6) {
        Image(systemName: "list.number")
          .font(.system(size: 10, weight: .semibold))
          .foregroundColor(AppTheme.textSecondary)
        Text(L10n.Media.queueTitle)
          .font(.system(size: 11, weight: .bold, design: .rounded))
          .foregroundColor(AppTheme.textPrimary)
        Spacer(minLength: 4)
      }

      if mediaManager.queue.isEmpty {
        VStack(alignment: .leading, spacing: 6) {
          Image(systemName: "text.bubble")
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(AppTheme.textTertiary)
          Text(L10n.Media.queueEmpty)
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(AppTheme.textSecondary)
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
      } else {
        ForEach(Array(mediaManager.queue.enumerated()), id: \.element.id) { index, item in
          HStack(spacing: 8) {
            Text("\(index + 1)")
              .font(.system(size: 9.5, weight: .medium, design: .rounded))
              .foregroundColor(AppTheme.textTertiary)
              .frame(width: 16, alignment: .leading)

            VStack(alignment: .leading, spacing: 1) {
              Text(item.title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(AppTheme.textPrimary)
                .lineLimit(1)
              Text(item.artist.isEmpty ? L10n.Media.nowPlaying : item.artist)
                .font(.system(size: 8.5, weight: .medium))
                .foregroundColor(AppTheme.textSecondary)
                .lineLimit(1)
            }

            Spacer(minLength: 4)
          }
          .padding(.vertical, 3)
        }
      }
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 8)
    .background(
      RoundedRectangle(cornerRadius: 10, style: .continuous)
        .fill(AppTheme.cardBackground)
        .overlay(
          RoundedRectangle(cornerRadius: 10, style: .continuous)
            .stroke(AppTheme.cardBorder, lineWidth: 0.6)
        )
    )
  }

  private func prayerStatusBanner(next: PrayerScheduleItem) -> some View {
    HStack(spacing: 8) {
      Image(systemName: "moon.stars.fill")
        .font(.system(size: 10))
        .foregroundColor(.white)

      Text("\(next.name) • \(next.timeString)")
        .font(.system(size: 10.5, weight: .medium))
        .foregroundColor(AppTheme.textSecondary)

      Spacer(minLength: 4)

      Button(action: {
        adzanPlayer.isMuted.toggle()
      }) {
        HStack(spacing: 4) {
          Image(systemName: adzanPlayer.isMuted ? "bell.slash.fill" : "bell.fill")
            .font(.system(size: 9))
          Text(adzanPlayer.isMuted ? L10n.Prayer.adzanMuted : L10n.Prayer.adzanActive)
            .font(.system(size: 9.5, weight: .semibold))
        }
        .foregroundColor(adzanPlayer.isMuted ? AppTheme.textSecondary : AppTheme.textPrimary)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(AppTheme.badgeBackground)
        .cornerRadius(5)
      }
      .buttonStyle(.plain)
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 5)
    .background(
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .fill(AppTheme.cardBackground)
        .overlay(
          RoundedRectangle(cornerRadius: 8, style: .continuous)
            .stroke(AppTheme.cardBorder, lineWidth: 0.6)
        )
    )
  }

  // MARK: - Empty Audio Mode View

  private var emptyAudioView: some View {
    VStack(spacing: 14) {
      HStack(spacing: 12) {
        ZStack {
          Circle()
            .fill(AppTheme.badgeBackground)
            .frame(width: 44, height: 44)

          Image(systemName: "music.note")
            .font(.system(size: 18, weight: .semibold))
            .foregroundColor(AppTheme.textPrimary)
        }

        VStack(alignment: .leading, spacing: 3) {
          Text(L10n.Media.noTrackPlaying)
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(AppTheme.textPrimary)
            .lineLimit(1)

          Text(L10n.Media.openMusicPrompt)
            .font(.system(size: 11))
            .foregroundColor(AppTheme.textSecondary)
            .lineLimit(1)
        }

        Spacer(minLength: 4)
      }
    }
  }

  private func openApp(bundleIdentifier: String, fallbackUrl: String) {
    if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
      NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    } else if let url = URL(string: fallbackUrl) {
      NSWorkspace.shared.open(url)
    }
  }
}

// MARK: - Expanded Live Lyrics Stream View

struct ExpandedLyricsView: View {
  @ObservedObject var mediaManager = MediaManager.shared
  let mediaAccentColor: Color

  @State private var hoveredLineId: UUID? = nil
  @State private var isUserInteracting = false
  @State private var interactionResetTask: Task<Void, Never>? = nil

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      headerBar

      switch mediaManager.lyricsStatus {
      case .loading:
        loadingView
      case .instrumental:
        instrumentalView
      case .synced:
        if !mediaManager.syncedLyrics.isEmpty {
          syncedLyricsStream
        } else {
          unavailableLyricsView
        }
      case .unsynced:
        if !mediaManager.unsyncedLyrics.isEmpty {
          unsyncedLyricsStream
        } else {
          unavailableLyricsView
        }
      case .unavailable:
        unavailableLyricsView
      case .idle:
        if mediaManager.isLoadingLyrics {
          loadingView
        } else if !mediaManager.syncedLyrics.isEmpty {
          syncedLyricsStream
        } else if !mediaManager.unsyncedLyrics.isEmpty {
          unsyncedLyricsStream
        } else {
          unavailableLyricsView
        }
      }
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 6)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .fill(AppTheme.cardBackground)
        .overlay(
          RoundedRectangle(cornerRadius: 12, style: .continuous)
            .stroke(AppTheme.cardBorder, lineWidth: 0.6)
        )
    )
  }

  private var headerBar: some View {
    HStack(spacing: 4) {
      Image(systemName: "quote.bubble.fill")
        .font(.system(size: 9, weight: .bold))
        .foregroundColor(mediaAccentColor)

      Text(L10n.Media.syncedLyricsTitle.uppercased())
        .font(.system(size: 8.5, weight: .bold, design: .rounded))
        .tracking(0.4)
        .foregroundColor(AppTheme.textSecondary)

      statusBadge

      Spacer(minLength: 4)
    }
  }

  @ViewBuilder
  private var statusBadge: some View {
    switch mediaManager.lyricsStatus {
    case .synced:
      HStack(spacing: 3) {
        Circle()
          .fill(mediaAccentColor)
          .frame(width: 4.5, height: 4.5)
        Text(L10n.Media.syncedLyricsBadge.uppercased())
          .font(.system(size: 7.5, weight: .bold, design: .rounded))
      }
      .foregroundColor(mediaAccentColor)
      .padding(.horizontal, 5)
      .padding(.vertical, 1.5)
      .background(mediaAccentColor.opacity(0.12))
      .clipShape(Capsule())

    case .unsynced:
      HStack(spacing: 3) {
        Image(systemName: "text.alignleft")
          .font(.system(size: 7, weight: .bold))
        Text(L10n.Media.unsyncedLyricsBadge.uppercased())
          .font(.system(size: 7.5, weight: .bold, design: .rounded))
      }
      .foregroundColor(AppTheme.accentAmber)
      .padding(.horizontal, 5)
      .padding(.vertical, 1.5)
      .background(AppTheme.accentAmber.opacity(0.14))
      .clipShape(Capsule())

    case .instrumental:
      HStack(spacing: 3) {
        Image(systemName: "music.quarternote.3")
          .font(.system(size: 7, weight: .bold))
        Text(L10n.Media.instrumental.uppercased())
          .font(.system(size: 7.5, weight: .bold, design: .rounded))
      }
      .foregroundColor(AppTheme.accentCyan)
      .padding(.horizontal, 5)
      .padding(.vertical, 1.5)
      .background(AppTheme.accentCyan.opacity(0.12))
      .clipShape(Capsule())

    case .unavailable:
      HStack(spacing: 3) {
        Image(systemName: "nosign")
          .font(.system(size: 7, weight: .bold))
        Text(L10n.Media.noLyricsFound.uppercased())
          .font(.system(size: 7.5, weight: .bold, design: .rounded))
      }
      .foregroundColor(AppTheme.textTertiary)
      .padding(.horizontal, 5)
      .padding(.vertical, 1.5)
      .background(AppTheme.badgeBackground)
      .clipShape(Capsule())

    default:
      EmptyView()
    }
  }

  private var syncedLyricsStream: some View {
    ScrollViewReader { proxy in
      ScrollView(.vertical, showsIndicators: false) {
        LazyVStack(alignment: .leading, spacing: 3) {
          ForEach(Array(mediaManager.syncedLyrics.enumerated()), id: \.element.id) { index, line in
            let isActive = index == mediaManager.currentLyricIndex
            let isPast = index < mediaManager.currentLyricIndex
            let isHovered = hoveredLineId == line.id

            lyricLineRow(
              line: line,
              index: index,
              isActive: isActive,
              isPast: isPast,
              isHovered: isHovered
            )
            .id(line.id)
          }
        }
        .padding(.vertical, 8)
      }
      .frame(height: 120)
      .mask(
        LinearGradient(
          stops: [
            .init(color: .clear, location: 0.0),
            .init(color: .black, location: 0.16),
            .init(color: .black, location: 0.84),
            .init(color: .clear, location: 1.0)
          ],
          startPoint: .top,
          endPoint: .bottom
        )
      )
      .simultaneousGesture(
        DragGesture(minimumDistance: 1)
          .onChanged { _ in
            markUserInteraction()
          }
      )
      .onChange(of: mediaManager.currentLyricIndex) { _, newIndex in
        guard !isUserInteracting,
              newIndex >= 0 && newIndex < mediaManager.syncedLyrics.count else { return }
        let targetId = mediaManager.syncedLyrics[newIndex].id
        withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
          proxy.scrollTo(targetId, anchor: .center)
        }
      }
      .onAppear {
        if mediaManager.currentLyricIndex >= 0 && mediaManager.currentLyricIndex < mediaManager.syncedLyrics.count {
          let targetId = mediaManager.syncedLyrics[mediaManager.currentLyricIndex].id
          proxy.scrollTo(targetId, anchor: .center)
        }
      }
    }
  }

  private func markUserInteraction() {
    isUserInteracting = true
    interactionResetTask?.cancel()
    interactionResetTask = Task {
      try? await Task.sleep(nanoseconds: 4_500_000_000)
      guard !Task.isCancelled else { return }
      await MainActor.run {
        withAnimation(.easeInOut(duration: 0.3)) {
          isUserInteracting = false
        }
      }
    }
  }

  private func lyricLineRow(
    line: LyricLine,
    index: Int,
    isActive: Bool,
    isPast: Bool,
    isHovered: Bool
  ) -> some View {
    Button(action: {
      isUserInteracting = false
      interactionResetTask?.cancel()
      mediaManager.seek(to: line.time)
    }) {
      HStack(alignment: .center, spacing: 8) {
        if isActive {
          Capsule()
            .fill(mediaAccentColor)
            .frame(width: 3, height: 14)
            .transition(.scale.combined(with: .opacity))
        } else {
          Color.clear
            .frame(width: 3, height: 14)
        }

        Text(line.text)
          .font(.system(
            size: isActive ? 13 : 11.5,
            weight: isActive ? .bold : (isPast ? .medium : .semibold),
            design: .rounded
          ))
          .foregroundColor(
            isActive
              ? AppTheme.textPrimary
              : (isHovered
                ? AppTheme.textPrimary
                : (isPast ? AppTheme.textTertiary : AppTheme.textSecondary))
          )
          .multilineTextAlignment(.leading)
          .lineLimit(2)
          .frame(maxWidth: .infinity, alignment: .leading)

        if isHovered {
          Text(formatTimestamp(line.time))
            .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
            .foregroundColor(mediaAccentColor)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(mediaAccentColor.opacity(0.14))
            .cornerRadius(4)
            .transition(.opacity)
        }
      }
      .padding(.horizontal, 4)
      .padding(.vertical, isActive ? 3 : 2)
      .background(
        RoundedRectangle(cornerRadius: 6, style: .continuous)
          .fill(
            isActive
              ? AppTheme.badgeBackground
              : (isHovered ? AppTheme.badgeBackground.opacity(0.6) : Color.clear)
          )
      )
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .onHover { hovering in
      if hovering {
        hoveredLineId = line.id
        NSCursor.pointingHand.push()
      } else {
        if hoveredLineId == line.id {
          hoveredLineId = nil
        }
        NSCursor.pop()
      }
    }
  }

  private func formatTimestamp(_ time: TimeInterval) -> String {
    let minutes = Int(time) / 60
    let seconds = Int(time) % 60
    return String(format: "%d:%02d", minutes, seconds)
  }

  private var singleLineView: some View {
    HStack(alignment: .firstTextBaseline, spacing: 8) {
      Capsule()
        .fill(mediaAccentColor)
        .frame(width: 3, height: 14)

      Text(mediaManager.currentLyricText)
        .font(.system(size: 12.5, weight: .bold, design: .rounded))
        .foregroundColor(AppTheme.textPrimary)
        .multilineTextAlignment(.leading)
        .lineLimit(2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(.vertical, 6)
    .padding(.horizontal, 4)
  }

  private var loadingView: some View {
    HStack(spacing: 8) {
      ProgressView()
        .controlSize(.small)
      Text(L10n.Media.loadingLyrics)
        .font(.system(size: 11, weight: .medium, design: .rounded))
        .foregroundColor(AppTheme.textSecondary)
      Spacer(minLength: 4)
    }
    .padding(.vertical, 8)
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var unsyncedLyricsStream: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 5) {
        Image(systemName: "info.circle.fill")
          .font(.system(size: 8.5))
          .foregroundColor(AppTheme.accentAmber)
        Text(L10n.Media.unsyncedLyricsNotice)
          .font(.system(size: 9, weight: .medium))
          .foregroundColor(AppTheme.textSecondary)
          .lineLimit(1)
      }
      .padding(.vertical, 2)

      ScrollView(.vertical, showsIndicators: true) {
        VStack(alignment: .leading, spacing: 4) {
          ForEach(Array(mediaManager.unsyncedLyrics.enumerated()), id: \.offset) { _, line in
            Text(line)
              .font(.system(size: 11.5, weight: .regular, design: .rounded))
              .foregroundColor(AppTheme.textPrimary)
              .multilineTextAlignment(.leading)
              .frame(maxWidth: .infinity, alignment: .leading)
          }
        }
        .padding(.vertical, 2)
      }
      .frame(height: 130)
    }
  }

  private var instrumentalView: some View {
    HStack(spacing: 10) {
      ZStack {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
          .fill(AppTheme.accentCyan.opacity(0.12))
          .frame(width: 28, height: 28)

        Image(systemName: "music.quarternote.3")
          .font(.system(size: 12, weight: .semibold))
          .foregroundColor(AppTheme.accentCyan)
      }

      VStack(alignment: .leading, spacing: 1.5) {
        Text(L10n.Media.instrumental)
          .font(.system(size: 11, weight: .bold, design: .rounded))
          .foregroundColor(AppTheme.textPrimary)

        Text(L10n.Media.instrumentalDesc)
          .font(.system(size: 9.5, weight: .medium))
          .foregroundColor(AppTheme.textSecondary)
          .lineLimit(2)
      }

      Spacer(minLength: 4)
    }
    .padding(.vertical, 6)
  }

  private var unavailableLyricsView: some View {
    HStack(spacing: 10) {
      ZStack {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
          .fill(AppTheme.badgeBackground)
          .frame(width: 28, height: 28)

        Image(systemName: "quote.bubble")
          .font(.system(size: 12, weight: .semibold))
          .foregroundColor(AppTheme.textTertiary)
      }

      VStack(alignment: .leading, spacing: 1.5) {
        Text(L10n.Media.lyricsUnavailable)
          .font(.system(size: 11, weight: .bold, design: .rounded))
          .foregroundColor(AppTheme.textPrimary)

        Text(L10n.Media.lyricsUnavailableDesc)
          .font(.system(size: 9.5, weight: .medium))
          .foregroundColor(AppTheme.textSecondary)
          .lineLimit(2)
      }

      Spacer(minLength: 4)

      Button(action: {
        mediaManager.refetchLyrics()
      }) {
        Image(systemName: "arrow.clockwise")
          .font(.system(size: 9, weight: .bold))
          .foregroundColor(mediaAccentColor)
          .frame(width: 24, height: 24)
          .background(mediaAccentColor.opacity(0.12))
          .clipShape(Circle())
      }
      .buttonStyle(.plain)
      .help("Retry lyrics fetch")
    }
    .padding(.vertical, 6)
  }

  private var emptyLyricsView: some View {
    unavailableLyricsView
  }
}

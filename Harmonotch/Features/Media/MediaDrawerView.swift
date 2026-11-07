import AppKit
import SwiftUI

struct MediaDrawerView: View {
  @ObservedObject var mediaManager = MediaManager.shared
  @ObservedObject var playbackClock = MediaManager.shared.playbackClock
  @ObservedObject var adzanPlayer = AdzanPlayer.shared
  @ObservedObject var prayerManager = PrayerManager.shared

  enum MediaPanel: Equatable {
    case lyrics
    case queue
  }

  @State var activePanel: MediaPanel?

  var isLyricsShown: Bool { activePanel == .lyrics }
  var isQueueShown: Bool { activePanel == .queue }

  var mediaAccentColor: Color {
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
      } else if let pres = mediaManager.presentation {
        switch pres.kind {
        case .track:
          mediaPlaybackView.transition(NotchMotion.drawer)
        case .audioOnly(let appInfo):
          audioOnlyPlaybackView(appInfo: appInfo).transition(NotchMotion.drawer)
        }
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
    .animation(NotchMotion.content, value: mediaManager.hasMediaSession)
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

  func selectPanel(_ panel: MediaPanel) {
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
        .font(AppTypography.caption(.bold))
      Text(message)
        .font(AppTypography.caption(.medium))
        .lineLimit(2)
    }
    .foregroundColor(.white.opacity(0.85))
    .padding(.horizontal, 10)
    .padding(.vertical, 6)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.white.opacity(0.08))
    .cornerRadius(8)
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
}

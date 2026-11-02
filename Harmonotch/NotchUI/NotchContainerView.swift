import SwiftUI

struct NotchContainerView: View {
  @ObservedObject var notchVM = NotchViewModel.shared
  @ObservedObject var adzanPlayer = AdzanPlayer.shared
  @ObservedObject var mediaManager = MediaManager.shared
  @ObservedObject var themeManager = ThemeManager.shared

  private var geometry: NotchGeometry {
    notchVM.geometry
  }

  private var isMediaPlaying: Bool {
    mediaManager.isPlaying && mediaManager.hasActiveTrack && !adzanPlayer.isPlaying
  }

  private var leftContentExpansion: CGFloat {
    if isMediaPlaying {
      return notchVM.isCompanionEnabled ? NotchLayout.mediaLeftExpansion : 0
    }
    return notchVM.isLeftCompanionVisible ? NotchLayout.companionExpansion : 0
  }

  private var targetWidth: CGFloat {
    guard !notchVM.isExpanded else { return NotchLayout.expandedWidth }

    return geometry.collapsedWidth(
      isHovered: notchVM.isHovered,
      isMediaPlaying: isMediaPlaying
    ) + leftContentExpansion
  }

  private var topClearance: CGFloat {
    geometry.hasHardwareNotch ? (geometry.physicalNotchHeight + 4) : 8
  }

  private var targetHeight: CGFloat {
    guard notchVM.isExpanded else { return geometry.collapsedHeight }

    switch notchVM.selectedTab {
    case .battery:
      return topClearance + NotchLayout.expandedBatteryHeight
    case .media:
      if adzanPlayer.isPlaying {
        return topClearance + NotchLayout.expandedAdzanHeight
      }
      let hasLyrics = mediaManager.hasActiveTrack
        && (!mediaManager.syncedLyrics.isEmpty || !mediaManager.currentLyricText.isEmpty || mediaManager.isLoadingLyrics || mediaManager.isInstrumental)
      return topClearance
        + (hasLyrics
          ? NotchLayout.expandedMediaTrackHeight
          : NotchLayout.expandedMediaHeight)
    case .prayer:
      return topClearance
        + (adzanPlayer.isPlaying
          ? NotchLayout.expandedAdzanHeight
          : NotchLayout.expandedPrayerHeight)
    }
  }

  private var notchShape: NotchShape {
    NotchShape.island(
      height: targetHeight,
      isExpanded: notchVM.isExpanded,
      isFloating: !geometry.hasHardwareNotch
    )
  }

  var body: some View {
    ZStack(alignment: .top) {
      // Pure Black Background Silhouette
      HarmonotchSurface(shape: notchShape, isExpanded: notchVM.isExpanded)
        .frame(width: targetWidth, height: targetHeight)

      if notchVM.isExpanded {
        VStack(spacing: 10) {
          NotchTabBar(selectedTab: $notchVM.selectedTab)

          ZStack(alignment: .top) {
            switch notchVM.selectedTab {
            case .battery:
              BatteryDrawerView()
                .transition(NotchMotion.drawer)
            case .media:
              MediaDrawerView()
                .transition(NotchMotion.drawer)
            case .prayer:
              PrayerDrawerView()
                .transition(NotchMotion.drawer)
            }
          }
          .frame(width: NotchLayout.expandedContentWidth)
          .frame(maxHeight: .infinity, alignment: .top)
          .clipped()
        }
        .padding(.top, topClearance)
        .padding(.horizontal, NotchLayout.expandedHorizontalInset)
        .padding(.bottom, NotchLayout.expandedBottomInset)
        .frame(width: targetWidth, height: targetHeight, alignment: .top)
        .clipped()
        .transition(
          .asymmetric(
            insertion: .scale(scale: 0.86, anchor: .top)
              .combined(with: .opacity)
              .combined(with: .offset(y: -6)),
            removal: .scale(scale: 0.70, anchor: .top)
              .combined(with: .opacity)
              .combined(with: .offset(y: -8))
          )
        )
      } else {
        NotchPillView()
          .frame(width: targetWidth, height: targetHeight, alignment: .top)
          .transition(
            .asymmetric(
              insertion: .scale(scale: 0.85, anchor: .top)
                .combined(with: .opacity),
              removal: .scale(scale: 0.92, anchor: .top)
                .combined(with: .opacity)
            )
          )
      }
    }
    .frame(width: targetWidth, height: targetHeight, alignment: .top)
    .clipShape(notchShape)
    .offset(
      x: !notchVM.isExpanded && leftContentExpansion > 0
        ? -(leftContentExpansion / 2)
        : 0,
      y: geometry.hasHardwareNotch ? 0 : NotchLayout.floatingTopInset
    )
    .frame(width: NotchWindowController.canvasWidth, alignment: .top)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .animation(
      .spring(
        response: notchVM.isExpanded ? 0.36 : 0.34,
        dampingFraction: notchVM.isExpanded ? 0.78 : 0.96,
        blendDuration: 0.04
      ),
      value: notchVM.isExpanded
    )
    .animation(.spring(response: 0.24, dampingFraction: 0.80), value: notchVM.isHovered)
    .animation(NotchMotion.content, value: targetWidth)
    .animation(NotchMotion.content, value: targetHeight)
    .preferredColorScheme(themeManager.colorScheme)
  }
}

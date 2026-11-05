import SwiftUI

struct NotchContainerView: View {
  @ObservedObject var notchVM = NotchViewModel.shared
  @ObservedObject var adzanPlayer = AdzanPlayer.shared
  @ObservedObject var mediaManager = MediaManager.shared
  @ObservedObject var themeManager = ThemeManager.shared

  /// Tinggi konten expanded aktual yang diukur dari layout; 0 sebelum pengukuran pertama.
  @State private var measuredExpandedHeight: CGFloat = 0

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

  private var collapsedWings: (left: CGFloat, right: CGFloat) {
    geometry.collapsedWingWidths(
      isHovered: notchVM.isHovered,
      isMediaPlaying: isMediaPlaying,
      leftExtra: leftContentExpansion,
      measured: notchVM.collapsedWingWidths
    )
  }

  private var targetWidth: CGFloat {
    guard !notchVM.isExpanded else { return NotchLayout.expandedWidth }

    return geometry.collapsedWidth(
      isHovered: notchVM.isHovered,
      isMediaPlaying: isMediaPlaying,
      leftExtra: leftContentExpansion,
      measured: notchVM.collapsedWingWidths
    )
  }

  private var topClearance: CGFloat {
    geometry.hasHardwareNotch ? (geometry.physicalNotchHeight + 4) : 8
  }

  private var targetHeight: CGFloat {
    guard notchVM.isExpanded else { return geometry.collapsedHeight }
    // Pakai tinggi konten terukur agar pas per tab; fallback sebelum pengukuran pertama.
    return measuredExpandedHeight > 0 ? measuredExpandedHeight : fallbackExpandedHeight
  }

  private var fallbackExpandedHeight: CGFloat {
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
      if notchVM.isExpanded {
        expandedContent
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
          .frame(width: targetWidth, height: geometry.collapsedHeight, alignment: .top)
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
    .frame(width: targetWidth, alignment: .top)
    .background(
      HarmonotchSurface(shape: notchShape, isExpanded: notchVM.isExpanded)
    )
    .clipShape(notchShape)
    .overlay(
      notchShape.openBorder
        .stroke(AppTheme.surfaceBorder, lineWidth: 0.8)
        .allowsHitTesting(false)
    )
    .offset(
      x: !notchVM.isExpanded && geometry.hasHardwareNotch
        ? -(collapsedWings.left - collapsedWings.right) / 2
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
    .animation(NotchMotion.content, value: notchVM.selectedTab)
    .preferredColorScheme(themeManager.colorScheme)
    .onPreferenceChange(ExpandedContentHeightKey.self) { height in
      guard height > 0 else { return }
      measuredExpandedHeight = height
    }
    .onChange(of: measuredExpandedHeight) { _, newValue in
      notchVM.expandedContentHeight = newValue
    }
  }

  /// Konten expanded dengan tinggi alami (mengikuti isi tiap tab).
  private var expandedContent: some View {
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
    }
    .padding(.top, topClearance)
    .padding(.horizontal, NotchLayout.expandedHorizontalInset)
    .padding(.bottom, NotchLayout.expandedBottomInset)
    .frame(width: targetWidth, alignment: .top)
    .background(
      GeometryReader { proxy in
        Color.clear.preference(
          key: ExpandedContentHeightKey.self,
          value: proxy.size.height
        )
      }
    )
  }
}

/// Tinggi total konten expanded (termasuk padding atas/bawah) untuk penyesuaian panel.
private struct ExpandedContentHeightKey: PreferenceKey {
  static var defaultValue: CGFloat = 0
  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = nextValue()
  }
}

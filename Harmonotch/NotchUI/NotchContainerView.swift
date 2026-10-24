import SwiftUI

struct NotchContainerView: View {
    @ObservedObject var notchVM = NotchViewModel.shared
    @ObservedObject var adzanPlayer = AdzanPlayer.shared
    @ObservedObject var mediaManager = MediaManager.shared
    @ObservedObject var themeManager = ThemeManager.shared

    private var geometry: NotchGeometry {
        notchVM.geometry
    }

    private var targetWidth: CGFloat {
        notchVM.isExpanded ? 540 : geometry.physicalNotchWidth
    }

    private var targetHeight: CGFloat {
        let notchHeight = geometry.hasHardwareNotch ? geometry.physicalNotchHeight : 0
        if notchVM.isExpanded {
            switch notchVM.selectedTab {
            case .prayer:
                let contentHeight = adzanPlayer.isPlaying
                    ? NotchLayout.expandedAdzanHeight
                    : NotchLayout.expandedPrayerHeight
                return notchHeight + contentHeight
            case .battery:
                return notchHeight + NotchLayout.expandedBatteryHeight
            case .media:
                let contentHeight = mediaManager.hasActiveTrack
                    ? NotchLayout.expandedMediaTrackHeight
                    : NotchLayout.expandedMediaHeight
                return notchHeight + contentHeight
            }
        } else {
            if notchVM.selectedTab == .media && mediaManager.hasActiveTrack && !mediaManager.currentLyricText.isEmpty {
                return notchHeight + NotchLayout.collapsedLyricHeight
            } else {
                return notchHeight + NotchLayout.collapsedPillHeight
            }
        }
    }

    private var targetRadius: CGFloat {
        if notchVM.isExpanded {
            return 20
        } else if notchVM.selectedTab == .media && mediaManager.hasActiveTrack && !mediaManager.currentLyricText.isEmpty {
            return 16
        } else {
            return geometry.hasHardwareNotch ? 12 : 13
        }
    }

    private var notchShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: 0,
            bottomLeadingRadius: targetRadius,
            bottomTrailingRadius: targetRadius,
            topTrailingRadius: 0,
            style: .continuous
        )
    }

    var body: some View {
        ZStack(alignment: .top) {
            HarmonotchSurface(
                shape: notchShape,
                isExpanded: notchVM.isExpanded
            )
            .frame(width: targetWidth, height: targetHeight)

            Group {
                if notchVM.isExpanded {
                    VStack(spacing: 10) {
                        if geometry.hasHardwareNotch {
                            Color.clear
                                .frame(height: geometry.physicalNotchHeight + 4)
                        } else {
                            Color.clear
                                .frame(height: 8)
                        }

                        NotchTabBar(selectedTab: $notchVM.selectedTab)

                        ZStack {
                            switch notchVM.selectedTab {
                            case .prayer:
                                PrayerDrawerView()
                                    .transition(.opacity)
                            case .battery:
                                BatteryDrawerView()
                                    .transition(.opacity)
                            case .media:
                                MediaDrawerView()
                                    .transition(.opacity)
                            }
                        }
                        .animation(.spring(response: 0.26, dampingFraction: 0.84), value: notchVM.selectedTab)
                    }
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .offset(y: -6)),
                        removal: .opacity
                    ))
                    .onHover { isHovered in
                        notchVM.setHovered(isHovered)
                    }
                } else {
                    NotchPillView()
                        .transition(.asymmetric(
                            insertion: .opacity,
                            removal: .opacity.combined(with: .scale(scale: 0.9, anchor: .top))
                        ))
                        .onHover { isHovered in
                            if isHovered {
                                notchVM.setHovered(true)
                            }
                        }
                }
            }
            .frame(width: targetWidth, height: targetHeight, alignment: .top)
            .clipShape(notchShape)
        }
        .frame(width: targetWidth, height: targetHeight, alignment: .top)
        .frame(width: NotchWindowController.canvasWidth, alignment: .top)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(
            notchVM.isExpanded
                ? .spring(response: 0.34, dampingFraction: 0.76, blendDuration: 0.08)
                : .spring(response: 0.25, dampingFraction: 0.88, blendDuration: 0.05),
            value: notchVM.isExpanded
        )
        .animation(.spring(response: 0.32, dampingFraction: 0.82), value: notchVM.selectedTab)
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: adzanPlayer.isPlaying)
        .animation(.spring(response: 0.32, dampingFraction: 0.82), value: mediaManager.currentLyricText.isEmpty)
        .animation(.spring(response: 0.32, dampingFraction: 0.82), value: mediaManager.hasActiveTrack)
        .preferredColorScheme(themeManager.colorScheme)
    }
}

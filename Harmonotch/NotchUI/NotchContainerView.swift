import SwiftUI

struct NotchContainerView: View {
    @ObservedObject var notchVM = NotchViewModel.shared
    @ObservedObject var adzanPlayer = AdzanPlayer.shared
    @ObservedObject var mediaManager = MediaManager.shared
    @ObservedObject var themeManager = ThemeManager.shared

    let geometry = NotchGeometry.current()

    private var targetWidth: CGFloat {
        notchVM.isExpanded ? 540 : geometry.physicalNotchWidth
    }

    private var targetHeight: CGFloat {
        if notchVM.isExpanded {
            let notchHeight = geometry.hasHardwareNotch ? geometry.physicalNotchHeight : 0
            switch notchVM.selectedTab {
            case .prayer:
                let contentHeight: CGFloat = adzanPlayer.isPlaying ? 325 : 272
                return notchHeight + contentHeight
            case .battery:
                return notchHeight + 288
            case .media:
                let contentHeight: CGFloat = mediaManager.hasActiveTrack ? 350 : 288
                return notchHeight + contentHeight
            }
        } else {
            let notchHeight = geometry.hasHardwareNotch ? geometry.physicalNotchHeight : 0
            if notchVM.selectedTab == .media && mediaManager.hasActiveTrack && !mediaManager.currentLyricText.isEmpty {
                return notchHeight + 64
            } else {
                return geometry.hasHardwareNotch ? (geometry.physicalNotchHeight + 26) : 32
            }
        }
    }

    private var targetRadius: CGFloat {
        if notchVM.isExpanded {
            return 20
        } else if notchVM.selectedTab == .media && mediaManager.hasActiveTrack && !mediaManager.currentLyricText.isEmpty {
            return 16
        } else {
            return 12
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
                                    .transition(.asymmetric(
                                        insertion: .opacity.combined(with: .offset(x: -8)),
                                        removal: .opacity.combined(with: .offset(x: -8))
                                    ))
                            case .battery:
                                BatteryDrawerView()
                                    .transition(.asymmetric(
                                        insertion: .opacity.combined(with: .offset(x: 8)),
                                        removal: .opacity.combined(with: .offset(x: 8))
                                    ))
                            case .media:
                                MediaDrawerView()
                                    .transition(.asymmetric(
                                        insertion: .opacity.combined(with: .offset(x: 8)),
                                        removal: .opacity.combined(with: .offset(x: 8))
                                    ))
                            }
                        }
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
        }
        .frame(width: targetWidth, height: targetHeight, alignment: .top)
        .clipped()
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

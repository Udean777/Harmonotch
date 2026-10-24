import SwiftUI

struct NotchPillView: View {
    @ObservedObject var prayerManager = PrayerManager.shared
    @ObservedObject var adzanPlayer = AdzanPlayer.shared
    @ObservedObject var notchVM = NotchViewModel.shared
    @ObservedObject var batteryMonitor = BatteryMonitor.shared
    @ObservedObject var languageManager = LanguageManager.shared
    @ObservedObject var mediaManager = MediaManager.shared

    private var geometry: NotchGeometry {
        notchVM.geometry
    }

    var body: some View {
        VStack(spacing: 0) {
            if geometry.hasHardwareNotch {
                Color.clear
                    .frame(width: geometry.physicalNotchWidth, height: geometry.physicalNotchHeight)
            }

            Group {
                if adzanPlayer.isPlaying {
                    HStack(spacing: 6) {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.green)
                            .symbolEffect(.variableColor.iterative.reversing)

                        Text("Adzan \(L10n.Prayer.localizedPrayerName(adzanPlayer.playingPrayerName))")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.green)
                    }
                } else if notchVM.selectedTab == .prayer {
                    HStack(spacing: 6) {
                        Image(systemName: "moon.stars.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Color.amberCustom)

                        if let current = prayerManager.currentPrayerItem {
                            Text(current.name)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.white.opacity(0.85))
                        }

                        Text("•")
                            .font(.system(size: 7))
                            .foregroundColor(.white.opacity(0.3))

                        if let next = prayerManager.nextPrayerItem {
                            Text(next.name)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.white.opacity(0.9))

                            Text(next.timeString)
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundColor(.green)
                        }
                    }
                } else if notchVM.selectedTab == .battery {
                    HStack(spacing: 5) {
                        Image(systemName: "macbook")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(batteryMonitor.isPluggedIn ? .green : (batteryMonitor.currentCapacity <= 20 ? .orange : Color.amberCustom))

                        Text("\(batteryMonitor.currentCapacity)%")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.white)

                        Text("•")
                            .font(.system(size: 7))
                            .foregroundColor(.white.opacity(0.3))

                        if batteryMonitor.isCharging {
                            HStack(spacing: 2) {
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 8))
                                Text(L10n.Battery.charging)
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .foregroundColor(.green)
                        } else if batteryMonitor.isPluggedIn {
                            Text(L10n.Battery.acAdapter)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.cyan)
                        } else {
                            Text("\(batteryMonitor.healthPercent)% \(L10n.Battery.healthSuffix)")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.white.opacity(0.85))
                        }

                        Text("•")
                            .font(.system(size: 7))
                            .foregroundColor(.white.opacity(0.3))

                        HStack(spacing: 2.5) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 7.5, weight: .bold))
                            Text("\(batteryMonitor.cycleCount)")
                                .font(.system(size: 9, weight: .semibold, design: .rounded))
                        }
                        .foregroundColor(Color.amberCustom)
                    }
                } else {
                    if mediaManager.hasActiveTrack && !mediaManager.currentLyricText.isEmpty {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 4) {
                                Image(systemName: mediaManager.isPlaying ? "waveform" : mediaManager.mediaSource.iconName)
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(mediaManager.isPlaying ? mediaManager.mediaSource.brandColor : .white.opacity(0.5))
                                    .symbolEffect(.variableColor.iterative.reversing, isActive: mediaManager.isPlaying)

                                Text("\(mediaManager.trackTitle) • \(mediaManager.artistName)")
                                    .font(.system(size: 8.5, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.55))
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            }

                            Text(mediaManager.currentLyricText)
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .lineLimit(3)
                                .lineSpacing(1.5)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                                .id(mediaManager.currentLyricText)
                                .transition(
                                    .asymmetric(
                                        insertion: .opacity.combined(with: .offset(y: 4)),
                                        removal: .opacity.combined(with: .offset(y: -4))
                                    )
                                )
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .animation(.easeInOut(duration: 0.28), value: mediaManager.currentLyricText)
                    } else {
                        HStack(spacing: 5) {
                            Image(systemName: mediaManager.isPlaying ? "waveform" : mediaManager.mediaSource.iconName)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(mediaManager.isPlaying ? mediaManager.mediaSource.brandColor : .white.opacity(0.6))
                                .symbolEffect(.variableColor.iterative.reversing, isActive: mediaManager.isPlaying)

                            if mediaManager.hasActiveTrack {
                                Text("\(mediaManager.trackTitle) • \(mediaManager.artistName)")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.white.opacity(0.9))
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            } else {
                                Text(L10n.Media.noTrackPlaying)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, pillContentHeight > 26 ? 6 : 0)
            .frame(width: geometry.physicalNotchWidth, height: pillContentHeight)
            .transition(.opacity)
        }
        .frame(width: geometry.physicalNotchWidth)
        .animation(.spring(response: 0.32, dampingFraction: 0.8), value: pillContentHeight)
        .animation(.easeInOut(duration: 0.2), value: notchVM.selectedTab)
    }

    private var pillContentHeight: CGFloat {
        if notchVM.selectedTab == .media && mediaManager.hasActiveTrack && !mediaManager.currentLyricText.isEmpty {
            return 64
        } else {
            return 26
        }
    }
}

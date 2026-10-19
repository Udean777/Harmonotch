//
//  NotchPillView.swift
//  Harmonotch
//

import SwiftUI

struct NotchPillView: View {
    @ObservedObject var prayerManager = PrayerManager.shared
    @ObservedObject var adzanPlayer = AdzanPlayer.shared
    @ObservedObject var notchVM = NotchViewModel.shared
    @ObservedObject var batteryMonitor = BatteryMonitor.shared
    @ObservedObject var languageManager = LanguageManager.shared
    @ObservedObject var mediaManager = MediaManager.shared

    let geometry = NotchGeometry.current()

    var body: some View {
        VStack(spacing: 0) {
            // Ruang setinggi notch hardware
            if geometry.hasHardwareNotch {
                Color.clear
                    .frame(width: geometry.physicalNotchWidth, height: geometry.physicalNotchHeight)
            }

            // Konten Ekstensi Notch (Dinamis sesuai Tab / Capsule yang dipilih)
            Group {
                if adzanPlayer.isPlaying {
                    // 1. Banner Adzan Aktif (Prioritas Tertinggi)
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
                    // 2. Konten Jadwal Sholat
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
                    // 3. Konten Baterai & Hardware Mac (Menggunakan ikon monitor/macbook)
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

                        Text("\(batteryMonitor.cycleCount) C")
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                            .foregroundColor(Color.amberCustom)
                    }
                } else {
                    // 4. Konten Media Player / Now Playing & Lirik Berjalan
                    HStack(spacing: 5) {
                        Image(systemName: mediaManager.isPlaying ? "waveform" : "music.note")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(mediaManager.isPlaying ? .green : .white.opacity(0.6))
                            .symbolEffect(.variableColor.iterative.reversing, isActive: mediaManager.isPlaying)

                        if mediaManager.hasActiveTrack {
                            Text(mediaManager.currentLyricText.isEmpty ? "\(mediaManager.trackTitle) • \(mediaManager.artistName)" : mediaManager.currentLyricText)
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
            .padding(.horizontal, 8)
            .frame(width: geometry.physicalNotchWidth, height: 26)
            .transition(.opacity)
        }
        .frame(width: geometry.physicalNotchWidth)
        .animation(.easeInOut(duration: 0.2), value: notchVM.selectedTab)
    }
}

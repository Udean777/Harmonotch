//
//  NotchPillView.swift
//  Harmonotch
//

import SwiftUI

struct NotchPillView: View {
    @ObservedObject var prayerManager = PrayerManager.shared
    @ObservedObject var adzanPlayer = AdzanPlayer.shared

    let geometry = NotchGeometry.current()

    var body: some View {
        VStack(spacing: 0) {
            // Ruang setinggi notch hardware
            if geometry.hasHardwareNotch {
                Color.clear
                    .frame(width: geometry.physicalNotchWidth, height: geometry.physicalNotchHeight)
            }

            // Konten Ekstensi Notch
            HStack(spacing: 6) {
                // Ikon Sholat / Adzan
                if adzanPlayer.isPlaying {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.green)
                        .symbolEffect(.variableColor.iterative.reversing)
                } else {
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Color.amberCustom)
                }

                // Sholat Aktif
                if let current = prayerManager.currentPrayerItem, !adzanPlayer.isPlaying {
                    Text(current.name)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                }

                // Separator
                Text("•")
                    .font(.system(size: 7))
                    .foregroundColor(.white.opacity(0.3))

                // Sholat Berikutnya
                if adzanPlayer.isPlaying {
                    Text("Adzan \(adzanPlayer.playingPrayerName)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.green)
                } else if let next = prayerManager.nextPrayerItem {
                    Text(next.name)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))

                    Text(next.timeString)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.green)
                }
            }
            .padding(.horizontal, 8)
            .frame(width: geometry.physicalNotchWidth, height: 26)
        }
        .frame(width: geometry.physicalNotchWidth)
    }
}

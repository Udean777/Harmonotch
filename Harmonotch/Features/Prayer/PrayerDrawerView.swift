//
//  PrayerDrawerView.swift
//  Harmonotch
//

import SwiftUI

struct PrayerDrawerView: View {
    @ObservedObject var prayerManager = PrayerManager.shared
    @ObservedObject var adzanPlayer = AdzanPlayer.shared

    let geometry = NotchGeometry.current()

    var body: some View {
        VStack(spacing: 12) {
            // MARK: - Notch Hardware Clearance Spacer (Mencegah konten naik ke notch fisik)
            if geometry.hasHardwareNotch {
                Color.clear
                    .frame(height: geometry.physicalNotchHeight + 6)
            } else {
                Color.clear
                    .frame(height: 8)
            }

            // MARK: - Header (Wilayah & Tanggal)
            HStack(alignment: .center) {
                // Lokasi & Picker
                Menu {
                    Toggle(isOn: $prayerManager.useGPS) {
                        Label("Gunakan Lokasi Otomatis (GPS)", systemImage: "location.fill")
                    }

                    Divider()

                    ForEach(CityPreset.presets) { city in
                        Button(action: {
                            prayerManager.useGPS = false
                            prayerManager.selectedCity = city
                        }) {
                            HStack {
                                Text("\(city.name) (\(city.province))")
                                if !prayerManager.useGPS && prayerManager.selectedCity.id == city.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: prayerManager.useGPS ? "location.fill" : "mappin.and.ellipse")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.green)

                        Text(prayerManager.currentLocationName)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)

                        Image(systemName: "chevron.down")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(8)
                }
                .menuStyle(.borderlessButton)

                Spacer()

                // Tanggal Masehi & Hijriah
                VStack(alignment: .trailing, spacing: 2) {
                    Text(prayerManager.gregorianDateString)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))

                    Text(prayerManager.hijriDateString)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Color.amberCustom)
                }
            }
            .padding(.horizontal, 16)

            // MARK: - Adzan Active Banner
            if adzanPlayer.isPlaying {
                HStack(spacing: 12) {
                    Image(systemName: "speaker.wave.3.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .symbolEffect(.variableColor.iterative.reversing)

                    VStack(alignment: .leading, spacing: 1) {
                        Text("Adzan \(adzanPlayer.playingPrayerName) Sedang Berkumandang")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)

                        Text("Hayya 'alash Shalaah...")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.8))
                    }

                    Spacer()

                    Button(action: {
                        adzanPlayer.stop()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "stop.fill")
                                .font(.system(size: 9, weight: .bold))
                            Text("Hentikan")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.red.opacity(0.85))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(LinearGradient(
                            colors: [Color.green.opacity(0.35), Color.black.opacity(0.6)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.green.opacity(0.4), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 14)
                .transition(.opacity.combined(with: .scale))
            }

            // MARK: - Daftar Waktu Sholat (HStack Cards)
            HStack(spacing: 8) {
                ForEach(prayerManager.prayerItems) { item in
                    PrayerCardView(item: item)
                }
            }
            .padding(.horizontal, 14)

            Divider()
                .background(Color.white.opacity(0.1))
                .padding(.horizontal, 14)

            // MARK: - Footer Controls
            HStack(spacing: 14) {
                // Mute / Unmute Toggle
                Button(action: {
                    adzanPlayer.isMuted.toggle()
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: adzanPlayer.isMuted ? "bell.slash.fill" : "bell.fill")
                            .font(.system(size: 11))
                            .foregroundColor(adzanPlayer.isMuted ? .red : .green)

                        Text(adzanPlayer.isMuted ? "Adzan Dimatikan" : "Adzan Aktif")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)

                // Volume slider
                HStack(spacing: 6) {
                    Image(systemName: "speaker.fill")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.5))

                    Slider(value: Binding(
                        get: { Double(adzanPlayer.volume) },
                        set: { adzanPlayer.volume = Float($0) }
                    ), in: 0...1)
                    .frame(width: 80)

                    Image(systemName: "speaker.wave.3.fill")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.5))
                }

                Spacer()

                // Test Adzan Button
                Button(action: {
                    adzanPlayer.testPlay()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: adzanPlayer.isPlaying ? "stop.circle.fill" : "play.circle.fill")
                            .font(.system(size: 12))
                        Text(adzanPlayer.isPlaying ? "Stop Audio" : "Uji Audio")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(adzanPlayer.isPlaying ? .red : Color.amberCustom)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .frame(width: 540)
    }
}

//
//  PrayerDrawerView.swift
//  Harmonotch
//
//

import SwiftUI

struct PrayerDrawerView: View {
    @ObservedObject var prayerManager = PrayerManager.shared
    @ObservedObject var adzanPlayer = AdzanPlayer.shared
    @ObservedObject var languageManager = LanguageManager.shared
    @ObservedObject var themeManager = ThemeManager.shared

    var body: some View {
        VStack(spacing: 10) {
            // MARK: - Header (Wilayah, Language Toggle, & Tanggal)
            HStack(alignment: .center, spacing: 8) {
                // Lokasi & Picker
                Menu {
                    Toggle(isOn: $prayerManager.useGPS) {
                        Label(L10n.Prayer.autoGPS, systemImage: "location.fill")
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
                            .foregroundColor(AppTheme.accentGreen)

                        Text(prayerManager.currentLocationName)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(AppTheme.textPrimary)

                        Image(systemName: "chevron.down")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(AppTheme.textTertiary)
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(.ultraThinMaterial)
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(AppTheme.badgeBackground)
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(
                                    LinearGradient(
                                        colors: AppTheme.isDark
                                            ? [Color.white.opacity(0.25), Color.white.opacity(0.05)]
                                            : [Color.white.opacity(0.85), Color.black.opacity(0.06)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 0.6
                                )
                        }
                    )
                }
                .menuStyle(.borderlessButton)

                // Qibla Direction Badge
                if !prayerManager.qiblaString.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "safari.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(AppTheme.accentAmber)
                            .rotationEffect(.degrees(prayerManager.qiblaHeading))

                        Text("\(L10n.Prayer.qibla) \(prayerManager.qiblaString)")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(.ultraThinMaterial)
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(AppTheme.badgeBackground)
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(
                                    LinearGradient(
                                        colors: AppTheme.isDark
                                            ? [Color.white.opacity(0.22), Color.white.opacity(0.04)]
                                            : [Color.white.opacity(0.80), Color.black.opacity(0.05)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 0.5
                                )
                        }
                    )
                }

                // Waktu Imsak Badge
                if !prayerManager.imsakTimeString.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "moon.haze.fill")
                            .font(.system(size: 9))
                            .foregroundColor(AppTheme.accentCyan)

                        Text("\(L10n.Prayer.imsak) \(prayerManager.imsakTimeString)")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundColor(AppTheme.accentCyan)
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(.ultraThinMaterial)
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(AppTheme.accentCyan.opacity(AppTheme.isDark ? 0.12 : 0.08))
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(
                                    LinearGradient(
                                        colors: [AppTheme.accentCyan.opacity(0.4), AppTheme.accentCyan.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 0.5
                                )
                        }
                    )
                }

                Spacer()

                // Tanggal Masehi & Hijriah
                VStack(alignment: .trailing, spacing: 2) {
                    Text(prayerManager.gregorianDateString)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppTheme.textSecondary)

                    Text(prayerManager.hijriDateString)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(AppTheme.accentAmber)
                }
            }
            .padding(.horizontal, 16)

            // MARK: - Adzan Active Banner
            if adzanPlayer.isPlaying {
                HStack(spacing: 12) {
                    Image(systemName: "speaker.wave.3.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(AppTheme.accentGreen)
                        .symbolEffect(.variableColor.iterative.reversing)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(L10n.Prayer.adzanBannerTitle(name: adzanPlayer.playingPrayerName))
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(AppTheme.textPrimary)

                        Text(L10n.Prayer.adzanBannerSubtitle)
                            .font(.system(size: 10))
                            .foregroundColor(AppTheme.textSecondary)
                    }

                    Spacer()

                    Button(action: {
                        adzanPlayer.stop()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "stop.fill")
                                .font(.system(size: 9, weight: .bold))
                            Text(L10n.Prayer.stop)
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.red.opacity(0.88))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(LinearGradient(
                            colors: AppTheme.isDark
                                ? [Color.green.opacity(0.35), Color.black.opacity(0.6)]
                                : [AppTheme.accentGreen.opacity(0.18), AppTheme.accentGreen.opacity(0.06)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(AppTheme.accentGreen.opacity(0.4), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 16)
                .transition(.opacity.combined(with: .scale))
            }

            // MARK: - Daftar Waktu Sholat (HStack Cards)
            HStack(spacing: 8) {
                ForEach(prayerManager.prayerItems) { item in
                    PrayerCardView(item: item)
                }
            }
            .padding(.horizontal, 16)

            Divider()
                .background(AppTheme.divider)
                .padding(.horizontal, 16)

            // MARK: - Footer Controls
            HStack(spacing: 12) {
                // Mute / Unmute Toggle
                Button(action: {
                    adzanPlayer.isMuted.toggle()
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: adzanPlayer.isMuted ? "bell.slash.fill" : "bell.fill")
                            .font(.system(size: 11))
                            .foregroundColor(adzanPlayer.isMuted ? AppTheme.accentRed : AppTheme.accentGreen)

                        Text(adzanPlayer.isMuted ? L10n.Prayer.adzanMuted : L10n.Prayer.adzanActive)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppTheme.badgeBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(AppTheme.cardBorder, lineWidth: 0.5)
                    )
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)

                // Volume slider
                HStack(spacing: 6) {
                    Image(systemName: "speaker.fill")
                        .font(.system(size: 9))
                        .foregroundColor(AppTheme.textTertiary)

                    Slider(value: Binding(
                        get: { Double(adzanPlayer.volume) },
                        set: { adzanPlayer.volume = Float($0) }
                    ), in: 0...1)
                    .frame(width: 75)

                    Image(systemName: "speaker.wave.3.fill")
                        .font(.system(size: 9))
                        .foregroundColor(AppTheme.textTertiary)
                }

                Spacer()

                // Theme Quick Toggle Pill
                ThemeTogglePill()

                // Language Quick Toggle Pill
                LanguageTogglePill()

                // Test Adzan Button
                Button(action: {
                    adzanPlayer.testPlay()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: adzanPlayer.isPlaying ? "stop.circle.fill" : "play.circle.fill")
                            .font(.system(size: 12))
                        Text(adzanPlayer.isPlaying ? L10n.Prayer.stopAudio : L10n.Prayer.testAudio)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(adzanPlayer.isPlaying ? AppTheme.accentRed : AppTheme.accentAmber)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(AppTheme.badgeBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(AppTheme.cardBorder, lineWidth: 0.5)
                    )
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 16)
        }
        .frame(width: 540)
    }
}

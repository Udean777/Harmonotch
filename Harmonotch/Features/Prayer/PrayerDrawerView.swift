import SwiftUI

struct PrayerDrawerView: View {
    @ObservedObject var prayerManager = PrayerManager.shared
    @ObservedObject var adzanPlayer = AdzanPlayer.shared

    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .center, spacing: 8) {
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

                    Divider()

                    Menu {
                        ForEach([-15, -10, -5, 0, 5, 10, 15, 20, 25, 30], id: \.self) { offset in
                            Button(action: {
                                prayerManager.jumatOffsetMinutes = offset
                            }) {
                                HStack {
                                    Text(L10n.Prayer.jumatOffsetLabel(offset))
                                    if prayerManager.jumatOffsetMinutes == offset {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        Label(L10n.Prayer.jumatOffsetLabel(prayerManager.jumatOffsetMinutes), systemImage: "person.3.fill")
                    }
                } label: {
                    NotchChip(cornerRadius: 7, horizontalPadding: 8, verticalPadding: 4) {
                        HStack(spacing: 5) {
                            Image(systemName: prayerManager.useGPS ? "location.fill" : "mappin.and.ellipse")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(AppTheme.accentAmber)

                            Text(prayerManager.currentLocationName)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(AppTheme.textPrimary)
                                .lineLimit(1)

                            Image(systemName: "chevron.down")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(AppTheme.textTertiary)
                        }
                    }
                }
                .menuStyle(.borderlessButton)

                Spacer(minLength: 4)

                if adzanPlayer.isPlaying {
                    Button(action: {
                        adzanPlayer.stop()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "stop.fill")
                                .font(.system(size: 8.5, weight: .bold))
                            Text("\(L10n.Prayer.stop) (\(L10n.Prayer.localizedPrayerName(adzanPlayer.playingPrayerName)))")
                                .font(.system(size: 10, weight: .semibold))
                                .lineLimit(1)
                        }
                        .foregroundColor(AppTheme.accentRed)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppTheme.accentRed.opacity(0.14))
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(AppTheme.accentRed.opacity(0.3), lineWidth: 0.6))
                    }
                    .buttonStyle(.plain)
                }

                Button(action: {
                    adzanPlayer.isMuted.toggle()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: adzanPlayer.isMuted ? "bell.slash.fill" : "bell.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(adzanPlayer.isMuted ? AppTheme.textTertiary : AppTheme.accentAmber)

                        Text(L10n.Prayer.audioAdzanTitle)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(adzanPlayer.isMuted ? AppTheme.textSecondary : AppTheme.textPrimary)
                            .lineLimit(1)
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

                Button(action: {
                    adzanPlayer.testPlay()
                }) {
                    Image(systemName: adzanPlayer.isPlaying ? "stop.fill" : "play.fill")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundColor(AppTheme.textPrimary)
                        .frame(width: 26, height: 26)
                        .background(AppTheme.badgeBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(AppTheme.cardBorder, lineWidth: 0.5)
                        )
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .help(adzanPlayer.isPlaying ? L10n.Prayer.stopAudio : L10n.Prayer.testAudio)
            }

            HStack(spacing: 8) {
                ForEach(prayerManager.prayerItems) { item in
                    PrayerCardView(item: item)
                }
            }
        }
        .frame(width: NotchLayout.expandedContentWidth, alignment: .top)
    }
}

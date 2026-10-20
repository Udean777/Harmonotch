//
//  MediaDrawerView.swift
//  Harmonotch
//
//

import SwiftUI
import AppKit

struct MediaDrawerView: View {
    @ObservedObject var mediaManager = MediaManager.shared
    @ObservedObject var languageManager = LanguageManager.shared
    @ObservedObject var themeManager = ThemeManager.shared

    var body: some View {
        VStack(spacing: 12) {
            if mediaManager.hasActiveTrack {
                // MARK: - Active Player Card (Artwork, Track Info & Playback Controls)
                HStack(alignment: .center, spacing: 14) {
                    // 1. Album Artwork
                    ZStack {
                        if let art = mediaManager.artworkImage {
                            Image(nsImage: art)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 60, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        } else {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(
                                    LinearGradient(
                                        colors: [AppTheme.accentAmber.opacity(0.35), AppTheme.isDark ? Color.black.opacity(0.8) : Color.white.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 60, height: 60)
                                .overlay(
                                    Image(systemName: mediaManager.mediaSource.iconName)
                                        .font(.system(size: 24))
                                        .foregroundColor(mediaManager.mediaSource.brandColor)
                                )
                        }
                    }
                    .shadow(color: AppTheme.isDark ? Color.black.opacity(0.4) : Color.black.opacity(0.12), radius: 6, x: 0, y: 3)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: AppTheme.isDark
                                        ? [Color.white.opacity(0.35), Color.white.opacity(0.08)]
                                        : [Color.white.opacity(0.85), Color.black.opacity(0.08)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.8
                            )
                    )

                    // 2. Track Meta & Progress
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(mediaManager.trackTitle)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(AppTheme.textPrimary)
                                .lineLimit(1)

                            Spacer()

                            // Source App Badge
                            HStack(spacing: 3) {
                                Image(systemName: mediaManager.mediaSource.iconName)
                                    .font(.system(size: 8))
                                Text(mediaManager.mediaSource.rawValue)
                                    .font(.system(size: 9, weight: .semibold))
                            }
                            .foregroundColor(mediaManager.mediaSource.brandColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(mediaManager.mediaSource.brandColor.opacity(AppTheme.isDark ? 0.15 : 0.10))
                            .cornerRadius(4)
                        }

                        Text(mediaManager.artistName)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(AppTheme.textSecondary)
                            .lineLimit(1)

                        // Scrubber Slider
                        VStack(spacing: 2) {
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(AppTheme.cardBorder)
                                        .frame(height: 4)

                                    Capsule()
                                        .fill(AppTheme.accentAmber)
                                        .frame(width: geo.size.width * CGFloat(mediaManager.progress), height: 4)
                                }
                            }
                            .frame(height: 4)
                            .padding(.top, 4)

                            HStack {
                                Text(mediaManager.formattedPosition)
                                Spacer()
                                Text(mediaManager.formattedDuration)
                            }
                            .font(.system(size: 8, weight: .medium, design: .monospaced))
                            .foregroundColor(AppTheme.textTertiary)
                        }
                    }

                    // 3. Playback Controls
                    HStack(spacing: 8) {
                        Button(action: {
                            mediaManager.previousTrack()
                        }) {
                            Image(systemName: "backward.fill")
                                .font(.system(size: 12))
                                .foregroundColor(AppTheme.textPrimary)
                                .frame(width: 28, height: 28)
                                .background(AppTheme.badgeBackground)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(AppTheme.cardBorder, lineWidth: 0.5))
                        }
                        .buttonStyle(.plain)

                        Button(action: {
                            mediaManager.playPause()
                        }) {
                            Image(systemName: mediaManager.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 14))
                                .foregroundColor(AppTheme.isDark ? .black : .white)
                                .frame(width: 34, height: 34)
                                .background(AppTheme.isDark ? Color.white : Color(red: 0.12, green: 0.12, blue: 0.14))
                                .clipShape(Circle())
                                .shadow(color: AppTheme.isDark ? Color.white.opacity(0.2) : Color.black.opacity(0.15), radius: 4)
                        }
                        .buttonStyle(.plain)

                        Button(action: {
                            mediaManager.nextTrack()
                        }) {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 12))
                                .foregroundColor(AppTheme.textPrimary)
                                .frame(width: 28, height: 28)
                                .background(AppTheme.badgeBackground)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(AppTheme.cardBorder, lineWidth: 0.5))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)

                Divider()
                    .background(AppTheme.divider)
                    .padding(.horizontal, 16)

                // MARK: - Floating Synced Lyrics Section
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "quote.bubble.fill")
                            .font(.system(size: 10))
                            .foregroundColor(AppTheme.accentAmber)

                        Text(L10n.Media.syncedLyricsTitle)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(AppTheme.accentAmber)
                            .textCase(.uppercase)

                        Spacer()

                        Button(action: {
                            mediaManager.refetchLyrics()
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(AppTheme.textTertiary)
                        }
                        .buttonStyle(.plain)

                        if mediaManager.isLoadingLyrics {
                            ProgressView()
                                .scaleEffect(0.6)
                                .frame(width: 14, height: 14)
                        }
                    }
                    .padding(.horizontal, 16)

                    // Lyrics Container
                    ZStack {
                        // 1. Nested Frosted Blur
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(.ultraThinMaterial)

                        // 2. Optical Tint Sheen
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: AppTheme.isDark
                                        ? [Color.white.opacity(0.06), Color.white.opacity(0.02)]
                                        : [Color.white.opacity(0.50), Color.white.opacity(0.20)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )

                        // 3. Directional Specular Stroke
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: AppTheme.isDark
                                        ? [Color.white.opacity(0.28), Color.white.opacity(0.05)]
                                        : [Color.white.opacity(0.85), Color.black.opacity(0.06)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.8
                            )

                        if mediaManager.isInstrumental {
                            HStack(spacing: 6) {
                                Image(systemName: "guitars.fill")
                                    .font(.system(size: 12))
                                Text(L10n.Media.instrumental)
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundColor(AppTheme.textSecondary)
                            .padding(.vertical, 30)
                        } else if mediaManager.isLoadingLyrics {
                            Text(L10n.Media.loadingLyrics)
                                .font(.system(size: 11))
                                .foregroundColor(AppTheme.textTertiary)
                                .padding(.vertical, 30)
                        } else if mediaManager.syncedLyrics.isEmpty {
                            Text(L10n.Media.noLyricsFound)
                                .font(.system(size: 11))
                                .foregroundColor(AppTheme.textTertiary)
                                .padding(.vertical, 30)
                        } else {
                            ScrollViewReader { proxy in
                                ScrollView(.vertical, showsIndicators: false) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        ForEach(Array(mediaManager.syncedLyrics.enumerated()), id: \.element.id) { index, line in
                                            let isCurrent = (index == mediaManager.currentLyricIndex)
                                            Button(action: {
                                                mediaManager.seek(to: line.time)
                                            }) {
                                                Text(line.text)
                                                    .font(.system(
                                                        size: isCurrent ? 13 : 11,
                                                        weight: isCurrent ? .bold : .medium,
                                                        design: .rounded
                                                    ))
                                                    .foregroundColor(isCurrent ? AppTheme.textPrimary : AppTheme.textTertiary)
                                                    .padding(.horizontal, isCurrent ? 8 : 4)
                                                    .padding(.vertical, isCurrent ? 4 : 2)
                                                    .background(
                                                        RoundedRectangle(cornerRadius: 6)
                                                            .fill(isCurrent ? AppTheme.accentAmber.opacity(AppTheme.isDark ? 0.22 : 0.15) : Color.clear)
                                                    )
                                                    .scaleEffect(isCurrent ? 1.02 : 1.0, anchor: .leading)
                                                    .animation(.spring(response: 0.28, dampingFraction: 0.75), value: isCurrent)
                                            }
                                            .buttonStyle(.plain)
                                            .id(index)
                                        }
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                }
                                .onChange(of: mediaManager.currentLyricIndex) { oldValue, newIndex in
                                    if newIndex >= 0 {
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            proxy.scrollTo(newIndex, anchor: .center)
                                        }
                                    }
                                }
                                .onAppear {
                                    scrollToCurrentLyric(proxy: proxy)
                                }
                                .onChange(of: mediaManager.syncedLyrics.count) {
                                    scrollToCurrentLyric(proxy: proxy)
                                }
                            }
                            .mask(
                                LinearGradient(
                                    stops: [
                                        .init(color: .clear, location: 0),
                                        .init(color: .white, location: 0.12),
                                        .init(color: .white, location: 0.88),
                                        .init(color: .clear, location: 1.0)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        }
                    }
                    .frame(height: 180)
                    .padding(.horizontal, 16)
                }
            } else {
                // MARK: - Empty Idle State
                VStack(spacing: 16) {
                    Spacer(minLength: 8)

                    ZStack {
                        Circle()
                            .fill(AppTheme.badgeBackground)
                            .frame(width: 54, height: 54)

                        Image(systemName: "music.note")
                            .font(.system(size: 24))
                            .foregroundColor(AppTheme.accentAmber)
                    }

                    VStack(spacing: 5) {
                        Text(L10n.Media.noTrackPlaying)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(AppTheme.textPrimary)

                        Text(L10n.Media.openMusicPrompt)
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.textSecondary)
                    }

                    HStack(spacing: 12) {
                        Button(action: {
                            openApp(bundleIdentifier: "com.spotify.client", fallbackUrl: "spotify:")
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "music.note.list")
                                    .font(.system(size: 11))
                                Text("Spotify")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundColor(.green)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(Color.green.opacity(AppTheme.isDark ? 0.15 : 0.10))
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)

                        Button(action: {
                            openApp(bundleIdentifier: "com.apple.Music", fallbackUrl: "music:")
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "apple.logo")
                                    .font(.system(size: 11))
                                Text("Apple Music")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundColor(.pink)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(Color.pink.opacity(AppTheme.isDark ? 0.15 : 0.10))
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 4)

                    Spacer(minLength: 12)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 250)
                .padding(.horizontal, 20)
            }
        }
        .frame(width: 540)
        .padding(.bottom, 14)
        .onAppear {
            mediaManager.pollCurrentMediaState()
        }
    }

    private func scrollToCurrentLyric(proxy: ScrollViewProxy) {
        let index = mediaManager.currentLyricIndex
        guard index >= 0 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeInOut(duration: 0.35)) {
                proxy.scrollTo(index, anchor: .center)
            }
        }
    }

    private func openApp(bundleIdentifier: String, fallbackUrl: String) {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        } else if let url = URL(string: fallbackUrl) {
            NSWorkspace.shared.open(url)
        }
    }
}

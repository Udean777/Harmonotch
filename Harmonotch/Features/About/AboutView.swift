import SwiftUI
import AppKit

struct AboutView: View {
    @ObservedObject var languageManager = LanguageManager.shared
    @ObservedObject var themeManager = ThemeManager.shared
    @ObservedObject var updateManager = UpdateManager.shared
    @State private var showingAdhanLicense: Bool = false

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 10) {
                Group {
                    if let nsImage = NSImage(named: "AppLogo") ?? NSImage(named: NSImage.applicationIconName) ?? NSApplication.shared.applicationIconImage {
                        Image(nsImage: nsImage)
                            .resizable()
                    } else {
                        Image("AppLogo")
                            .resizable()
                    }
                }
                .aspectRatio(contentMode: .fit)
                .frame(width: 68, height: 68)
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.4), radius: 8, x: 0, y: 3)

                Text("Harmonotch")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(AppTheme.textPrimary)

                Text(L10n.About.subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)

                HStack(spacing: 6) {
                    Text(L10n.About.version)
                    Text("•")
                    Text(L10n.About.developedBy)
                }
                .font(.system(size: 10, weight: .regular))
                .foregroundColor(AppTheme.textTertiary)

                Button(action: {
                    if updateManager.hasUpdate {
                        updateManager.downloadLatestDMG()
                    } else {
                        updateManager.checkForUpdates(isUserInitiated: true)
                    }
                }) {
                    HStack(spacing: 4) {
                        if updateManager.isChecking || updateManager.isDownloading {
                            ProgressView()
                                .scaleEffect(0.5)
                                .frame(width: 10, height: 10)
                        } else {
                            Image(systemName: updateManager.hasUpdate ? "arrow.down.circle.fill" : "arrow.triangle.2.circlepath")
                                .font(.system(size: 9))
                        }
                        Text(updateManager.hasUpdate ? L10n.Update.updateAvailableTitle(version: updateManager.latestVersion) : L10n.Update.checkForUpdates)
                            .font(.system(size: 10, weight: updateManager.hasUpdate ? .semibold : .medium))
                    }
                    .foregroundColor(updateManager.hasUpdate ? AppTheme.accentAmber : AppTheme.accentCyan)
                }
                .buttonStyle(.plain)
                .disabled(updateManager.isDownloading)
            }
            .padding(.top, 8)

            Divider()
                .background(AppTheme.divider)

            VStack(alignment: .leading, spacing: 10) {
                Text(L10n.About.openSourceCredits)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(AppTheme.accentAmber)
                    .textCase(.uppercase)

                ScrollView(.vertical, showsIndicators: true) {
                    VStack(spacing: 10) {
                        AcknowledgementCard(
                            title: L10n.About.adhanTitle,
                            author: "Batoul Apps",
                            license: "MIT License",
                            description: L10n.About.adhanDesc,
                            iconName: "globe.asia.australia.fill",
                            url: URL(string: "https://github.com/batoulapps/adhan-swift"),
                            onViewLicense: {
                                showingAdhanLicense.toggle()
                            }
                        )

                        if showingAdhanLicense {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("MIT License, Copyright © 2018 Batoul Apps")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundColor(AppTheme.textPrimary)

                                Text("Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the \"Software\"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software...")
                                    .font(.system(size: 8, design: .monospaced))
                                    .foregroundColor(AppTheme.textSecondary)
                                    .lineSpacing(2)
                            }
                            .padding(8)
                            .background(AppTheme.badgeBackground)
                            .cornerRadius(6)
                            .transition(.opacity)
                        }

                        AcknowledgementCard(
                            title: L10n.About.vorssaintTitle,
                            author: "Vorssaint",
                            license: "Open Source",
                            description: L10n.About.vorssaintDesc,
                            iconName: "waveform.circle.fill",
                            url: URL(string: "https://github.com/vorssaint/vorssaint-utils"),
                            onViewLicense: nil
                        )

                        AcknowledgementCard(
                            title: L10n.About.audioTitle,
                            author: "IslamDownload.net",
                            license: "Free Audio",
                            description: L10n.About.audioDesc,
                            iconName: "speaker.wave.2.fill",
                            url: URL(string: "https://islamdownload.net/123801-download-suara-adzan.html"),
                            onViewLicense: nil
                        )

                        AcknowledgementCard(
                            title: L10n.About.appleTechTitle,
                            author: "Apple Inc.",
                            license: "macOS SDK / Darwin",
                            description: L10n.About.appleTechDesc,
                            iconName: "apple.logo",
                            url: nil,
                            onViewLicense: nil
                        )
                    }
                    .padding(.trailing, 2)
                }
                .frame(maxHeight: 200)
            }
            .padding(.horizontal, 16)

            Spacer(minLength: 0)

            HStack {
                Text("MIT License © 2026 Sajudin")
                    .font(.system(size: 9))
                    .foregroundColor(AppTheme.textTertiary)

                Spacer()

                Button(action: {
                    AboutWindowController.shared.close()
                }) {
                    Text(L10n.About.close)
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 4)
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .frame(width: 440, height: 420)
        .background(Color.black)
        .preferredColorScheme(.dark)
    }
}

private struct AcknowledgementCard: View {
    let title: String
    let author: String
    let license: String
    let description: String
    let iconName: String
    let url: URL?
    let onViewLicense: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: iconName)
                .font(.system(size: 14))
                .foregroundColor(.white)
                .frame(width: 22, height: 22)
                .background(AppTheme.badgeBackground)
                .clipShape(RoundedRectangle(cornerRadius: 5))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(AppTheme.textPrimary)

                    Text("•")
                        .font(.system(size: 9))
                        .foregroundColor(AppTheme.textTertiary)

                    Text(author)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(AppTheme.textSecondary)

                    Spacer()

                    Text(license)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.white.opacity(0.12))
                        .cornerRadius(4)
                }

                Text(description)
                    .font(.system(size: 10))
                    .foregroundColor(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    if let url = url {
                        Link(destination: url) {
                            HStack(spacing: 3) {
                                Text(url.host?.contains("github") == true ? "GitHub" : "Website")
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 8))
                            }
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.white)
                        }
                    }

                    if let onViewLicense = onViewLicense {
                        Button(action: onViewLicense) {
                            Text(L10n.About.viewLicense)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.white)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(10)
        .background(AppTheme.cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppTheme.cardBorder, lineWidth: 0.6)
        )
        .cornerRadius(8)
    }
}

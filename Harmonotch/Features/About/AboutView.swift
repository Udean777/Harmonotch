//
//  AboutView.swift
//  Harmonotch
//

import SwiftUI
import AppKit

struct AboutView: View {
    @ObservedObject var languageManager = LanguageManager.shared
    @State private var showingAdhanLicense: Bool = false

    var body: some View {
        VStack(spacing: 16) {
            // MARK: - App Branding Header
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.amberCustom.opacity(0.3), Color.black],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                        .overlay(
                            Circle()
                                .stroke(Color.amberCustom.opacity(0.4), lineWidth: 1)
                        )

                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 26))
                        .foregroundColor(Color.amberCustom)
                }

                Text("Harmonotch")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)

                Text(L10n.About.subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)

                HStack(spacing: 6) {
                    Text(L10n.About.version)
                    Text("•")
                    Text(L10n.About.developedBy)
                }
                .font(.system(size: 10, weight: .regular))
                .foregroundColor(.white.opacity(0.45))
            }
            .padding(.top, 8)

            Divider()
                .background(Color.white.opacity(0.1))

            // MARK: - Open Source Acknowledgements Section
            VStack(alignment: .leading, spacing: 10) {
                Text(L10n.About.openSourceCredits)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color.amberCustom)
                    .textCase(.uppercase)

                ScrollView(.vertical, showsIndicators: true) {
                    VStack(spacing: 10) {
                        // 1. Adhan-Swift
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
                                Text("MIT License — Copyright © 2018 Batoul Apps")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.9))

                                Text("Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the \"Software\"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software...")
                                    .font(.system(size: 8, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.6))
                                    .lineSpacing(2)
                            }
                            .padding(8)
                            .background(Color.white.opacity(0.04))
                            .cornerRadius(6)
                            .transition(.opacity)
                        }

                        // 2. Adzan Audio
                        AcknowledgementCard(
                            title: L10n.About.audioTitle,
                            author: "IslamDownload.net",
                            license: "Free Audio",
                            description: L10n.About.audioDesc,
                            iconName: "speaker.wave.2.fill",
                            url: URL(string: "https://islamdownload.net/123801-download-suara-adzan.html"),
                            onViewLicense: nil
                        )

                        // 3. Apple Technologies
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

            // MARK: - Footer Actions
            HStack {
                Text("MIT License © 2026 Sajudin")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.3))

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
        .background(
            Color(nsColor: .windowBackgroundColor)
                .opacity(0.96)
        )
    }
}

// MARK: - Subview: Acknowledgement Card
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
                .foregroundColor(Color.amberCustom)
                .frame(width: 22, height: 22)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 5))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)

                    Text("•")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.3))

                    Text(author)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.65))

                    Spacer()

                    Text(license)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.green.opacity(0.9))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.green.opacity(0.12))
                        .cornerRadius(4)
                }

                Text(description)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.55))
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
                            .foregroundColor(.cyan)
                        }
                    }

                    if let onViewLicense = onViewLicense {
                        Button(action: onViewLicense) {
                            Text(L10n.About.viewLicense)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(Color.amberCustom)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.04))
        .cornerRadius(8)
    }
}

import AppKit
import SwiftUI

struct AIUsageDrawerView: View {
    @ObservedObject var usageManager = AIUsageManager.shared
    @ObservedObject var languageManager = LanguageManager.shared
    @State private var hasCopiedAgy: Bool = false

    var body: some View {
        VStack(spacing: 8) {
            headerBar

            if usageManager.availableProviders.count > 1 {
                providerSelector
            }

            if let snapshot = usageManager.currentSnapshot {
                loadedView(snapshot: snapshot)
            } else if usageManager.isMonitoring && usageManager.snapshots.isEmpty {
                loadingView
            } else {
                unavailableView(for: usageManager.selectedProvider)
            }
        }
        .frame(width: NotchLayout.expandedContentWidth, alignment: .top)
        .onAppear {
            usageManager.startMonitoring()
        }
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack(alignment: .center, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(AppTheme.accentCyan)

                Text(L10n.AI.title)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)
            }

            Spacer(minLength: 4)

            connectionBadge

            Button(action: {
                Task {
                    await usageManager.refresh()
                }
            }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(AppTheme.textSecondary)
                    .padding(5)
                    .background(
                        Circle()
                            .fill(AppTheme.badgeBackground)
                            .overlay(Circle().stroke(AppTheme.cardBorder, lineWidth: 0.6))
                    )
            }
            .buttonStyle(.plain)
            .help(L10n.AI.refresh)
        }
    }

    // MARK: - Provider Selector

    private var providerSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 5) {
                ForEach(usageManager.availableProviders, id: \.self) { provider in
                    let isSelected = usageManager.selectedProvider == provider
                    let isConnected = usageManager.snapshots[provider]?.isConnected == true
                    Button(action: {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                            usageManager.selectedProvider = provider
                        }
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: provider.iconName)
                                .font(.system(size: 9.5, weight: .semibold))

                            Text(provider.shortName)
                                .font(.system(size: 10, weight: isSelected ? .bold : .medium))

                            Circle()
                                .fill(isConnected ? AppTheme.accentGreen : AppTheme.textTertiary.opacity(0.6))
                                .frame(width: 4.5, height: 4.5)
                        }
                        .foregroundColor(isSelected ? AppTheme.textPrimary : AppTheme.textSecondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3.5)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(isSelected ? AppTheme.tabActiveBackground : AppTheme.cardBackground.opacity(0.6))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .stroke(isSelected ? AppTheme.accentCyan.opacity(0.6) : AppTheme.cardBorder, lineWidth: 0.6)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 1)
        }
    }

    private var connectionBadge: some View {
        let isConnected = usageManager.currentSnapshot?.isConnected == true
        return HStack(spacing: 4) {
            Circle()
                .fill(isConnected ? AppTheme.accentGreen : AppTheme.textTertiary)
                .frame(width: 6, height: 6)

            Text(isConnected ? L10n.AI.connected : L10n.AI.offline)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(isConnected ? AppTheme.textPrimary : AppTheme.textTertiary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3.5)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(AppTheme.badgeBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(AppTheme.cardBorder, lineWidth: 0.6)
                )
        )
    }

    // MARK: - Loaded View

    @ViewBuilder
    private func loadedView(snapshot: AIAgentQuotaSnapshot) -> some View {
        if snapshot.models.isEmpty {
            VStack(spacing: 6) {
                agentOverviewHeader(snapshot: snapshot)

                Text(L10n.AI.noActiveAgent)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(AppTheme.textSecondary)
                    .padding(.vertical, 16)
            }
            .padding(10)
            .background(cardBackground)
        } else {
            VStack(spacing: 7) {
                agentOverviewHeader(snapshot: snapshot)

                let showScroll = snapshot.models.count > 5
                let contentHeight = CGFloat(min(max(snapshot.models.count, 1), 5)) * 36
                ScrollView(.vertical, showsIndicators: showScroll) {
                    VStack(spacing: 6) {
                        ForEach(snapshot.models) { model in
                            modelQuotaRow(model: model)
                        }
                    }
                    .padding(.trailing, showScroll ? 4 : 0)
                }
                .scrollBounceBehavior(.basedOnSize)
                .frame(maxHeight: contentHeight)
            }
            .padding(10)
            .background(cardBackground)
        }
    }

    private func agentOverviewHeader(snapshot: AIAgentQuotaSnapshot) -> some View {
        HStack(alignment: .center, spacing: 6) {
            Image(systemName: snapshot.provider.iconName)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(AppTheme.accentCyan)

            Text(snapshot.provider.displayName)
                .font(.system(size: 11.5, weight: .bold))
                .foregroundColor(AppTheme.textPrimary)

            if let tier = snapshot.userTier {
                Text(tier)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(AppTheme.accentAmber)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1.5)
                    .background(
                        Capsule()
                            .fill(AppTheme.accentAmber.opacity(0.14))
                    )
            }

            Spacer()

            Text(snapshot.endpointDescription)
                .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                .foregroundColor(AppTheme.textTertiary)
                .lineLimit(1)
        }
    }

    private func modelQuotaRow(model: AIModelQuota) -> some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(model.label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(1)

                Spacer(minLength: 8)

                if let countdown = model.formattedResetCountdown {
                    HStack(spacing: 3) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 8.5))
                        Text(countdown)
                            .font(.system(size: 9.5, weight: .medium))
                    }
                    .foregroundColor(AppTheme.textSecondary)
                }

                Text("\(model.remainingPercentage)%")
                    .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                    .foregroundColor(progressColor(for: model.remainingFraction))
                    .monospacedDigit()
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppTheme.cardBorder.opacity(0.4))
                        .frame(height: 5)

                    Capsule()
                        .fill(progressColor(for: model.remainingFraction))
                        .frame(
                            width: max(4, geo.size.width * CGFloat(model.remainingFraction)),
                            height: 5
                        )
                }
            }
            .frame(height: 5)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Unavailable View

    @ViewBuilder
    private func unavailableView(for provider: AIProviderType) -> some View {
        if provider == .antigravity {
            antigravitySetupView
        } else {
            genericUnavailableView(for: provider)
        }
    }

    private var antigravitySetupView: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 7) {
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(AppTheme.accentCyan)

                Text(L10n.AI.antigravityNotDetectedTitle)
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundColor(AppTheme.textPrimary)

                Spacer()

                Text("CLI Setup")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(AppTheme.accentAmber)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(AppTheme.accentAmber.opacity(0.14))
                    )
            }

            Text(L10n.AI.antigravityNotDetectedDesc)
                .font(.system(size: 10, weight: .regular))
                .foregroundColor(AppTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 3.5) {
                stepRow(icon: "1.circle.fill", text: L10n.AI.antigravityStep1)
                stepRow(icon: "2.circle.fill", text: L10n.AI.antigravityStep2)
                stepRow(icon: "3.circle.fill", text: L10n.AI.antigravityStep3)
            }
            .padding(.vertical, 2)

            HStack(spacing: 8) {
                Button(action: {
                    if let url = URL(string: "https://antigravity.google") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 9.5))
                        Text(L10n.AI.openDocs)
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(AppTheme.textPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4.5)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(AppTheme.badgeBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .stroke(AppTheme.cardBorder, lineWidth: 0.6)
                            )
                    )
                }
                .buttonStyle(.plain)

                Button(action: {
                    copyToClipboard("agy")
                    withAnimation(.easeInOut(duration: 0.2)) {
                        hasCopiedAgy = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        withAnimation {
                            hasCopiedAgy = false
                        }
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: hasCopiedAgy ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 9.5))
                        Text(hasCopiedAgy ? L10n.AI.copied : L10n.AI.copyLoginCommand)
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(hasCopiedAgy ? AppTheme.accentGreen : AppTheme.accentCyan)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4.5)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(hasCopiedAgy ? AppTheme.accentGreen.opacity(0.12) : AppTheme.accentCyan.opacity(0.12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .stroke((hasCopiedAgy ? AppTheme.accentGreen : AppTheme.accentCyan).opacity(0.4), lineWidth: 0.6)
                            )
                    )
                }
                .buttonStyle(.plain)

                Spacer()
            }

            Divider()
                .background(AppTheme.divider)

            HStack(spacing: 5) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 9.5))
                    .foregroundColor(AppTheme.accentGreen)

                Text(L10n.AI.safeReadNote)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(AppTheme.textTertiary)
                    .lineLimit(1)
            }
        }
        .padding(10)
        .background(cardBackground)
    }

    private func stepRow(icon: String, text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 9.5))
                .foregroundColor(AppTheme.accentCyan.opacity(0.85))

            Text(text)
                .font(.system(size: 9.5, weight: .medium))
                .foregroundColor(AppTheme.textPrimary.opacity(0.9))
                .lineLimit(1)
        }
    }

    private func copyToClipboard(_ string: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
    }

    private func genericUnavailableView(for provider: AIProviderType) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: provider.iconName)
                    .font(.system(size: 16))
                    .foregroundColor(AppTheme.accentCyan)

                VStack(alignment: .leading, spacing: 2) {
                    Text(provider.displayName)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(AppTheme.textPrimary)

                    Text(L10n.AI.noActiveAgent)
                        .font(.system(size: 10.5, weight: .regular))
                        .foregroundColor(AppTheme.textSecondary)
                }

                Spacer()
            }

            Divider()
                .background(AppTheme.divider)

            HStack(spacing: 6) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 10))
                    .foregroundColor(AppTheme.accentGreen)

                Text(L10n.AI.safeReadNote)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundColor(AppTheme.textTertiary)

                Spacer()
            }
        }
        .padding(12)
        .background(cardBackground)
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.8)
            Text("Checking local AI Agent quotas...")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundColor(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 70)
        .background(cardBackground)
    }

    // MARK: - Helpers

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(AppTheme.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(AppTheme.cardBorder, lineWidth: 0.6)
            )
    }

    private func progressColor(for fraction: Double) -> Color {
        if fraction > 0.40 {
            return AppTheme.accentGreen
        } else if fraction > 0.15 {
            return AppTheme.accentAmber
        } else {
            return AppTheme.accentRed
        }
    }
}

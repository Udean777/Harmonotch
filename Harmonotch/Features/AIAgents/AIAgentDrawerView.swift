import AppKit
import SwiftUI

/// Expanded Notch Drawer view for AI Agents.
/// Shows the agent pinned from the Menu Bar; switching providers stays in the Menu Bar.
struct AIAgentDrawerView: View {
  @ObservedObject private var quotaService = AIAgentQuotaService.shared
  @AppStorage("Harmonotch_SelectedNotchAIAgent") private var selectedNotchAgent: String =
    AIAgentKind.gemini.rawValue
  @State private var copiedCommand: Bool = false

  private var activeKind: AIAgentKind {
    AIAgentKind(rawValue: selectedNotchAgent) ?? .gemini
  }

  private var activeAgent: AIAgentStatusItem? {
    quotaService.agents.first(where: { $0.kind == activeKind })
  }

  var body: some View {
    VStack(spacing: 7) {
      headerBar

      if quotaService.isScanning && quotaService.agents.isEmpty {
        scanningStateView
      } else if let agent = activeAgent {
        providerCard(for: agent)
      } else if !quotaService.hasCompletedInitialScan {
        initialScanPrompt
      } else {
        providerNotInstalledCard
      }

      footerBar
    }
    .onAppear {
      if !quotaService.hasCompletedInitialScan && !quotaService.isScanning {
        quotaService.checkInstalledAgents()
      }
    }
  }

  // MARK: - Header

  private var headerBar: some View {
    HStack(alignment: .center, spacing: 6) {
      Image(systemName: activeKind.icon)
        .font(.system(size: 12, weight: .bold))
        .foregroundColor(AppTheme.accentCyan)

      Text(activeKind.displayName)
        .font(.system(size: 12, weight: .bold))
        .foregroundColor(AppTheme.textPrimary)
        .lineLimit(1)

      if let version = activeAgent?.version, !version.isEmpty {
        Text("v\(version)")
          .font(.system(size: 8.5, weight: .medium, design: .monospaced))
          .foregroundColor(AppTheme.textTertiary)
          .lineLimit(1)
      }

      Spacer(minLength: 4)

      if let agent = activeAgent {
        statusBadge(for: agent.authStatus)
      }

      refreshButton
    }
  }

  private var refreshButton: some View {
    Button {
      quotaService.checkInstalledAgents(force: true)
    } label: {
      Group {
        if quotaService.isScanning {
          ProgressView()
            .controlSize(.mini)
        } else {
          Image(systemName: "arrow.clockwise")
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(AppTheme.textSecondary)
        }
      }
      .frame(width: 22, height: 22)
      .background(
        RoundedRectangle(cornerRadius: 6, style: .continuous)
          .fill(AppTheme.badgeBackground)
          .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
              .stroke(AppTheme.cardBorder, lineWidth: 0.5)
          )
      )
    }
    .buttonStyle(.plain)
    .disabled(quotaService.isScanning)
    .help(L10n.AIAgents.refreshAgents)
    .accessibilityLabel(L10n.AIAgents.refreshAgents)
  }

  // MARK: - Provider Card (When Installed & Available)

  private func providerCard(for agent: AIAgentStatusItem) -> some View {
    let progressMetrics = agent.quotaProgressMetrics
    let infoMetrics = agent.metadataMetrics

    return VStack(alignment: .leading, spacing: 6) {
      switch agent.authStatus {
      case .authenticated:
        if !progressMetrics.isEmpty {
          VStack(spacing: 5) {
            ForEach(progressMetrics) { metric in
              metricRow(metric)
            }
          }
        }

        if !infoMetrics.isEmpty {
          VStack(alignment: .leading, spacing: 3) {
            ForEach(infoMetrics) { metric in
              HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(metric.label)
                  .font(AppTypography.micro(.medium))
                  .foregroundColor(AppTheme.textTertiary)
                  .lineLimit(1)

                Spacer(minLength: 4)

                if let extra = metric.resetDescription, !extra.isEmpty {
                  Text(extra)
                    .font(AppTypography.micro(.regular))
                    .foregroundColor(AppTheme.textTertiary)
                    .lineLimit(1)
                }

                Text(metric.valueText)
                  .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                  .foregroundColor(AppTheme.textPrimary)
                  .lineLimit(1)
              }
            }
          }
          .padding(.horizontal, 8)
          .padding(.vertical, 5)
          .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
              .fill(AppTheme.badgeBackground.opacity(0.65))
          )
        }

      case .failed(let reason):
        let cmd = agent.kind.loginCommandHint
        VStack(alignment: .leading, spacing: 5) {
          Text(reason)
            .font(AppTypography.caption2(.semibold))
            .foregroundColor(AppTheme.accentRed)
            .lineLimit(1)

          HStack(spacing: 6) {
            Image(systemName: "terminal")
              .font(.system(size: 8.5, weight: .semibold))
              .foregroundColor(AppTheme.textTertiary)

            Text(cmd)
              .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
              .foregroundColor(AppTheme.textPrimary)
              .lineLimit(1)

            Spacer(minLength: 4)

            Button {
              NSPasteboard.general.clearContents()
              NSPasteboard.general.setString(cmd, forType: .string)
              withAnimation(.easeInOut(duration: 0.14)) {
                copiedCommand = true
              }
              DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                withAnimation(.easeInOut(duration: 0.14)) {
                  copiedCommand = false
                }
              }
            } label: {
              HStack(spacing: 3) {
                Image(systemName: copiedCommand ? "checkmark" : "doc.on.doc")
                  .font(.system(size: 8, weight: .bold))
                Text(copiedCommand ? L10n.AIAgents.copiedCommand : L10n.AIAgents.copyCommand)
                  .font(AppTypography.micro(.semibold))
              }
              .foregroundColor(copiedCommand ? AppTheme.accentGreen : AppTheme.accentCyan)
              .padding(.horizontal, 6)
              .padding(.vertical, 2.5)
              .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                  .fill((copiedCommand ? AppTheme.accentGreen : AppTheme.accentCyan).opacity(0.14))
              )
            }
            .buttonStyle(.plain)
          }
          .padding(.horizontal, 8)
          .padding(.vertical, 4.5)
          .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
              .fill(AppTheme.badgeBackground)
          )
        }
      }
    }
    .padding(9)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: 10, style: .continuous)
        .fill(AppTheme.cardBackground)
        .overlay(
          RoundedRectangle(cornerRadius: 10, style: .continuous)
            .stroke(AppTheme.cardBorder, lineWidth: 0.6)
        )
    )
    .help(agent.binaryPath)
  }

  // MARK: - Provider Not Installed State

  private var providerNotInstalledCard: some View {
    VStack(spacing: 5) {
      HStack(spacing: 6) {
        Image(systemName: "exclamationmark.triangle.fill")
          .font(.system(size: 11.5, weight: .semibold))
          .foregroundColor(AppTheme.accentAmber)

        Text(L10n.AIAgents.agentNotInstalled(activeKind.displayName))
          .font(.system(size: 11, weight: .semibold))
          .foregroundColor(AppTheme.textPrimary)
          .lineLimit(1)
      }

      Text(L10n.AIAgents.selectDifferentProviderHint)
        .font(.system(size: 9.5, weight: .regular))
        .foregroundColor(AppTheme.textSecondary)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(11)
    .frame(maxWidth: .infinity)
    .background(
      RoundedRectangle(cornerRadius: 10, style: .continuous)
        .fill(AppTheme.cardBackground)
        .overlay(
          RoundedRectangle(cornerRadius: 10, style: .continuous)
            .stroke(AppTheme.cardBorder, lineWidth: 0.6)
        )
    )
  }

  // MARK: - Scanning / Initial States

  private var initialScanPrompt: some View {
    VStack(spacing: 7) {
      Text(L10n.AIAgents.setupTitle)
        .font(.system(size: 12, weight: .bold))
        .foregroundColor(AppTheme.textPrimary)

      Text(L10n.AIAgents.setupSubtitle)
        .font(.system(size: 10, weight: .regular))
        .foregroundColor(AppTheme.textSecondary)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 16)

      Button {
        quotaService.checkInstalledAgents(force: true)
      } label: {
        HStack(spacing: 5) {
          Image(systemName: "magnifyingglass")
            .font(.system(size: 10, weight: .bold))
          Text(L10n.AIAgents.checkButton)
            .font(.system(size: 11, weight: .semibold))
        }
        .foregroundColor(AppTheme.textPrimary)
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(
          RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(AppTheme.accentCyan.opacity(0.24))
            .overlay(
              RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(AppTheme.accentCyan.opacity(0.55), lineWidth: 0.8)
            )
        )
      }
      .buttonStyle(.plain)
    }
    .padding(.vertical, 10)
    .frame(maxWidth: .infinity)
  }

  private var scanningStateView: some View {
    HStack(spacing: 10) {
      ProgressView()
        .controlSize(.small)

      Text(L10n.AIAgents.scanningText)
        .font(.system(size: 11, weight: .medium))
        .foregroundColor(AppTheme.textSecondary)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 18)
  }

  // MARK: - Badges & Metrics

  private func statusBadge(for status: AIAgentAuthStatus) -> some View {
    let isAuth = status.isAuthenticated
    let badgeColor = isAuth ? AppTheme.accentGreen : AppTheme.accentRed

    let badgeText: String = {
      switch status {
      case .authenticated(let detail):
        if let detail, !detail.isEmpty {
          return detail
        }
        return L10n.AIAgents.statusActive
      case .failed:
        return L10n.AIAgents.statusFailed
      }
    }()

    return HStack(spacing: 4) {
      Circle()
        .fill(badgeColor)
        .frame(width: 5, height: 5)

      Text(badgeText)
        .font(.system(size: 8.5, weight: .bold))
        .foregroundColor(isAuth ? AppTheme.textPrimary : AppTheme.accentRed)
        .lineLimit(1)
    }
    .padding(.horizontal, 6)
    .padding(.vertical, 2.5)
    .background(
      RoundedRectangle(cornerRadius: 5, style: .continuous)
        .fill(badgeColor.opacity(0.14))
        .overlay(
          RoundedRectangle(cornerRadius: 5, style: .continuous)
            .stroke(badgeColor.opacity(0.38), lineWidth: 0.6)
        )
    )
  }

  private func metricRow(_ metric: AIAgentQuotaMetric) -> some View {
    VStack(alignment: .leading, spacing: 3) {
      HStack(alignment: .firstTextBaseline, spacing: 6) {
        Text(metric.label)
          .font(.system(size: 9.5, weight: .medium))
          .foregroundColor(AppTheme.textSecondary)
          .lineLimit(1)

        Spacer(minLength: 4)

        if let reset = metric.resetDescription, !reset.isEmpty {
          Text(reset)
            .font(.system(size: 8.5, weight: .regular))
            .foregroundColor(AppTheme.textTertiary)
            .lineLimit(1)
        }

        Text(metric.valueText)
          .font(.system(size: 10, weight: .bold, design: .rounded))
          .monospacedDigit()
          .foregroundColor(AppTheme.textPrimary)
          .lineLimit(1)
      }

      if let ratio = metric.remainingRatio {
        GeometryReader { geo in
          let clamped = max(0, min(1, ratio))
          ZStack(alignment: .leading) {
            Capsule()
              .fill(AppTheme.cardBorder)

            Capsule()
              .fill(progressColor(for: clamped))
              .frame(width: max(4, geo.size.width * clamped))
          }
        }
        .frame(height: 4.5)
      }
    }
  }

  private func progressColor(for remainingRatio: Double) -> Color {
    if remainingRatio <= 0.15 {
      return AppTheme.accentRed
    } else if remainingRatio <= 0.35 {
      return AppTheme.accentAmber
    }
    return AppTheme.accentGreen
  }

  // MARK: - Footer

  private var footerBar: some View {
    HStack(spacing: 5) {
      Image(systemName: "menubar.dock.rectangle")
        .font(.system(size: 8.5))
        .foregroundColor(AppTheme.textTertiary)

      Text(L10n.AIAgents.selectedInMenuBar)
        .font(.system(size: 8.5, weight: .regular))
        .foregroundColor(AppTheme.textTertiary)
        .lineLimit(1)

      Spacer(minLength: 4)

      if let lastChecked = quotaService.lastCheckedAt {
        Text(TimeFormatting.relativeText(for: lastChecked))
          .font(.system(size: 8.5, weight: .regular))
          .foregroundColor(AppTheme.textTertiary)
      }
    }
    .padding(.horizontal, 2)
  }
}

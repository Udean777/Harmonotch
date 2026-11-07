import AppKit
import SwiftUI

struct DashboardAgentsSection: View {
  @ObservedObject private var quotaService = AIAgentQuotaService.shared
  @AppStorage("Harmonotch_SelectedNotchAIAgent") private var selectedNotchAgent: String =
    AIAgentKind.gemini.rawValue
  @State private var expandedAgentIds: Set<String> = []
  @State private var copiedAgentId: String? = nil

  var body: some View {
    Group {
      if quotaService.isScanning && quotaService.agents.isEmpty {
        scanningCard
      } else if !quotaService.hasCompletedInitialScan {
        initialSetupCard
      } else if quotaService.agents.isEmpty {
        noAgentsFoundCard
      } else {
        unifiedAgentsView
      }
    }
    .onAppear {
      if !quotaService.hasCompletedInitialScan && !quotaService.isScanning {
        quotaService.checkInstalledAgents()
      }
    }
  }

  // MARK: - Unified Single-Page View with Per-Item Expand

  private var unifiedAgentsView: some View {
    VStack(spacing: 8) {
      topStatusHeader

      ForEach(quotaService.agents) { agent in
        agentCard(for: agent)
      }

      bottomFooterBar
    }
  }

  private var bottomFooterBar: some View {
    HStack(spacing: 6) {
      if let checkedAt = quotaService.lastCheckedAt {
        Text(TimeFormatting.relativeText(for: checkedAt))
          .font(AppTypography.micro(.medium))
          .foregroundColor(AppTheme.textTertiary)
          .lineLimit(1)
      }

      Spacer(minLength: 4)

      Button {
        quotaService.checkInstalledAgents(force: true)
      } label: {
        HStack(spacing: 4) {
          if quotaService.isScanning {
            ProgressView()
              .controlSize(.mini)
          } else {
            Image(systemName: "arrow.clockwise")
              .font(.system(size: 9, weight: .bold))
          }
          Text(L10n.AIAgents.refreshAgents)
            .font(AppTypography.micro(.semibold))
        }
        .foregroundColor(AppTheme.textSecondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
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
      .disabled(quotaService.isScanning)
      .help(L10n.AIAgents.refreshAgents)
    }
    .padding(.horizontal, 2)
    .padding(.top, 2)
  }

  private var topStatusHeader: some View {
    let activeCount = quotaService.agents.filter { $0.authStatus.isAuthenticated }.count
    let failedCount = quotaService.agents.count - activeCount

    return HStack(spacing: 6) {
      Circle()
        .fill(failedCount > 0 ? AppTheme.accentAmber : AppTheme.accentGreen)
        .frame(width: 6, height: 6)
        .accessibilityHidden(true)

      Text(L10n.AIAgents.summaryCount(active: activeCount, failed: failedCount))
        .font(AppTypography.caption2(.semibold))
        .foregroundColor(failedCount > 0 ? AppTheme.accentAmber : AppTheme.textSecondary)
        .lineLimit(1)

      if let checkedAt = quotaService.lastCheckedAt {
        Text("• \(TimeFormatting.relativeText(for: checkedAt))")
          .font(AppTypography.micro(.medium))
          .foregroundColor(AppTheme.textTertiary)
          .lineLimit(1)
      }

      Spacer(minLength: 4)

      Button {
        quotaService.checkInstalledAgents(force: true)
      } label: {
        HStack(spacing: 4) {
          if quotaService.isScanning {
            ProgressView()
              .controlSize(.mini)
          } else {
            Image(systemName: "arrow.clockwise")
              .font(.system(size: 9, weight: .bold))
          }
          Text(L10n.AIAgents.refreshAgents)
            .font(AppTypography.micro(.semibold))
        }
        .foregroundColor(AppTheme.textSecondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
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
      .disabled(quotaService.isScanning)
      .help(L10n.AIAgents.refreshAgents)
      .accessibilityLabel(L10n.AIAgents.refreshAgents)
    }
    .padding(.horizontal, 2)
  }

  // MARK: - Collapsible Agent Card

  private func agentCard(for agent: AIAgentStatusItem) -> some View {
    let isFailed = !agent.authStatus.isAuthenticated
    let isPinnedToNotch = selectedNotchAgent == agent.kind.rawValue
    let isExpanded = expandedAgentIds.contains(agent.id)
    let progressMetrics = agent.quotaProgressMetrics
    let infoMetrics = agent.metadataMetrics

    return VStack(alignment: .leading, spacing: 8) {
      // Top Row: Clickable Identity Summary + 1-Click Notch Pin + Expand Button
      HStack(alignment: .center, spacing: 7) {
        Button {
          toggleExpanded(for: agent.id)
        } label: {
          HStack(alignment: .center, spacing: 8) {
            ZStack {
              RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(
                  isFailed
                    ? AppTheme.accentRed.opacity(0.14)
                    : (isPinnedToNotch ? AppTheme.accentCyan.opacity(0.18) : AppTheme.badgeBackground)
                )
                .frame(width: 24, height: 24)

              Image(systemName: agent.kind.icon)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundColor(
                  isFailed
                    ? AppTheme.accentRed
                    : (isPinnedToNotch ? AppTheme.accentCyan : AppTheme.textPrimary)
                )
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1.5) {
              HStack(spacing: 5) {
                Text(agent.kind.displayName)
                  .font(AppTypography.subheadline(.bold))
                  .foregroundColor(AppTheme.textPrimary)
                  .lineLimit(1)

                if let version = agent.version, !version.isEmpty {
                  Text("v\(version)")
                    .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                    .foregroundColor(AppTheme.textTertiary)
                    .lineLimit(1)
                }
              }

              collapsedSubtitle(for: agent)
            }

            Spacer(minLength: 4)
          }
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(agent.binaryPath)

        notchPinButton(for: agent.kind, isPinned: isPinnedToNotch)

        expandToggleButton(for: agent, isExpanded: isExpanded)
      }

      // Expanded Details: All Models, Quota Bars, or Login Recovery
      if isExpanded {
        Divider()
          .background(AppTheme.divider)

        switch agent.authStatus {
        case .authenticated:
          if !progressMetrics.isEmpty {
            VStack(spacing: 6) {
              ForEach(progressMetrics) { metric in
                metricProgressRow(metric)
              }
            }
          }

          if !infoMetrics.isEmpty {
            metadataStrip(metrics: infoMetrics)
          }

          if progressMetrics.isEmpty && infoMetrics.isEmpty,
             let note = agent.statusNote, !note.isEmpty
          {
            Text(note)
              .font(AppTypography.caption2(.medium))
              .foregroundColor(AppTheme.textSecondary)
          }

        case .failed(let reason):
          failedRecoveryBox(for: agent, reason: reason)
        }
      }
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: 10, style: .continuous)
        .fill(AppTheme.cardBackground)
        .overlay(
          RoundedRectangle(cornerRadius: 10, style: .continuous)
            .stroke(
              isPinnedToNotch ? AppTheme.accentCyan.opacity(0.45) : AppTheme.cardBorder,
              lineWidth: isPinnedToNotch ? 0.9 : 0.6
            )
        )
    )
  }

  private func toggleExpanded(for id: String) {
    withAnimation(.easeInOut(duration: 0.16)) {
      if expandedAgentIds.contains(id) {
        expandedAgentIds.remove(id)
      } else {
        expandedAgentIds.insert(id)
      }
    }
  }

  private func expandToggleButton(for agent: AIAgentStatusItem, isExpanded: Bool) -> some View {
    let label = isExpanded ? L10n.AIAgents.hideDetails : L10n.AIAgents.showDetails
    return Button {
      toggleExpanded(for: agent.id)
    } label: {
      Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
        .font(.system(size: 9.5, weight: .bold))
        .foregroundColor(isExpanded ? AppTheme.textPrimary : AppTheme.textSecondary)
        .frame(width: 24, height: 24)
        .background(
          RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(isExpanded ? AppTheme.accentCyan.opacity(0.16) : AppTheme.badgeBackground)
            .overlay(
              RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(
                  isExpanded ? AppTheme.accentCyan.opacity(0.45) : AppTheme.cardBorder,
                  lineWidth: 0.6
                )
            )
        )
    }
    .buttonStyle(.plain)
    .help(label)
    .accessibilityLabel("\(agent.kind.displayName), \(label)")
  }

  @ViewBuilder
  private func collapsedSubtitle(for agent: AIAgentStatusItem) -> some View {
    switch agent.authStatus {
    case .authenticated(let detail):
      HStack(spacing: 4) {
        Circle()
          .fill(
            agent.primaryQuotaMetric?.remainingRatio.map { progressColor(for: max(0, min(1, $0))) }
              ?? AppTheme.accentGreen
          )
          .frame(width: 5, height: 5)

        if let quota = agent.primaryQuotaMetric {
          Text(quota.valueText)
            .font(AppTypography.micro(.bold, design: .rounded))
            .monospacedDigit()
            .foregroundColor(AppTheme.textPrimary)
            .lineLimit(1)

          if let model = agent.activeModelSummary {
            Text("• \(model)")
              .font(AppTypography.micro(.medium))
              .foregroundColor(AppTheme.textSecondary)
              .lineLimit(1)
          } else {
            Text("• \(quota.label)")
              .font(AppTypography.micro(.medium))
              .foregroundColor(AppTheme.textSecondary)
              .lineLimit(1)
          }
        } else {
          Text(
            agent.activeModelSummary
              ?? agent.statusNote
              ?? detail
              ?? L10n.AIAgents.statusActive
          )
          .font(AppTypography.micro(.medium))
          .foregroundColor(AppTheme.textSecondary)
          .lineLimit(1)
        }
      }
    case .failed:
      HStack(spacing: 4) {
        Circle()
          .fill(AppTheme.accentRed)
          .frame(width: 5, height: 5)

        Text(L10n.AIAgents.statusFailed)
          .font(AppTypography.micro(.semibold))
          .foregroundColor(AppTheme.accentRed)
          .lineLimit(1)
      }
    }
  }

  private func notchPinButton(for kind: AIAgentKind, isPinned: Bool) -> some View {
    Button {
      withAnimation(.easeInOut(duration: 0.14)) {
        selectedNotchAgent = kind.rawValue
        UserDefaults.standard[UserDefaultsKeys.selectedNotchAIAgent] = kind.rawValue
        NotificationCenter.default.post(name: .notchAIAgentChanged, object: kind.rawValue)
      }
      if isPinned {
        NotchViewModel.shared.selectedTab = .agents
        NotchViewModel.shared.isExpanded = true
      }
    } label: {
      HStack(spacing: 4) {
        Image(
          systemName: isPinned
            ? "menubar.dock.rectangle.badge.record"
            : "menubar.dock.rectangle"
        )
        .font(.system(size: 8.5, weight: .semibold))

        Text(isPinned ? L10n.AIAgents.activeInNotchBadge : L10n.AIAgents.showInNotchTitle)
          .font(AppTypography.micro(isPinned ? .bold : .semibold))
          .lineLimit(1)
      }
      .foregroundColor(isPinned ? AppTheme.accentCyan : AppTheme.textSecondary)
      .padding(.horizontal, 7)
      .padding(.vertical, 3.5)
      .background(
        RoundedRectangle(cornerRadius: 6, style: .continuous)
          .fill(isPinned ? AppTheme.accentCyan.opacity(0.16) : AppTheme.badgeBackground)
          .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
              .stroke(
                isPinned ? AppTheme.accentCyan.opacity(0.45) : AppTheme.cardBorder,
                lineWidth: 0.6
              )
          )
      )
    }
    .buttonStyle(.plain)
    .help(isPinned ? L10n.Menu.openDrawer : L10n.AIAgents.showInNotchTitle)
    .accessibilityLabel(
      "\(kind.displayName), \(isPinned ? L10n.AIAgents.activeInNotchBadge : L10n.AIAgents.showInNotchTitle)"
    )
  }

  // MARK: - Quota Bars & Compact Metadata Strip

  private func metricProgressRow(_ metric: AIAgentQuotaMetric) -> some View {
    VStack(alignment: .leading, spacing: 3.5) {
      HStack(alignment: .firstTextBaseline, spacing: 6) {
        Text(metric.label)
          .font(AppTypography.caption(.medium))
          .foregroundColor(AppTheme.textSecondary)
          .lineLimit(1)

        Spacer(minLength: 4)

        if let reset = metric.resetDescription, !reset.isEmpty {
          Text(reset)
            .font(AppTypography.micro(.regular))
            .foregroundColor(AppTheme.textTertiary)
            .lineLimit(1)
        }

        Text(metric.valueText)
          .font(AppTypography.footnote(.bold, design: .rounded))
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
        .frame(height: 5)
      }
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(
      "\(metric.label): \(metric.valueText)\(metric.resetDescription.map { ", \($0)" } ?? "")"
    )
  }

  private func metadataStrip(metrics: [AIAgentQuotaMetric]) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      ForEach(metrics) { metric in
        VStack(alignment: .leading, spacing: 1.5) {
          HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(metric.label)
              .font(AppTypography.micro(.medium))
              .foregroundColor(AppTheme.textTertiary)
              .lineLimit(1)

            Spacer(minLength: 4)

            Text(metric.valueText)
              .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
              .foregroundColor(AppTheme.textPrimary)
              .lineLimit(1)
          }

          if let extra = metric.resetDescription, !extra.isEmpty {
            Text(extra)
              .font(AppTypography.micro(.regular))
              .foregroundColor(AppTheme.textSecondary)
              .fixedSize(horizontal: false, vertical: true)
          }
        }
      }
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 5.5)
    .background(
      RoundedRectangle(cornerRadius: 6, style: .continuous)
        .fill(AppTheme.badgeBackground.opacity(0.65))
    )
  }

  // MARK: - Failed / Unauthenticated Recovery with 1-Click Copy

  private func failedRecoveryBox(for agent: AIAgentStatusItem, reason: String) -> some View {
    let command = agent.kind.loginCommandHint
    let isCopied = copiedAgentId == agent.id

    return VStack(alignment: .leading, spacing: 5) {
      Text(reason)
        .font(AppTypography.caption2(.medium))
        .foregroundColor(AppTheme.textSecondary)
        .lineLimit(2)

      HStack(spacing: 6) {
        Image(systemName: "terminal")
          .font(.system(size: 9, weight: .semibold))
          .foregroundColor(AppTheme.textTertiary)
          .accessibilityHidden(true)

        Text(command)
          .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
          .foregroundColor(AppTheme.textPrimary)
          .lineLimit(1)

        Spacer(minLength: 4)

        Button {
          NSPasteboard.general.clearContents()
          NSPasteboard.general.setString(command, forType: .string)
          withAnimation(.easeInOut(duration: 0.14)) {
            copiedAgentId = agent.id
          }
          DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            if copiedAgentId == agent.id {
              withAnimation(.easeInOut(duration: 0.14)) {
                copiedAgentId = nil
              }
            }
          }
        } label: {
          HStack(spacing: 3) {
            Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
              .font(.system(size: 8.5, weight: .bold))
            Text(isCopied ? L10n.AIAgents.copiedCommand : L10n.AIAgents.copyCommand)
              .font(AppTypography.micro(.semibold))
          }
          .foregroundColor(isCopied ? AppTheme.accentGreen : AppTheme.accentCyan)
          .padding(.horizontal, 6)
          .padding(.vertical, 2.5)
          .background(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
              .fill(
                (isCopied ? AppTheme.accentGreen : AppTheme.accentCyan).opacity(0.14)
              )
          )
        }
        .buttonStyle(.plain)
        .help(L10n.AIAgents.loginHint(command))
        .accessibilityLabel("\(L10n.AIAgents.copyCommand) \(command)")
      }
      .padding(.horizontal, 8)
      .padding(.vertical, 5)
      .background(
        RoundedRectangle(cornerRadius: 6, style: .continuous)
          .fill(AppTheme.badgeBackground)
          .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
              .stroke(AppTheme.cardBorder, lineWidth: 0.5)
          )
      )
    }
  }

  // MARK: - Loading, Initial & Empty States (R-27)

  private var scanningCard: some View {
    DashboardCard {
      HStack(spacing: 10) {
        ProgressView()
          .controlSize(.small)

        Text(L10n.AIAgents.scanningText)
          .font(AppTypography.subheadline(.semibold))
          .foregroundColor(AppTheme.textPrimary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.vertical, 6)
    }
  }

  private var initialSetupCard: some View {
    DashboardCard {
      HStack(spacing: 10) {
        Image(systemName: "cpu.fill")
          .font(.system(size: 15, weight: .semibold))
          .foregroundColor(AppTheme.accentCyan)
          .frame(width: 28, height: 28)
          .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
              .fill(AppTheme.accentCyan.opacity(0.14))
          )
          .accessibilityHidden(true)

        VStack(alignment: .leading, spacing: 2) {
          Text(L10n.AIAgents.setupTitle)
            .font(AppTypography.subheadline(.bold))
            .foregroundColor(AppTheme.textPrimary)

          Text(L10n.AIAgents.setupSubtitle)
            .font(AppTypography.caption2(.regular))
            .foregroundColor(AppTheme.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
        }

        Spacer(minLength: 4)

        Button {
          quotaService.checkInstalledAgents(force: true)
        } label: {
          Text(L10n.AIAgents.checkButton)
            .font(AppTypography.caption(.semibold))
            .foregroundColor(AppTheme.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
              RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(AppTheme.accentCyan.opacity(0.22))
                .overlay(
                  RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(AppTheme.accentCyan.opacity(0.5), lineWidth: 0.8)
                )
            )
        }
        .buttonStyle(.plain)
      }
    }
  }

  private var noAgentsFoundCard: some View {
    DashboardCard {
      VStack(alignment: .leading, spacing: 8) {
        HStack(spacing: 8) {
          Image(systemName: "exclamationmark.triangle.fill")
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(AppTheme.accentAmber)
            .accessibilityHidden(true)

          Text(L10n.AIAgents.noAgentsInstalledTitle)
            .font(AppTypography.subheadline(.bold))
            .foregroundColor(AppTheme.textPrimary)
        }

        Text(L10n.AIAgents.noAgentsInstalledDetail)
          .font(AppTypography.caption2(.regular))
          .foregroundColor(AppTheme.textSecondary)
          .fixedSize(horizontal: false, vertical: true)

        HStack {
          Spacer()
          Button {
            quotaService.checkInstalledAgents(force: true)
          } label: {
            HStack(spacing: 4) {
              Image(systemName: "arrow.clockwise")
                .font(.system(size: 9, weight: .bold))
              Text(L10n.AIAgents.checkButton)
                .font(AppTypography.caption2(.semibold))
            }
            .foregroundColor(AppTheme.textPrimary)
            .padding(.horizontal, 9)
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
        }
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
}

import SwiftUI

struct DashboardAgentsSection: View {
  @ObservedObject private var quotaService = AIAgentQuotaService.shared
  @State private var showingDetailQuota: Bool = false
  @State private var selectedAgentKind: AIAgentKind? = nil

  var body: some View {
    if !quotaService.hasCompletedInitialScan && !quotaService.isScanning {
      initialSetupCard
    } else if quotaService.isScanning && quotaService.agents.isEmpty {
      scanningCard
    } else if quotaService.agents.isEmpty {
      noAgentsFoundCard
    } else if showingDetailQuota {
      detailQuotaView
    } else {
      agentsOverviewView
    }
  }

  private var initialSetupCard: some View {
    DashboardCard {
      VStack(spacing: 12) {
        ZStack {
          Circle()
            .fill(AppTheme.accentCyan.opacity(0.14))
            .frame(width: 42, height: 42)

          Image(systemName: "cpu.fill")
            .font(.system(size: 18, weight: .semibold))
            .foregroundColor(AppTheme.accentCyan)
        }
        .padding(.top, 4)

        VStack(spacing: 4) {
          Text(L10n.AIAgents.setupTitle)
            .font(.system(size: 13, weight: .bold))
            .foregroundColor(AppTheme.textPrimary)

          Text(L10n.AIAgents.setupSubtitle)
            .font(.system(size: 10.5, weight: .regular))
            .foregroundColor(AppTheme.textSecondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 8)
        }

        Button {
          quotaService.checkInstalledAgents()
        } label: {
          HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
              .font(.system(size: 11, weight: .bold))
            Text(L10n.AIAgents.checkButton)
              .font(.system(size: 11.5, weight: .semibold))
          }
          .foregroundColor(AppTheme.textPrimary)
          .padding(.horizontal, 16)
          .padding(.vertical, 7)
          .background(
            Capsule()
              .fill(AppTheme.accentCyan.opacity(0.24))
              .overlay(
                Capsule()
                  .stroke(AppTheme.accentCyan.opacity(0.55), lineWidth: 1)
              )
          )
        }
        .buttonStyle(.plain)
        .padding(.bottom, 4)
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 6)
    }
  }

  private var scanningCard: some View {
    DashboardCard {
      HStack(spacing: 10) {
        ProgressView()
          .controlSize(.small)

        Text(L10n.AIAgents.scanningText)
          .font(.system(size: 11.5, weight: .semibold))
          .foregroundColor(AppTheme.textPrimary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.vertical, 8)
    }
  }

  private var noAgentsFoundCard: some View {
    VStack(spacing: 8) {
      DashboardCard {
        VStack(alignment: .leading, spacing: 6) {
          HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
              .font(.system(size: 14, weight: .semibold))
              .foregroundColor(AppTheme.accentAmber)

            Text(L10n.AIAgents.noAgentsInstalledTitle)
              .font(.system(size: 12, weight: .bold))
              .foregroundColor(AppTheme.textPrimary)
          }

          Text(L10n.AIAgents.noAgentsInstalledDetail)
            .font(.system(size: 10.5, weight: .regular))
            .foregroundColor(AppTheme.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }

      footerBar
    }
  }

  private var agentsOverviewView: some View {
    VStack(spacing: 8) {
      Button {
        withAnimation(.easeInOut(duration: 0.16)) {
          selectedAgentKind = nil
          showingDetailQuota = true
        }
      } label: {
        DashboardCard {
          HStack(spacing: 8) {
            ZStack {
              Circle()
                .fill(AppTheme.accentCyan.opacity(0.16))
                .frame(width: 26, height: 26)

              Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(AppTheme.accentCyan)
            }

            VStack(alignment: .leading, spacing: 1) {
              Text(L10n.AIAgents.viewDetailQuota)
                .font(.system(size: 11.5, weight: .bold))
                .foregroundColor(AppTheme.textPrimary)

              let activeCount = quotaService.agents.filter { $0.authStatus.isAuthenticated }.count
              let failedCount = quotaService.agents.count - activeCount
              Text(L10n.AIAgents.summaryCount(active: activeCount, failed: failedCount))
                .font(.system(size: 9.5, weight: .medium))
                .foregroundColor(AppTheme.textSecondary)
            }

            Spacer(minLength: 4)

            Image(systemName: "chevron.right")
              .font(.system(size: 11, weight: .bold))
              .foregroundColor(AppTheme.textTertiary)
          }
        }
      }
      .buttonStyle(.plain)

      ForEach(quotaService.agents) { agent in
        Button {
          withAnimation(.easeInOut(duration: 0.16)) {
            selectedAgentKind = agent.kind
            showingDetailQuota = true
          }
        } label: {
          agentOverviewCard(for: agent)
        }
        .buttonStyle(.plain)
      }

      footerBar
    }
  }

  private func agentOverviewCard(for agent: AIAgentStatusItem) -> some View {
    let isFailed = !agent.authStatus.isAuthenticated

    return DashboardCard {
      HStack(spacing: 8) {
        Image(systemName: agent.kind.icon)
          .font(.system(size: 13, weight: .semibold))
          .foregroundColor(isFailed ? AppTheme.accentRed : AppTheme.accentCyan)
          .frame(width: 18)

        VStack(alignment: .leading, spacing: 2) {
          HStack(spacing: 5) {
            Text(agent.kind.displayName)
              .font(.system(size: 11.5, weight: .bold))
              .foregroundColor(AppTheme.textPrimary)
              .lineLimit(1)

            if let version = agent.version, !version.isEmpty {
              Text("v\(version)")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(AppTheme.textTertiary)
                .lineLimit(1)
            }
          }

          Text(agent.binaryPath)
            .font(.system(size: 8.5, weight: .regular, design: .monospaced))
            .foregroundColor(AppTheme.textTertiary)
            .lineLimit(1)
        }

        Spacer(minLength: 4)

        statusBadge(for: agent.authStatus)

        Image(systemName: "chevron.right")
          .font(.system(size: 10, weight: .bold))
          .foregroundColor(AppTheme.textTertiary)
          .padding(.leading, 2)
      }
    }
  }

  private var detailQuotaView: some View {
    VStack(spacing: 8) {
      HStack(spacing: 8) {
        Button {
          withAnimation(.easeInOut(duration: 0.16)) {
            showingDetailQuota = false
            selectedAgentKind = nil
          }
        } label: {
          HStack(spacing: 4) {
            Image(systemName: "chevron.left")
              .font(.system(size: 10, weight: .bold))
            Text(L10n.AIAgents.backButton)
              .font(.system(size: 10.5, weight: .semibold))
          }
          .foregroundColor(AppTheme.accentCyan)
          .padding(.horizontal, 8)
          .padding(.vertical, 4)
          .background(
            Capsule()
              .fill(AppTheme.badgeBackground)
              .overlay(
                Capsule()
                  .stroke(AppTheme.cardBorder, lineWidth: 0.5)
              )
          )
        }
        .buttonStyle(.plain)

        Text(L10n.AIAgents.detailQuotaTitle)
          .font(.system(size: 12, weight: .bold))
          .foregroundColor(AppTheme.textPrimary)

        Spacer(minLength: 4)

        let activeCount = quotaService.agents.filter { $0.authStatus.isAuthenticated }.count
        let failedCount = quotaService.agents.count - activeCount
        Text(L10n.AIAgents.summaryCount(active: activeCount, failed: failedCount))
          .font(.system(size: 9, weight: .bold))
          .foregroundColor(failedCount > 0 ? AppTheme.accentAmber : AppTheme.accentGreen)
          .padding(.horizontal, 6)
          .padding(.vertical, 2.5)
          .background(
            Capsule()
              .fill((failedCount > 0 ? AppTheme.accentAmber : AppTheme.accentGreen).opacity(0.14))
          )
      }
      .padding(.horizontal, 2)

      if quotaService.agents.count > 1 {
        filterChips
      }

      let displayedAgents = displayedAgentsList
      ForEach(displayedAgents) { agent in
        detailedQuotaCard(for: agent)
      }

      footerBar
    }
  }

  private var filterChips: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 5) {
        Button {
          withAnimation(.easeInOut(duration: 0.14)) {
            selectedAgentKind = nil
          }
        } label: {
          Text(L10n.AIAgents.filterAll)
            .font(.system(size: 9.5, weight: selectedAgentKind == nil ? .bold : .medium))
            .foregroundColor(selectedAgentKind == nil ? AppTheme.textPrimary : AppTheme.textSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
              Capsule()
                .fill(selectedAgentKind == nil ? AppTheme.accentCyan.opacity(0.24) : AppTheme.badgeBackground)
                .overlay(
                  Capsule()
                    .stroke(selectedAgentKind == nil ? AppTheme.accentCyan.opacity(0.55) : AppTheme.cardBorder, lineWidth: 0.6)
                )
            )
        }
        .buttonStyle(.plain)

        ForEach(quotaService.agents) { agent in
          let isSelected = selectedAgentKind == agent.kind
          Button {
            withAnimation(.easeInOut(duration: 0.14)) {
              selectedAgentKind = agent.kind
            }
          } label: {
            HStack(spacing: 4) {
              Image(systemName: agent.kind.icon)
                .font(.system(size: 8.5))
              Text(agent.kind.displayName)
                .font(.system(size: 9.5, weight: isSelected ? .bold : .medium))
            }
            .foregroundColor(isSelected ? AppTheme.textPrimary : AppTheme.textSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
              Capsule()
                .fill(isSelected ? AppTheme.accentCyan.opacity(0.24) : AppTheme.badgeBackground)
                .overlay(
                  Capsule()
                    .stroke(isSelected ? AppTheme.accentCyan.opacity(0.55) : AppTheme.cardBorder, lineWidth: 0.6)
                )
            )
          }
          .buttonStyle(.plain)
        }
      }
      .padding(.vertical, 1)
    }
  }

  private var displayedAgentsList: [AIAgentStatusItem] {
    if let selected = selectedAgentKind {
      let filtered = quotaService.agents.filter { $0.kind == selected }
      return filtered.isEmpty ? quotaService.agents : filtered
    }
    return quotaService.agents
  }

  private func detailedQuotaCard(for agent: AIAgentStatusItem) -> some View {
    let isFailed = !agent.authStatus.isAuthenticated

    return DashboardCard {
      VStack(alignment: .leading, spacing: 7) {
        HStack(alignment: .center, spacing: 7) {
          Image(systemName: agent.kind.icon)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(isFailed ? AppTheme.accentRed : AppTheme.accentCyan)
            .frame(width: 18)

          VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 5) {
              Text(agent.kind.displayName)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(AppTheme.textPrimary)
                .lineLimit(1)

              if let version = agent.version, !version.isEmpty {
                Text("v\(version)")
                  .font(.system(size: 9, weight: .medium, design: .monospaced))
                  .foregroundColor(AppTheme.textTertiary)
                  .lineLimit(1)
              }
            }

            Text(agent.binaryPath)
              .font(.system(size: 8.5, weight: .regular, design: .monospaced))
              .foregroundColor(AppTheme.textTertiary)
              .lineLimit(1)
          }

          Spacer(minLength: 4)

          statusBadge(for: agent.authStatus)
        }

        switch agent.authStatus {
        case .authenticated:
          if !agent.metrics.isEmpty {
            VStack(spacing: 6) {
              ForEach(agent.metrics) { metric in
                metricRow(metric)
              }
            }
            .padding(.top, 2)
          }

          if let note = agent.statusNote, !note.isEmpty {
            Text(note)
              .font(.system(size: 9.5, weight: .medium))
              .foregroundColor(AppTheme.textSecondary)
              .lineLimit(1)
          }

        case .failed(let reason):
          VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
              Image(systemName: "xmark.octagon.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(AppTheme.accentRed)

              Text(reason)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(AppTheme.accentRed)
                .lineLimit(1)
            }

            Text(L10n.AIAgents.loginHint(agent.kind.loginCommandHint))
              .font(.system(size: 9.5, weight: .regular))
              .foregroundColor(AppTheme.textSecondary)
              .lineLimit(2)
          }
          .padding(.top, 2)
        }
      }
    }
  }

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
        .frame(width: 5.5, height: 5.5)

      Text(badgeText)
        .font(.system(size: 9, weight: .bold))
        .foregroundColor(isAuth ? AppTheme.textPrimary : AppTheme.accentRed)
        .lineLimit(1)
    }
    .padding(.horizontal, 7)
    .padding(.vertical, 3)
    .background(
      Capsule()
        .fill(badgeColor.opacity(0.14))
        .overlay(
          Capsule()
            .stroke(badgeColor.opacity(0.38), lineWidth: 0.8)
        )
    )
  }

  private func metricRow(_ metric: AIAgentQuotaMetric) -> some View {
    VStack(alignment: .leading, spacing: 3) {
      HStack(alignment: .firstTextBaseline, spacing: 6) {
        Text(metric.label)
          .font(.system(size: 10, weight: .medium))
          .foregroundColor(AppTheme.textSecondary)
          .lineLimit(1)

        Spacer(minLength: 4)

        if let reset = metric.resetDescription, !reset.isEmpty {
          Text(reset)
            .font(.system(size: 9, weight: .regular))
            .foregroundColor(AppTheme.textTertiary)
            .lineLimit(1)
        }

        Text(metric.valueText)
          .font(.system(size: 10.5, weight: .bold, design: .rounded))
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
  }

  private func progressColor(for remainingRatio: Double) -> Color {
    if remainingRatio <= 0.15 {
      return AppTheme.accentRed
    } else if remainingRatio <= 0.35 {
      return AppTheme.accentAmber
    }
    return AppTheme.accentGreen
  }

  private var footerBar: some View {
    let activeCount = quotaService.agents.filter { $0.authStatus.isAuthenticated }.count
    let failedCount = quotaService.agents.count - activeCount

    return HStack(spacing: 6) {
      Text(L10n.AIAgents.summaryCount(active: activeCount, failed: failedCount))
        .font(.system(size: 9.5, weight: .semibold))
        .foregroundColor(failedCount > 0 ? AppTheme.accentAmber : AppTheme.textSecondary)

      if let checkedAt = quotaService.lastCheckedAt {
        Text("• \(L10n.Dashboard.batteryUpdated(TimeFormatting.relativeText(for: checkedAt)))")
          .font(.system(size: 9.5, weight: .medium))
          .foregroundColor(AppTheme.textTertiary)
          .lineLimit(1)
      }

      Spacer(minLength: 4)

      Button {
        quotaService.checkInstalledAgents()
      } label: {
        HStack(spacing: 4) {
          if quotaService.isScanning {
            ProgressView()
              .controlSize(.mini)
          } else {
            Image(systemName: "arrow.clockwise")
              .font(.system(size: 9.5, weight: .bold))
          }
          Text(L10n.AIAgents.checkButton)
            .font(.system(size: 9.5, weight: .semibold))
        }
        .foregroundColor(AppTheme.textSecondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 3.5)
        .background(
          Capsule()
            .fill(AppTheme.badgeBackground)
            .overlay(
              Capsule()
                .stroke(AppTheme.cardBorder, lineWidth: 0.5)
            )
        )
      }
      .buttonStyle(.plain)
      .disabled(quotaService.isScanning)
      .accessibilityLabel(L10n.AIAgents.refreshAgents)
    }
    .padding(.horizontal, 2)
  }
}

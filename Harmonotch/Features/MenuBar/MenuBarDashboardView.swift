import AppKit
import SwiftUI

struct MenuBarDashboardView: View {
  @ObservedObject var viewModel: MenuBarDashboardViewModel
  var onClose: () -> Void

  @ObservedObject private var updateManager = UpdateManager.shared
  @ObservedObject private var quotaService = AIAgentQuotaService.shared

  private var visibleTabs: [DashboardTab] {
    if quotaService.agents.isEmpty {
      return DashboardTab.allCases.filter { $0 != .agents }
    }
    return DashboardTab.allCases
  }

  var body: some View {
    GeometryReader { proxy in
      cardContent
        .frame(width: proxy.size.width, alignment: .top)
    }
    .localizedThemedRoot()
    .onPreferenceChange(DashboardHeightPreferenceKey.self) { height in
      viewModel.onCardHeightChanged?(height)
    }
    .onAppear {
      if !quotaService.hasCompletedInitialScan && !quotaService.isScanning {
        quotaService.checkInstalledAgents()
      }
      if quotaService.agents.isEmpty && viewModel.selectedTab == .agents {
        viewModel.selectedTab = .now
      }
    }
    .onChange(of: quotaService.agents.isEmpty) { _, isEmpty in
      if isEmpty && viewModel.selectedTab == .agents {
        viewModel.selectedTab = .now
      }
    }
    .onExitCommand(perform: onClose)
  }

  private var cardContent: some View {
    VStack(spacing: 10) {
      headerBar

      tabSelectorBar

      currentTabContent

      Divider()
        .background(AppTheme.divider)

      footerBar
    }
    .padding(14)
    .frame(width: MenuBarDashboardViewModel.panelWidth)
    .background(
      ZStack {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .fill(AppTheme.surfaceBackground)

        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .stroke(AppTheme.surfaceBorder, lineWidth: 1)
      }
    )
    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    .background(
      GeometryReader { geo in
        Color.clear.preference(key: DashboardHeightPreferenceKey.self, value: geo.size.height)
      }
    )
  }

  private var headerBar: some View {
    HStack(spacing: 8) {
      brandIdentity
        .layoutPriority(0)

      Spacer(minLength: 4)

      if updateManager.hasUpdate {
        updateBadgeButton
          .layoutPriority(1)
      }

      DashboardCloseButton(action: onClose)
    }
  }

  private var brandIdentity: some View {
    HStack(spacing: 8) {
      Group {
        if let nsImage = NSImage(named: "AppLogo") ?? NSImage(named: NSImage.applicationIconName)
          ?? NSApplication.shared.applicationIconImage
        {
          Image(nsImage: nsImage)
            .resizable()
        } else {
          Image("AppLogo")
            .resizable()
        }
      }
      .aspectRatio(contentMode: .fit)
      .frame(width: 24, height: 24)
      .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 6, style: .continuous)
          .stroke(AppTheme.surfaceBorder, lineWidth: 0.8)
      )
      .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 1) {
        Text("Harmonotch")
          .font(.system(size: 13, weight: .bold))
          .foregroundColor(AppTheme.textPrimary)
          .lineLimit(1)

        Text(L10n.Menu.headerSubtitle)
          .font(AppTypography.caption2(.medium))
          .foregroundColor(AppTheme.textTertiary)
          .lineLimit(1)
          .truncationMode(.tail)
      }
    }
  }

  private var updateBadgeButton: some View {
    Button(action: { updateManager.checkForUpdates(isUserInitiated: true) }) {
      HStack(spacing: 4) {
        Image(systemName: "arrow.down.circle.fill")
          .font(.system(size: 10.5, weight: .bold))
        Text(L10n.Update.available)
          .font(.system(size: 10, weight: .semibold))
          .lineLimit(1)
      }
      .foregroundColor(AppTheme.accentAmber)
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(AppTheme.accentAmber.opacity(0.14))
      .clipShape(Capsule())
      .overlay(
        Capsule()
          .stroke(AppTheme.accentAmber.opacity(0.40), lineWidth: 0.7)
      )
    }
    .buttonStyle(.plain)
    .fixedSize()
    .help(L10n.Menu.checkForUpdates)
  }

  private var tabSelectorBar: some View {
    HStack(spacing: 3) {
      ForEach(visibleTabs) { tab in
        DashboardTabItemButton(
          tab: tab,
          isSelected: viewModel.selectedTab == tab,
          label: tabLabel(for: tab),
          action: {
            viewModel.selectedTab = tab
          }
        )
      }
    }
    .padding(2.5)
    .background(
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .fill(AppTheme.tabBarBackground)
        .overlay(
          RoundedRectangle(cornerRadius: 8, style: .continuous)
            .stroke(AppTheme.cardBorder, lineWidth: 0.6)
        )
    )
  }

  @ViewBuilder
  private var currentTabContent: some View {
    switch viewModel.selectedTab {
    case .now:
      DashboardNowSection(
        onSelectTab: { tab in
          viewModel.selectedTab = tab
        }
      )
    case .battery:
      DashboardBatterySection()
    case .prayer:
      DashboardPrayerSection()
    case .agents:
      DashboardAgentsSection()
    }
  }

  private var footerBar: some View {
    HStack(spacing: 6) {
      Text("v\(updateManager.currentVersion)")
        .font(.system(size: 10.5, weight: .medium, design: .rounded))
        .foregroundColor(AppTheme.textTertiary)

      Spacer()

      DashboardIconButton(
        icon: "arrow.clockwise",
        label: viewModel.selectedTab == .agents ? L10n.Dashboard.batteryRefresh : L10n.Dashboard.updateShort,
        helpText: viewModel.selectedTab == .agents ? L10n.AIAgents.refreshAgents : L10n.Menu.checkForUpdates,
        action: {
          if viewModel.selectedTab == .agents {
            AIAgentQuotaService.shared.checkInstalledAgents(force: true)
          } else {
            updateManager.checkForUpdates(isUserInitiated: true)
          }
        }
      )

      DashboardIconButton(
        icon: "info.circle",
        label: L10n.Dashboard.aboutShort,
        helpText: L10n.Menu.aboutHarmonotch,
        action: { AboutWindowController.shared.show() }
      )

      DashboardIconButton(
        icon: "power",
        label: L10n.Dashboard.quitShort,
        helpText: L10n.Menu.quit,
        isDestructive: true,
        action: { NSApplication.shared.terminate(nil) }
      )
    }
  }

  private func tabLabel(for tab: DashboardTab) -> String {
    switch tab {
    case .now: return L10n.Dashboard.nowTab
    case .battery: return L10n.Dashboard.batteryTab
    case .prayer: return L10n.Dashboard.prayerTab
    case .agents: return L10n.Dashboard.agentsTab
    }
  }
}

private struct DashboardTabItemButton: View {
  let tab: DashboardTab
  let isSelected: Bool
  let label: String
  let action: () -> Void

  @State private var isHovered = false

  var body: some View {
    Button(action: action) {
      VStack(spacing: 2.5) {
        Image(systemName: tab.icon)
          .font(.system(size: 11.5, weight: isSelected ? .semibold : .regular))
          .frame(height: 14)

        Text(label)
          .font(.system(size: 10, weight: isSelected ? .semibold : .medium))
          .lineLimit(1)
      }
      .foregroundColor(
        isSelected
          ? AppTheme.tabActiveText
          : (isHovered ? AppTheme.textPrimary : AppTheme.tabInactiveText)
      )
      .frame(maxWidth: .infinity)
      .padding(.vertical, 5)
      .padding(.horizontal, 2)
      .background(
        Group {
          if isSelected {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
              .fill(AppTheme.tabActiveBackground)
              .shadow(color: Color.black.opacity(AppTheme.isDark ? 0.35 : 0.08), radius: 1.5, x: 0, y: 1)
              .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                  .stroke(AppTheme.surfaceBorder.opacity(0.8), lineWidth: 0.5)
              )
          } else if isHovered {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
              .fill(AppTheme.tabActiveBackground.opacity(0.4))
          } else {
            Color.clear
          }
        }
      )
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .onHover { hovering in
      withAnimation(.easeInOut(duration: 0.12)) {
        isHovered = hovering
      }
    }
    .accessibilityLabel(label)
    .help(label)
  }
}

private struct DashboardIconButton: View {
  let icon: String
  var label: String? = nil
  let helpText: String
  var isDestructive: Bool = false
  let action: () -> Void

  @State private var isHovered = false

  var body: some View {
    Button(action: action) {
      HStack(spacing: 4) {
        Image(systemName: icon)
          .font(.system(size: 10, weight: isDestructive ? .bold : .semibold))

        if let label {
          Text(label)
            .font(.system(size: 10, weight: .semibold))
            .lineLimit(1)
        }
      }
      .foregroundColor(foregroundColor)
      .padding(.horizontal, label != nil ? 8 : 0)
      .frame(minWidth: 26, minHeight: 24)
      .background(
        RoundedRectangle(cornerRadius: 6, style: .continuous)
          .fill(
            isHovered
              ? (isDestructive ? AppTheme.accentRed.opacity(0.15) : AppTheme.badgeBackground.opacity(1.3))
              : AppTheme.badgeBackground
          )
      )
      .overlay(
        RoundedRectangle(cornerRadius: 6, style: .continuous)
          .stroke(
            isHovered
              ? (isDestructive ? AppTheme.accentRed.opacity(0.45) : AppTheme.cardBorder)
              : AppTheme.cardBorder.opacity(0.6),
            lineWidth: 0.6
          )
      )
    }
    .buttonStyle(.plain)
    .onHover { hovering in
      withAnimation(.easeInOut(duration: 0.12)) {
        isHovered = hovering
      }
    }
    .help(helpText)
    .accessibilityLabel(helpText)
  }

  private var foregroundColor: Color {
    if isDestructive {
      return isHovered ? AppTheme.accentRed : AppTheme.textSecondary
    }
    return isHovered ? AppTheme.textPrimary : AppTheme.textSecondary
  }
}

private struct DashboardCloseButton: View {
  let action: () -> Void
  @State private var isHovered = false

  var body: some View {
    Button(action: action) {
      Image(systemName: "xmark")
        .font(.system(size: 9.5, weight: .bold))
        .foregroundColor(isHovered ? AppTheme.textPrimary : AppTheme.textTertiary)
        .frame(width: 22, height: 22)
        .background(
          Circle()
            .fill(isHovered ? AppTheme.badgeBackground : Color.clear)
        )
    }
    .buttonStyle(.plain)
    .onHover { hovering in
      withAnimation(.easeInOut(duration: 0.12)) {
        isHovered = hovering
      }
    }
    .help(L10n.Dashboard.closeDashboard)
    .accessibilityLabel(L10n.Dashboard.closeDashboard)
  }
}

/// Reports the dashboard card's natural rendered height so the controller can
/// resize the panel while keeping its top edge anchored below the menu bar.
struct DashboardHeightPreferenceKey: PreferenceKey {
  static var defaultValue: CGFloat = 0
  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = max(value, nextValue())
  }
}

struct DashboardCard<Content: View>: View {
  var minHeight: CGFloat? = nil
  var alignment: Alignment = .leading
  @ViewBuilder var content: Content

  var body: some View {
    content
      .frame(maxWidth: .infinity, minHeight: minHeight, alignment: alignment)
      .cardChrome(cornerRadius: 10, padding: 10, lineWidth: 0.6)
  }
}

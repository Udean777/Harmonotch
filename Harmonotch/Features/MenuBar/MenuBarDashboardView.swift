import AppKit
import SwiftUI

struct MenuBarDashboardView: View {
  @ObservedObject var viewModel: MenuBarDashboardViewModel
  var onClose: () -> Void

  @ObservedObject private var themeManager = ThemeManager.shared
  @ObservedObject private var updateManager = UpdateManager.shared
  @ObservedObject private var languageManager = LanguageManager.shared

  var body: some View {
    VStack(spacing: 10) {
      headerBar

      Divider()
        .background(AppTheme.divider)

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
    .onPreferenceChange(DashboardHeightPreferenceKey.self) { height in
      viewModel.onCardHeightChanged?(height)
    }
    .onExitCommand(perform: onClose)
  }

  private var headerBar: some View {
    HStack(spacing: 10) {
      brandIdentity

      Spacer(minLength: 4)

      tabSelector

      Button(action: onClose) {
        Image(systemName: "xmark.circle.fill")
          .font(.system(size: 14, weight: .semibold))
          .foregroundColor(AppTheme.textTertiary)
      }
      .buttonStyle(.plain)
      .accessibilityLabel(L10n.Dashboard.closeDashboard)
      .help(L10n.Dashboard.closeDashboard)
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
        HStack(spacing: 4) {
          Text("Harmonotch")
            .font(.system(size: 12.5, weight: .bold))
            .foregroundColor(AppTheme.textPrimary)
            .lineLimit(1)

          if updateManager.hasUpdate {
            Image(systemName: "sparkles")
              .font(.system(size: 8.5, weight: .bold))
              .foregroundColor(AppTheme.accentAmber)
              .accessibilityHidden(true)
          }
        }

        Text(tabLabel(for: viewModel.selectedTab))
          .font(.system(size: 9.5, weight: .semibold))
          .foregroundColor(AppTheme.textTertiary)
          .lineLimit(1)
      }
    }
  }

  private var tabSelector: some View {
    HStack(spacing: 2) {
      ForEach(DashboardTab.allCases) { tab in
        tabButton(tab)
      }
    }
    .padding(2.5)
    .frame(height: 29)
    .background(
      Capsule()
        .fill(AppTheme.cardBackground)
        .overlay(
          Capsule()
            .stroke(AppTheme.cardBorder, lineWidth: 0.6)
        )
    )
  }

  private func tabButton(_ tab: DashboardTab) -> some View {
    let isSelected = (viewModel.selectedTab == tab)
    let label = tabLabel(for: tab)
    return Button(action: {
      viewModel.selectedTab = tab
    }) {
      ZStack {
        if isSelected {
          Capsule()
            .fill(AppTheme.tabActiveBackground)
            .overlay(
              Capsule()
                .stroke(AppTheme.accentAmber.opacity(0.35), lineWidth: 0.7)
            )
            .transition(.opacity)
        }

        Image(systemName: tab.icon)
          .font(.system(size: 11, weight: isSelected ? .bold : .semibold))
          .foregroundColor(isSelected ? AppTheme.tabActiveText : AppTheme.tabInactiveText)
          .frame(width: 28, height: 24)
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .animation(.easeInOut(duration: 0.16), value: isSelected)
    .accessibilityLabel(label)
    .help(label)
  }

  @ViewBuilder
  private var currentTabContent: some View {
    Group {
      switch viewModel.selectedTab {
      case .now:
        DashboardNowSection(
          onSelectTab: { tab in
            viewModel.selectedTab = tab
          }
        )
      case .battery:
        DashboardBatterySection()
      case .process:
        DashboardProcessSection()
      case .prayer:
        DashboardPrayerSection()
      case .utilities:
        DashboardUtilitiesSection()
      }
    }
    .transition(.opacity)
    .id(viewModel.selectedTab)
  }

  private var footerBar: some View {
    HStack(spacing: 8) {
      Text("v\(updateManager.currentVersion)")
        .font(.system(size: 9.5, weight: .semibold, design: .rounded))
        .foregroundColor(AppTheme.textTertiary)

      Spacer()

      Button(action: { updateManager.checkForUpdates(isUserInitiated: true) }) {
        Image(systemName: "arrow.clockwise")
          .font(.system(size: 10, weight: .semibold))
          .foregroundColor(AppTheme.textSecondary)
          .frame(width: 24, height: 24)
          .background(AppTheme.badgeBackground)
          .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
      }
      .buttonStyle(.plain)
      .help(L10n.Menu.checkForUpdates)

      Button(action: { AboutWindowController.shared.show() }) {
        Image(systemName: "info.circle")
          .font(.system(size: 10, weight: .semibold))
          .foregroundColor(AppTheme.textSecondary)
          .frame(width: 24, height: 24)
          .background(AppTheme.badgeBackground)
          .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
      }
      .buttonStyle(.plain)
      .help(L10n.Menu.aboutHarmonotch)

      Button(action: { NSApplication.shared.terminate(nil) }) {
        Image(systemName: "power")
          .font(.system(size: 10, weight: .bold))
          .foregroundColor(AppTheme.accentRed)
          .frame(width: 24, height: 24)
          .background(AppTheme.badgeBackground)
          .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
      }
      .buttonStyle(.plain)
      .help(L10n.Menu.quit)
    }
  }

  private func tabLabel(for tab: DashboardTab) -> String {
    switch tab {
    case .now: return L10n.Dashboard.nowTab
    case .battery: return L10n.Dashboard.batteryTab
    case .process: return L10n.Dashboard.processTab
    case .prayer: return L10n.Dashboard.prayerTab
    case .utilities: return L10n.Dashboard.utilitiesTab
    }
  }
}

/// Reports the dashboard card's natural rendered height so the controller can
/// resize the panel while keeping its top edge anchored below the menu bar.
struct DashboardHeightPreferenceKey: PreferenceKey {
  static var defaultValue: CGFloat = 400
  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = nextValue()
  }
}

struct DashboardCard<Content: View>: View {
  @ViewBuilder var content: Content

  var body: some View {
    content
      .padding(10)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(
        RoundedRectangle(cornerRadius: 10, style: .continuous)
          .fill(AppTheme.cardBackground)
          .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
              .stroke(AppTheme.cardBorder, lineWidth: 0.6)
          )
      )
  }
}

struct DashboardSectionTitle: View {
  let text: String

  var body: some View {
    Text(text)
      .font(.system(size: 9.5, weight: .bold))
      .tracking(0.6)
      .foregroundColor(AppTheme.textTertiary)
      .textCase(.uppercase)
  }
}

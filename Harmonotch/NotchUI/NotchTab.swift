import SwiftUI

enum DrawerTab: String, CaseIterable, Identifiable {
    case prayer = "prayer"
    case battery = "battery"
    case media = "media"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .prayer:
            return L10n.Drawer.prayerTab
        case .battery:
            return L10n.Drawer.batteryTab
        case .media:
            return L10n.Drawer.mediaTab
        }
    }

    var icon: String {
        switch self {
        case .prayer:
            return "moon.stars.fill"
        case .battery:
            return "macbook"
        case .media:
            return "music.note"
        }
    }
}

struct NotchTabBar: View {
    @Binding var selectedTab: DrawerTab
    @ObservedObject var languageManager = LanguageManager.shared
    @ObservedObject var themeManager = ThemeManager.shared
    @Namespace private var tabAnimation

    var body: some View {
        HStack(spacing: 6) {
            ForEach(DrawerTab.allCases) { tab in
                Button(action: {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                        selectedTab = tab
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 11, weight: .semibold))

                        Text(tab.title)
                            .font(.system(size: 12, weight: selectedTab == tab ? .semibold : .medium))
                    }
                    .foregroundColor(selectedTab == tab ? AppTheme.tabActiveText : AppTheme.tabInactiveText)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 5)
                    .background {
                        if selectedTab == tab {
                            Capsule()
                                .fill(AppTheme.tabActiveBackground)
                                .overlay(
                                    Capsule()
                                        .stroke(
                                            LinearGradient(
                                                colors: AppTheme.isDark
                                                    ? [Color.white.opacity(0.40), Color.white.opacity(0.10)]
                                                    : [Color.white.opacity(0.95), Color.black.opacity(0.08)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 0.7
                                        )
                                )
                                .shadow(
                                    color: AppTheme.isDark ? Color.black.opacity(0.25) : Color.black.opacity(0.08),
                                    radius: 3,
                                    x: 0,
                                    y: 1.5
                                )
                                .matchedGeometryEffect(id: "ActiveTabIndicator", in: tabAnimation)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(
            ZStack {
                Capsule()
                    .fill(.ultraThinMaterial)
                Capsule()
                    .fill(AppTheme.tabBarBackground)
                Capsule()
                    .stroke(
                        LinearGradient(
                            colors: AppTheme.isDark
                                ? [Color.white.opacity(0.20), Color.white.opacity(0.04)]
                                : [Color.white.opacity(0.85), Color.black.opacity(0.06)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.6
                    )
            }
        )
    }
}

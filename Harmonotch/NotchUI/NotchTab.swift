import SwiftUI

enum DrawerTab: String, CaseIterable, Identifiable {
    case battery = "battery"
    case media = "media"
    case prayer = "prayer"
    case agents = "agents"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .battery:
            return L10n.Drawer.batteryTab
        case .media:
            return L10n.Drawer.mediaTab
        case .prayer:
            return L10n.Drawer.prayerTab
        case .agents:
            return L10n.Drawer.agentsTab
        }
    }

    var icon: String {
        switch self {
        case .battery:
            return "battery.100"
        case .media:
            return "waveform"
        case .prayer:
            return "moon.stars.fill"
        case .agents:
            return "cpu.fill"
        }
    }
}

struct NotchTabBar: View {
    @Binding var selectedTab: DrawerTab
    @ObservedObject var mediaManager = MediaManager.shared
    @ObservedObject var adzanPlayer = AdzanPlayer.shared
    @Namespace private var tabAnimation

    private var isAudioActive: Bool {
        adzanPlayer.isPlaying || mediaManager.summary.hasMediaSession
    }

    private var visibleTabs: [DrawerTab] {
        if isAudioActive {
            return [.media, .battery, .prayer, .agents]
        } else {
            return [.battery, .prayer, .agents]
        }
    }

    var body: some View {
        HStack(spacing: 3) {
            ForEach(visibleTabs) { tab in
                let isSelected = (selectedTab == tab)
                Button(action: {
                    withAnimation(NotchMotion.content) {
                        selectedTab = tab
                    }
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: tab.icon)
                            .font(AppTypography.subheadline(isSelected ? .semibold : .regular))

                        Text(tab.title)
                            .font(AppTypography.subheadline(isSelected ? .semibold : .medium))
                            .lineLimit(1)
                    }
                    .foregroundColor(isSelected ? AppTheme.tabActiveText : AppTheme.tabInactiveText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(AppTheme.tabActiveBackground)
                                .shadow(color: Color.black.opacity(AppTheme.isDark ? 0.35 : 0.08), radius: 2, x: 0, y: 1)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .stroke(AppTheme.surfaceBorder.opacity(0.8), lineWidth: 0.6)
                                )
                                .matchedGeometryEffect(id: "ActiveTabIndicator", in: tabAnimation)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2.5)
        .animation(NotchMotion.content, value: visibleTabs)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(AppTheme.tabBarBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(AppTheme.cardBorder, lineWidth: 0.6)
                )
        )
    }
}

/// Shared motion language so every transition in the notch feels the same.
enum NotchMotion {
    static let content = Animation.spring(response: 0.34, dampingFraction: 0.82)
    static let quick = Animation.spring(response: 0.26, dampingFraction: 0.86)
    static let fade = Animation.easeInOut(duration: 0.22)

    static var swap: AnyTransition {
        .asymmetric(
            insertion: .scale(scale: 0.7, anchor: .center).combined(with: .opacity),
            removal: .scale(scale: 0.7, anchor: .center).combined(with: .opacity)
        )
    }

    static var drawer: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.96, anchor: .top)).combined(with: .offset(y: 4)),
            removal: .opacity.combined(with: .scale(scale: 0.98, anchor: .top))
        )
    }
}

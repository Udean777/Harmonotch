import SwiftUI

enum DrawerTab: String, CaseIterable, Identifiable {
    case battery = "battery"
    case media = "media"
    case prayer = "prayer"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .battery:
            return L10n.Drawer.batteryTab
        case .media:
            return "Audio"
        case .prayer:
            return L10n.Drawer.prayerTab
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
        }
    }
}

struct NotchTabBar: View {
    @Binding var selectedTab: DrawerTab
    @ObservedObject var languageManager = LanguageManager.shared
    @ObservedObject var mediaManager = MediaManager.shared
    @ObservedObject var adzanPlayer = AdzanPlayer.shared
    @Namespace private var tabAnimation

    private var isAudioActive: Bool {
        adzanPlayer.isPlaying || mediaManager.hasActiveTrack
    }

    private var visibleTabs: [DrawerTab] {
        if isAudioActive {
            return [.media, .battery, .prayer]
        } else {
            return [.battery, .prayer]
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(visibleTabs) { tab in
                Button(action: {
                    withAnimation(NotchMotion.content) {
                        selectedTab = tab
                    }
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 10, weight: .semibold))

                        Text(tab.title)
                            .font(.system(size: 11, weight: selectedTab == tab ? .semibold : .medium))
                            .lineLimit(1)
                    }
                    .foregroundColor(selectedTab == tab ? AppTheme.tabActiveText : AppTheme.tabInactiveText)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 4)
                    .background {
                        if selectedTab == tab {
                            Capsule()
                                .fill(AppTheme.tabActiveBackground)
                                .overlay(
                                    Capsule()
                                        .stroke(Color.white.opacity(0.12), lineWidth: 0.7)
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
        .animation(NotchMotion.content, value: visibleTabs)
        .background(
            Capsule()
                .fill(AppTheme.tabBarBackground)
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.10), lineWidth: 0.6)
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

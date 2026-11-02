import Combine
import Foundation

enum DashboardTab: String, CaseIterable, Identifiable {
  case now
  case battery
  case process
  case prayer
  case utilities

  var id: String { rawValue }

  var icon: String {
    switch self {
    case .now:
      return "square.grid.2x2.fill"
    case .battery:
      return "battery.100"
    case .process:
      return "cpu"
    case .prayer:
      return "moon.stars.fill"
    case .utilities:
      return "slider.horizontal.3"
    }
  }

  var defaultLabel: String {
    switch self {
    case .now:
      return "Overview"
    case .battery:
      return "Battery"
    case .process:
      return "Activity"
    case .prayer:
      return "Prayer"
    case .utilities:
      return "Utilities"
    }
  }
}

/// Owns dashboard-wide state, tab selection, and the panel lifecycle used by demand-driven
/// samplers. Sections can observe `isPanelOpen` instead of polling in the background.
final class MenuBarDashboardViewModel: ObservableObject {
  static let panelWidth: CGFloat = 360

  @Published private(set) var isPanelOpen = false
  @Published var selectedTab: DashboardTab = .now {
    didSet {
      guard oldValue != selectedTab else { return }
      onTabChanged?(selectedTab)
    }
  }

  var onPanelOpened: (() -> Void)?
  var onPanelClosed: (() -> Void)?
  var onTabChanged: ((DashboardTab) -> Void)?
  /// Called whenever the dashboard card's rendered height changes. Used to update hit-test masking.
  var onCardHeightChanged: ((CGFloat) -> Void)?

  var shouldSampleProcesses: Bool {
    isPanelOpen && selectedTab == .process
  }

  func panelDidOpen() {
    guard !isPanelOpen else { return }
    isPanelOpen = true
    onPanelOpened?()
  }

  func panelDidClose() {
    guard isPanelOpen else { return }
    isPanelOpen = false
    onPanelClosed?()
  }
}

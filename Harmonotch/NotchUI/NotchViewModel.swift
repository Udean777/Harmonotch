import Combine
import SwiftUI

final class NotchViewModel: ObservableObject {
  static let shared = NotchViewModel()

  @Published var isExpanded: Bool = false
  @Published var isHovered: Bool = false
  @Published var isLeftCompanionVisible: Bool = false
  @Published var isCompanionEnabled: Bool {
    didSet {
      UserDefaults.standard.set(isCompanionEnabled, forKey: UserDefaultsKeys.companionEnabled)
      if !isCompanionEnabled { isLeftCompanionVisible = false }
    }
  }
  @Published var selectedTab: DrawerTab = .battery  // Default / main view is Battery
  @Published var geometry: NotchGeometry = NotchGeometry.current()

  private var cancellables = Set<AnyCancellable>()

  func updateGeometry(for screen: NSScreen?) {
    let newGeometry = NotchGeometry.current(for: screen)
    if geometry != newGeometry {
      geometry = newGeometry
    }
  }

  init() {
    self.isCompanionEnabled = UserDefaults.standard.bool(
      forKey: UserDefaultsKeys.companionEnabled)

    // Switch to Media tab when Adzan starts playing
    AdzanPlayer.shared.$isPlaying
      .receive(on: DispatchQueue.main)
      .sink { [weak self] isAdzanPlaying in
        guard let self = self else { return }
        if isAdzanPlaying {
          withAnimation(.spring(response: 0.36, dampingFraction: 0.74)) {
            self.selectedTab = .media
          }
        } else if !MediaManager.shared.hasActiveTrack {
          if self.selectedTab == .media {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.68)) {
              self.selectedTab = .battery
            }
          }
        }
      }
      .store(in: &cancellables)

    // Switch to Media tab when media starts playing, never while the user is on another tab.
    Publishers.CombineLatest(MediaManager.shared.$isPlaying, MediaManager.shared.$trackTitle)
      .map { isPlaying, trackTitle in
        isPlaying && !trackTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      }
      .removeDuplicates()
      .receive(on: DispatchQueue.main)
      .sink { [weak self] isMediaActive in
        guard let self = self else { return }
        if isMediaActive {
          guard self.selectedTab != .media else { return }
          withAnimation(.spring(response: 0.36, dampingFraction: 0.74)) {
            self.selectedTab = .media
          }
        } else if !AdzanPlayer.shared.isPlaying, self.selectedTab == .media {
          withAnimation(.spring(response: 0.38, dampingFraction: 0.68)) {
            self.selectedTab = .battery
          }
        }
      }
      .store(in: &cancellables)
  }

  func setHovered(_ hovered: Bool) {
    isHovered = hovered
  }

  func setLeftCompanionVisible(_ visible: Bool) {
    let next = visible && isCompanionEnabled
    guard isLeftCompanionVisible != next else { return }
    isLeftCompanionVisible = next
  }

  func collapse() {
    guard isExpanded else { return }
    withAnimation(.spring(response: 0.34, dampingFraction: 0.96)) {
      isExpanded = false
    }
  }

  func toggleExpanded() {
    let expanding = !isExpanded
    withAnimation(
      .spring(response: expanding ? 0.36 : 0.34, dampingFraction: expanding ? 0.78 : 0.96)
    ) {
      isExpanded.toggle()
    }
  }
}

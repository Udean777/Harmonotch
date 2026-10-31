import SwiftUI
import Combine

final class NotchViewModel: ObservableObject {
    static let shared = NotchViewModel()

    @Published var isExpanded: Bool = false
    @Published var isHovered: Bool = false
    @Published var selectedTab: DrawerTab = .battery // Default / main view is Battery
    @Published var geometry: NotchGeometry = NotchGeometry.current()

    private var cancellables = Set<AnyCancellable>()

    func updateGeometry(for screen: NSScreen?) {
        let newGeometry = NotchGeometry.current(for: screen)
        if geometry != newGeometry {
            geometry = newGeometry
        }
    }

    init() {
        // Switch to Audio mode whenever Adzan starts playing
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

        // Switch to Audio mode whenever Music / Video / YouTube starts playing
        Publishers.CombineLatest(MediaManager.shared.$isPlaying, MediaManager.shared.$trackTitle)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isPlaying, trackTitle in
                guard let self = self else { return }
                let hasTrack = !trackTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                if isPlaying && hasTrack {
                    withAnimation(.spring(response: 0.36, dampingFraction: 0.74)) {
                        self.selectedTab = .media
                    }
                } else if !hasTrack && !AdzanPlayer.shared.isPlaying {
                    if self.selectedTab == .media {
                        withAnimation(.spring(response: 0.38, dampingFraction: 0.68)) {
                            self.selectedTab = .battery
                        }
                    }
                }
            }
            .store(in: &cancellables)
    }

    func setHovered(_ hovered: Bool) {
        isHovered = hovered
    }

    func collapse() {
        guard isExpanded else { return }
        withAnimation(.spring(response: 0.34, dampingFraction: 0.96)) {
            isExpanded = false
        }
    }

    func toggleExpanded() {
        let expanding = !isExpanded
        withAnimation(.spring(response: expanding ? 0.36 : 0.34, dampingFraction: expanding ? 0.78 : 0.96)) {
            isExpanded.toggle()
        }
    }
}

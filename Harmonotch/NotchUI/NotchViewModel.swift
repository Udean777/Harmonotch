import SwiftUI
import Combine

final class NotchViewModel: ObservableObject {
    static let shared = NotchViewModel()

    @Published var isExpanded: Bool = false
    @Published var isHovered: Bool = false
    @Published var selectedTab: DrawerTab = .prayer

    private var collapseWorkItem: DispatchWorkItem?
    private var cancellables = Set<AnyCancellable>()

    init() {
        AdzanPlayer.shared.$isPlaying
            .receive(on: DispatchQueue.main)
            .filter { $0 }
            .sink { [weak self] _ in
                guard let self = self else { return }
                withAnimation(.spring(response: 0.34, dampingFraction: 0.76)) {
                    self.selectedTab = .prayer
                }
            }
            .store(in: &cancellables)
    }

    func setHovered(_ hovered: Bool) {
        if isHovered == hovered && isExpanded == hovered { return }
        isHovered = hovered
        if hovered {
            collapseWorkItem?.cancel()
            collapseWorkItem = nil
            if !isExpanded {
                withAnimation(.spring(response: 0.34, dampingFraction: 0.76)) {
                    isExpanded = true
                }
            }
        } else {
            collapseWorkItem?.cancel()
            let work = DispatchWorkItem { [weak self] in
                guard let self = self, !self.isHovered else { return }
                if self.isExpanded {
                    withAnimation(.spring(response: 0.26, dampingFraction: 0.86)) {
                        self.isExpanded = false
                    }
                }
            }
            collapseWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.14, execute: work)
        }
    }

    func toggleExpanded() {
        collapseWorkItem?.cancel()
        withAnimation(.spring(response: 0.30, dampingFraction: 0.80)) {
            isExpanded.toggle()
        }
    }
}

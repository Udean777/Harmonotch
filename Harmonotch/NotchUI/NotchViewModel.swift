//
//  NotchViewModel.swift
//  Harmonotch
//

import SwiftUI
import Combine

final class NotchViewModel: ObservableObject {
    static let shared = NotchViewModel()

    @Published var isExpanded: Bool = false
    @Published var isHovered: Bool = false

    private var collapseWorkItem: DispatchWorkItem?

    func setHovered(_ hovered: Bool) {
        isHovered = hovered
        if hovered {
            collapseWorkItem?.cancel()
            withAnimation(.spring(response: 0.34, dampingFraction: 0.76)) {
                isExpanded = true
            }
        } else {
            // Delay ultra-responsif (0.14 detik) agar terasa instan namun tidak sengaja tertutup jika kursor bergerak cepat
            collapseWorkItem?.cancel()
            let work = DispatchWorkItem { [weak self] in
                withAnimation(.spring(response: 0.26, dampingFraction: 0.86)) {
                    self?.isExpanded = false
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

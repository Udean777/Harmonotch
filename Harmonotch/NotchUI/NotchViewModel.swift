import Combine
import SwiftUI

struct VolumeNotice: Equatable {
  let level: Double
  let muted: Bool
  let symbol: String
}

private struct MediaActiveState: Equatable {
  let isMediaPlaying: Bool
  let hasSession: Bool
}

final class NotchViewModel: ObservableObject {
  static let shared = NotchViewModel()
  static let volumeNoticeDuration: TimeInterval = 1.6

  @Published var isExpanded: Bool = false
  @Published var isHovered: Bool = false
  @Published private(set) var volumeNotice: VolumeNotice?
  @Published var selectedTab: DrawerTab = .battery
  @Published var geometry: NotchGeometry = NotchGeometry.current()
  /// Content-driven wing widths reported by the collapsed pill.
  @Published var collapsedWingWidths = NotchWingWidths()
  /// Measured expanded content height (including padding) for hit-test outside notch.
  @Published var expandedContentHeight: CGFloat = 0

  private var cancellables = Set<AnyCancellable>()
  private var volumeNoticeDismissWorkItem: DispatchWorkItem?

  func updateGeometry(for screen: NSScreen?) {
    let newGeometry = NotchGeometry.current(for: screen)
    if geometry != newGeometry {
      geometry = newGeometry
    }
  }

  init() {
    // Switch to Media tab when Adzan starts playing
    AdzanPlayer.shared.$isPlaying
      .receive(on: DispatchQueue.main)
      .sink { [weak self] isAdzanPlaying in
        guard let self = self else { return }
        if isAdzanPlaying {
          withAnimation(.spring(response: 0.36, dampingFraction: 0.74)) {
            self.selectedTab = .media
          }
        } else if !MediaManager.shared.hasMediaSession {
          if self.selectedTab == .media {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.68)) {
              self.selectedTab = .battery
            }
          }
        }
      }
      .store(in: &cancellables)

    // Switch to Media tab when media starts playing.
    // When paused, remain on Media tab so long as a media session exists.
    // Only switch to battery when the session is cleared and Adzan is not playing.
    Publishers.CombineLatest(MediaManager.shared.$isPlaying, MediaManager.shared.$presentation)
      .map { isPlaying, presentation -> MediaActiveState in
        MediaActiveState(
          isMediaPlaying: isPlaying && presentation != nil,
          hasSession: presentation != nil
        )
      }
      .removeDuplicates()
      .receive(on: DispatchQueue.main)
      .sink { [weak self] state in
        guard let self = self else { return }
        if state.isMediaPlaying {
          guard self.selectedTab != .media else { return }
          withAnimation(.spring(response: 0.36, dampingFraction: 0.74)) {
            self.selectedTab = .media
          }
        } else if !state.hasSession && !AdzanPlayer.shared.isPlaying {
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
    withAnimation(
      .spring(response: expanding ? 0.36 : 0.34, dampingFraction: expanding ? 0.78 : 0.96)
    ) {
      isExpanded.toggle()
    }
  }

  func showVolumeNotice(
    level: Double,
    muted: Bool,
    symbol: String? = nil,
    isRepeat: Bool = false
  ) {
    let clamped = min(1, max(0, level))
    let resolvedSymbol = symbol ?? VolumeKeyRouter.volumeSymbol(level: clamped, muted: muted)
    let nextNotice = VolumeNotice(
      level: muted ? 0 : clamped,
      muted: muted,
      symbol: resolvedSymbol
    )

    let wasNil = (volumeNotice == nil)
    if wasNil {
      withAnimation(NotchMotion.content) {
        volumeNotice = nextNotice
      }
    } else if volumeNotice != nextNotice {
      volumeNotice = nextNotice
    }

    // Dedupe: one notice per press; repeat updates level in-place without
    // creating a new notice or resetting an already-running dismiss timer.
    if wasNil || !isRepeat || volumeNoticeDismissWorkItem == nil {
      scheduleVolumeNoticeDismiss()
    }
  }

  func dismissVolumeNotice() {
    volumeNoticeDismissWorkItem?.cancel()
    volumeNoticeDismissWorkItem = nil
    guard volumeNotice != nil else { return }
    withAnimation(NotchMotion.content) {
      volumeNotice = nil
    }
  }

  private func scheduleVolumeNoticeDismiss() {
    volumeNoticeDismissWorkItem?.cancel()
    let workItem = DispatchWorkItem { [weak self] in
      guard let self = self else { return }
      if VolumeHUDController.shared.hasHeldKey {
        self.scheduleVolumeNoticeDismiss()
        return
      }
      self.volumeNoticeDismissWorkItem = nil
      withAnimation(NotchMotion.content) {
        self.volumeNotice = nil
      }
    }
    volumeNoticeDismissWorkItem = workItem
    DispatchQueue.main.asyncAfter(
      deadline: .now() + Self.volumeNoticeDuration,
      execute: workItem
    )
  }
}

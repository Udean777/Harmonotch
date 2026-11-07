import AppKit
import SwiftUI

struct NotchVerticalVolumeSlider: View {
  var height: CGFloat = 175

  @ObservedObject private var audioService = SystemAudioService.shared
  @ObservedObject private var notchVM = NotchViewModel.shared

  private var currentLevel: Double {
    if let vol = audioService.outputVolume {
      return Double(vol)
    }
    if let notice = notchVM.volumeNotice {
      return notice.level
    }
    return 0.5
  }

  private var isMuted: Bool {
    if let muted = audioService.isMuted {
      return muted
    }
    if let notice = notchVM.volumeNotice {
      return notice.muted
    }
    return currentLevel <= 0.005
  }

  private var percent: Int {
    if isMuted { return 0 }
    return min(100, max(0, Int((currentLevel * 100).rounded())))
  }

  private var symbol: String {
    VolumeKeyRouter.volumeSymbol(level: currentLevel, muted: isMuted)
  }

  var body: some View {
    NotchSatelliteSlider(
      height: height,
      level: currentLevel,
      percent: percent,
      isFillActive: !isMuted,
      dimmed: isMuted,
      accessibilityLabel: L10n.Volume.accessibilityLabel(percent: percent, muted: isMuted),
      onLevelChanged: { audioService.setVolume($0) },
      onScrollStep: { step in
        let next = max(0, min(1, Float(currentLevel) + step))
        audioService.setVolume(next)
      }
    ) { iconColor in
      Button(action: {
        withAnimation(NotchMotion.quick) {
          _ = audioService.toggleMute()
        }
      }) {
        Image(systemName: symbol)
          .font(.system(size: 11, weight: .semibold))
          .symbolRenderingMode(.monochrome)
          .foregroundColor(iconColor)
          .frame(width: 20, height: 20)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .padding(.bottom, 10)
    }
    .onAppear {
      audioService.startObserving()
    }
  }
}

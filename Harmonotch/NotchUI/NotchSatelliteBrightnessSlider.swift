import AppKit
import SwiftUI

struct NotchSatelliteBrightnessSlider: View {
  var height: CGFloat = 175

  @ObservedObject private var brightnessService = SystemBrightnessService.shared

  private var currentLevel: Double {
    Double(brightnessService.currentBrightness)
  }

  private var percent: Int {
    min(100, max(0, Int((currentLevel * 100).rounded())))
  }

  private var iconName: String {
    if currentLevel > 0.5 {
      return "sun.max.fill"
    } else if currentLevel > 0.05 {
      return "sun.min.fill"
    } else {
      return "sun.min"
    }
  }

  var body: some View {
    NotchSatelliteSlider(
      height: height,
      level: currentLevel,
      percent: percent,
      accessibilityLabel: "Display Brightness \(percent)%",
      onLevelChanged: { brightnessService.setBrightness($0) },
      onScrollStep: { step in
        let next = max(0, min(1, brightnessService.currentBrightness + step))
        brightnessService.setBrightness(next)
      }
    ) { iconColor in
      Image(systemName: iconName)
        .font(.system(size: 11, weight: .semibold))
        .symbolRenderingMode(.monochrome)
        .foregroundColor(iconColor)
        .frame(width: 20, height: 20)
        .padding(.bottom, 10)
    }
    .onAppear {
      brightnessService.startObserving()
    }
    .onDisappear {
      brightnessService.stopObserving()
    }
  }
}

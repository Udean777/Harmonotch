import AppKit
import SwiftUI

struct NotchSatelliteBrightnessSlider: View {
  var height: CGFloat = 175

  @ObservedObject private var brightnessService = SystemBrightnessService.shared
  @ObservedObject private var notchVM = NotchViewModel.shared
  @State private var dragBrightness: Float?
  @State private var isDragging: Bool = false
  @State private var isHovered: Bool = false

  private var currentLevel: Double {
    if let drag = dragBrightness {
      return Double(drag)
    }
    return Double(brightnessService.currentBrightness)
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

  private var topClearance: CGFloat {
    notchVM.geometry.hasHardwareNotch
      ? (notchVM.geometry.physicalNotchHeight + 4)
      : 10
  }

  var body: some View {
    GeometryReader { geo in
      let totalHeight = geo.size.height
      let fillHeight = max(0, min(totalHeight, totalHeight * CGFloat(currentLevel)))

      ZStack(alignment: .bottom) {
        // Satellite Container Background
        Capsule(style: .continuous)
          .fill(AppTheme.surfaceBackground)
          .overlay(
            Capsule(style: .continuous)
              .stroke(AppTheme.surfaceBorder, lineWidth: 0.8)
          )
          .shadow(color: Color.black.opacity(0.35), radius: 5, x: 0, y: 2)

        // Filled Brightness Level
        VStack(spacing: 0) {
          Spacer(minLength: 0)
          Capsule(style: .continuous)
            .fill(
              LinearGradient(
                colors: [
                  Color.white.opacity(isDragging || isHovered ? 0.96 : 0.88),
                  Color.white.opacity(isDragging || isHovered ? 0.88 : 0.80),
                ],
                startPoint: .top,
                endPoint: .bottom
              )
            )
            .frame(height: fillHeight)
        }
        .clipShape(Capsule(style: .continuous))
        .animation(isDragging ? nil : NotchMotion.quick, value: currentLevel)

        // Content Overlays (Percentage at top, Sun Icon at bottom)
        VStack(spacing: 0) {
          Text("\(percent)%")
            .font(.system(size: 8, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundColor(topLabelColor(totalHeight: totalHeight))
            .lineLimit(1)
            .padding(.top, topClearance)

          Spacer(minLength: 0)

          Image(systemName: iconName)
            .font(.system(size: 11, weight: .semibold))
            .symbolRenderingMode(.monochrome)
            .foregroundColor(bottomIconColor)
            .frame(width: 20, height: 20)
            .padding(.bottom, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
      .frame(width: geo.size.width, height: totalHeight)
      .contentShape(Capsule(style: .continuous))
      .gesture(
        DragGesture(minimumDistance: 0)
          .onChanged { value in
            isDragging = true
            let total = max(1, totalHeight)
            let progress = max(0, min(1, Float(1.0 - (value.location.y / total))))
            dragBrightness = progress
            brightnessService.setBrightness(progress)
          }
          .onEnded { value in
            let total = max(1, totalHeight)
            let progress = max(0, min(1, Float(1.0 - (value.location.y / total))))
            brightnessService.setBrightness(progress)
            isDragging = false
            dragBrightness = nil
          }
      )
      .overlay(
        SatelliteScrollHandler { deltaY in
          let step: Float = deltaY > 0 ? 0.03 : -0.03
          let next = max(0, min(1, Float(currentLevel) + step))
          brightnessService.setBrightness(next)
        }
      )
    }
    .frame(width: NotchLayout.satelliteSliderWidth, height: height)
    .onHover { hovering in
      if isHovered != hovering {
        isHovered = hovering
      }
    }
    .onAppear {
      brightnessService.startObserving()
    }
    .onDisappear {
      brightnessService.stopObserving()
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Display Brightness \(percent)%")
  }

  private func topLabelColor(totalHeight: CGFloat) -> Color {
    let threshold = max(0.65, 1.0 - (topClearance + 12) / max(1, totalHeight))
    if currentLevel >= threshold {
      return Color.black.opacity(0.85)
    }
    return Color.white.opacity(0.92)
  }

  private var bottomIconColor: Color {
    if currentLevel >= 0.12 {
      return Color.black.opacity(0.85)
    }
    return Color.white.opacity(0.92)
  }
}

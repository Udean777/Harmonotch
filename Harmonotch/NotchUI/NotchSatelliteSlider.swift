import AppKit
import SwiftUI

struct NotchSatelliteSlider<BottomContent: View>: View {
  var height: CGFloat = 175
  var level: Double
  var percent: Int
  var isFillActive: Bool = true
  var dimmed: Bool = false
  var accessibilityLabel: String
  var onLevelChanged: (Float) -> Void
  var onScrollStep: (Float) -> Void
  @ViewBuilder var bottomContent: (Color) -> BottomContent

  @ObservedObject private var notchVM = NotchViewModel.shared
  @State private var dragLevel: Float?
  @State private var isDragging: Bool = false
  @State private var isHovered: Bool = false

  private var activeLevel: Double {
    if let drag = dragLevel {
      return Double(drag)
    }
    return level
  }

  private var topClearance: CGFloat {
    notchVM.geometry.hasHardwareNotch
      ? (notchVM.geometry.physicalNotchHeight + 4)
      : 10
  }

  var body: some View {
    GeometryReader { geo in
      let totalHeight = geo.size.height
      let fillHeight = isFillActive
        ? max(0, min(totalHeight, totalHeight * CGFloat(activeLevel)))
        : 0

      ZStack(alignment: .bottom) {
        // Satellite Container Background
        Capsule(style: .continuous)
          .fill(AppTheme.surfaceBackground)
          .overlay(
            Capsule(style: .continuous)
              .stroke(AppTheme.surfaceBorder, lineWidth: 0.8)
          )
          .shadow(color: Color.black.opacity(0.35), radius: 5, x: 0, y: 2)

        // Filled Level
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
        .animation(isDragging ? nil : NotchMotion.quick, value: activeLevel)

        // Content Overlays (Percentage at top, Bottom control at bottom)
        VStack(spacing: 0) {
          Text("\(percent)%")
            .font(.system(size: 8, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundColor(topLabelColor(totalHeight: totalHeight))
            .lineLimit(1)
            .padding(.top, topClearance)

          Spacer(minLength: 0)

          bottomContent(bottomIconColor)
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
            dragLevel = progress
            onLevelChanged(progress)
          }
          .onEnded { value in
            let total = max(1, totalHeight)
            let progress = max(0, min(1, Float(1.0 - (value.location.y / total))))
            onLevelChanged(progress)
            isDragging = false
            dragLevel = nil
          }
      )
      .overlay(
        SatelliteScrollHandler { deltaY in
          let step: Float = deltaY > 0 ? 0.03 : -0.03
          onScrollStep(step)
        }
      )
    }
    .frame(width: NotchLayout.satelliteSliderWidth, height: height)
    .onHover { hovering in
      if isHovered != hovering {
        isHovered = hovering
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(accessibilityLabel)
  }

  private func topLabelColor(totalHeight: CGFloat) -> Color {
    if dimmed {
      return Color.white.opacity(0.55)
    }
    let threshold = max(0.65, 1.0 - (topClearance + 12) / max(1, totalHeight))
    if activeLevel >= threshold {
      return Color.black.opacity(0.85)
    }
    return Color.white.opacity(0.92)
  }

  private var bottomIconColor: Color {
    if dimmed {
      return Color.white.opacity(0.55)
    }
    if activeLevel >= 0.12 {
      return Color.black.opacity(0.85)
    }
    return Color.white.opacity(0.92)
  }
}

/// Invisible scroll wheel interceptor for mouse wheel and trackpad adjustments.
struct SatelliteScrollHandler: NSViewRepresentable {
  var onScroll: (CGFloat) -> Void

  func makeNSView(context: Context) -> ScrollNSView {
    let view = ScrollNSView()
    view.onScroll = onScroll
    return view
  }

  func updateNSView(_ nsView: ScrollNSView, context: Context) {
    nsView.onScroll = onScroll
  }

  final class ScrollNSView: NSView {
    var onScroll: ((CGFloat) -> Void)?

    override func scrollWheel(with event: NSEvent) {
      if abs(event.deltaY) > 0.01 {
        onScroll?(event.deltaY)
      } else {
        super.scrollWheel(with: event)
      }
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
      nil
    }
  }
}

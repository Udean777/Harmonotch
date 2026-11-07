import AppKit
import SwiftUI

struct NotchVerticalVolumeSlider: View {
  var height: CGFloat = 175

  @ObservedObject private var audioService = SystemAudioService.shared
  @ObservedObject private var notchVM = NotchViewModel.shared
  @State private var dragVolume: Float?
  @State private var isDragging: Bool = false
  @State private var isHovered: Bool = false

  private var currentLevel: Double {
    if let drag = dragVolume {
      return Double(drag)
    }
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

  private var topClearance: CGFloat {
    notchVM.geometry.hasHardwareNotch
      ? (notchVM.geometry.physicalNotchHeight + 4)
      : 10
  }

  var body: some View {
    GeometryReader { geo in
      let totalHeight = geo.size.height
      let fillHeight = isMuted ? 0 : max(0, min(totalHeight, totalHeight * CGFloat(currentLevel)))

      ZStack(alignment: .bottom) {
        // Satellite Container Background
        Capsule(style: .continuous)
          .fill(AppTheme.surfaceBackground)
          .overlay(
            Capsule(style: .continuous)
              .stroke(AppTheme.surfaceBorder, lineWidth: 0.8)
          )
          .shadow(color: Color.black.opacity(0.35), radius: 5, x: 0, y: 2)

        // Filled Volume Level
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

        // Content Overlays (Percentage at top, Speaker Icon at bottom)
        VStack(spacing: 0) {
          Text("\(percent)%")
            .font(.system(size: 8, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundColor(topLabelColor(totalHeight: totalHeight))
            .lineLimit(1)
            .padding(.top, topClearance)

          Spacer(minLength: 0)

          Button(action: {
            withAnimation(NotchMotion.quick) {
              _ = audioService.toggleMute()
            }
          }) {
            Image(systemName: symbol)
              .font(.system(size: 11, weight: .semibold))
              .symbolRenderingMode(.monochrome)
              .foregroundColor(bottomIconColor)
              .frame(width: 20, height: 20)
              .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
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
            dragVolume = progress
            audioService.setVolume(progress)
          }
          .onEnded { value in
            let total = max(1, totalHeight)
            let progress = max(0, min(1, Float(1.0 - (value.location.y / total))))
            audioService.setVolume(progress)
            isDragging = false
            dragVolume = nil
          }
      )
      .overlay(
        SatelliteScrollHandler { deltaY in
          let step: Float = deltaY > 0 ? 0.03 : -0.03
          let next = max(0, min(1, Float(currentLevel) + step))
          audioService.setVolume(next)
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
      audioService.startObserving()
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(L10n.Volume.accessibilityLabel(percent: percent, muted: isMuted))
  }

  private func topLabelColor(totalHeight: CGFloat) -> Color {
    if isMuted {
      return Color.white.opacity(0.55)
    }
    let threshold = max(0.65, 1.0 - (topClearance + 12) / max(1, totalHeight))
    if currentLevel >= threshold {
      return Color.black.opacity(0.85)
    }
    return Color.white.opacity(0.92)
  }

  private var bottomIconColor: Color {
    if isMuted {
      return Color.white.opacity(0.55)
    }
    if currentLevel >= 0.12 {
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

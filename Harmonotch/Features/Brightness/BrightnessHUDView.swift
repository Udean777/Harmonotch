import SwiftUI

struct BrightnessMiniProgressBar: View {
  var progress: Float

  var body: some View {
    GeometryReader { geo in
      ZStack(alignment: .leading) {
        Capsule()
          .fill(Color.white.opacity(0.18))

        Capsule()
          .fill(
            LinearGradient(
              colors: [Color.yellow.opacity(0.85), Color.yellow],
              startPoint: .leading,
              endPoint: .trailing
            )
          )
          .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(progress))))
          .animation(.spring(response: 0.22, dampingFraction: 0.82), value: progress)
      }
    }
  }
}

struct BrightnessHUDLeftWingView: View {
  @ObservedObject var brightnessManager = BrightnessManager.shared

  var body: some View {
    Button(action: {
      brightnessManager.brightnessDown()
    }) {
      HStack(spacing: 5) {
        Image(systemName: "sun.min.fill")
          .font(.system(size: 11, weight: .bold))
          .foregroundColor(Color(red: 1.0, green: 0.85, blue: 0.35))
          .frame(width: 14)

        Text("\(Int(round(brightnessManager.currentBrightness * 100)))%")
          .font(.system(size: 10.5, weight: .bold, design: .rounded))
          .monospacedDigit()
          .foregroundColor(.white)
          .lineLimit(1)
      }
    }
    .buttonStyle(.plain)
  }
}

struct BrightnessHUDRightWingView: View {
  @ObservedObject var brightnessManager = BrightnessManager.shared

  var body: some View {
    HStack(spacing: 5) {
      GeometryReader { geo in
        ZStack(alignment: .leading) {
          Capsule()
            .fill(Color.white.opacity(0.18))

          Capsule()
            .fill(
              LinearGradient(
                colors: [Color(red: 1.0, green: 0.85, blue: 0.35), Color(red: 1.0, green: 0.95, blue: 0.5)],
                startPoint: .leading,
                endPoint: .trailing
              )
            )
            .frame(
              width: max(
                0,
                min(geo.size.width, geo.size.width * CGFloat(brightnessManager.currentBrightness))
              )
            )
            .animation(.spring(response: 0.22, dampingFraction: 0.82), value: brightnessManager.currentBrightness)
        }
        .contentShape(Rectangle())
        .gesture(
          DragGesture(minimumDistance: 0)
            .onChanged { value in
              let pct = max(0.0, min(1.0, Float(value.location.x / geo.size.width)))
              brightnessManager.setBrightness(to: pct)
            }
        )
      }
      .frame(height: 6)

      Button(action: {
        brightnessManager.brightnessUp()
      }) {
        Image(systemName: "sun.max.fill")
          .font(.system(size: 10.5, weight: .bold))
          .foregroundColor(brightnessManager.currentBrightness >= 1.0 ? Color(red: 1.0, green: 0.95, blue: 0.5) : Color(red: 1.0, green: 0.85, blue: 0.35))
          .frame(width: 14)
      }
      .buttonStyle(.plain)
    }
    .frame(width: 74)
  }
}

struct BrightnessHUDFloatingView: View {
  @ObservedObject var brightnessManager = BrightnessManager.shared

  var body: some View {
    HStack(spacing: 8) {
      Button(action: {
        brightnessManager.brightnessDown()
      }) {
        Image(systemName: "sun.min.fill")
          .font(.system(size: 11, weight: .bold))
          .foregroundColor(Color(red: 1.0, green: 0.85, blue: 0.35))
          .frame(width: 14)
      }
      .buttonStyle(.plain)

      Text("\(Int(round(brightnessManager.currentBrightness * 100)))%")
        .font(.system(size: 10.5, weight: .bold, design: .rounded))
        .monospacedDigit()
        .foregroundColor(.white)
        .frame(width: 32, alignment: .leading)

      GeometryReader { geo in
        ZStack(alignment: .leading) {
          Capsule()
            .fill(Color.white.opacity(0.18))

          Capsule()
            .fill(
              LinearGradient(
                colors: [Color(red: 1.0, green: 0.85, blue: 0.35), Color(red: 1.0, green: 0.95, blue: 0.5)],
                startPoint: .leading,
                endPoint: .trailing
              )
            )
            .frame(
              width: max(
                0,
                min(geo.size.width, geo.size.width * CGFloat(brightnessManager.currentBrightness))
              )
            )
            .animation(.spring(response: 0.22, dampingFraction: 0.82), value: brightnessManager.currentBrightness)
        }
        .contentShape(Rectangle())
        .gesture(
          DragGesture(minimumDistance: 0)
            .onChanged { value in
              let pct = max(0.0, min(1.0, Float(value.location.x / geo.size.width)))
              brightnessManager.setBrightness(to: pct)
            }
        )
      }
      .frame(height: 6)

      Button(action: {
        brightnessManager.brightnessUp()
      }) {
        Image(systemName: "sun.max.fill")
          .font(.system(size: 10.5, weight: .bold))
          .foregroundColor(brightnessManager.currentBrightness >= 1.0 ? Color(red: 1.0, green: 0.95, blue: 0.5) : Color(red: 1.0, green: 0.85, blue: 0.35))
          .frame(width: 14)
      }
      .buttonStyle(.plain)
    }
    .padding(.horizontal, 10)
    .frame(maxHeight: .infinity)
  }
}

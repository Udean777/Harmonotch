import SwiftUI

struct VolumeMiniProgressBar: View {
  var progress: Float

  var body: some View {
    GeometryReader { geo in
      ZStack(alignment: .leading) {
        Capsule()
          .fill(Color.white.opacity(0.18))

        Capsule()
          .fill(
            LinearGradient(
              colors: [Color.white.opacity(0.9), Color.white],
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

struct VolumeHUDLeftWingView: View {
  @ObservedObject var volumeManager = VolumeManager.shared

  private var downIconName: String {
    if volumeManager.isMuted || volumeManager.currentVolume == 0 {
      return "speaker.slash.fill"
    } else {
      return "speaker.fill"
    }
  }

  private var iconColor: Color {
    volumeManager.isMuted ? Color(red: 1.0, green: 0.45, blue: 0.45) : .white
  }

  var body: some View {
    Button(action: {
      volumeManager.toggleMute()
    }) {
      HStack(spacing: 5) {
        Image(systemName: downIconName)
          .font(.system(size: 11, weight: .bold))
          .foregroundColor(iconColor)
          .frame(width: 14)

        Text(volumeManager.isMuted ? "MUTE" : "\(Int(round(volumeManager.currentVolume * 100)))%")
          .font(.system(size: 10.5, weight: .bold, design: .rounded))
          .monospacedDigit()
          .foregroundColor(.white)
          .lineLimit(1)
      }
    }
    .buttonStyle(.plain)
  }
}

struct VolumeHUDRightWingView: View {
  @ObservedObject var volumeManager = VolumeManager.shared

  var body: some View {
    HStack(spacing: 5) {
      GeometryReader { geo in
        ZStack(alignment: .leading) {
          Capsule()
            .fill(Color.white.opacity(0.18))

          Capsule()
            .fill(
              LinearGradient(
                colors: [Color.white.opacity(0.9), Color.white],
                startPoint: .leading,
                endPoint: .trailing
              )
            )
            .frame(
              width: max(
                0,
                min(geo.size.width, geo.size.width * CGFloat(volumeManager.isMuted ? 0 : volumeManager.currentVolume))
              )
            )
            .animation(.spring(response: 0.22, dampingFraction: 0.82), value: volumeManager.currentVolume)
        }
        .contentShape(Rectangle())
        .gesture(
          DragGesture(minimumDistance: 0)
            .onChanged { value in
              let pct = max(0.0, min(1.0, Float(value.location.x / geo.size.width)))
              volumeManager.setVolume(to: pct)
            }
        )
      }
      .frame(height: 6)

      Button(action: {
        volumeManager.volumeUp()
      }) {
        Image(systemName: "speaker.wave.3.fill")
          .font(.system(size: 10.5, weight: .bold))
          .foregroundColor(volumeManager.currentVolume >= 1.0 ? Color(red: 0.45, green: 0.95, blue: 0.6) : .white)
          .frame(width: 14)
      }
      .buttonStyle(.plain)
    }
    .frame(width: 74)
  }
}

struct VolumeHUDFloatingView: View {
  @ObservedObject var volumeManager = VolumeManager.shared

  private var downIconName: String {
    if volumeManager.isMuted || volumeManager.currentVolume == 0 {
      return "speaker.slash.fill"
    } else {
      return "speaker.fill"
    }
  }

  private var iconColor: Color {
    volumeManager.isMuted ? Color(red: 1.0, green: 0.45, blue: 0.45) : .white
  }

  var body: some View {
    HStack(spacing: 8) {
      Button(action: {
        volumeManager.toggleMute()
      }) {
        Image(systemName: downIconName)
          .font(.system(size: 11, weight: .bold))
          .foregroundColor(iconColor)
          .frame(width: 14)
      }
      .buttonStyle(.plain)

      Text(volumeManager.isMuted ? "MUTE" : "\(Int(round(volumeManager.currentVolume * 100)))%")
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
                colors: [Color.white.opacity(0.9), Color.white],
                startPoint: .leading,
                endPoint: .trailing
              )
            )
            .frame(
              width: max(
                0,
                min(geo.size.width, geo.size.width * CGFloat(volumeManager.isMuted ? 0 : volumeManager.currentVolume))
              )
            )
            .animation(.spring(response: 0.22, dampingFraction: 0.82), value: volumeManager.currentVolume)
        }
        .contentShape(Rectangle())
        .gesture(
          DragGesture(minimumDistance: 0)
            .onChanged { value in
              let pct = max(0.0, min(1.0, Float(value.location.x / geo.size.width)))
              volumeManager.setVolume(to: pct)
            }
        )
      }
      .frame(height: 6)

      Button(action: {
        volumeManager.volumeUp()
      }) {
        Image(systemName: "speaker.wave.3.fill")
          .font(.system(size: 10.5, weight: .bold))
          .foregroundColor(volumeManager.currentVolume >= 1.0 ? Color(red: 0.45, green: 0.95, blue: 0.6) : .white)
          .frame(width: 14)
      }
      .buttonStyle(.plain)
    }
    .padding(.horizontal, 10)
  }
}

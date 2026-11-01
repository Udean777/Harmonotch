import SwiftUI

struct NotchPillView: View {
  @ObservedObject var prayerManager = PrayerManager.shared
  @ObservedObject var adzanPlayer = AdzanPlayer.shared
  @ObservedObject var notchVM = NotchViewModel.shared
  @ObservedObject var batteryMonitor = BatteryMonitor.shared
  @ObservedObject var languageManager = LanguageManager.shared
  @ObservedObject var mediaManager = MediaManager.shared
  @State private var isLeftHovered = false

  private var geometry: NotchGeometry {
    notchVM.geometry
  }

  private var height: CGFloat {
    geometry.collapsedHeight
  }

  private var isMediaPlaying: Bool {
    mediaManager.isPlaying && mediaManager.hasActiveTrack && !adzanPlayer.isPlaying
  }

  private var wingWidth: CGFloat {
    (isMediaPlaying ? NotchLayout.mediaWingWidth : NotchLayout.collapsedWingWidth)
      + (notchVM.isHovered ? NotchLayout.hoverWingExpansion : 0)
  }

  private var leftContentExpansion: CGFloat {
    if isMediaPlaying {
      return NotchLayout.mediaLeftExpansion
    }
    return notchVM.isLeftCompanionVisible ? NotchLayout.companionExpansion : 0
  }

  private var leftWingWidth: CGFloat {
    wingWidth + leftContentExpansion
  }

  private var noNotchWidth: CGFloat {
    let baseWidth =
      isMediaPlaying
      ? NotchLayout.noNotchPillWidth - 2
        * (NotchLayout.collapsedWingWidth - NotchLayout.mediaWingWidth)
      : NotchLayout.noNotchPillWidth
    return baseWidth
      + 2 * (notchVM.isHovered ? NotchLayout.hoverWingExpansion : 0)
      + leftContentExpansion
  }

  private var outerInset: CGFloat {
    NotchLayout.wingOuterInset(height: height)
  }

  private var innerInset: CGFloat {
    NotchLayout.wingInnerInset
  }

  /// 0 = battery, 1 = media session, 2 = adzan. Drives swap transitions.
  private var contentMode: Int {
    adzanPlayer.isPlaying ? 2 : ((mediaManager.isPlaying && mediaManager.hasActiveTrack) ? 1 : 0)
  }

  private var isBatteryMode: Bool {
    !adzanPlayer.isPlaying && !(mediaManager.isPlaying && mediaManager.hasActiveTrack)
  }

  var body: some View {
    Group {
      if geometry.hasHardwareNotch {
        HStack(spacing: 0) {
          leftContent
            .padding(.leading, outerInset)
            .padding(.trailing, innerInset)
            .frame(width: leftWingWidth, height: height, alignment: .leading)
            .clipped()
            .onHover {
              isLeftHovered = $0
              notchVM.setLeftCompanionVisible($0 && isBatteryMode)
            }

          Color.clear
            .frame(width: geometry.physicalNotchWidth, height: height)

          rightContent
            .padding(.leading, innerInset)
            .padding(.trailing, outerInset)
            .frame(width: wingWidth, height: height, alignment: .trailing)
            .clipped()
        }
      } else {
        HStack(spacing: 8) {
          leftContent
            .frame(maxWidth: .infinity, alignment: .leading)
            .clipped()
            .onHover {
              isLeftHovered = $0
              notchVM.setLeftCompanionVisible($0 && isBatteryMode)
            }

          rightContent
            .layoutPriority(1)
            .frame(alignment: .trailing)
        }
        .padding(.horizontal, outerInset)
        .frame(width: noNotchWidth, height: height)
        .clipped()
      }
    }
    .contentShape(Rectangle())
    .onTapGesture {
      notchVM.toggleExpanded()
    }
    .onHover { notchVM.setHovered($0) }
    .onChange(of: isBatteryMode) { _, batteryMode in
      notchVM.setLeftCompanionVisible(isLeftHovered && batteryMode)
    }
  }

  private var leftContent: some View {
    ZStack { leftContentBody.id(contentMode).transition(NotchMotion.swap) }
      .animation(NotchMotion.content, value: contentMode)
      .animation(NotchMotion.quick, value: isLeftHovered)
  }

  private var rightContent: some View {
    ZStack { rightContentBody.id(contentMode).transition(NotchMotion.swap) }
      .animation(NotchMotion.content, value: contentMode)
  }

  @ViewBuilder
  private var leftContentBody: some View {
    if isBatteryMode {
      HStack(spacing: 4) {
        if isLeftHovered {
          PrayerCompanionView()
            .transition(.opacity.combined(with: .scale(scale: 0.82, anchor: .trailing)))
        }
        batteryLeft
      }
    } else if isMediaPlaying {
      mediaLeft
    } else {
      PrayerCompanionView()
    }
  }

  @ViewBuilder
  private var rightContentBody: some View {
    if adzanPlayer.isPlaying {
      HStack(spacing: 4) {
        Circle()
          .fill(Color.white)
          .frame(width: 5, height: 5)

        Text(L10n.Prayer.localizedPrayerName(adzanPlayer.playingPrayerName))
          .font(.system(size: 10.5, weight: .bold, design: .rounded))
          .foregroundColor(.white)
          .lineLimit(1)
      }
    } else if mediaManager.isPlaying && mediaManager.hasActiveTrack {
      mediaRight
    } else {
      batteryRight
    }
  }

  private var batteryLeft: some View {
    HStack(spacing: 4) {
      Image(systemName: batteryIconName)
        .font(.system(size: 10, weight: .semibold))
        .symbolRenderingMode(.monochrome)
        .foregroundColor(.white)
        .symbolEffect(.pulse, isActive: batteryMonitor.isCharging)

      Text("\(batteryMonitor.currentCapacity)%")
        .font(.system(size: 10.5, weight: .bold, design: .rounded))
        .monospacedDigit()
        .foregroundColor(.white)
    }
  }

  private var batteryIconName: String {
    let cap = batteryMonitor.currentCapacity
    // Only battery.100.bolt exists in SF Symbols; lower bolt variants are not available.
    if batteryMonitor.isCharging && cap >= 90 { return "battery.100.bolt" }
    if cap >= 60 { return "battery.75" }
    if cap >= 35 { return "battery.50" }
    if cap >= 10 { return "battery.25" }
    return "battery.0"
  }

  @ViewBuilder
  private var batteryRight: some View {
    if batteryMonitor.isCharging {
      HStack(spacing: 3) {
        Image(systemName: "bolt.fill")
          .font(.system(size: 8.5, weight: .bold))
        Text(L10n.Battery.charging)
          .font(.system(size: 10, weight: .semibold))
          .lineLimit(1)
          .minimumScaleFactor(0.85)
      }
      .foregroundColor(.white)
    } else if batteryMonitor.isPluggedIn {
      HStack(spacing: 3) {
        Image(systemName: "powerplug.fill")
          .font(.system(size: 8.5, weight: .semibold))
        Text("AC")
          .font(.system(size: 10, weight: .semibold, design: .rounded))
          .lineLimit(1)
      }
      .foregroundColor(.white)
    } else {
      HStack(spacing: 3) {
        Image(systemName: "heart.fill")
          .font(.system(size: 8.5, weight: .semibold))
          .foregroundColor(.white.opacity(0.85))
        Text("\(batteryMonitor.healthPercent)%")
          .font(.system(size: 10, weight: .semibold, design: .rounded))
          .monospacedDigit()
          .foregroundColor(.white.opacity(0.85))
          .lineLimit(1)
      }
    }
  }

  private var mediaLeft: some View {
    HStack(spacing: 5) {
      PrayerCompanionView()
      thumbnail
    }
    .animation(NotchMotion.fade, value: mediaManager.artworkImage != nil)
  }

  @ViewBuilder
  private var thumbnail: some View {
    Group {
      if let art = mediaManager.artworkImage {
        Image(nsImage: art)
          .resizable()
          .aspectRatio(contentMode: .fill)
          .frame(width: 19, height: 19)
          .clipShape(RoundedRectangle(cornerRadius: 4.5, style: .continuous))
          .overlay(
            RoundedRectangle(cornerRadius: 4.5, style: .continuous)
              .stroke(Color.white.opacity(0.20), lineWidth: 0.6)
          )
      } else {
        RoundedRectangle(cornerRadius: 4.5, style: .continuous)
          .fill(Color(white: 0.16))
          .frame(width: 19, height: 19)
          .overlay(
            Image(systemName: mediaManager.mediaSource.iconName)
              .font(.system(size: 9.5, weight: .semibold))
              .foregroundColor(.white.opacity(0.85))
          )
          .overlay(
            RoundedRectangle(cornerRadius: 4.5, style: .continuous)
              .stroke(Color.white.opacity(0.18), lineWidth: 0.6)
          )
      }
    }
  }

  @ViewBuilder
  private var mediaRight: some View {
    ZStack {
      if mediaManager.isPlaying {
        EqualizerWaveformView()
          .transition(NotchMotion.swap)
      } else {
        Image(systemName: "pause.fill")
          .font(.system(size: 9.5, weight: .bold))
          .foregroundColor(.white.opacity(0.80))
          .transition(NotchMotion.swap)
      }
    }
    .animation(NotchMotion.content, value: mediaManager.isPlaying)
  }
}

// MARK: - Equalizer Sound Bars View

struct EqualizerWaveformView: View {
  @State private var isAnimating = false

  var body: some View {
    HStack(alignment: .center, spacing: 2.2) {
      RoundedRectangle(cornerRadius: 1)
        .fill(Color.white)
        .frame(width: 2.2, height: isAnimating ? 11 : 4)
        .animation(.easeInOut(duration: 0.45).repeatForever(autoreverses: true), value: isAnimating)

      RoundedRectangle(cornerRadius: 1)
        .fill(Color.white)
        .frame(width: 2.2, height: isAnimating ? 5 : 12)
        .animation(
          .easeInOut(duration: 0.35).repeatForever(autoreverses: true).delay(0.1),
          value: isAnimating)

      RoundedRectangle(cornerRadius: 1)
        .fill(Color.white)
        .frame(width: 2.2, height: isAnimating ? 12 : 5)
        .animation(
          .easeInOut(duration: 0.4).repeatForever(autoreverses: true).delay(0.2), value: isAnimating
        )

      RoundedRectangle(cornerRadius: 1)
        .fill(Color.white)
        .frame(width: 2.2, height: isAnimating ? 4 : 9)
        .animation(
          .easeInOut(duration: 0.5).repeatForever(autoreverses: true).delay(0.15),
          value: isAnimating)
    }
    .frame(height: 14)
    .onAppear {
      isAnimating = true
    }
  }
}

import SwiftUI

struct NotchPillView: View {
  @ObservedObject var prayerManager = PrayerManager.shared
  @ObservedObject var adzanPlayer = AdzanPlayer.shared
  @ObservedObject var notchVM = NotchViewModel.shared
  @ObservedObject var batteryMonitor = BatteryMonitor.shared
  @ObservedObject var mediaManager = MediaManager.shared
  @State private var isLeftHovered = false

  private var geometry: NotchGeometry {
    notchVM.geometry
  }

  private var height: CGFloat {
    geometry.collapsedHeight
  }

  private var isMediaPlaying: Bool {
    mediaManager.isPlaying && mediaManager.hasMediaSession && !adzanPlayer.isPlaying
  }

  private var leftContentExpansion: CGFloat {
    if isMediaPlaying {
      return notchVM.isCompanionEnabled ? NotchLayout.mediaLeftExpansion : 0
    }
    return notchVM.isLeftCompanionVisible ? NotchLayout.companionExpansion : 0
  }

  private var wings: (left: CGFloat, right: CGFloat) {
    geometry.collapsedWingWidths(
      isHovered: notchVM.isHovered,
      isMediaPlaying: isMediaPlaying,
      leftExtra: leftContentExpansion,
      measured: notchVM.collapsedWingWidths
    )
  }

  private var outerInset: CGFloat {
    NotchLayout.wingOuterInset(height: height)
  }

  private var innerInset: CGFloat {
    NotchLayout.wingInnerInset
  }

  /// 0 = battery, 1 = media session, 2 = adzan. Drives swap transitions.
  private var contentMode: Int {
    return adzanPlayer.isPlaying ? 2 : (isMediaPlaying ? 1 : 0)
  }

  private var isBatteryMode: Bool {
    !adzanPlayer.isPlaying && !isMediaPlaying
  }

  var body: some View {
    Group {
      if geometry.hasHardwareNotch {
        HStack(spacing: 0) {
          leftWing
          Color.clear
            .frame(width: geometry.physicalNotchWidth, height: height)
          rightWing
        }
      } else {
        HStack(spacing: NotchLayout.floatingWingSpacing) {
          leftWing
          Spacer(minLength: 0)
          rightWing
        }
      }
    }
    .contentShape(Rectangle())
    .onTapGesture {
      notchVM.toggleExpanded()
    }
    .onHover { notchVM.setHovered($0) }
    .onPreferenceChange(NotchWingWidthsKey.self) { widths in
      if notchVM.collapsedWingWidths != widths {
        notchVM.collapsedWingWidths = widths
      }
    }
    .onChange(of: isBatteryMode) { _, _ in
      updateLeftHover(isLeftHovered)
    }
  }

  private var showsVolumeOnLeft: Bool {
    notchVM.volumeNotice != nil && isMediaPlaying
  }

  private var showsVolumeOnRight: Bool {
    notchVM.volumeNotice != nil && !isMediaPlaying
  }

  private var leftLeadingInset: CGFloat {
    if isMediaPlaying && !showsVolumeOnLeft && !geometry.hasHardwareNotch {
      return 0
    }
    return outerInset
  }

  private var leftWing: some View {
    leftContent
      .fixedSize(horizontal: true, vertical: false)
      .padding(.leading, leftLeadingInset)
      .padding(.trailing, innerInset)
      .background(wingWidthProbe(isLeft: true))
      .frame(width: wings.left, height: height, alignment: .leading)
      .clipped()
      .onHover { updateLeftHover($0) }
  }

  private var rightWing: some View {
    rightContent
      .fixedSize(horizontal: true, vertical: false)
      .padding(.leading, innerInset)
      .padding(.trailing, outerInset)
      .background(wingWidthProbe(isLeft: false))
      .frame(width: wings.right, height: height, alignment: .trailing)
      .clipped()
  }

  private func wingWidthProbe(isLeft: Bool) -> some View {
    GeometryReader { proxy in
      Color.clear.preference(
        key: NotchWingWidthsKey.self,
        value: isLeft
          ? NotchWingWidths(left: proxy.size.width)
          : NotchWingWidths(right: proxy.size.width)
      )
    }
  }

  private func updateLeftHover(_ hovering: Bool) {
    if isLeftHovered != hovering { isLeftHovered = hovering }
    notchVM.setLeftCompanionVisible(hovering && isBatteryMode)
  }

  private var leftContent: some View {
    ZStack {
      leftContentBody
        .id("\(contentMode)-\(showsVolumeOnLeft)")
        .transition(NotchMotion.swap)
    }
    .animation(NotchMotion.content, value: contentMode)
    .animation(NotchMotion.content, value: showsVolumeOnLeft)
    .animation(NotchMotion.quick, value: isLeftHovered)
  }

  private var rightContent: some View {
    ZStack {
      rightContentBody
        .id("\(contentMode)-\(showsVolumeOnRight)")
        .transition(NotchMotion.swap)
    }
    .animation(NotchMotion.content, value: contentMode)
    .animation(NotchMotion.content, value: showsVolumeOnRight)
  }

  @ViewBuilder
  private var leftContentBody: some View {
    if let notice = notchVM.volumeNotice, isMediaPlaying {
      VolumeNoticeView(notice: notice)
    } else if isBatteryMode {
      HStack(spacing: 4) {
        if isLeftHovered && notchVM.isCompanionEnabled {
          PrayerCompanionView(isVisible: !notchVM.isExpanded)
            .transition(.opacity.combined(with: .scale(scale: 0.82, anchor: .trailing)))
        }
        batteryLeft
      }
    } else if isMediaPlaying {
      mediaLeft
    } else if notchVM.isCompanionEnabled {
      PrayerCompanionView(isVisible: !notchVM.isExpanded)
    } else {
      batteryLeft
    }
  }

  @ViewBuilder
  private var rightContentBody: some View {
    if let notice = notchVM.volumeNotice, !isMediaPlaying {
      VolumeNoticeView(notice: notice)
    } else if adzanPlayer.isPlaying {
      HStack(spacing: 4) {
        Circle()
          .fill(Color.white)
          .frame(width: 5, height: 5)

        Text(L10n.Prayer.localizedPrayerName(adzanPlayer.playingPrayerName))
          .font(.system(size: 10.5, weight: .bold, design: .rounded))
          .foregroundColor(.white)
          .lineLimit(1)
      }
    } else if isMediaPlaying {
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
    BatteryPresentation.iconName(
      capacity: batteryMonitor.currentCapacity,
      isCharging: batteryMonitor.isCharging
    )
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
      // On a virtual notch, the artwork forms the rounded left end of the pill.
      if !geometry.hasHardwareNotch {
        thumbnail
      }

      if notchVM.isCompanionEnabled {
        PrayerCompanionView(isVisible: !notchVM.isExpanded)
      }

      if geometry.hasHardwareNotch {
        thumbnail
      }
    }
    .animation(NotchMotion.fade, value: mediaManager.artworkImage != nil)
  }

  private var thumbnailDiameter: CGFloat {
    geometry.hasHardwareNotch ? 19 : height
  }

  private var thumbnailCornerRadius: CGFloat {
    geometry.hasHardwareNotch ? 5 : NotchLayout.floatingRadius(height: height, isExpanded: false)
  }

  @ViewBuilder
  private var thumbnail: some View {
    Group {
      if let art = mediaManager.artworkImage {
        Image(nsImage: art)
          .resizable()
          .aspectRatio(contentMode: .fill)
          .frame(width: thumbnailDiameter, height: thumbnailDiameter)
          .clipShape(RoundedRectangle(cornerRadius: thumbnailCornerRadius, style: .continuous))
          .overlay(
            RoundedRectangle(cornerRadius: thumbnailCornerRadius, style: .continuous)
              .stroke(Color.white.opacity(0.18), lineWidth: 0.6)
          )
      } else if let appIcon = mediaManager.presentation?.app.appIcon {
        RoundedRectangle(cornerRadius: thumbnailCornerRadius, style: .continuous)
          .fill(Color(white: 0.16))
          .frame(width: thumbnailDiameter, height: thumbnailDiameter)
          .overlay(
            Image(nsImage: appIcon)
              .resizable()
              .aspectRatio(contentMode: .fit)
              .frame(width: thumbnailDiameter - 2, height: thumbnailDiameter - 2)
              .clipShape(RoundedRectangle(cornerRadius: max(2, thumbnailCornerRadius - 1), style: .continuous))
          )
          .overlay(
            RoundedRectangle(cornerRadius: thumbnailCornerRadius, style: .continuous)
              .stroke(Color.white.opacity(0.18), lineWidth: 0.6)
          )
      } else {
        RoundedRectangle(cornerRadius: thumbnailCornerRadius, style: .continuous)
          .fill(Color(white: 0.16))
          .frame(width: thumbnailDiameter, height: thumbnailDiameter)
          .overlay(
            Image(systemName: mediaManager.presentation?.app.iconSymbolName ?? mediaManager.mediaSource.iconName)
              .font(.system(size: 9.5, weight: .semibold))
              .foregroundColor(.white.opacity(0.85))
          )
          .overlay(
            RoundedRectangle(cornerRadius: thumbnailCornerRadius, style: .continuous)
              .stroke(Color.white.opacity(0.18), lineWidth: 0.6)
          )
      }
    }
  }

  private var mediaAccentColor: Color {
    mediaManager.artworkAccentColor.map(Color.init(nsColor:)) ?? .white
  }

  @ViewBuilder
  private var mediaRight: some View {
    ZStack {
      if mediaManager.isPlaying {
        EqualizerWaveformView(barColor: mediaAccentColor, isActive: !notchVM.isExpanded)
          .transition(NotchMotion.swap)
      } else {
        Image(systemName: "pause.fill")
          .font(.system(size: 9.5, weight: .bold))
          .foregroundColor(mediaAccentColor.opacity(0.80))
          .transition(NotchMotion.swap)
      }
    }
    .animation(NotchMotion.content, value: mediaManager.isPlaying)
    .animation(NotchMotion.fade, value: mediaAccentColor)
  }
}

/// Merges the two wing probes into one measured value.
private struct NotchWingWidthsKey: PreferenceKey {
  static let defaultValue = NotchWingWidths()

  static func reduce(value: inout NotchWingWidths, nextValue: () -> NotchWingWidths) {
    let next = nextValue()
    if next.left > 0 { value.left = next.left }
    if next.right > 0 { value.right = next.right }
  }
}

// MARK: - Equalizer Sound Bars View

struct EqualizerWaveformView: View {
  var barColor: Color = .white
  /// False when the pill is not on screen (expanded), so bars stop animating.
  var isActive: Bool = true
  @State private var isAnimating = false

  private func refresh() {
    isAnimating = isActive
  }

  var body: some View {
    HStack(alignment: .center, spacing: 2.2) {
      RoundedRectangle(cornerRadius: 1)
        .fill(barColor)
        .frame(width: 2.2, height: isAnimating ? 11 : 4)
        .animation(.easeInOut(duration: 0.95).repeatForever(autoreverses: true), value: isAnimating)

      RoundedRectangle(cornerRadius: 1)
        .fill(barColor)
        .frame(width: 2.2, height: isAnimating ? 5 : 12)
        .animation(
          .easeInOut(duration: 0.8).repeatForever(autoreverses: true).delay(0.2),
          value: isAnimating)

      RoundedRectangle(cornerRadius: 1)
        .fill(barColor)
        .frame(width: 2.2, height: isAnimating ? 12 : 5)
        .animation(
          .easeInOut(duration: 0.85).repeatForever(autoreverses: true).delay(0.4), value: isAnimating
        )

      RoundedRectangle(cornerRadius: 1)
        .fill(barColor)
        .frame(width: 2.2, height: isAnimating ? 4 : 9)
        .animation(
          .easeInOut(duration: 1.0).repeatForever(autoreverses: true).delay(0.3),
          value: isAnimating)
    }
    .frame(height: 14)
    .onAppear(perform: refresh)
    .onDisappear {
      isAnimating = false
    }
    .onChange(of: isActive) { _, _ in refresh() }
  }
}

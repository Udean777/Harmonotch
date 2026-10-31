import SwiftUI

/// A small battery-aware companion for the collapsed notch pill.
struct PrayerCompanionView: View {
  @ObservedObject private var prayerManager = PrayerManager.shared
  @ObservedObject private var adzanPlayer = AdzanPlayer.shared
  @ObservedObject private var batteryMonitor = BatteryMonitor.shared
  @State private var isBlinking = false
  @State private var motionPhase = false
  @State private var isReacting = false
  @State private var blinkBounce: CGFloat = 1
  @State private var blinkLift: CGFloat = 0
  @State private var hopOffset: CGFloat = 0

  private var isCelebrating: Bool {
    adzanPlayer.isPlaying || prayerManager.activeAdzanAlertPrayer != nil
  }

  private var batteryMood: BatteryMood {
    switch batteryMonitor.currentCapacity {
    case 70...100: return .happy
    case 40..<70: return .warning
    default: return .danger
    }
  }

  private var moodColor: Color {
    switch batteryMood {
    case .happy: return AppTheme.accentGreen
    case .warning: return AppTheme.accentAmber
    case .danger: return AppTheme.accentRed
    }
  }

  private var motionAnimation: Animation {
    switch batteryMood {
    case .happy:
      return .easeInOut(duration: 0.7)
    case .warning:
      return .easeInOut(duration: 0.16)
    case .danger:
      return .easeInOut(duration: 0.24)
    }
  }

  var body: some View {
    ZStack {
      Ellipse()
        .fill(moodColor.opacity(0.34))
        .frame(width: 20, height: 14)
        .blur(radius: 3.5)
        .scaleEffect(isBlinking ? 1.16 : 1)
        .opacity(batteryMood == .danger ? 1 : 0.88)
        .animation(.easeOut(duration: 0.18), value: isBlinking)

      Ellipse()
        .stroke(moodColor.opacity(0.34), lineWidth: 1)
        .frame(width: 17, height: 11)
        .blur(radius: 2)
        .opacity(isBlinking ? 0.95 : 0.62)
        .animation(.easeOut(duration: 0.18), value: isBlinking)

      companionSilhouette
        .shadow(color: moodColor.opacity(0.72), radius: 4.5)
    }
    .compositingGroup()
    .frame(width: 24, height: 18)
    .scaleEffect(scale * blinkBounce)
    .rotationEffect(.degrees(rotation))
    .offset(x: horizontalOffset, y: verticalOffset + hopOffset + blinkLift)
    .shadow(
      color: moodColor.opacity(batteryMood == .happy ? (motionPhase ? 0.55 : 0.15) : 0),
      radius: batteryMood == .happy ? 3 : 0
    )
    .animation(motionAnimation, value: motionPhase)
    .animation(.spring(response: 0.22, dampingFraction: 0.7), value: isCelebrating)

    .onAppear {
      motionPhase = true
    }
    .task {
      await blinkLoop()
    }
    .task {
      await runEntranceHop()
    }
    .task(id: batteryMood) {
      await runMoodReaction()
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(companionAccessibilityLabel)
  }

  @ViewBuilder
  private var companionSilhouette: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 3, style: .continuous)
        .fill(Color.white.opacity(0.92))
        .frame(width: 14.5, height: 8.5)
        .offset(y: 3)
      HStack(spacing: 6.2) {
        RoundedRectangle(cornerRadius: 1, style: .continuous).fill(Color.white.opacity(0.92)).frame(width: 2.2, height: 2.3)
        RoundedRectangle(cornerRadius: 1, style: .continuous).fill(Color.white.opacity(0.92)).frame(width: 2.2, height: 2.3)
      }.offset(y: 7)
      RoundedRectangle(cornerRadius: 4, style: .continuous)
        .fill(Color.white)
        .frame(width: 15.5, height: 10.5)
        .offset(y: -1.4)
      RoundedRectangle(cornerRadius: 3.2, style: .continuous)
        .fill(Color.black.opacity(0.42))
        .frame(width: 12.2, height: 7.5)
        .overlay(RoundedRectangle(cornerRadius: 3.2, style: .continuous).stroke(moodColor.opacity(0.8), lineWidth: 0.55))
        .offset(y: -1.4)
      HStack(spacing: 3.5) { companionEye; companionEye }
        .offset(y: -2.1)
        .scaleEffect(y: eyeExpressionScale)
        .animation(motionAnimation, value: motionPhase)
      expressionBrows.offset(y: -5.1)
      HStack(spacing: 6.8) {
        Circle().fill(moodColor.opacity(0.82)).frame(width: 1.45, height: 1.1)
        Circle().fill(moodColor.opacity(0.82)).frame(width: 1.45, height: 1.1)
      }.offset(y: 0.9).opacity(batteryMood == .happy ? 0.72 : 0.48)
      expressionMouth.offset(y: 2.1).scaleEffect(y: mouthExpressionScale).animation(motionAnimation, value: motionPhase)
      Circle().fill(Color.white.opacity(0.72)).frame(width: 1.4, height: 1.1).offset(x: -4.7, y: -4.2)
    }
  }

  @ViewBuilder
  private var companionEye: some View {
    if batteryMood == .happy {
      HappyEyeShape()
        .stroke(Color.white, style: StrokeStyle(lineWidth: 1.1, lineCap: .round))
        .frame(width: 3.8, height: 3.2)
        .scaleEffect(y: isBlinking ? 0.12 : 1)
        .animation(.easeInOut(duration: 0.16), value: isBlinking)
    } else {
      Capsule(style: .continuous)
        .fill(Color.white)
        .frame(width: batteryMood == .danger ? 2.6 : 2.35, height: eyeHeight)
        .animation(.easeInOut(duration: 0.12), value: isBlinking)
    }
  }

  private var eyeExpressionScale: CGFloat {
    switch batteryMood {
    case .happy: return isReacting && !motionPhase ? 0.78 : 1
    case .warning: return isReacting && !motionPhase ? 0.94 : 1
    case .danger: return isReacting && !motionPhase ? 1.06 : 1
    }
  }

  private var mouthExpressionScale: CGFloat {
    switch batteryMood {
    case .happy: return isReacting && !motionPhase ? 0.68 : 1
    case .warning: return isReacting && !motionPhase ? 0.9 : 1
    case .danger: return isReacting && !motionPhase ? 0.92 : 1.04
    }
  }

  private var eyeHeight: CGFloat {
    if isBlinking { return 1 }
    switch batteryMood {
    case .happy: return 3.5
    case .warning: return 2.8
    case .danger: return 4.2
    }
  }

  @ViewBuilder
  private var expressionBrows: some View {
    HStack(spacing: 4.5) {
      Capsule(style: .continuous)
        .fill(Color.white.opacity(0.9))
        .frame(width: 3.5, height: 0.9)
        .rotationEffect(.degrees(leftBrowAngle))
      Capsule(style: .continuous)
        .fill(Color.white.opacity(0.9))
        .frame(width: 3.5, height: 0.9)
        .rotationEffect(.degrees(rightBrowAngle))
    }
    .opacity(batteryMood == .happy ? 0 : 1)
  }

  @ViewBuilder
  private var expressionMouth: some View {
    switch batteryMood {
    case .happy:
      SmileShape()
        .stroke(Color.white.opacity(0.95), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
        .frame(width: isCelebrating ? 6.8 : 5.8, height: 4.2)
    case .warning:
      ConcernedMouthShape()
        .stroke(Color.white.opacity(0.95), style: StrokeStyle(lineWidth: 1.05, lineCap: .round))
        .frame(width: 4.8, height: 2.8)
    case .danger:
      FrownShape()
        .stroke(Color.white.opacity(0.95), style: StrokeStyle(lineWidth: 1.1, lineCap: .round))
        .frame(width: 5.2, height: 3.6)
    }
  }

  private var leftBrowAngle: Double {
    batteryMood == .danger ? 22 : -15
  }

  private var rightBrowAngle: Double {
    batteryMood == .danger ? -22 : 15
  }

  private var scale: CGFloat {
    switch batteryMood {
    case .happy: return 1
    case .warning: return isReacting && !motionPhase ? 0.985 : 1
    case .danger: return isReacting ? (motionPhase ? 1.035 : 0.975) : 1
    }
  }

  private var rotation: Double {
    switch batteryMood {
    case .happy: return 0
    case .warning: return isReacting ? (motionPhase ? 3.2 : -3.2) : 0
    case .danger: return isReacting ? (motionPhase ? -2.2 : 2.2) : 0
    }
  }

  private var horizontalOffset: CGFloat {
    batteryMood == .warning && isReacting ? (motionPhase ? 0.7 : -0.7) : 0
  }

  private var verticalOffset: CGFloat {
    switch batteryMood {
    case .happy: return 0
    case .warning: return 0
    case .danger: return isReacting ? (motionPhase ? 0.65 : -0.65) : 0
    }
  }

  private var companionAccessibilityLabel: String {
    let battery = "Baterai \(batteryMonitor.currentCapacity) persen"
    if isCelebrating, let prayer = prayerManager.activeAdzanAlertPrayer {
      return "Adzan untuk \(prayer). \(battery)"
    }
    if let nextPrayer = prayerManager.nextPrayerItem {
      return "Salat berikutnya \(nextPrayer.name), pukul \(nextPrayer.timeString). \(battery)"
    }
    return battery
  }

  private func runMoodReaction() async {
    guard !Task.isCancelled else { return }
    isReacting = true
    motionPhase = false
    withAnimation(motionAnimation) { motionPhase = true }
    try? await Task.sleep(for: .milliseconds(batteryMood == .happy ? 260 : 230))
    guard !Task.isCancelled else { return }
    withAnimation(motionAnimation) { motionPhase = false }
    try? await Task.sleep(for: .milliseconds(batteryMood == .happy ? 500 : 230))
    guard !Task.isCancelled else { return }
    withAnimation(.easeOut(duration: 0.24)) { isReacting = false }
  }

  private func runEntranceHop() async {
    guard batteryMood == .happy else { return }

    withAnimation(.easeOut(duration: 0.14)) {
      hopOffset = -2.5
    }
    try? await Task.sleep(for: .milliseconds(140))
    guard !Task.isCancelled else { return }

    withAnimation(.easeInOut(duration: 0.16)) {
      hopOffset = 0.5
    }
    try? await Task.sleep(for: .milliseconds(160))
    guard !Task.isCancelled else { return }

    withAnimation(.easeOut(duration: 0.12)) {
      hopOffset = 0
    }
  }

  private func blinkLoop() async {
    while !Task.isCancelled {
      let interval: Duration = batteryMood == .danger ? .seconds(1.8) : .seconds(3.5)
      try? await Task.sleep(for: interval)
      guard !Task.isCancelled else { return }
      withAnimation(.easeInOut(duration: 0.08)) {
        isBlinking = true
      }
      withAnimation(.spring(response: 0.16, dampingFraction: 0.58)) {
        blinkBounce = 1.055
        blinkLift = -0.55
      }
      try? await Task.sleep(for: .milliseconds(125))
      guard !Task.isCancelled else { return }
      withAnimation(.spring(response: 0.22, dampingFraction: 0.72)) {
        isBlinking = false
        blinkBounce = 1
        blinkLift = 0
      }
    }
  }

  private enum BatteryMood: Equatable, Hashable {
    case happy
    case warning
    case danger
  }
}

private struct CompanionHeadShape: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path(); path.addRoundedRect(in: rect, cornerSize: CGSize(width: 3.5, height: 3.5)); return path
  }
}

private struct CompanionBodyShape: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path(); path.addRoundedRect(in: CGRect(x: rect.minX + 1.2, y: rect.minY, width: rect.width - 2.4, height: rect.height), cornerSize: CGSize(width: 3.2, height: 3.2)); return path
  }
}

private struct HappyEyeShape: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    path.move(to: CGPoint(x: rect.minX, y: rect.maxY - 0.5))
    path.addQuadCurve(
      to: CGPoint(x: rect.maxX, y: rect.maxY - 0.5),
      control: CGPoint(x: rect.midX, y: rect.minY)
    )
    return path
  }
}

private struct ConcernedMouthShape: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path(); path.move(to: CGPoint(x: rect.minX, y: rect.maxY - 0.8)); path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY - 0.8), control: CGPoint(x: rect.midX, y: rect.minY)); return path
  }
}

private struct FrownShape: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path(); path.move(to: CGPoint(x: rect.minX, y: rect.minY + 0.8)); path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + 0.8), control: CGPoint(x: rect.midX, y: rect.maxY)); return path
  }
}

private struct SmileShape: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    path.move(to: CGPoint(x: rect.minX, y: rect.minY + 0.8))
    path.addQuadCurve(
      to: CGPoint(x: rect.maxX, y: rect.minY + 0.8),
      control: CGPoint(x: rect.midX, y: rect.maxY)
    )
    return path
  }
}

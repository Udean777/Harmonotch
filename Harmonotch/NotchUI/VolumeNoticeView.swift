import SwiftUI

struct VolumeNoticeView: View {
  let notice: VolumeNotice
  var isExpandedBadge: Bool = false

  private var percent: Int {
    guard !notice.muted else { return 0 }
    return min(100, max(0, Int((notice.level * 100).rounded())))
  }

  private var clampedLevel: CGFloat {
    guard !notice.muted else { return 0 }
    return CGFloat(min(1, max(0, notice.level)))
  }

  private var barWidth: CGFloat {
    isExpandedBadge ? 72 : 38
  }

  private var barHeight: CGFloat {
    isExpandedBadge ? 5.5 : 4.5
  }

  var body: some View {
    HStack(spacing: isExpandedBadge ? 8 : 5) {
      Image(systemName: notice.symbol)
        .font(.system(size: isExpandedBadge ? 12 : 11, weight: .semibold))
        .symbolRenderingMode(.monochrome)
        .foregroundColor(notice.muted ? .white.opacity(0.65) : .white)
        .frame(width: 15, alignment: .center)

      ZStack(alignment: .leading) {
        Capsule(style: .continuous)
          .fill(Color.white.opacity(0.22))
          .frame(width: barWidth, height: barHeight)

        Capsule(style: .continuous)
          .fill(notice.muted ? Color.white.opacity(0.45) : Color.white)
          .frame(width: max(0, barWidth * clampedLevel), height: barHeight)
      }
      .frame(width: barWidth, height: barHeight)
      .animation(NotchMotion.quick, value: clampedLevel)

      Text("\(percent)%")
        .font(.system(size: isExpandedBadge ? 11.5 : 10.5, weight: .bold, design: .rounded))
        .monospacedDigit()
        .foregroundColor(notice.muted ? .white.opacity(0.75) : .white)
        .lineLimit(1)
        .frame(minWidth: 30, alignment: .trailing)
    }
    .padding(.horizontal, isExpandedBadge ? 12 : 2)
    .padding(.vertical, isExpandedBadge ? 6.5 : 0)
    .background {
      if isExpandedBadge {
        Capsule(style: .continuous)
          .fill(AppTheme.surfaceBackground)
          .overlay(
            Capsule(style: .continuous)
              .stroke(AppTheme.surfaceBorder, lineWidth: 0.8)
          )
          .shadow(color: Color.black.opacity(0.35), radius: 8, x: 0, y: 4)
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(L10n.Volume.accessibilityLabel(percent: percent, muted: notice.muted))
  }
}

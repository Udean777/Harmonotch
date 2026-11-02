import AppKit
import SwiftUI

struct DashboardProcessSection: View {
  @ObservedObject private var monitor = ProcessActivityMonitor.shared
  @ObservedObject private var themeManager = ThemeManager.shared
  @ObservedObject private var languageManager = LanguageManager.shared

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      DashboardCard {
        switch monitor.state {
        case .loaded(let snapshot, _):
          loadedView(snapshot)
        case .loading, .idle:
          loadingView
        case .empty:
          message(icon: "moon.zzz.fill", title: L10n.Dashboard.processIdle, detail: nil)
        case .unavailable, .permissionRequired, .permissionDenied:
          message(icon: "cpu", title: L10n.Dashboard.processUnavailable, detail: nil)
        case .failed:
          message(icon: "exclamationmark.triangle", title: L10n.Dashboard.processFailed, detail: nil)
        }
      }

      footerBar
    }
  }

  private var loadingView: some View {
    HStack(spacing: 10) {
      ProgressView()
        .scaleEffect(0.65)
        .frame(width: 16, height: 16)

      VStack(alignment: .leading, spacing: 2) {
        Text(L10n.Dashboard.processMeasuring)
          .font(.system(size: 11, weight: .semibold))
          .foregroundColor(AppTheme.textSecondary)

        Text(L10n.Dashboard.processNotEnabled)
          .font(.system(size: 9))
          .foregroundColor(AppTheme.textTertiary)
          .fixedSize(horizontal: false, vertical: true)
      }

      Spacer(minLength: 4)
    }
    .padding(.vertical, 4)
  }

  private func loadedView(_ snapshot: ProcessActivitySnapshot) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      ForEach(Array(snapshot.entries.enumerated()), id: \.element.id) { index, entry in
        row(entry, rank: index + 1)
      }

      if snapshot.isPartial {
        Label(L10n.Dashboard.processPartial, systemImage: "exclamationmark.triangle.fill")
          .font(.system(size: 9, weight: .medium))
          .foregroundColor(AppTheme.accentAmber)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private func row(_ entry: ProcessActivityEntry, rank: Int) -> some View {
    VStack(spacing: 4) {
      HStack(spacing: 8) {
        Text("#\(rank)")
          .font(.system(size: 9.5, weight: .bold, design: .rounded))
          .monospacedDigit()
          .foregroundColor(rank == 1 ? AppTheme.accentAmber : AppTheme.textTertiary)
          .frame(width: 16, alignment: .leading)
          .accessibilityHidden(true)

        Group {
          if let icon = NSRunningApplication(processIdentifier: entry.representativePID)?.icon {
            Image(nsImage: icon).resizable()
          } else {
            Image(systemName: "app.fill").foregroundColor(AppTheme.textTertiary)
          }
        }
        .frame(width: 20, height: 20)
        .accessibilityHidden(true)

        VStack(alignment: .leading, spacing: 1) {
          Text(entry.name)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(AppTheme.textPrimary)
            .lineLimit(1)

          if entry.processCount > 1 {
            Text(L10n.Dashboard.processCount(entry.processCount))
              .font(.system(size: 8.5, weight: .medium))
              .foregroundColor(AppTheme.textTertiary)
          }
        }

        Spacer(minLength: 4)

        Text(String(format: "%.1f%% CPU", entry.cpuPercent))
          .font(.system(size: 11, weight: .bold, design: .rounded))
          .monospacedDigit()
          .foregroundColor(rank == 1 ? AppTheme.accentAmber : AppTheme.textPrimary)
          .padding(.horizontal, 7)
          .padding(.vertical, 2.5)
          .background(
            Capsule()
              .fill(AppTheme.badgeBackground)
              .overlay(Capsule().stroke(AppTheme.cardBorder, lineWidth: 0.5))
          )
      }

      GeometryReader { geo in
        let fraction = min(1.0, max(0.03, entry.cpuPercent / 100.0))
        ZStack(alignment: .leading) {
          Capsule()
            .fill(AppTheme.cardBorder)
            .frame(height: 3.5)

          Capsule()
            .fill(rank == 1 ? AppTheme.accentAmber : AppTheme.accentCyan)
            .frame(width: max(4, geo.size.width * CGFloat(fraction)), height: 3.5)
        }
      }
      .frame(height: 3.5)
    }
    .accessibilityElement(children: .combine)
  }

  private var footerBar: some View {
    HStack(alignment: .center, spacing: 8) {
      if case .loaded(let snapshot, _) = monitor.state {
        Text(L10n.Dashboard.processMetricNote(seconds: max(1, Int(snapshot.samplingInterval.rounded()))))
          .font(.system(size: 8.5))
          .foregroundColor(AppTheme.textTertiary)
          .fixedSize(horizontal: false, vertical: true)
      } else {
        Text(L10n.Dashboard.topResourceActivity)
          .font(.system(size: 9, weight: .medium))
          .foregroundColor(AppTheme.textTertiary)
      }

      Spacer(minLength: 4)

      Button {
        monitor.refresh()
      } label: {
        HStack(spacing: 4) {
          Image(systemName: "arrow.clockwise")
            .font(.system(size: 9, weight: .bold))
          Text(L10n.Dashboard.processRefresh)
            .font(.system(size: 9, weight: .semibold))
            .lineLimit(1)
        }
        .foregroundColor(AppTheme.textSecondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 3.5)
        .background(
          Capsule()
            .fill(AppTheme.badgeBackground)
            .overlay(Capsule().stroke(AppTheme.cardBorder, lineWidth: 0.5))
        )
      }
      .buttonStyle(.plain)
      .disabled(!monitor.isRunning)
      .accessibilityLabel(L10n.Dashboard.processRefresh)
    }
  }

  private func message(icon: String, title: String, detail: String?) -> some View {
    HStack(spacing: 9) {
      Image(systemName: icon)
        .font(.system(size: 14, weight: .semibold))
        .foregroundColor(AppTheme.textTertiary)
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(.system(size: 11, weight: .semibold))
          .foregroundColor(AppTheme.textSecondary)
          .fixedSize(horizontal: false, vertical: true)

        if let detail {
          Text(detail)
            .font(.system(size: 9))
            .foregroundColor(AppTheme.textTertiary)
        }
      }

      Spacer(minLength: 4)
    }
    .padding(.vertical, 4)
  }
}

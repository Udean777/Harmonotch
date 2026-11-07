import SwiftUI

struct DashboardNowSection: View {
  @ObservedObject private var adzanPlayer = AdzanPlayer.shared
  @ObservedObject private var mediaManager = MediaManager.shared
  @ObservedObject private var updateManager = UpdateManager.shared
  @ObservedObject private var themeManager = ThemeManager.shared
  @ObservedObject private var languageManager = LanguageManager.shared

  var onSelectTab: (DashboardTab) -> Void

  var body: some View {
    VStack(spacing: 8) {
      if shouldShowUpdateBanner {
        UpdateBannerView()
      }

      heroCard

      AIAgentQuickRow(
        onSelectAgentsTab: {
          onSelectTab(.agents)
        }
      )

      if adzanPlayer.isPlaying {
        AdzanBannerRow()
      } else if mediaManager.hasMediaSession {
        MediaQuickRow()
      }

      VolumeHUDQuickRow()
    }
  }

  private var heroCard: some View {
    HStack(alignment: .top, spacing: 8) {
      Button {
        onSelectTab(.prayer)
      } label: {
        PrayerSummaryCard()
      }
      .buttonStyle(.plain)
      .accessibilityLabel("\(L10n.Menu.nextPrayer), \(L10n.Dashboard.prayerTab)")

      Button {
        onSelectTab(.battery)
      } label: {
        BatterySummaryCard()
      }
      .buttonStyle(.plain)
      .accessibilityLabel("\(L10n.Dashboard.battery), \(L10n.Dashboard.batteryTab)")
    }
  }

  private var shouldShowUpdateBanner: Bool {
    switch updateManager.state {
    case .available, .downloading, .installing, .readyToQuit, .failed:
      return true
    default:
      return false
    }
  }
}

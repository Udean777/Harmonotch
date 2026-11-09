import SwiftUI

struct UpdateBannerView: View {
  @ObservedObject private var updateManager = UpdateManager.shared

  var body: some View {
    switch updateManager.state {
    case .available(let version):
      HStack(spacing: 8) {
        Image(systemName: "arrow.down.circle.fill")
          .font(.system(size: 16))
          .foregroundColor(AppTheme.accentCyan)

        VStack(alignment: .leading, spacing: 1) {
          Text(L10n.Update.available)
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(AppTheme.textPrimary)
            .lineLimit(1)
          Text("v\(version)")
            .font(.system(size: 9.5, weight: .medium, design: .rounded))
            .foregroundColor(AppTheme.textSecondary)
            .lineLimit(1)
        }

        Spacer()

        Button(action: {
          updateManager.downloadAndInstallUpdate()
        }) {
          Text(L10n.Update.updateNow)
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(Color.black)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Capsule().fill(AppTheme.accentAmber))
        }
        .buttonStyle(.plain)
      }
      .padding(8)
      .background(
        RoundedRectangle(cornerRadius: 9, style: .continuous)
          .fill(AppTheme.badgeBackground)
          .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
              .stroke(AppTheme.cardBorder, lineWidth: 0.8)
          )
      )

    case .downloading(let progress):
      VStack(spacing: 5) {
        HStack(spacing: 6) {
          ProgressView()
            .scaleEffect(0.5)
            .frame(width: 12, height: 12)

          Text(L10n.Update.downloading)
            .font(.system(size: 10.5, weight: .medium))
            .foregroundColor(AppTheme.textPrimary)

          Spacer()

          if let progress = progress {
            Text("\(Int(progress * 100))%")
              .font(.system(size: 10, weight: .bold, design: .monospaced))
              .foregroundColor(AppTheme.textSecondary)
          }
        }

        if let progress = progress {
          ProgressView(value: progress)
            .progressViewStyle(.linear)
            .tint(AppTheme.accentCyan)
            .scaleEffect(y: 0.8)
        } else {
          ProgressView()
            .progressViewStyle(.linear)
            .tint(AppTheme.accentCyan)
            .scaleEffect(y: 0.8)
        }
      }
      .padding(8)
      .background(
        RoundedRectangle(cornerRadius: 9, style: .continuous)
          .fill(AppTheme.cardBackground)
          .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
              .stroke(AppTheme.cardBorder, lineWidth: 0.5)
          )
      )

    case .installing:
      HStack(spacing: 8) {
        ProgressView()
          .scaleEffect(0.6)
          .frame(width: 16, height: 16)

        Text(L10n.Update.installing)
          .font(.system(size: 10.5, weight: .medium))
          .foregroundColor(AppTheme.textPrimary)

        Spacer()
      }
      .padding(8)
      .background(
        RoundedRectangle(cornerRadius: 9, style: .continuous)
          .fill(AppTheme.cardBackground)
          .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
              .stroke(AppTheme.cardBorder, lineWidth: 0.5)
          )
      )

    case .readyToQuit(let version):
      VStack(alignment: .leading, spacing: 6) {
        HStack(spacing: 6) {
          Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 14))
            .foregroundColor(AppTheme.accentGreen)

          Text(L10n.Update.readyToQuitTitle(version: version))
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(AppTheme.textPrimary)
        }

        Text(L10n.Update.readyToQuitSubtitle)
          .font(.system(size: 9.5))
          .foregroundColor(AppTheme.textSecondary)
          .fixedSize(horizontal: false, vertical: true)

        HStack(spacing: 8) {
          Button(action: {
            updateManager.quitAfterUpdate(relaunch: true)
          }) {
            HStack(spacing: 4) {
              Image(systemName: "arrow.clockwise")
                .font(.system(size: 9, weight: .bold))
              Text(L10n.Update.restartApp)
                .font(.system(size: 10, weight: .bold))
            }
            .foregroundColor(Color.black)
            .accessibilityLabel(L10n.Update.restartApp)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 5)
            .background(Capsule().fill(AppTheme.accentAmber))
          }
          .buttonStyle(.plain)

          Button(action: {
            updateManager.quitAfterUpdate(relaunch: false)
          }) {
            HStack(spacing: 4) {
              Image(systemName: "power")
                .font(.system(size: 9, weight: .bold))
              Text(L10n.Update.quitApp)
                .font(.system(size: 10, weight: .semibold))
            }
            .foregroundColor(AppTheme.textPrimary)
            .accessibilityLabel(L10n.Update.quitApp)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 5)
            .background(Capsule().fill(AppTheme.badgeBackground))
            .overlay(
              Capsule().stroke(AppTheme.cardBorder, lineWidth: 0.5)
            )
          }
          .buttonStyle(.plain)
        }
        .padding(.top, 2)
      }
      .padding(10)
      .background(
        RoundedRectangle(cornerRadius: 9, style: .continuous)
          .fill(AppTheme.badgeBackground)
          .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
              .stroke(AppTheme.cardBorder, lineWidth: 0.8)
          )
      )

    case .failed(let message):
      HStack(spacing: 8) {
        Image(systemName: "exclamationmark.circle.fill")
          .font(.system(size: 14))
          .foregroundColor(AppTheme.accentAmber)

        VStack(alignment: .leading, spacing: 1) {
          Text(L10n.Update.downloadFailedTitle)
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(AppTheme.textPrimary)
          Text(message)
            .font(.system(size: 8.5))
            .foregroundColor(AppTheme.textSecondary)
            .lineLimit(1)
        }

        Spacer()

        Button(action: {
          updateManager.downloadAndInstallUpdate()
        }) {
          Text(L10n.Update.retry)
            .font(.system(size: 9.5, weight: .semibold))
            .foregroundColor(AppTheme.accentCyan)
            .accessibilityLabel(L10n.Update.retry)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(AppTheme.accentCyan.opacity(0.15)))
        }
        .buttonStyle(.plain)
      }
      .padding(8)
      .background(
        RoundedRectangle(cornerRadius: 9, style: .continuous)
          .fill(AppTheme.cardBackground)
          .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
              .stroke(AppTheme.cardBorder, lineWidth: 0.5)
          )
      )

    default:
      EmptyView()
    }
  }
}

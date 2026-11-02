import SwiftUI

struct DashboardPrayerSection: View {
  @ObservedObject private var prayerManager = PrayerManager.shared
  @ObservedObject private var adzanPlayer = AdzanPlayer.shared
  @ObservedObject private var themeManager = ThemeManager.shared
  @ObservedObject private var languageManager = LanguageManager.shared

  var body: some View {
    if prayerManager.prayerItems.isEmpty {
      DashboardCard {
        unavailableView
      }
    } else {
      VStack(alignment: .leading, spacing: 8) {
        headerControls

        DashboardCard {
          VStack(spacing: 4) {
            if !prayerManager.imsakTimeString.isEmpty {
              row(
                name: L10n.Prayer.imsak,
                icon: "sparkles",
                time: prayerManager.imsakTimeString,
                isCurrent: false,
                isNext: false
              )
            }

            ForEach(prayerManager.prayerItems) { item in
              row(
                name: item.name,
                icon: item.iconName,
                time: item.timeString,
                isCurrent: item.isCurrent,
                isNext: item.isNext
              )
            }
          }
        }

        metadataFooter
      }
    }
  }

  private var headerControls: some View {
    HStack(spacing: 8) {
      Menu {
        Toggle(isOn: $prayerManager.useGPS) {
          Label(L10n.Prayer.autoGPS, systemImage: "location.fill")
        }

        Divider()

        ForEach(CityPreset.presets) { city in
          Button {
            prayerManager.useGPS = false
            prayerManager.selectedCity = city
          } label: {
            HStack {
              Text("\(city.name) (\(city.province))")
              if !prayerManager.useGPS && prayerManager.selectedCity.id == city.id {
                Image(systemName: "checkmark")
              }
            }
          }
        }

        Divider()

        Menu {
          ForEach([-15, -10, -5, 0, 5, 10, 15, 20, 25, 30], id: \.self) { offset in
            Button {
              prayerManager.jumatOffsetMinutes = offset
            } label: {
              HStack {
                Text(L10n.Prayer.jumatOffsetLabel(offset))
                if prayerManager.jumatOffsetMinutes == offset {
                  Image(systemName: "checkmark")
                }
              }
            }
          }
        } label: {
          Label(
            L10n.Prayer.jumatOffsetLabel(prayerManager.jumatOffsetMinutes),
            systemImage: "person.3.fill"
          )
        }
      } label: {
        HStack(spacing: 5) {
          Image(systemName: prayerManager.useGPS ? "location.fill" : "mappin.and.ellipse")
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(AppTheme.accentAmber)
            .accessibilityHidden(true)

          Text(prayerManager.currentLocationName)
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(AppTheme.textPrimary)
            .lineLimit(1)

          Image(systemName: "chevron.down")
            .font(.system(size: 8, weight: .bold))
            .foregroundColor(AppTheme.textTertiary)
            .accessibilityHidden(true)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(
          RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(AppTheme.cardBackground)
            .overlay(
              RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(AppTheme.cardBorder, lineWidth: 0.6)
            )
        )
      }
      .menuStyle(.borderlessButton)
      .fixedSize()
      .accessibilityLabel(prayerManager.currentLocationName)

      if !prayerManager.hijriDateString.isEmpty {
        Text(prayerManager.hijriDateString)
          .font(.system(size: 9.5, weight: .medium))
          .foregroundColor(AppTheme.textSecondary)
          .lineLimit(1)
      }

      Spacer(minLength: 4)

      HStack(spacing: 4) {
        adzanButton(
          systemImage: adzanPlayer.isPlaying ? "stop.fill" : "play.fill",
          color: adzanPlayer.isPlaying ? AppTheme.accentRed : AppTheme.accentGreen,
          label: adzanPlayer.isPlaying ? L10n.Prayer.stopAudio : L10n.Prayer.testAudio
        ) {
          if adzanPlayer.isPlaying {
            adzanPlayer.stop()
          } else {
            adzanPlayer.testPlay()
          }
        }

        adzanButton(
          systemImage: adzanPlayer.isMuted ? "bell.slash.fill" : "bell.fill",
          color: adzanPlayer.isMuted ? AppTheme.accentRed : AppTheme.accentAmber,
          label: adzanPlayer.isMuted ? L10n.Prayer.adzanMuted : L10n.Prayer.adzanActive
        ) {
          adzanPlayer.isMuted.toggle()
        }
      }
    }
  }

  private var metadataFooter: some View {
    HStack(spacing: 8) {
      if !prayerManager.qiblaString.isEmpty {
        HStack(spacing: 4) {
          Image(systemName: "location.north.line.fill")
            .font(.system(size: 8.5, weight: .bold))
            .foregroundColor(AppTheme.accentAmber)
            .accessibilityHidden(true)
          Text("\(L10n.Prayer.qibla): \(prayerManager.qiblaString)")
            .font(.system(size: 9, weight: .semibold))
            .foregroundColor(AppTheme.textSecondary)
        }
      }

      Spacer(minLength: 4)

      Text(L10n.Dashboard.calculationMethod(prayerManager.calculationMethodName))
        .font(.system(size: 9, weight: .medium))
        .foregroundColor(AppTheme.textTertiary)
        .lineLimit(1)
    }
  }

  private func row(
    name: String,
    icon: String,
    time: String,
    isCurrent: Bool,
    isNext: Bool
  ) -> some View {
    let emphasized = isCurrent || isNext
    return HStack(spacing: 8) {
      Image(systemName: icon)
        .font(.system(size: 10.5, weight: .semibold))
        .foregroundColor(
          isNext ? AppTheme.accentAmber : (isCurrent ? AppTheme.accentGreen : AppTheme.textTertiary)
        )
        .frame(width: 16)
        .accessibilityHidden(true)

      Text(name)
        .font(.system(size: 11, weight: emphasized ? .bold : .medium))
        .foregroundColor(emphasized ? AppTheme.textPrimary : AppTheme.textSecondary)

      if isNext || isCurrent {
        Text(isNext ? L10n.Prayer.nextBadge : L10n.Prayer.currentBadge)
          .font(.system(size: 8, weight: .bold))
          .foregroundColor(isNext ? AppTheme.accentAmber : AppTheme.accentGreen)
          .padding(.horizontal, 6)
          .padding(.vertical, 1.5)
          .background(
            Capsule()
              .fill((isNext ? AppTheme.accentAmber : AppTheme.accentGreen).opacity(0.14))
          )
      }

      Spacer(minLength: 4)

      Text(time)
        .font(.system(size: 11.5, weight: emphasized ? .bold : .medium, design: .rounded))
        .monospacedDigit()
        .foregroundColor(
          isNext ? AppTheme.accentAmber : (emphasized ? AppTheme.textPrimary : AppTheme.textSecondary)
        )
    }
    .padding(.vertical, 4)
    .padding(.horizontal, 6)
    .background(
      RoundedRectangle(cornerRadius: 7, style: .continuous)
        .fill(
          isNext
            ? AppTheme.accentAmber.opacity(0.10)
            : (isCurrent ? AppTheme.badgeBackground : Color.clear)
        )
        .overlay(
          RoundedRectangle(cornerRadius: 7, style: .continuous)
            .stroke(
              isNext ? AppTheme.accentAmber.opacity(0.35) : Color.clear,
              lineWidth: 0.7
            )
        )
    )
    .accessibilityElement(children: .combine)
    .accessibilityLabel(accessibilityText(name: name, time: time, isCurrent: isCurrent, isNext: isNext))
  }

  private func accessibilityText(name: String, time: String, isCurrent: Bool, isNext: Bool) -> String {
    var text = "\(name), \(time)"
    if isNext { text += ", \(L10n.Prayer.nextBadge)" }
    if isCurrent { text += ", \(L10n.Prayer.currentBadge)" }
    return text
  }

  private func adzanButton(
    systemImage: String,
    color: Color,
    label: String,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      Image(systemName: systemImage)
        .font(.system(size: 10, weight: .bold))
        .foregroundColor(color)
        .frame(width: 24, height: 24)
        .background(AppTheme.badgeBackground)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(
          RoundedRectangle(cornerRadius: 6, style: .continuous)
            .stroke(AppTheme.cardBorder, lineWidth: 0.5)
        )
    }
    .buttonStyle(.plain)
    .accessibilityLabel(label)
    .help(label)
  }

  private var unavailableView: some View {
    HStack(spacing: 9) {
      Image(systemName: "moon.stars")
        .font(.system(size: 14, weight: .semibold))
        .foregroundColor(AppTheme.textTertiary)
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 2) {
        Text(L10n.Dashboard.prayerUnavailable)
          .font(.system(size: 11, weight: .semibold))
          .foregroundColor(AppTheme.textSecondary)
        Text(L10n.Dashboard.prayerUnavailableDetail)
          .font(.system(size: 9))
          .foregroundColor(AppTheme.textTertiary)
          .fixedSize(horizontal: false, vertical: true)
      }
      Spacer(minLength: 4)
    }
  }
}

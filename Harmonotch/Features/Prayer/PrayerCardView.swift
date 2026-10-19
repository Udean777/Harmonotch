//
//  PrayerCardView.swift
//  Harmonotch
//

import SwiftUI

struct PrayerCardView: View {
    let item: PrayerScheduleItem
    @ObservedObject var languageManager = LanguageManager.shared

    var body: some View {
        VStack(spacing: 4) {
            // Icon & status indicator
            ZStack {
                Circle()
                    .fill(backgroundCircleColor)
                    .frame(width: 28, height: 28)

                Image(systemName: item.iconName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(iconColor)
            }

            // Nama Sholat & Arab
            VStack(spacing: 1) {
                Text(item.name)
                    .font(.system(size: 11, weight: item.isNext || item.isCurrent ? .bold : .medium))
                    .foregroundColor(.white)

                Text(item.arabicName)
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.45))
            }

            // Jam Sholat
            Text(item.timeString)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(item.isNext ? Color.green : (item.isCurrent ? Color.amberCustom : .white.opacity(0.85)))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(item.isNext ? Color.green.opacity(0.18) : (item.isCurrent ? Color.amberCustom.opacity(0.18) : Color.white.opacity(0.06)))
                )

            // Badge Status
            if item.isNext {
                Text(L10n.Prayer.nextBadge)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.green)
                    .textCase(.uppercase)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(Color.green.opacity(0.2)))
            } else if item.isCurrent {
                Text(L10n.Prayer.currentBadge)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(Color.amberCustom)
                    .textCase(.uppercase)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(Color.amberCustom.opacity(0.2)))
            } else {
                Text(" ")
                    .font(.system(size: 8))
                    .padding(.vertical, 1)
            }
        }
        .frame(width: 76)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 11)
                .fill(cardBackgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 11)
                        .stroke(cardBorderColor, lineWidth: 0.8)
                )
        )
    }

    private var cardBackgroundColor: Color {
        if item.isNext {
            return Color.green.opacity(0.12)
        } else if item.isCurrent {
            return Color.amberCustom.opacity(0.10)
        } else {
            return Color.white.opacity(0.04)
        }
    }

    private var cardBorderColor: Color {
        if item.isNext {
            return Color.green.opacity(0.4)
        } else if item.isCurrent {
            return Color.amberCustom.opacity(0.35)
        } else {
            return Color.white.opacity(0.08)
        }
    }

    private var backgroundCircleColor: Color {
        if item.isNext {
            return Color.green.opacity(0.25)
        } else if item.isCurrent {
            return Color.amberCustom.opacity(0.25)
        } else {
            return Color.white.opacity(0.08)
        }
    }

    private var iconColor: Color {
        if item.isNext {
            return .green
        } else if item.isCurrent {
            return Color.amberCustom
        } else {
            return .white.opacity(0.7)
        }
    }
}

// Helper Color
extension Color {
    static let amberCustom = Color(red: 1.0, green: 0.75, blue: 0.2)
}

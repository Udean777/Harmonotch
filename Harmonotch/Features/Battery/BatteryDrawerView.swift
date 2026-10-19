//
//  BatteryDrawerView.swift
//  Harmonotch
//

import SwiftUI
import AppKit

struct BatteryDrawerView: View {
    @ObservedObject var batteryMonitor = BatteryMonitor.shared
    @State private var isRefreshing: Bool = false

    var body: some View {
        VStack(spacing: 10) {
            // MARK: - Hero Battery Status Header
            HStack(alignment: .center, spacing: 14) {
                // Large Battery Icon
                ZStack {
                    Circle()
                        .fill(batteryAccentColor.opacity(0.18))
                        .frame(width: 42, height: 42)

                    Image(systemName: batteryIconName)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(batteryAccentColor)
                        .symbolEffect(.pulse, isActive: batteryMonitor.isCharging)
                }

                // Battery % & State Text
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(batteryMonitor.currentCapacity)%")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.white)

                        if batteryMonitor.isCharging {
                            Text("Mengisi Daya")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.green)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.green.opacity(0.2)))
                        } else if batteryMonitor.isPluggedIn {
                            Text("Tersambung")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.cyan)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.cyan.opacity(0.2)))
                        }
                    }

                    Text(batteryMonitor.timeRemainingFormatted)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.75))
                }

                Spacer()

                // Power Source Badge
                HStack(spacing: 5) {
                    Image(systemName: batteryMonitor.isPluggedIn ? "bolt.fill" : "batteryblock.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(batteryMonitor.isPluggedIn ? .green : .white.opacity(0.6))

                    Text(powerSourceLabel)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.08))
                .cornerRadius(8)
            }
            .padding(.horizontal, 16)

            // MARK: - Visual Battery Level Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.10))
                        .frame(height: 5)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [batteryAccentColor.opacity(0.8), batteryAccentColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(
                            width: max(8, geo.size.width * CGFloat(batteryMonitor.currentCapacity) / 100.0),
                            height: 5
                        )
                }
            }
            .frame(height: 5)
            .padding(.horizontal, 16)

            // MARK: - Metric Stat Cards (Grid of 4)
            HStack(spacing: 8) {
                // 1. Health
                BatteryStatCard(
                    icon: "heart.fill",
                    iconColor: .green,
                    title: "Kesehatan",
                    value: "\(batteryMonitor.healthPercent)%",
                    subtext: batteryMonitor.conditionString
                )

                // 2. Cycle Count
                BatteryStatCard(
                    icon: "arrow.triangle.2.circlepath",
                    iconColor: .cyan,
                    title: "Siklus Baterai",
                    value: "\(batteryMonitor.cycleCount)",
                    subtext: "Maks. \(batteryMonitor.maxCycleCount)"
                )

                // 3. Real vs Design Capacity
                BatteryStatCard(
                    icon: "gauge.with.needle.fill",
                    iconColor: Color.amberCustom,
                    title: "Kapasitas Penuh",
                    value: batteryMonitor.nominalCapacity > 0 ? "\(batteryMonitor.nominalCapacity) mAh" : "-",
                    subtext: batteryMonitor.designCapacity > 0 ? "Desain: \(batteryMonitor.designCapacity)" : "Maks"
                )

                // 4. Power Source / State
                BatteryStatCard(
                    icon: batteryMonitor.isPluggedIn ? "powerplug.fill" : "bolt.batteryblock",
                    iconColor: batteryMonitor.isPluggedIn ? .green : .white.opacity(0.7),
                    title: "Sumber Daya",
                    value: batteryMonitor.isPluggedIn ? "Adaptor AC" : "Baterai",
                    subtext: batteryMonitor.adapterWatts != nil ? "\(batteryMonitor.adapterWatts!)W Daya" : "Mandiri"
                )
            }
            .padding(.horizontal, 16)

            Divider()
                .background(Color.white.opacity(0.1))
                .padding(.horizontal, 16)

            // MARK: - Footer Controls
            HStack(spacing: 12) {
                // Refresh Button
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        isRefreshing = true
                    }
                    batteryMonitor.refreshBatteryInfo()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        isRefreshing = false
                    }
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11, weight: .semibold))
                            .rotationEffect(.degrees(isRefreshing ? 360 : 0))

                        Text("Perbarui Data")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)

                Spacer()

                // Open macOS Battery Settings
                Button(action: {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.battery") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 10))
                        Text("Pengaturan Baterai macOS")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(Color.amberCustom)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .frame(width: 540)
    }

    // MARK: - Helpers
    private var powerSourceLabel: String {
        if batteryMonitor.isPluggedIn {
            if let watts = batteryMonitor.adapterWatts {
                return "\(watts)W Adaptor AC"
            }
            return "Adaptor AC"
        }
        return "Baterai Internal"
    }

    private var batteryIconName: String {
        let cap = batteryMonitor.currentCapacity
        if batteryMonitor.isCharging {
            if cap >= 90 { return "battery.100.bolt" }
            if cap >= 60 { return "battery.75.bolt" }
            if cap >= 35 { return "battery.50.bolt" }
            return "battery.25.bolt"
        } else {
            if cap >= 90 { return "battery.100" }
            if cap >= 60 { return "battery.75" }
            if cap >= 35 { return "battery.50" }
            if cap >= 10 { return "battery.25" }
            return "battery.0"
        }
    }

    private var batteryAccentColor: Color {
        if batteryMonitor.isCharging {
            return .green
        }
        let cap = batteryMonitor.currentCapacity
        if cap > 20 {
            return .green
        } else if cap > 10 {
            return .orange
        } else {
            return .red
        }
    }
}

// MARK: - Compact Stat Card Component
struct BatteryStatCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String
    let subtext: String

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.16))
                    .frame(width: 26, height: 26)

                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(iconColor)
            }

            VStack(spacing: 2) {
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(1)

                Text(value)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }

            Text(subtext)
                .font(.system(size: 8, weight: .semibold))
                .foregroundColor(iconColor)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(
                    Capsule()
                        .fill(iconColor.opacity(0.14))
                )
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 11)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 11)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
                )
        )
    }
}

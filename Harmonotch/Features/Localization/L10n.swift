//
//  L10n.swift
//  Harmonotch
//

import SwiftUI

enum L10n {
    private static var isEnglish: Bool {
        LanguageManager.shared.currentLanguage == .english
    }

    // MARK: - Drawer Navigation
    enum Drawer {
        static var prayerTab: String {
            isEnglish ? "Prayer Times" : "Jadwal Sholat"
        }
        static var batteryTab: String {
            isEnglish ? "Battery Status" : "Status Baterai"
        }
    }

    // MARK: - Prayer Schedules & Adzan
    enum Prayer {
        static func localizedPrayerName(_ key: String) -> String {
            switch key.lowercased() {
            case "fajr", "subuh":
                return isEnglish ? "Fajr" : "Subuh"
            case "sunrise", "terbit":
                return isEnglish ? "Sunrise" : "Terbit"
            case "dhuhr", "dzuhur":
                return isEnglish ? "Dhuhr" : "Dzuhur"
            case "asr", "ashar":
                return isEnglish ? "Asr" : "Ashar"
            case "maghrib":
                return "Maghrib"
            case "isha", "isya":
                return isEnglish ? "Isha" : "Isya"
            default:
                return key
            }
        }

        static var autoGPS: String {
            isEnglish ? "Use Automatic Location (GPS)" : "Gunakan Lokasi Otomatis (GPS)"
        }
        static var nextBadge: String {
            isEnglish ? "NEXT" : "BERIKUTNYA"
        }
        static var currentBadge: String {
            isEnglish ? "NOW" : "SEKARANG"
        }
        static func adzanBannerTitle(name: String) -> String {
            let prayer = localizedPrayerName(name)
            return isEnglish ? "\(prayer) Adzan is Playing" : "Adzan \(prayer) Sedang Berkumandang"
        }
        static var adzanBannerSubtitle: String {
            "Hayya 'alash Shalaah..."
        }
        static var stop: String {
            isEnglish ? "Stop" : "Hentikan"
        }
        static var adzanActive: String {
            isEnglish ? "Adzan Active" : "Adzan Aktif"
        }
        static var adzanMuted: String {
            isEnglish ? "Adzan Muted" : "Adzan Dimatikan"
        }
        static var testAudio: String {
            isEnglish ? "Test Audio" : "Uji Audio"
        }
        static var stopAudio: String {
            isEnglish ? "Stop Audio" : "Stop Audio"
        }
    }

    // MARK: - Battery & Power Health Hub
    enum Battery {
        static var charging: String {
            isEnglish ? "Charging" : "Mengisi Daya"
        }
        static var connected: String {
            isEnglish ? "Connected" : "Tersambung"
        }
        static var onBattery: String {
            isEnglish ? "Using Battery" : "Menggunakan Baterai"
        }
        static func acAdapterWatts(_ watts: Int) -> String {
            isEnglish ? "\(watts)W AC Adapter" : "\(watts)W Adaptor AC"
        }
        static var acAdapter: String {
            isEnglish ? "AC Adapter" : "Adaptor AC"
        }
        static var internalBattery: String {
            isEnglish ? "Internal Battery" : "Baterai Internal"
        }
        static var healthTitle: String {
            isEnglish ? "Health" : "Kesehatan"
        }
        static var cycleTitle: String {
            isEnglish ? "Battery Cycles" : "Siklus Baterai"
        }
        static var capacityTitle: String {
            isEnglish ? "Full Capacity" : "Kapasitas Penuh"
        }
        static var powerSourceTitle: String {
            isEnglish ? "Power Source" : "Sumber Daya"
        }
        static var designPrefix: String {
            isEnglish ? "Design: " : "Desain: "
        }
        static var maxPrefix: String {
            isEnglish ? "Max. " : "Maks. "
        }
        static var conditionNormal: String {
            isEnglish ? "Normal Condition" : "Kondisi Normal"
        }
        static var powerBattery: String {
            isEnglish ? "Battery" : "Baterai"
        }
        static var powerAC: String {
            isEnglish ? "AC Power" : "Adaptor AC"
        }
        static var refreshData: String {
            isEnglish ? "Refresh Data" : "Perbarui Data"
        }
        static var batterySettings: String {
            isEnglish ? "macOS Battery Settings" : "Pengaturan Baterai macOS"
        }
        static var fullChargeAc: String {
            isEnglish ? "Full Charge (AC Adapter)" : "Daya Penuh (Adaptor AC)"
        }
        static var connectedCharger: String {
            isEnglish ? "Connected to Charger" : "Tersambung ke Pengisi Daya"
        }
        static func timeRemaining(hours: Int, mins: Int) -> String {
            isEnglish ? "\(hours)h \(mins)m remaining" : "\(hours)j \(mins)m tersisa"
        }
        static func timeToFull(hours: Int, mins: Int) -> String {
            isEnglish ? "\(hours)h \(mins)m until full" : "\(hours)j \(mins)m hingga penuh"
        }
        static var healthSuffix: String {
            isEnglish ? "Health" : "Sehat"
        }
    }

    // MARK: - Menu Bar Status Item & Dropdown Menu
    enum Menu {
        static var appTitle: String {
            "Harmonotch — Islamic Notch"
        }
        static var openDrawer: String {
            isEnglish ? "Open Notch Drawer" : "Buka Drawer Notch"
        }
        static var closeDrawer: String {
            isEnglish ? "Close Notch Drawer" : "Tutup Drawer Notch"
        }
        static var hideNotch: String {
            isEnglish ? "Hide Notch on Screen" : "Sembunyikan Notch di Layar"
        }
        static var showNotch: String {
            isEnglish ? "Show Notch on Screen" : "Tampilkan Notch di Layar"
        }
        static var languageMenu: String {
            isEnglish ? "Language" : "Bahasa"
        }
        static var locationPrefix: String {
            isEnglish ? "Location: " : "Wilayah: "
        }
        static var nextTag: String {
            isEnglish ? " [Next]" : " [Berikutnya]"
        }
        static var nowTag: String {
            isEnglish ? " [Now]" : " [Sekarang]"
        }
        static var testAdzan: String {
            isEnglish ? "Test Adzan Audio" : "Uji Coba Audio Adzan"
        }
        static var stopAdzan: String {
            isEnglish ? "Stop Adzan Audio" : "Hentikan Adzan"
        }
        static var quit: String {
            isEnglish ? "Quit Harmonotch" : "Keluar Harmonotch"
        }
        static var cyclesSuffix: String {
            isEnglish ? "Cycles" : "Siklus"
        }
    }
}

// MARK: - Sleek Language Toggle Pill View Component
struct LanguageTogglePill: View {
    @ObservedObject var languageManager = LanguageManager.shared

    var body: some View {
        HStack(spacing: 2) {
            ForEach(AppLanguage.allCases) { lang in
                Button(action: {
                    languageManager.setLanguage(lang)
                }) {
                    Text(lang.shortCode)
                        .font(.system(size: 10, weight: languageManager.currentLanguage == lang ? .bold : .medium))
                        .foregroundColor(languageManager.currentLanguage == lang ? .white : .white.opacity(0.45))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background {
                            if languageManager.currentLanguage == lang {
                                Capsule()
                                    .fill(Color.white.opacity(0.20))
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.08))
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.12), lineWidth: 0.6)
                )
        )
    }
}

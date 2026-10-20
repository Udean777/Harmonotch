import SwiftUI

enum L10n {
    private static var isEnglish: Bool {
        LanguageManager.shared.currentLanguage == .english
    }

    enum Drawer {
        static var prayerTab: String {
            isEnglish ? "Prayer Times" : "Jadwal Sholat"
        }
        static var batteryTab: String {
            isEnglish ? "Battery Status" : "Status Baterai"
        }
        static var mediaTab: String {
            isEnglish ? "Music & Lyrics" : "Musik & Lirik"
        }
    }

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
        static var audioAdzanTitle: String {
            isEnglish ? "Adzan Audio" : "Audio Adzan"
        }
        static var testAudio: String {
            isEnglish ? "Test Audio" : "Uji Audio"
        }
        static var stopAudio: String {
            isEnglish ? "Stop Audio" : "Stop Audio"
        }
        static var qibla: String {
            isEnglish ? "Qibla" : "Kiblat"
        }
        static var imsak: String {
            "Imsak"
        }
        static var imsakDetail: String {
            isEnglish ? "10m before Fajr" : "10m sebelum Subuh"
        }
    }

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

    enum Media {
        static var nowPlaying: String {
            isEnglish ? "Now Playing" : "Sedang Diputar"
        }
        static var paused: String {
            isEnglish ? "Paused" : "Dijeda"
        }
        static var noTrackPlaying: String {
            isEnglish ? "No Media Playing" : "Tidak Ada Musik"
        }
        static var openMusicPrompt: String {
            isEnglish ? "Play a song on Apple Music or Spotify" : "Putar lagu di Apple Music atau Spotify"
        }
        static var syncedLyricsTitle: String {
            isEnglish ? "Synced Lyrics" : "Lirik Lagu"
        }
        static var loadingLyrics: String {
            isEnglish ? "Fetching lyrics..." : "Memuat lirik..."
        }
        static var noLyricsFound: String {
            isEnglish ? "No synced lyrics available" : "Lirik lagu tidak tersedia"
        }
        static var instrumental: String {
            isEnglish ? "Instrumental Track" : "Lagu Instrumental"
        }
    }

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
        static var tabsMenu: String {
            isEnglish ? "Quick Tab Switcher" : "Pindah Tampilan Tab"
        }
        static var testAdzan: String {
            isEnglish ? "Test Adzan Audio" : "Uji Coba Audio Adzan"
        }
        static var stopAdzan: String {
            isEnglish ? "Stop Adzan Audio" : "Hentikan Adzan"
        }
        static var muteAdzan: String {
            isEnglish ? "Mute Adzan Audio" : "Bisukan Audio Adzan"
        }
        static var unmuteAdzan: String {
            isEnglish ? "Unmute Adzan Audio" : "Bunyikan Audio Adzan"
        }
        static var aboutHarmonotch: String {
            isEnglish ? "About Harmonotch" : "Tentang Harmonotch"
        }
        static var launchAtLogin: String {
            isEnglish ? "Launch at Login" : "Buka Otomatis saat Login"
        }
        static var quit: String {
            isEnglish ? "Quit Harmonotch" : "Keluar Harmonotch"
        }
        static var cyclesSuffix: String {
            isEnglish ? "Cycles" : "Siklus"
        }
    }

    enum Theme {
        static var themeMenu: String {
            isEnglish ? "Theme" : "Tema Tampilan"
        }
        static var designStyleSection: String {
            isEnglish ? "Design Style" : "Gaya Desain"
        }
        static var liquidGlass: String {
            isEnglish ? "Liquid Glass (Frosted Blur)" : "Liquid Glass (Kaca Cair)"
        }
        static var zenSerenity: String {
            isEnglish ? "Zen Serenity (Warm Paper)" : "Zen Serenity (Kertas Hangat)"
        }
        static var appearanceSection: String {
            isEnglish ? "Appearance Mode" : "Mode Tampilan"
        }
        static var system: String {
            isEnglish ? "Match System" : "Ikuti Sistem"
        }
        static var dark: String {
            isEnglish ? "Always Dark" : "Selalu Gelap"
        }
        static var light: String {
            isEnglish ? "Always Light" : "Selalu Terang"
        }
    }

    enum About {
        static var title: String {
            isEnglish ? "About Harmonotch" : "Tentang Harmonotch"
        }
        static var subtitle: String {
            isEnglish ? "Islamic Prayer & Battery Hub for MacBook Notch" : "Pusat Jadwal Sholat & Baterai untuk Notch MacBook"
        }
        static var version: String {
            let ver = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
            return "Version \(ver)"
        }
        static var developedBy: String {
            isEnglish ? "Crafted with care by Sajudin" : "Dibuat dengan penuh dedikasi oleh Sajudin"
        }
        static var openSourceCredits: String {
            isEnglish ? "Open Source Acknowledgements" : "Kredit & Lisensi Open Source"
        }
        static var adhanTitle: String {
            "Adhan-Swift"
        }
        static var adhanDesc: String {
            isEnglish ? "Astronomical calculation engine by Batoul Apps (MIT License)" : "Mesin kalkulasi astronomi waktu sholat oleh Batoul Apps (Lisensi MIT)"
        }
        static var audioTitle: String {
            isEnglish ? "Adzan Audio Recordings" : "Rekaman Audio Adzan"
        }
        static var audioDesc: String {
            isEnglish ? "High-fidelity adzan audio recordings sourced from IslamDownload.net" : "Rekaman audio adzan bersumber dari koleksi audio IslamDownload.net"
        }
        static var appleTechTitle: String {
            "Apple SF Symbols & IOKit"
        }
        static var appleTechDesc: String {
            isEnglish ? "Native macOS iconography & Darwin hardware battery framework" : "Ikonografi native macOS & framework baterai hardware Darwin"
        }
        static var viewLicense: String {
            isEnglish ? "View License" : "Lihat Lisensi"
        }
        static var close: String {
            isEnglish ? "Close" : "Tutup"
        }
    }
}

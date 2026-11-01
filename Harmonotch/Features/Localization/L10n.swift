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
            case "jumat", "jumuah", "jummah":
                return isEnglish ? "Jumu'ah" : "Jumat"
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
        static var myLocation: String {
            isEnglish ? "My Location" : "Lokasi Saya"
        }
        static var testPrayer: String {
            isEnglish ? "Test" : "Uji Coba"
        }
        static var imsak: String {
            "Imsak"
        }
        static func jumatOffsetLabel(_ minutes: Int) -> String {
            let name = localizedPrayerName("jumat")
            if minutes == 0 {
                return isEnglish ? "\(name): Dhuhr" : "\(name): Dzuhur"
            }
            let sign = minutes > 0 ? "+" : "−"
            return isEnglish ? "\(name): \(sign)\(abs(minutes)) min" : "\(name): \(sign)\(abs(minutes)) mnt"
        }
        static func notificationTitle(name: String) -> String {
            let prayer = localizedPrayerName(name)
            return isEnglish ? "\(prayer) Prayer Time" : "Waktu Sholat \(prayer)"
        }
        static func notificationBody(name: String, time: String, location: String) -> String {
            let prayer = localizedPrayerName(name)
            return isEnglish
                ? "It is now \(prayer) (\(time)) in \(location)."
                : "Telah masuk waktu sholat \(prayer) (\(time)) untuk wilayah \(location)."
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
        static var designPrefix: String {
            isEnglish ? "Design: " : "Desain: "
        }
        static var maxPrefix: String {
            isEnglish ? "Max. " : "Maks. "
        }
        static var conditionNormal: String {
            isEnglish ? "Normal Condition" : "Kondisi Normal"
        }
        static var conditionService: String {
            isEnglish ? "Service Recommended" : "Disarankan Servis"
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

    enum Clamshell {
        static var title: String {
            isEnglish ? "Clamshell Mode" : "Mode Clamshell"
        }
        static var subtitle: String {
            isEnglish ? "Keep awake with lid closed" : "Tetap hidup saat layar ditutup"
        }
        static var active: String {
            isEnglish ? "Active" : "Aktif"
        }
        static var standby: String {
            isEnglish ? "Standby (No Display)" : "Siaga (Menunggu Monitor)"
        }
        static var pausedLowBattery: String {
            isEnglish ? "Paused (Battery ≤ 50%)" : "Dijeda (Baterai ≤ 50%)"
        }
        static var off: String {
            isEnglish ? "Off" : "Nonaktif"
        }
        static var externalDisplayLabel: String {
            isEnglish ? "External Display" : "Monitor Eksternal"
        }
        static var noExternalDisplay: String {
            isEnglish ? "No external display detected" : "Tidak ada monitor eksternal terhubung"
        }
        static var setupPermission: String {
            isEnglish ? "Allow Access" : "Izinkan Akses"
        }
        static var authorized: String {
            isEnglish ? "Authorized" : "Akses diizinkan"
        }
        static var authorizing: String {
            isEnglish ? "Authorizing..." : "Meminta izin..."
        }
        static var batteryProtectionNote: String {
            isEnglish ? "Auto-pauses at ≤ 50% on battery" : "Otomatis dijeda jika baterai ≤ 50%"
        }
        static var warningNotificationTitle: String {
            isEnglish ? "Harmonotch stay-awake warning" : "Peringatan mode tetap hidup"
        }
        static func warningNotificationBody(capacity: Int) -> String {
            isEnglish
                ? "Battery is at \(capacity)%. Connect the charger to keep the Mac awake. Stay Awake pauses at 50%."
                : "Baterai tersisa \(capacity)%. Sambungkan pengisi daya agar Mac tetap hidup. Mode tetap hidup dijeda otomatis di 50%."
        }
    }

    enum Media {
        static func javascriptDisabledHint(browser: String) -> String {
            if browser == "Safari" {
                return isEnglish
                    ? "Safari: Develop > Developer Settings > Allow JavaScript from Apple Events"
                    : "Safari: Develop > Developer Settings > Allow JavaScript from Apple Events"
            }
            return isEnglish
                ? "\(browser): View > Developer > Allow JavaScript from Apple Events"
                : "\(browser): View > Developer > Allow JavaScript from Apple Events"
        }
        static func automationDeniedHint(browser: String) -> String {
            isEnglish
                ? "Allow Harmonotch to control \(browser) in System Settings > Privacy & Security > Automation"
                : "Izinkan Harmonotch mengontrol \(browser) di Pengaturan Sistem > Privasi & Keamanan > Otomasi"
        }
        static var nowPlaying: String {
            isEnglish ? "Now Playing" : "Sedang Diputar"
        }
        static var paused: String {
            isEnglish ? "Paused" : "Dijeda"
        }
        static var noTrackPlaying: String {
            isEnglish ? "No Media Playing" : "Tidak Ada Media"
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
            isEnglish ? "No synced lyrics available" : "Lirik tersinkron tidak tersedia"
        }
        static var instrumental: String {
            isEnglish ? "Instrumental Track" : "Lagu Instrumental"
        }
    }

    enum Menu {
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
        static var checkForUpdates: String {
            isEnglish ? "Check for Updates..." : "Periksa Pembaruan..."
        }
        static func updateAvailable(version: String) -> String {
            isEnglish ? "New Version Available (v\(version))" : "Versi Baru Tersedia (v\(version))"
        }
        static var downloadDMGAction: String {
            isEnglish ? "Download DMG Installer" : "Unduh Installer DMG"
        }
        static var viewReleaseNotesAction: String {
            isEnglish ? "View Release Notes on GitHub" : "Lihat Catatan Rilis di GitHub"
        }
        static var launchAtLogin: String {
            isEnglish ? "Launch at Login" : "Buka Otomatis saat Login"
        }
        static var clamshellToggle: String {
            isEnglish ? "Stay Awake with Lid Closed" : "Tetap Hidup saat Layar Ditutup"
        }
        static var quit: String {
            isEnglish ? "Quit Harmonotch" : "Keluar Harmonotch"
        }
        static var nextPrayer: String {
            isEnglish ? "Next Prayer" : "Sholat Berikutnya"
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
            isEnglish ? "Prayer times, battery, and music for the MacBook notch" : "Jadwal sholat, baterai, dan musik untuk notch MacBook"
        }
        static var version: String {
            let ver = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
            return "Version \(ver)"
        }
        static var developedBy: String {
            isEnglish ? "Made by Sajudin" : "Dibuat oleh Sajudin"
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

    enum Update {
        static var available: String {
            isEnglish ? "New Update Available" : "Pembaruan Tersedia"
        }
        static var checkForUpdates: String {
            isEnglish ? "Check for Updates" : "Periksa Pembaruan"
        }
        static var checking: String {
            isEnglish ? "Checking for updates..." : "Memeriksa pembaruan..."
        }
        static var upToDateTitle: String {
            isEnglish ? "You're Up to Date!" : "Aplikasi Sudah Versi Terbaru!"
        }
        static func upToDateMessage(version: String) -> String {
            isEnglish ? "Harmonotch \(version) is currently the newest version available." : "Harmonotch \(version) adalah versi terbaru yang tersedia saat ini."
        }
        static var checkFailedTitle: String {
            isEnglish ? "Update Check Failed" : "Gagal Memeriksa Pembaruan"
        }
        static var networkErrorDesc: String {
            isEnglish ? "Unable to reach GitHub servers. Please check your internet connection." : "Tidak dapat terhubung ke server GitHub. Silakan periksa koneksi internet Anda."
        }
        static func updateAvailableTitle(version: String) -> String {
            isEnglish ? "Harmonotch \(version) is Available!" : "Harmonotch \(version) Telah Tersedia!"
        }
        static var updateAvailablePrompt: String {
            isEnglish ? "A newer version of Harmonotch has been released with improvements and fixes. Would you like to download the DMG installer or view the release notes?" : "Versi terbaru Harmonotch telah dirilis dengan berbagai perbaikan dan peningkatan. Apakah Anda ingin mengunduh installer DMG atau membaca catatan rilis?"
        }
        static var downloadDMG: String {
            isEnglish ? "Download DMG" : "Unduh DMG"
        }
        static var updateNow: String {
            isEnglish ? "Update Now" : "Perbarui Sekarang"
        }
        static var downloading: String {
            isEnglish ? "Downloading update..." : "Mengunduh pembaruan..."
        }
        static var installing: String {
            isEnglish ? "Installing update..." : "Menginstal pembaruan..."
        }
        static func readyToQuitTitle(version: String) -> String {
            isEnglish ? "Harmonotch v\(version) Ready" : "Harmonotch v\(version) Siap"
        }
        static var readyToQuitSubtitle: String {
            isEnglish ? "Installation complete. Quit or restart app to finish updating." : "Instalasi selesai. Keluar atau buka ulang aplikasi untuk menyelesaikan update."
        }
        static var quitApp: String {
            isEnglish ? "Quit App" : "Keluar Aplikasi"
        }
        static var restartApp: String {
            isEnglish ? "Restart App" : "Buka Ulang"
        }
        static var retry: String {
            isEnglish ? "Retry" : "Coba Lagi"
        }
        static var needsApplicationsTitle: String {
            isEnglish ? "Move to Applications" : "Pindahkan ke Aplikasi"
        }
        static var needsApplicationsBody: String {
            isEnglish
                ? "Harmonotch cannot self-update from a read-only location or disk image. Please move Harmonotch.app to your Applications folder first."
                : "Harmonotch tidak dapat memperbarui otomatis dari lokasi read-only atau disk image. Silakan pindahkan Harmonotch.app ke folder Applications terlebih dahulu."
        }
        static var downloadFailedTitle: String {
            isEnglish ? "Download Failed" : "Gagal Mengunduh"
        }
        static var viewReleaseNotes: String {
            isEnglish ? "Release Notes" : "Catatan Rilis"
        }
        static var later: String {
            isEnglish ? "Later" : "Nanti"
        }
    }
}

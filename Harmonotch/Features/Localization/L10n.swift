import SwiftUI

enum L10n {
    private static var isEnglish: Bool {
        LanguageManager.shared.currentLanguage == .english
    }

    enum Drawer {
        static var prayerTab: String {
            isEnglish ? "Prayer" : "Sholat"
        }
        static var batteryTab: String {
            isEnglish ? "Battery" : "Baterai"
        }
        static var mediaTab: String {
            isEnglish ? "Audio" : "Audio"
        }
        static var agentsTab: String {
            isEnglish ? "AI Agents" : "AI Agents"
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
        static var chargeLimitStatusBypass: String {
            isEnglish ? "AC Bypass Active" : "Bypass AC Aktif"
        }
    }

    enum Clamshell {
        static var title: String {
            isEnglish ? "Clamshell Mode" : "Mode Clamshell"
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
        static var noExternalDisplay: String {
            isEnglish ? "No external display detected" : "Tidak ada monitor eksternal terhubung"
        }
        static var setupPermission: String {
            isEnglish ? "Setup Access" : "Atur Izin"
        }
        static var authorizing: String {
            isEnglish ? "Authorizing..." : "Meminta izin..."
        }
        static var setupFailedMessage: String {
            isEnglish ? "Setup failed or cancelled. Admin permission is required." : "Pengaturan izin gagal atau dibatalkan. Izin admin diperlukan."
        }
        static var powerAdapterWarning: String {
            isEnglish ? "Connect power adapter recommended (auto-pauses at ≤ 50%)" : "Disarankan pasang adaptor daya (jeda otomatis saat ≤ 50%)"
        }
        static var batteryProtectionNote: String {
            isEnglish ? "Auto-pauses at ≤ 50% on battery" : "Otomatis dijeda jika baterai ≤ 50%"
        }
        static var menuSetupAction: String {
            isEnglish ? "Setup Clamshell Permission..." : "Atur Izin Mode Clamshell..."
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
        static var noTrackPlaying: String {
            isEnglish ? "No Media Playing" : "Tidak Ada Media"
        }
        static var openMusicPrompt: String {
            isEnglish ? "Play a song on Apple Music or Spotify" : "Putar lagu di Apple Music atau Spotify"
        }
        static var syncedLyricsTitle: String {
            isEnglish ? "Lyrics" : "Lirik Lagu"
        }
        static var syncedLyricsBadge: String {
            isEnglish ? "Synced" : "Tersinkron"
        }
        static var unsyncedLyricsBadge: String {
            isEnglish ? "Unsynced" : "Tidak Sinkron"
        }
        static var unsyncedLyricsNotice: String {
            isEnglish ? "This track only has plain lyrics without timing sync." : "Lagu ini hanya memiliki teks lirik tanpa sinkronisasi waktu."
        }
        static var lyricsUnavailable: String {
            isEnglish ? "Lyrics Unavailable" : "Lirik Tidak Tersedia"
        }
        static var lyricsUnavailableDesc: String {
            isEnglish ? "Lyrics could not be found or synced for this track." : "Lirik tidak dapat dimuat atau belum tersedia untuk lagu ini."
        }
        static var loadingLyrics: String {
            isEnglish ? "Fetching lyrics..." : "Memuat lirik..."
        }
        static var noLyricsFound: String {
            isEnglish ? "No lyrics available" : "Lirik tidak tersedia"
        }
        static var showLyrics: String {
            isEnglish ? "Show Lyrics" : "Tampilkan Lirik"
        }
        static var hideLyrics: String {
            isEnglish ? "Hide Lyrics" : "Sembunyikan Lirik"
        }
        static var syncLyrics: String {
            isEnglish ? "Sync Lyrics" : "Sinkronkan Lirik"
        }
        static var lyricsNotFound: String {
            isEnglish ? "Lyrics not found for this track." : "Lirik tidak ditemukan untuk lagu ini."
        }
        static var showQueue: String {
            isEnglish ? "Show Queue" : "Tampilkan Antrean"
        }
        static var hideQueue: String {
            isEnglish ? "Hide Queue" : "Sembunyikan Antrean"
        }
        static var queueEmpty: String {
            isEnglish ? "Queue is empty." : "Antrean kosong."
        }
        static var queueTitle: String {
            isEnglish ? "Queue" : "Antrean"
        }
        static var instrumental: String {
            isEnglish ? "Instrumental Track" : "Lagu Instrumental"
        }
        static var instrumentalDesc: String {
            isEnglish ? "Instrumental audio with no vocal lyrics." : "Audio instrumental tanpa vokal atau lirik."
        }
        static var previousTrack: String {
            isEnglish ? "Previous Track" : "Lagu Sebelumnya"
        }
        static var nextTrack: String {
            isEnglish ? "Next Track" : "Lagu Berikutnya"
        }
        static var play: String {
            isEnglish ? "Play" : "Putar"
        }
        static var pause: String {
            isEnglish ? "Pause" : "Jeda"
        }
        static var audioPlaying: String {
            isEnglish ? "Audio playing" : "Sedang memutar audio"
        }
        static func openApp(_ name: String) -> String {
            isEnglish ? "Open \(name)" : "Buka \(name)"
        }
        static func appPlayingAudio(_ name: String) -> String {
            isEnglish ? "\(name) is playing audio" : "\(name) sedang memutar audio"
        }
        static var includeOtherAudioApps: String {
            isEnglish ? "Include Other Audio Apps" : "Sertakan App Audio Lain"
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
        static var notchAgentMenu: String {
            isEnglish ? "Notch AI Provider" : "Provider AI di Notch"
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
        static var viewReleaseNotesAction: String {
            isEnglish ? "View Release Notes on GitHub" : "Lihat Catatan Rilis di GitHub"
        }
        static var launchAtLogin: String {
            isEnglish ? "Launch at Login" : "Buka Otomatis saat Login"
        }
        static var clamshellToggle: String {
            isEnglish ? "Stay Awake with Lid Closed" : "Tetap Hidup saat Layar Ditutup"
        }
        static var volumeHUDToggle: String {
            isEnglish ? "Volume HUD in Notch" : "Volume HUD di Notch"
        }
        static var quit: String {
            isEnglish ? "Quit Harmonotch" : "Keluar Harmonotch"
        }
        static var nextPrayer: String {
            isEnglish ? "Next Prayer" : "Sholat Berikutnya"
        }
        static var headerSubtitle: String {
            isEnglish ? "Battery & Audio Notch" : "Notch Baterai & Audio"
        }
    }

    enum Dashboard {
        static var nowTab: String {
            isEnglish ? "Overview" : "Ringkasan"
        }
        static var batteryTab: String {
            isEnglish ? "Battery" : "Baterai"
        }
        static var prayerTab: String {
            isEnglish ? "Prayer" : "Sholat"
        }
        static var agentsTab: String {
            isEnglish ? "AI Agent" : "AI Agent"
        }
        static var closeDashboard: String {
            isEnglish ? "Close Dashboard" : "Tutup Dashboard"
        }

        static var battery: String {
            isEnglish ? "Battery" : "Baterai"
        }
        static var loading: String {
            isEnglish ? "Loading..." : "Memuat..."
        }
        static var batteryReadFailed: String {
            isEnglish ? "Could not read the battery" : "Tidak dapat membaca baterai"
        }
        static var notAvailable: String {
            isEnglish ? "Not available" : "Tidak tersedia"
        }
        static var batteryRefresh: String {
            isEnglish ? "Refresh battery" : "Segarkan baterai"
        }
        static var batteryStale: String {
            isEnglish ? "Reading may be out of date" : "Pembacaan mungkin sudah usang"
        }
        static var batteryShowingLastReading: String {
            isEnglish ? "Refresh failed. Showing the last reading." : "Gagal menyegarkan. Menampilkan pembacaan terakhir."
        }
        static func batteryUpdated(_ time: String) -> String {
            isEnglish ? "Updated \(time)" : "Diperbarui \(time)"
        }
        static var designCapacity: String {
            isEnglish ? "Design Capacity" : "Kapasitas Desain"
        }
        static var designCycles: String {
            isEnglish ? "Design Cycles" : "Siklus Desain"
        }
        static var adapter: String {
            isEnglish ? "Adapter" : "Adaptor"
        }
        static var voltage: String {
            isEnglish ? "Voltage" : "Tegangan"
        }
        static var current: String {
            isEnglish ? "Current" : "Arus"
        }
        static var temperature: String {
            isEnglish ? "Temperature" : "Suhu"
        }
        static var power: String {
            isEnglish ? "Power" : "Daya"
        }
        static var powerSource: String {
            isEnglish ? "Power Source" : "Sumber Daya"
        }
        static var readingBattery: String {
            isEnglish ? "Reading battery..." : "Membaca baterai..."
        }
        static var batteryUnavailable: String {
            isEnglish ? "Battery unavailable" : "Baterai tidak tersedia"
        }
        static var noInternalBattery: String {
            isEnglish ? "No internal battery" : "Tidak ada baterai internal"
        }
        static func calculationMethod(_ name: String) -> String {
            isEnglish ? "Method: \(name)" : "Metode: \(name)"
        }
        static var prayerUnavailableDetail: String {
            isEnglish
                ? "Times could not be calculated for this location. Check the location in Prayer settings."
                : "Waktu tidak dapat dihitung untuk lokasi ini. Periksa lokasi di pengaturan Sholat."
        }
        static var prayerUnavailable: String {
            isEnglish ? "Prayer schedule unavailable" : "Jadwal sholat tidak tersedia"
        }
        static func countdown(hours: Int, minutes: Int) -> String {
            if hours <= 0 && minutes <= 0 {
                return isEnglish ? "in <1m" : "dalam <1m"
            }
            let value = hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
            return isEnglish ? "in \(value)" : "dalam \(value)"
        }
    }

    enum AIAgents {
        static var setupTitle: String {
            isEnglish ? "AI Agent Quota Monitor" : "Monitor Kuota AI Agent"
        }
        static var setupSubtitle: String {
            isEnglish
                ? "Scan installed AI Agent CLIs on this Mac to verify authentication and view realtime quota usage."
                : "Pindai CLI AI Agent yang terinstal di Mac ini untuk mengecek status login dan kuota secara realtime."
        }
        static var checkButton: String {
            isEnglish ? "Check AI Agents" : "Check AI Agents"
        }
        static var scanningText: String {
            isEnglish ? "Checking installed AI Agent CLIs..." : "Mengecek CLI AI Agent yang terinstal..."
        }
        static var refreshAgents: String {
            isEnglish ? "Refresh AI Agents" : "Segarkan AI Agent"
        }
        static var statusActive: String {
            isEnglish ? "Logged In" : "Terautentikasi"
        }
        static var statusFailed: String {
            isEnglish ? "Failed" : "Gagal"
        }
        static var notLoggedInReason: String {
            isEnglish ? "Not logged in / Unauthenticated" : "Belum login / Tidak terautentikasi"
        }
        static var noAgentsInstalledTitle: String {
            isEnglish ? "No AI Agent CLIs Found" : "CLI AI Agent Tidak Ditemukan"
        }
        static var noAgentsInstalledDetail: String {
            isEnglish
                ? "Install Claude Code, Codex, OpenCode, or Gemini CLI to track their quota here."
                : "Instal Claude Code, Codex, OpenCode, atau Gemini CLI untuk memantau kuotanya di sini."
        }
        static var cliSessions: String {
            isEnglish ? "Local CLI Sessions" : "Sesi CLI Lokal"
        }
        static var claudeSubscribedNote: String {
            isEnglish ? "OAuth session active via Claude CLI" : "Sesi OAuth aktif via Claude CLI"
        }
        static var authenticatedReady: String {
            isEnglish ? "Authenticated & ready" : "Terautentikasi & siap digunakan"
        }
        static var resetCredits: String {
            isEnglish ? "Reset Credits" : "Kredit Reset"
        }
        static var connectedProviders: String {
            isEnglish ? "Connected Providers" : "Provider Terhubung"
        }
        static var accountLabel: String {
            isEnglish ? "Account" : "Akun"
        }
        static var quotaWindow: String {
            isEnglish ? "Quota Window" : "Jendela Kuota"
        }
        static var activeModelLabel: String {
            isEnglish ? "Active Model" : "Model Aktif"
        }
        static var providerLabel: String {
            isEnglish ? "Provider" : "Penyedia"
        }
        static var configuredModels: String {
            isEnglish ? "Configured Models" : "Model Terkonfigurasi"
        }
        static var reasoningEffortLabel: String {
            isEnglish ? "Reasoning Effort" : "Tingkat Penalaran"
        }
        static var detailQuotaTitle: String {
            isEnglish ? "Quota Details" : "Detail Quota"
        }
        static var viewDetailQuota: String {
            isEnglish ? "View Quota Details" : "Lihat Detail Quota"
        }
        static var backButton: String {
            isEnglish ? "Back" : "Kembali"
        }
        static var filterAll: String {
            isEnglish ? "All" : "Semua"
        }
        static var showDetails: String {
            isEnglish ? "Show Quota Details" : "Lihat Sisa Kuota"
        }
        static var hideDetails: String {
            isEnglish ? "Hide Quota Details" : "Sembunyikan Kuota"
        }
        static var quotaOverview: String {
            isEnglish ? "Remaining Quota" : "Sisa Kuota"
        }
        static func loginHint(_ cmd: String) -> String {
            isEnglish ? "Run `\(cmd)` in Terminal to authenticate." : "Jalankan `\(cmd)` di Terminal untuk login."
        }
        static func summaryCount(active: Int, failed: Int) -> String {
            if failed > 0 {
                return isEnglish
                    ? "\(active) Active • \(failed) Failed"
                    : "\(active) Aktif • \(failed) Gagal"
            }
            return isEnglish ? "\(active) Active Agents" : "\(active) Agent Aktif"
        }
        static var showInNotchTitle: String {
            isEnglish ? "Pin to Notch" : "Pin ke Notch"
        }
        static var activeInNotchBadge: String {
            isEnglish ? "In Notch" : "Di Notch"
        }
        static var copyCommand: String {
            isEnglish ? "Copy" : "Salin"
        }
        static var copiedCommand: String {
            isEnglish ? "Copied" : "Tersalin"
        }
        static var switchAgentHint: String {
            isEnglish ? "Switch active AI Agent" : "Ganti AI Agent aktif"
        }
        static func agentNotInstalled(_ name: String) -> String {
            isEnglish ? "\(name) is not installed on this Mac" : "\(name) belum terinstal di Mac ini"
        }
        static var selectDifferentProviderHint: String {
            isEnglish ? "Choose an installed provider below or from the Menu Bar" : "Pilih provider yang terinstal di bawah atau dari Menu Bar"
        }
        static var selectedInMenuBar: String {
            isEnglish ? "Synced with Menu Bar" : "Tersinkron dengan Menu Bar"
        }
        static var availableAgentsPrefix: String {
            isEnglish ? "Installed:" : "Terinstal:"
        }
    }

    enum About {
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
        static var vorssaintTitle: String {
            "Vorssaint"
        }
        static var vorssaintDesc: String {
            isEnglish
                ? "Reference for the MediaRemote technique, playback state reconciliation, clamshell behavior, volume-key HUD, and accessibility permission flow"
                : "Referensi teknik MediaRemote, rekonsiliasi state playback, perilaku clamshell, HUD tombol volume, dan alur izin aksesibilitas"
        }
        static var lrclibTitle: String {
            "LRCLIB"
        }
        static var lrclibDesc: String {
            isEnglish
                ? "Real-time synchronized karaoke lyrics engine by Tran Xuan Thang (MIT License)"
                : "Mesin sinkronisasi lirik karaoke real-time oleh Tran Xuan Thang (Lisensi MIT)"
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

    enum Volume {
        static func accessibilityLabel(percent: Int, muted: Bool) -> String {
            if muted {
                return isEnglish ? "Volume muted, 0 percent" : "Volume dibisukan, 0 persen"
            }
            return isEnglish ? "Volume \(percent) percent" : "Volume \(percent) persen"
        }

        static var statusActive: String {
            isEnglish ? "Active in Notch" : "Aktif di Notch"
        }

        static var statusNeedsPermission: String {
            isEnglish ? "Needs Accessibility Permission" : "Butuh Izin Aksesibilitas"
        }

        static var statusDisabled: String {
            isEnglish ? "Using macOS System HUD" : "Menggunakan HUD Bawaan macOS"
        }

        static var grantPermissionAction: String {
            isEnglish ? "Grant Access" : "Beri Izin"
        }
    }
}

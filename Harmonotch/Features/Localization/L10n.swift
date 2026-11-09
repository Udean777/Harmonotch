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
            isEnglish ? "Adzan Sound: On" : "Suara Adzan: Aktif"
        }
        static var adzanMuted: String {
            isEnglish ? "Adzan Sound: Off" : "Suara Adzan: Mati"
        }
        static var audioAdzanTitle: String {
            isEnglish ? "Adzan Sound" : "Suara Adzan"
        }
        static var testAudio: String {
            isEnglish ? "Test Sound" : "Coba Suara"
        }
        static var stopAudio: String {
            isEnglish ? "Stop Sound" : "Hentikan Suara"
        }
        static var qibla: String {
            isEnglish ? "Qibla Direction" : "Arah Kiblat"
        }
        static var myLocation: String {
            isEnglish ? "Current Location" : "Lokasi Saat Ini"
        }
        static var testPrayer: String {
            isEnglish ? "Test" : "Uji Coba"
        }
        static var imsak: String {
            "Imsak"
        }
        static var jumatOffsetMenuTitle: String {
            isEnglish ? "Friday Prayer Time" : "Waktu Sholat Jumat"
        }
        static func jumatOffsetLabel(_ minutes: Int) -> String {
            let name = localizedPrayerName("jumat")
            if minutes == 0 {
                return isEnglish ? "\(name): Same as Dhuhr" : "\(name): Sesuai Waktu Dzuhur"
            }
            if minutes > 0 {
                return isEnglish
                    ? "\(name): \(minutes) min after Dhuhr"
                    : "\(name): \(minutes) mnt setelah Dzuhur"
            }
            return isEnglish
                ? "\(name): \(abs(minutes)) min before Dhuhr"
                : "\(name): \(abs(minutes)) mnt sebelum Dzuhur"
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
            isEnglish ? "Plugged In" : "Casan Terpasang"
        }
        static var onBattery: String {
            isEnglish ? "On Battery" : "Pakai Baterai"
        }
        static func acAdapterWatts(_ watts: Int) -> String {
            isEnglish ? "\(watts)W Charger" : "Casan \(watts)W"
        }
        static var acAdapter: String {
            isEnglish ? "Power Adapter" : "Casan Terpasang"
        }
        static var internalBattery: String {
            isEnglish ? "Mac Battery" : "Baterai Laptop"
        }
        static var healthTitle: String {
            isEnglish ? "Battery Health" : "Kondisi Baterai"
        }
        static var cycleTitle: String {
            isEnglish ? "Charge Cycles" : "Siklus Pakai"
        }
        static var capacityTitle: String {
            isEnglish ? "Current Capacity" : "Kapasitas Saat Ini"
        }
        static var fullChargeAc: String {
            isEnglish ? "Fully Charged (Plugged In)" : "Penuh (Casan Terpasang)"
        }
        static var connectedCharger: String {
            isEnglish ? "Connected to Charger" : "Tersambung ke Casan"
        }
        static func timeRemaining(hours: Int, mins: Int) -> String {
            isEnglish ? "\(hours)h \(mins)m remaining" : "Sisa sekitar \(hours) jam \(mins) mnt"
        }
        static func timeToFull(hours: Int, mins: Int) -> String {
            isEnglish ? "\(hours)h \(mins)m until full" : "\(hours) jam \(mins) mnt lagi penuh"
        }
        static var chargeLimitStatusBypass: String {
            isEnglish ? "Protected (Running on Charger)" : "Baterai Dijaga (Listrik Casan)"
        }
        static func healthCondition(_ percent: Int?) -> String {
            guard let percent else { return Dashboard.notAvailable }
            if percent >= 80 {
                return isEnglish ? "\(percent)% (Normal)" : "\(percent)% (Normal)"
            }
            return isEnglish ? "\(percent)% (Check Battery)" : "\(percent)% (Perlu Servis)"
        }
        static func temperatureWithStatus(_ celsius: Double) -> String {
            let formatted = String(format: "%.1f °C", celsius)
            if celsius < 36 {
                return isEnglish ? "\(formatted) (Cool)" : "\(formatted) (Dingin)"
            } else if celsius < 42 {
                return isEnglish ? "\(formatted) (Normal)" : "\(formatted) (Normal)"
            } else {
                return isEnglish ? "\(formatted) (Warm)" : "\(formatted) (Hangat)"
            }
        }
        static func technicalDetailsToggle(expanded: Bool) -> String {
            if expanded {
                return isEnglish ? "Hide Technical Details" : "Sembunyikan Detail Teknis"
            }
            return isEnglish ? "Show Technical Details" : "Lihat Detail Teknis"
        }
    }

    enum Clamshell {
        static var title: String {
            isEnglish ? "Keep Awake When Closed" : "Tetap Menyala Saat Ditutup"
        }
        static var active: String {
            isEnglish ? "Active" : "Aktif"
        }
        static var standby: String {
            isEnglish ? "Ready (Connect Monitor)" : "Siap (Pasang Monitor)"
        }
        static var pausedLowBattery: String {
            isEnglish ? "Paused (Battery ≤ 50%)" : "Dijeda (Baterai ≤ 50%)"
        }
        static var off: String {
            isEnglish ? "Off" : "Mati"
        }
        static var noExternalDisplay: String {
            isEnglish
                ? "Connect an external monitor to keep Mac awake when closed"
                : "Sambungkan monitor luar agar Mac tetap hidup saat layar ditutup"
        }
        static var setupPermission: String {
            isEnglish ? "Enable Access" : "Aktifkan Izin"
        }
        static var authorizing: String {
            isEnglish ? "Requesting access..." : "Meminta izin..."
        }
        static var setupFailedMessage: String {
            isEnglish
                ? "Access cancelled. Mac password is required to enable this feature."
                : "Izin dibatalkan. Kata sandi Mac diperlukan untuk mengaktifkan fitur ini."
        }
        static var powerAdapterWarning: String {
            isEnglish
                ? "Charger recommended (auto-pauses at ≤ 50% battery)"
                : "Sebaiknya pasang casan (jeda otomatis saat baterai ≤ 50%)"
        }
        static var batteryProtectionNote: String {
            isEnglish ? "Auto-pauses if battery drops to 50%" : "Otomatis dijeda jika baterai ≤ 50%"
        }
        static var menuSetupAction: String {
            isEnglish ? "Enable Closed-Display Access..." : "Aktifkan Izin Layar Tertutup..."
        }
        static var warningNotificationTitle: String {
            isEnglish ? "Harmonotch Stay-Awake Warning" : "Peringatan Baterai Harmonotch"
        }
        static func warningNotificationBody(capacity: Int) -> String {
            isEnglish
                ? "Battery is at \(capacity)%. Connect the charger to keep your Mac awake. Stay Awake pauses at 50%."
                : "Baterai tersisa \(capacity)%. Pasang casan agar Mac tetap menyala. Fitur ini otomatis dijeda di 50%."
        }
    }

    enum Media {
        static func javascriptDisabledHint(browser: String) -> String {
            if browser == "Safari" {
                return isEnglish
                    ? "To control playback in Safari, enable Develop > Allow JavaScript from Apple Events"
                    : "Agar kontrol lagu di Safari aktif, nyalakan Develop > Allow JavaScript from Apple Events"
            }
            return isEnglish
                ? "To control playback in \(browser), enable View > Developer > Allow JavaScript from Apple Events"
                : "Agar kontrol lagu di \(browser) aktif, nyalakan View > Developer > Allow JavaScript from Apple Events"
        }
        static func automationDeniedHint(browser: String) -> String {
            isEnglish
                ? "Allow Harmonotch to control \(browser) in System Settings > Privacy & Security > Automation"
                : "Izinkan Harmonotch mengatur lagu di \(browser) lewat Pengaturan Sistem > Privasi & Keamanan > Otomasi"
        }
        static var nowPlaying: String {
            isEnglish ? "Now Playing" : "Sedang Diputar"
        }
        static var noTrackPlaying: String {
            isEnglish ? "No Music Playing" : "Belum Ada Musik Diputar"
        }
        static var openMusicPrompt: String {
            isEnglish ? "Play a song on Apple Music, Spotify, or your browser" : "Putar lagu di Apple Music, Spotify, atau browser Anda"
        }
        static var syncedLyricsTitle: String {
            isEnglish ? "Lyrics" : "Lirik Lagu"
        }
        static var syncedLyricsBadge: String {
            isEnglish ? "Auto-Scroll" : "Otomatis"
        }
        static var unsyncedLyricsBadge: String {
            isEnglish ? "Plain Text" : "Teks Penuh"
        }
        static var unsyncedLyricsNotice: String {
            isEnglish
                ? "Showing full lyrics (timing sync not available for this song)."
                : "Menampilkan lirik penuh (sinkronisasi waktu belum tersedia untuk lagu ini)."
        }
        static var lyricsUnavailable: String {
            isEnglish ? "Lyrics Not Available" : "Lirik Belum Tersedia"
        }
        static var lyricsUnavailableDesc: String {
            isEnglish
                ? "We couldn't find lyrics for this song yet."
                : "Lirik untuk lagu ini belum ditemukan."
        }
        static var loadingLyrics: String {
            isEnglish ? "Loading lyrics..." : "Mencari lirik lagu..."
        }
        static var noLyricsFound: String {
            isEnglish ? "No lyrics found" : "Lirik belum ada"
        }
        static var showLyrics: String {
            isEnglish ? "Show Lyrics" : "Tampilkan Lirik"
        }
        static var hideLyrics: String {
            isEnglish ? "Hide Lyrics" : "Sembunyikan Lirik"
        }
        static var syncLyrics: String {
            isEnglish ? "Reload Lyrics" : "Cari Ulang Lirik"
        }
        static var lyricsNotFound: String {
            isEnglish ? "Lyrics not found for this song." : "Lirik untuk lagu ini belum ditemukan."
        }
        static var showQueue: String {
            isEnglish ? "Show Next Songs" : "Lihat Lagu Berikutnya"
        }
        static var hideQueue: String {
            isEnglish ? "Hide Next Songs" : "Sembunyikan Antrean"
        }
        static var queueEmpty: String {
            isEnglish ? "No upcoming songs in queue." : "Belum ada lagu berikutnya di antrean."
        }
        static var queueTitle: String {
            isEnglish ? "Up Next" : "Lagu Berikutnya"
        }
        static var instrumental: String {
            isEnglish ? "Instrumental Music" : "Musik Instrumental"
        }
        static var instrumentalDesc: String {
            isEnglish ? "This track plays music without vocals." : "Lagu ini hanya berisi musik tanpa lirik vokal."
        }
        static var previousTrack: String {
            isEnglish ? "Previous Song" : "Lagu Sebelumnya"
        }
        static var nextTrack: String {
            isEnglish ? "Next Song" : "Lagu Berikutnya"
        }
        static var play: String {
            isEnglish ? "Play" : "Putar"
        }
        static var pause: String {
            isEnglish ? "Pause" : "Jeda"
        }
        static var audioPlaying: String {
            isEnglish ? "Playing audio" : "Sedang memutar suara"
        }
        static func openApp(_ name: String) -> String {
            isEnglish ? "Open \(name)" : "Buka \(name)"
        }
        static func appPlayingAudio(_ name: String) -> String {
            isEnglish ? "\(name) is playing audio" : "\(name) sedang memutar suara"
        }
        static var includeOtherAudioApps: String {
            isEnglish ? "Show Audio from Other Apps" : "Tampilkan Suara dari Aplikasi Lain"
        }
    }

    enum Menu {
        static var openDrawer: String {
            isEnglish ? "Open Notch Panel" : "Buka Panel Notch"
        }
        static var closeDrawer: String {
            isEnglish ? "Close Notch Panel" : "Tutup Panel Notch"
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
            isEnglish ? "Switch Notch View" : "Pilih Tampilan Notch"
        }
        static var notchAgentMenu: String {
            isEnglish ? "AI Shown in Notch" : "AI yang Tampil di Notch"
        }
        static var testAdzan: String {
            isEnglish ? "Test Adzan Sound" : "Coba Suara Adzan"
        }
        static var stopAdzan: String {
            isEnglish ? "Stop Adzan Sound" : "Hentikan Suara Adzan"
        }
        static var muteAdzan: String {
            isEnglish ? "Mute Adzan Sound" : "Matikan Suara Adzan"
        }
        static var unmuteAdzan: String {
            isEnglish ? "Turn On Adzan Sound" : "Nyalakan Suara Adzan"
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
            isEnglish ? "See What's New" : "Lihat Apa yang Baru"
        }
        static var launchAtLogin: String {
            isEnglish ? "Start Automatically When Mac Turns On" : "Buka Otomatis Saat Mac Menyala"
        }
        static var clamshellToggle: String {
            isEnglish ? "Keep Awake with Lid Closed" : "Tetap Menyala Saat Laptop Ditutup"
        }
        static var volumeHUDToggle: String {
            isEnglish ? "Volume Indicator in Notch" : "Tampilan Volume di Notch"
        }
        static var quit: String {
            isEnglish ? "Quit Harmonotch" : "Keluar dari Harmonotch"
        }
        static var nextPrayer: String {
            isEnglish ? "Next Prayer" : "Sholat Berikutnya"
        }
        static var headerSubtitle: String {
            isEnglish ? "Prayer, Battery & Music" : "Jadwal Sholat, Baterai & Musik"
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
            isEnglish ? "Close Panel" : "Tutup Panel"
        }
        static var updateShort: String {
            isEnglish ? "Check Update" : "Cek Update"
        }
        static var aboutShort: String {
            isEnglish ? "About" : "Tentang"
        }
        static var quitShort: String {
            isEnglish ? "Quit" : "Keluar"
        }

        static var battery: String {
            isEnglish ? "Battery" : "Baterai"
        }
        static var loading: String {
            isEnglish ? "Loading..." : "Memuat..."
        }
        static var batteryReadFailed: String {
            isEnglish ? "Could not read battery status" : "Status baterai belum dapat dibaca"
        }
        static var notAvailable: String {
            isEnglish ? "Not available" : "Tidak tersedia"
        }
        static var batteryRefresh: String {
            isEnglish ? "Refresh" : "Perbarui Data"
        }
        static var batteryStale: String {
            isEnglish ? "Battery info is being updated" : "Data baterai sedang diperbarui"
        }
        static var batteryShowingLastReading: String {
            isEnglish ? "Showing the latest saved battery info." : "Menampilkan info baterai terakhir."
        }
        static func batteryUpdated(_ time: String) -> String {
            isEnglish ? "Updated \(time)" : "Diperbarui \(time)"
        }
        static var designCapacity: String {
            isEnglish ? "Factory Capacity" : "Kapasitas Bawaan Pabrik"
        }
        static var designCycles: String {
            isEnglish ? "Normal Cycle Limit" : "Batas Siklus Normal"
        }
        static var adapter: String {
            isEnglish ? "Charger Power" : "Daya Casan"
        }
        static var voltage: String {
            isEnglish ? "Voltage" : "Tegangan Listrik"
        }
        static var current: String {
            isEnglish ? "Electric Current" : "Arus Listrik"
        }
        static var temperature: String {
            isEnglish ? "Battery Temperature" : "Suhu Baterai"
        }
        static var power: String {
            isEnglish ? "Power Usage" : "Daya Listrik"
        }
        static var powerSource: String {
            isEnglish ? "Power Source" : "Sumber Daya"
        }
        static var readingBattery: String {
            isEnglish ? "Checking battery..." : "Memeriksa baterai..."
        }
        static var batteryUnavailable: String {
            isEnglish ? "Battery info unavailable" : "Info baterai belum tersedia"
        }
        static var noInternalBattery: String {
            isEnglish ? "No built-in battery on this Mac" : "Mac ini tidak menggunakan baterai"
        }
        static func calculationMethod(_ name: String) -> String {
            if name.contains("Singapore") || name.contains("MUIS") {
                return isEnglish ? "Standard: MABIMS (Southeast Asia)" : "Standar: Kemenag / MABIMS"
            }
            return isEnglish ? "Standard: \(name)" : "Standar: \(name)"
        }
        static var prayerUnavailableDetail: String {
            isEnglish
                ? "Prayer times could not be calculated. Please choose a city in the Prayer tab."
                : "Jadwal sholat belum dapat dihitung. Silakan pilih kota di menu lokasi."
        }
        static var prayerUnavailable: String {
            isEnglish ? "Prayer schedule unavailable" : "Jadwal sholat belum tersedia"
        }
        static func countdown(hours: Int, minutes: Int) -> String {
            if hours <= 0 && minutes <= 0 {
                return isEnglish ? "less than 1 min" : "kurang dari 1 mnt"
            }
            let value = hours > 0
                ? (isEnglish ? "\(hours)h \(minutes)m" : "\(hours) jam \(minutes) mnt")
                : (isEnglish ? "\(minutes)m" : "\(minutes) mnt")
            return isEnglish ? "in \(value)" : "\(value) lagi"
        }
    }

    enum AIAgents {
        static var setupTitle: String {
            isEnglish ? "AI Quota Monitor" : "Pantau Kuota AI"
        }
        static var setupSubtitle: String {
            isEnglish
                ? "Check installed AI tools on this Mac to view login status and remaining quota."
                : "Periksa aplikasi AI yang terinstal di Mac ini untuk melihat status akun dan sisa kuota."
        }
        static var checkButton: String {
            isEnglish ? "Scan AI Tools" : "Periksa Aplikasi AI"
        }
        static var scanningText: String {
            isEnglish ? "Checking installed AI tools..." : "Memeriksa aplikasi AI yang terinstal..."
        }
        static var refreshAgents: String {
            isEnglish ? "Refresh AI Quota" : "Perbarui Kuota AI"
        }
        static var statusActive: String {
            isEnglish ? "Signed In" : "Sudah Masuk"
        }
        static var statusFailed: String {
            isEnglish ? "Sign In Needed" : "Perlu Masuk Akun"
        }
        static var notLoggedInReason: String {
            isEnglish ? "Account not signed in yet" : "Akun belum masuk (login)"
        }
        static var noAgentsInstalledTitle: String {
            isEnglish ? "No AI Tools Detected" : "Aplikasi AI Belum Terinstal"
        }
        static var noAgentsInstalledDetail: String {
            isEnglish
                ? "If you use Claude Code, Codex, OpenCode, or Gemini, install it to view remaining quota here."
                : "Jika Anda menggunakan Claude Code, Codex, OpenCode, atau Gemini, instal aplikasinya untuk memantau sisa kuota di sini."
        }
        static var cliSessions: String {
            isEnglish ? "Usage History" : "Riwayat Pemakaian"
        }
        static var claudeSubscribedNote: String {
            isEnglish ? "Signed in with Claude account" : "Terhubung dengan akun Claude"
        }
        static var authenticatedReady: String {
            isEnglish ? "Signed in & ready" : "Sudah masuk & siap dipakai"
        }
        static var resetCredits: String {
            isEnglish ? "Quota Reset" : "Reset Kuota"
        }
        static var connectedProviders: String {
            isEnglish ? "Connected Services" : "Layanan Terhubung"
        }
        static var accountLabel: String {
            isEnglish ? "Account" : "Akun"
        }
        static var quotaWindow: String {
            isEnglish ? "Usage Quota" : "Batas Kuota"
        }
        static var activeModelLabel: String {
            isEnglish ? "Active AI Model" : "Model AI Aktif"
        }
        static var providerLabel: String {
            isEnglish ? "Service" : "Layanan"
        }
        static var configuredModels: String {
            isEnglish ? "Available Models" : "Model Tersedia"
        }
        static var reasoningEffortLabel: String {
            isEnglish ? "Thinking Mode" : "Mode Berpikir"
        }
        static var detailQuotaTitle: String {
            isEnglish ? "Quota Details" : "Rincian Kuota"
        }
        static var viewDetailQuota: String {
            isEnglish ? "View Quota Details" : "Lihat Rincian Kuota"
        }
        static var backButton: String {
            isEnglish ? "Back" : "Kembali"
        }
        static var filterAll: String {
            isEnglish ? "All" : "Semua"
        }
        static var showDetails: String {
            isEnglish ? "Show Quota Details" : "Lihat Rincian Kuota"
        }
        static var hideDetails: String {
            isEnglish ? "Hide Quota Details" : "Tutup Rincian Kuota"
        }
        static var quotaOverview: String {
            isEnglish ? "Remaining Quota" : "Sisa Kuota"
        }
        static func loginHint(_ cmd: String) -> String {
            isEnglish ? "Copy command `\(cmd)` to sign in via Terminal." : "Salin perintah `\(cmd)` untuk masuk akun lewat Terminal."
        }
        static func summaryCount(active: Int, failed: Int) -> String {
            if failed > 0 {
                return isEnglish
                    ? "\(active) Signed In • \(failed) Need Sign-In"
                    : "\(active) Aktif • \(failed) Perlu Login"
            }
            return isEnglish ? "\(active) Active AI" : "\(active) AI Aktif"
        }
        static var showInNotchTitle: String {
            isEnglish ? "Show in Notch" : "Tampilkan di Notch"
        }
        static var activeInNotchBadge: String {
            isEnglish ? "Shown in Notch" : "Tampil di Notch"
        }
        static var copyCommand: String {
            isEnglish ? "Copy" : "Salin"
        }
        static var copiedCommand: String {
            isEnglish ? "Copied" : "Tersalin"
        }
        static var switchAgentHint: String {
            isEnglish ? "Switch displayed AI" : "Ganti AI yang ditampilkan"
        }
        static func agentNotInstalled(_ name: String) -> String {
            isEnglish ? "\(name) is not installed on this Mac" : "\(name) belum terinstal di Mac ini"
        }
        static var selectDifferentProviderHint: String {
            isEnglish ? "Choose another AI from the Menu Bar" : "Pilih AI lain melalui ikon di Menu Bar atas"
        }
        static var selectedInMenuBar: String {
            isEnglish ? "Selected from Menu Bar" : "Dipilih dari Menu Bar"
        }
        static func percentRemaining(_ pct: Int) -> String {
            isEnglish ? "\(pct)% left" : "Sisa \(pct)%"
        }
        static var fiveHourQuota: String {
            isEnglish ? "5-Hour Quota" : "Kuota 5 Jam"
        }
        static var dailyQuota: String {
            isEnglish ? "Daily Quota" : "Kuota Harian"
        }
        static var weeklyQuota: String {
            isEnglish ? "Weekly Quota" : "Kuota Mingguan"
        }
        static var monthlyQuota: String {
            isEnglish ? "Monthly Quota" : "Kuota Bulanan"
        }
    }

    enum About {
        static var subtitle: String {
            isEnglish ? "Prayer times, battery, and music in your MacBook notch" : "Jadwal sholat, kondisi baterai, dan kontrol musik di bagian atas layar MacBook"
        }
        static var version: String {
            let ver = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
            return isEnglish ? "Version \(ver)" : "Versi \(ver)"
        }
        static var developedBy: String {
            isEnglish ? "Made by Sajudin" : "Dibuat oleh Sajudin"
        }
        static var openSourceCredits: String {
            isEnglish ? "Credits & Open Source" : "Kredit & Sumber Terbuka"
        }
        static var adhanTitle: String {
            "Adhan-Swift"
        }
        static var adhanDesc: String {
            isEnglish ? "Accurate prayer time calculation library by Batoul Apps (MIT License)" : "Perhitungan waktu sholat dan arah kiblat akurat oleh Batoul Apps (Lisensi MIT)"
        }
        static var vorssaintTitle: String {
            "Vorssaint"
        }
        static var vorssaintDesc: String {
            isEnglish
                ? "Inspiration for music controls, closed-lid mode, and volume indicator in the notch"
                : "Inspirasi untuk kontrol musik, fitur layar tertutup, dan tampilan volume di notch"
        }
        static var lrclibTitle: String {
            "LRCLIB"
        }
        static var lrclibDesc: String {
            isEnglish
                ? "Synchronized song lyrics service by Tran Xuan Thang (MIT License)"
                : "Layanan lirik lagu otomatis oleh Tran Xuan Thang (Lisensi MIT)"
        }
        static var audioTitle: String {
            isEnglish ? "Adzan Audio Recordings" : "Rekaman Suara Adzan"
        }
        static var audioDesc: String {
            isEnglish ? "Clear adzan recordings sourced from IslamDownload.net" : "Rekaman suara adzan jernih dari koleksi IslamDownload.net"
        }
        static var appleTechTitle: String {
            "Apple macOS System"
        }
        static var appleTechDesc: String {
            isEnglish ? "Built with native macOS icons and battery health sensors" : "Menggunakan ikon bawaan macOS dan sensor informasi baterai Apple"
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
            isEnglish ? "New Update Available" : "Versi Baru Tersedia"
        }
        static var checkForUpdates: String {
            isEnglish ? "Check for Updates" : "Periksa Pembaruan"
        }
        static var checking: String {
            isEnglish ? "Checking for updates..." : "Memeriksa versi terbaru..."
        }
        static var upToDateTitle: String {
            isEnglish ? "You're Using the Latest Version!" : "Aplikasi Sudah Paling Baru!"
        }
        static func upToDateMessage(version: String) -> String {
            isEnglish ? "Harmonotch \(version) is the newest version available." : "Harmonotch \(version) yang Anda gunakan saat ini sudah versi paling baru."
        }
        static var checkFailedTitle: String {
            isEnglish ? "Could Not Check for Updates" : "Belum Bisa Memeriksa Pembaruan"
        }
        static var networkErrorDesc: String {
            isEnglish ? "Could not connect to the update server. Please check your internet connection." : "Tidak dapat terhubung ke internet. Pastikan koneksi internet Anda aktif lalu coba lagi."
        }
        static func updateAvailableTitle(version: String) -> String {
            isEnglish ? "Harmonotch \(version) is Ready!" : "Harmonotch \(version) Tersedia!"
        }
        static var updateAvailablePrompt: String {
            isEnglish
                ? "A newer version of Harmonotch is available with improvements and fixes. Would you like to update now?"
                : "Versi terbaru Harmonotch sudah tersedia dengan perbaikan dan peningkatan fitur. Ingin memperbarui aplikasi sekarang?"
        }
        static var updateNow: String {
            isEnglish ? "Update Now" : "Perbarui Sekarang"
        }
        static var downloading: String {
            isEnglish ? "Downloading update..." : "Mengunduh pembaruan..."
        }
        static var installing: String {
            isEnglish ? "Installing update..." : "Memasang pembaruan..."
        }
        static func readyToQuitTitle(version: String) -> String {
            isEnglish ? "Harmonotch v\(version) Ready" : "Harmonotch v\(version) Siap Dipakai"
        }
        static var readyToQuitSubtitle: String {
            isEnglish ? "Update finished installing. Restart the app to use the new version." : "Pembaruan selesai dipasang. Buka ulang aplikasi untuk memakai versi baru."
        }
        static var quitApp: String {
            isEnglish ? "Quit App" : "Tutup Aplikasi"
        }
        static var restartApp: String {
            isEnglish ? "Restart Now" : "Buka Ulang Sekarang"
        }
        static var retry: String {
            isEnglish ? "Try Again" : "Coba Lagi"
        }
        static var needsApplicationsTitle: String {
            isEnglish ? "Move to Applications Folder" : "Pindahkan ke Folder Applications"
        }
        static var needsApplicationsBody: String {
            isEnglish
                ? "To update automatically, please move Harmonotch into your Mac's Applications folder first."
                : "Agar bisa diperbarui otomatis, silakan pindahkan aplikasi Harmonotch ke dalam folder Applications di Mac Anda terlebih dahulu."
        }
        static var downloadFailedTitle: String {
            isEnglish ? "Update Download Failed" : "Gagal Mengunduh Pembaruan"
        }
        static var viewReleaseNotes: String {
            isEnglish ? "What's New" : "Lihat Perubahan"
        }
        static var later: String {
            isEnglish ? "Later" : "Nanti Saja"
        }
    }

    enum Volume {
        static func accessibilityLabel(percent: Int, muted: Bool) -> String {
            if muted {
                return isEnglish ? "Volume muted, 0 percent" : "Suara dimatikan, 0 persen"
            }
            return isEnglish ? "Volume \(percent) percent" : "Volume \(percent) persen"
        }

        static var statusActive: String {
            isEnglish ? "Shown in Notch" : "Tampil di Notch"
        }

        static var statusNeedsPermission: String {
            isEnglish ? "Needs Permission in System Settings" : "Perlu Izin di Pengaturan Sistem"
        }

        static var statusDisabled: String {
            isEnglish ? "Using Standard macOS Volume Display" : "Memakai Tampilan Bawaan macOS"
        }

        static var grantPermissionAction: String {
            isEnglish ? "Allow Access" : "Beri Izin"
        }
    }
}

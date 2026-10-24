"use strict";

const dict = {
  id: {
    // Navigation
    "nav.skip": "Lewati ke konten",
    "nav.features": "Fitur",
    "nav.showcase": "Showcase Notch",
    "nav.install": "Instalasi",
    "nav.faq": "FAQ",
    "nav.download": "Unduh DMG",
    "aria.primary": "Navigasi utama",
    "aria.language": "Pilihan Bahasa",
    "aria.menu": "Menu navigasi",

    // Hero
    "hero.badge": "Rilis Perdana Harmonotch untuk macOS",
    "hero.notch.prayerLabel": "Sholat Berikutnya",
    "hero.notch.batteryLabel": "MagSafe Tersambung",
    "hero.notch.mediaLabel": "Sedang Diputar",
    "hero.title": "Ubah Notch MacBook Jadi <em>Pusat Harmoni</em> & Produktivitas",
    "hero.desc": "Aplikasi pendamping notch paling anggun di macOS. Menghadirkan <strong>Jadwal Sholat & Adzan akurat</strong>, <strong>Telemetri Baterai real-time</strong>, serta <strong>Kontrol Media dengan lirik sinkron</strong> dalam balutan antarmuka <em>Liquid Glass</em> yang memukau.",
    "hero.downloadBtn": "Unduh Installer (DMG)",
    "hero.viewFeatures": "Jelajahi Fitur",
    "hero.versionLabel": "Memeriksa versi terbaru...",
    "hero.metaReq": "Kompatibel dengan macOS 14.0+ (Sonoma & Sequoia) · Apple Silicon & Intel",
    "hero.tag1": "100% Native Swift",
    "hero.tag2": "Privasi Penuh & Offline",
    "hero.tag3": "Hemat Daya & Ringan",

    // Trust strip
    "trust.adhan": "Perhitungan Astronomis Akurat (Kemenag & Global)",
    "trust.battery": "Indikator Status Baterai & Siklus Daya",
    "trust.lyrics": "Visualizer Audio & Lirik Berjalan",
    "trust.privacy": "Zero Tracking & Tanpa Iklan",

    // Interactive Showcase
    "showcase.kicker": "Eksplorasi Interaktif",
    "showcase.title": "Sentuh & Rasakan Pengalaman Notch yang Hidup",
    "showcase.desc": "Pilih tab di bawah untuk melihat keanggunan animasi notch serta kemudahan akses via menu bar macOS.",
    "tab.video": "Animasi Live Notch",
    "tab.menubar": "Menu Bar Companion",

    // Showcase Drawer Descriptions
    "showcase.video.title": "Animasi Pegas Organik & Responsif",
    "showcase.video.desc": "Harmonotch melebur secara alami dengan bezel kamera MacBook Anda menggunakan kurva pegas (spring dynamics) asli Apple. Notch mengembang seketika saat kursor didekatkan, dan menutup kembali dengan halus tanpa mengganggu fokus kerja.",
    "showcase.video.f1": "60 FPS Native SwiftUI Spring Animation",
    "showcase.video.f2": "Snappy 0.14 detik dismiss debounce",
    "showcase.video.f3": "Navigasi kapsul instan antar fitur",

    "showcase.menubar.title": "Akses Instan dari Menu Bar",
    "showcase.menubar.desc": "Tidak punya layar notch? Tetap nikmati seluruh kemampuan Harmonotch melalui ikon menu bar yang praktis dan ringkas.",
    "showcase.menubar.f1": "Dropdown status sholat dan baterai cepat",
    "showcase.menubar.f2": "In-app update checker otomatis",
    "showcase.menubar.f3": "Shortcut dan pengaturan fleksibel",

    // Features Section
    "features.kicker": "Keunggulan Utama",
    "features.title": "Didesain Eksklusif untuk Pengguna macOS",
    "features.desc": "Harmonotch dibangun dari nol menggunakan Swift dan SwiftUI murni untuk menjamin performa secepat kilat dan efisiensi memori maksimal.",
    "features.c1t": "Presisi Waktu Sholat",
    "features.c1d": "Mendukung metode Kemenag RI, Muslim World League, ISNA, Umm Al-Qura, Egyptian Authority, dan penyesuaian menit manual.",
    "features.c2t": "Animasi Notch Organik",
    "features.c2d": "Drawer meluncur keluar dari bezel notch dengan kurva animasi spring khas Apple yang halus dan tidak mengganggu alur kerja.",
    "features.c3t": "Indikator Baterai Pintar",
    "features.c3d": "Dapatkan info detail mengenai persentase baterai, sisa waktu pemakaian, dan status fast-charging dalam satu lirik pandang.",
    "features.c4t": "100% Mengutamakan Privasi",
    "features.c4d": "Semua perhitungan waktu sholat dan telemetri perangkat diproses sepenuhnya di dalam perangkat. Tidak ada data yang dikirim ke server.",
    "features.c5t": "Dukungan Mac Tanpa Notch",
    "features.c5d": "Memiliki MacBook Pro lama, MacBook Air M1, Mac mini, iMac, atau Mac Studio? Harmonotch tetap berfungsi sempurna melalui floating drawer & menu bar.",
    "features.c6t": "Pembaruan Aplikasi Terintegrasi",
    "features.c6d": "Harmonotch secara berkala memeriksa rilis terbaru langsung dari repositori GitHub sehingga Anda selalu mendapatkan fitur dan perbaikan terkini.",

    // Installation Guide
    "install.kicker": "Panduan Cepat",
    "install.title": "Cara Pasang di Mac Anda",
    "install.desc": "Hanya butuh waktu kurang dari satu menit untuk mulai menikmati Harmonotch.",
    "install.step1Title": "1. Unduh File Installer",
    "install.step1Desc": "Klik tombol 'Unduh Installer (DMG)' untuk mengunduh paket resmi terbaru dari GitHub Releases.",
    "install.step2Title": "2. Drag ke Applications",
    "install.step2Desc": "Buka file DMG yang diunduh, lalu seret ikon Harmonotch ke folder Applications Mac Anda.",
    "install.step3Title": "3. Catatan Gatekeeper (Opsional)",
    "install.step3Desc": "Karena Harmonotch dirilis secara independen (ad-hoc signed), jika macOS memunculkan notifikasi keamanan 'Harmonotch cannot be opened', cukup jalankan perintah berikut di Terminal:",
    "install.copyBtn": "Salin Perintah",
    "install.copied": "Tersalin!",

    // FAQ
    "faq.kicker": "Pertanyaan Umum",
    "faq.title": "Ada Pertanyaan? Kami Punya Jawabannya",
    "faq.q1": "Apakah Harmonotch memerlukan koneksi internet untuk menghitung sholat?",
    "faq.a1": "Tidak. Perhitungan waktu sholat dihitung secara offline secara matematis berdasarkan koordinat astronomi kota Anda. Koneksi internet hanya dibutuhkan jika Anda menyalakan fitur cek pembaruan otomatis atau streaming lirik.",
    "faq.q2": "Apakah Harmonotch kompatibel dengan Mac yang tidak memiliki notch?",
    "faq.a2": "Ya! Harmonotch mendeteksi apakah layar Anda memiliki notch hardware atau tidak. Pada Mac tanpa notch (seperti MacBook Air M1, Mac mini, iMac), drawer akan muncul sebagai floating bar elegan di bagian atas layar serta melalui menu bar.",
            "faq.q3": "Kenapa muncul peringatan 'Apple cannot verify' saat pertama kali dibuka?",
    "faq.a3": "Harmonotch adalah proyek open-source independen yang belum memiliki sertifikat Apple Developer berbayar. Di macOS 15 Sequoia atau lebih baru, buka System Settings → Privacy & Security, gulir ke bagian Security, lalu klik 'Open Anyway'. Di macOS 14 atau lebih lama, klik kanan aplikasi lalu pilih 'Open'. Alternatif cepat lewat Terminal: <code>xattr -cr /Applications/Harmonotch.app</code>.",
    "faq.q4": "Apakah aplikasi ini menguras baterai MacBook saya?",
    "faq.a4": "Sama sekali tidak. Harmonotch dibuat dengan Swift murni dan AppKit/SwiftUI native. Penggunaan CPU saat idle adalah 0.0% dan penggunaan RAM kurang dari 35MB.",
    "faq.q5": "Metode perhitungan sholat apa saja yang didukung?",
    "faq.a5": "Harmonotch mendukung Kemenag (Kementerian Agama RI), Muslim World League (MWL), ISNA (North America), Umm Al-Qura (Makkah), Egyptian General Authority, University of Islamic Sciences Karachi, Dubai, Qatar, Kuwait, Singapore, dan Turki.",

    // CTA
    "cta.kicker": "Mulai Sekarang",
    "cta.title": "Harmoniskan Pengalaman MacBook Anda Hari Ini",
    "cta.desc": "Gratis, open-source, dan dibangun dengan penuh perhatian untuk detail.",
    "cta.downloadBtn": "Unduh Harmonotch untuk Mac",
    "cta.githubBtn": "Lihat di GitHub",

    // Footer
    "footer.desc": "Pusat harmoni, waktu sholat, telemetri daya, dan pemutar musik untuk notch macOS Anda. Dibuat dengan cinta untuk komunitas Mac.",
    "footer.linksTitle": "Tautan",
    "footer.features": "Fitur",
    "footer.showcase": "Showcase",
    "footer.install": "Instalasi",
    "footer.faq": "FAQ",
    "footer.repo": "Repositori GitHub",
    "footer.releases": "Daftar Rilis",
    "footer.issues": "Laporkan Bug",
    "footer.license": "Lisensi MIT",
    "footer.copyright": "Harmonotch. Proyek Open Source."
  },

  en: {
    // Navigation
    "nav.skip": "Skip to content",
    "nav.features": "Features",
    "nav.showcase": "Notch Showcase",
    "nav.install": "Install",
    "nav.faq": "FAQ",
    "nav.download": "Download DMG",
    "aria.primary": "Primary navigation",
    "aria.language": "Language Selector",
    "aria.menu": "Navigation menu",

    // Hero
    "hero.badge": "Harmonotch Inaugural Release for macOS",
    "hero.notch.prayerLabel": "Next Prayer",
    "hero.notch.batteryLabel": "MagSafe Connected",
    "hero.notch.mediaLabel": "Now Playing",
    "hero.title": "Turn Your MacBook Notch into a <em>Center of Harmony</em> & Productivity",
    "hero.desc": "The most exquisite notch companion for macOS. Featuring <strong>accurate Prayer Times & Adhan</strong>, <strong>real-time Battery Telemetry</strong>, and <strong>Media Controls with synced lyrics</strong> wrapped in an enchanting <em>Liquid Glass</em> design.",
    "hero.downloadBtn": "Download Installer (DMG)",
    "hero.viewFeatures": "Explore Features",
    "hero.versionLabel": "Checking latest release...",
    "hero.metaReq": "Compatible with macOS 14.0+ (Sonoma & Sequoia) · Apple Silicon & Intel",
    "hero.tag1": "100% Native Swift",
    "hero.tag2": "Fully Private & Offline",
    "hero.tag3": "Ultra Lightweight & Battery Friendly",

    // Trust strip
    "trust.adhan": "Accurate Astronomical Calculation (Kemenag & Global)",
    "trust.battery": "Live Battery Health & Cycle Telemetry",
    "trust.lyrics": "Audio Waveform & Synced Lyrics",
    "trust.privacy": "Zero Tracking & No Ads",

    // Interactive Showcase
    "showcase.kicker": "Interactive Showcase",
    "showcase.title": "Touch & Experience the Living Notch",
    "showcase.desc": "Select a tab below to experience the organic notch animation and the effortless macOS menu bar companion.",
    "tab.video": "Live Notch Animation",
    "tab.menubar": "Menu Bar Companion",

    // Showcase Drawer Descriptions
    "showcase.video.title": "Organic & Responsive Spring Dynamics",
    "showcase.video.desc": "Harmonotch seamlessly expands from your MacBook hardware notch using Apple's fluid spring dynamics. Hovering expands the drawer instantly with zero lag, snapping shut when your cursor moves away.",
    "showcase.video.f1": "60 FPS Native SwiftUI Spring Animation",
    "showcase.video.f2": "Snappy 0.14-second dismiss debounce",
    "showcase.video.f3": "Instant multi-tab segmented pill navigation",

    "showcase.menubar.title": "Instant Access via Menu Bar",
    "showcase.menubar.desc": "Using a Mac without a notch? Harmonotch remains fully functional through its sleek menu bar companion icon.",
    "showcase.menubar.f1": "Quick status popover for prayer and battery",
    "showcase.menubar.f2": "Automatic in-app update checker",
    "showcase.menubar.f3": "Customizable shortcuts and drawer hotkeys",

    // Features Section
    "features.kicker": "Key Highlights",
    "features.title": "Engineered Exclusively for macOS",
    "features.desc": "Built from scratch with pure Swift and AppKit/SwiftUI to ensure peak performance and minimal memory usage.",
    "features.c1t": "Astronomical Prayer Precision",
    "features.c1d": "Supports Kemenag, Muslim World League, ISNA, Umm Al-Qura, Egyptian General Authority, Karachi, and manual minute offsets.",
    "features.c2t": "Organic Notch Animations",
    "features.c2d": "Drawers smoothly slide out from the camera notch using Apple's fluid spring physics curves without disrupting your focus.",
    "features.c3t": "Smart Battery Insights",
    "features.c3d": "Instant visibility into health status, cycle wear, remaining time, and fast-charging state in a single glance.",
    "features.c4t": "100% Privacy-First Architecture",
    "features.c4d": "All computations run purely on-device. Zero analytics, zero telemetric beacons, and zero remote data harvesting.",
    "features.c5t": "Notchless Mac Support",
    "features.c5d": "Own an older MacBook Pro, M1 MacBook Air, Mac mini, or iMac? Harmonotch adapts into a top floating pill and menu bar tray.",
    "features.c6t": "Built-in Update Checker",
    "features.c6d": "Harmonotch seamlessly verifies GitHub Releases so you always stay up to date with new features and improvements.",

    // Installation Guide
    "install.kicker": "Quick Setup",
    "install.title": "How to Install on Your Mac",
    "install.desc": "Takes less than sixty seconds to get up and running.",
    "install.step1Title": "1. Download Installer",
    "install.step1Desc": "Click the 'Download Installer (DMG)' button to grab the latest official release from GitHub Releases.",
    "install.step2Title": "2. Drag to Applications",
    "install.step2Desc": "Mount the DMG disk image, then drag the Harmonotch icon directly into your Mac's Applications folder.",
    "install.step3Title": "3. Gatekeeper Note (Optional)",
    "install.step3Desc": "Because Harmonotch is independently ad-hoc signed, if macOS shows 'Harmonotch cannot be opened', simply run this quick command in Terminal:",
    "install.copyBtn": "Copy Command",
    "install.copied": "Copied!",

    // FAQ
    "faq.kicker": "Common Questions",
    "faq.title": "Frequently Asked Questions",
    "faq.q1": "Does Harmonotch require an internet connection to compute prayer times?",
    "faq.a1": "No. All prayer calculations are solved mathematically on your local CPU based on astronomical solar coordinates. Internet is only used for lyrics lookup and checking new GitHub releases.",
    "faq.q2": "Does Harmonotch work on Macs without a notch?",
    "faq.a2": "Yes! Harmonotch detects your display configuration. On notchless screens (like MacBook Air M1, Mac mini, iMac, or external monitors), it displays an elegant floating pill at the top center of the screen.",
    "faq.q3": "Why does macOS show an 'Apple cannot verify' security warning?",
    "faq.a3": "Harmonotch is an independent open-source project without a paid Apple Developer certificate. On macOS 15 Sequoia or later, open System Settings → Privacy & Security, scroll to Security, then click 'Open Anyway'. On macOS 14 or earlier, right-click the app and choose 'Open'. Or run <code>xattr -cr /Applications/Harmonotch.app</code> in Terminal.",
    "faq.q4": "Will Harmonotch drain my MacBook's battery?",
    "faq.a4": "Not at all. Harmonotch is written in pure native Swift with AppKit & SwiftUI. Idle CPU consumption stays at 0.0%, and RAM footprint is below 35MB.",
    "faq.q5": "Which prayer calculation methods are supported?",
    "faq.a5": "Supports Kemenag (Indonesia), Muslim World League (MWL), ISNA (North America), Umm Al-Qura (Makkah), Egyptian General Authority, University of Islamic Sciences Karachi, Dubai, Qatar, Kuwait, Singapore, and Turkey.",

    // CTA
    "cta.kicker": "Get Started",
    "cta.title": "Harmonize Your MacBook Experience Today",
    "cta.desc": "Free, open-source, and crafted with meticulous attention to detail.",
    "cta.downloadBtn": "Download Harmonotch for Mac",
    "cta.githubBtn": "View on GitHub",

    // Footer
    "footer.desc": "The living notch companion for prayer times, power telemetry, and music on macOS. Crafted with passion for the Mac community.",
    "footer.linksTitle": "Links",
    "footer.features": "Features",
    "footer.showcase": "Showcase",
    "footer.install": "Installation",
    "footer.faq": "FAQ",
    "footer.repo": "GitHub Repository",
    "footer.releases": "Releases",
    "footer.issues": "Report an Issue",
    "footer.license": "MIT License",
    "footer.copyright": "Harmonotch. Open Source Project."
  }
};

window.dict = dict;

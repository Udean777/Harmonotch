<div align="center">
  <img src="assets/logo.png" width="128" alt="Harmonotch Logo">
  <h1>Harmonotch</h1>
  <p><strong>Intelligent MacBook Notch Companion: Islamic Prayer Awareness, Battery Telemetry & Media Lyrics Island</strong></p>

[![macOS 14.0+](https://img.shields.io/badge/macOS-14.0%2B-black?logo=apple&style=flat-square)](https://apple.com/macos)
[![Swift 6](https://img.shields.io/badge/Swift-6.0%2B-F05138?logo=swift&logoColor=white&style=flat-square)](https://swift.org)
[![SwiftUI & AppKit](https://img.shields.io/badge/UI-SwiftUI%20%2B%20AppKit-blue?style=flat-square)](https://developer.apple.com/swiftui/)
[![Offline First](https://img.shields.io/badge/Offline--First-100%25-brightgreen?style=flat-square)](#)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg?style=flat-square)](LICENSE)

</div>

<br/>

> **Harmonotch** *(Harmony + Notch)* is an intelligent macOS utility that transforms your MacBook's hardware camera cutout into an elegant, mindful Dynamic Island—blending Islamic prayer awareness, comprehensive hardware battery monitoring, and active media playback with real-time synced lyrics seamlessly with native Apple design.

---

## 🌟 Features & Everyday Utility

### 🎛️ Segmented Capsule Navigation
* **Multi-Mode Drawer Switcher:** Switch effortlessly between daily prayer schedules, comprehensive power metrics, and active media playback with a fluid, native segmented pill control (`[ 🕌 Jadwal Sholat ]`, `[ 🔋 Status Baterai ]`, and `[ 🎵 Media & Lirik ]`).
* **Intelligent Auto-Switching:** If an Adzan starts while inspecting battery or media metrics, Harmonotch automatically slides back to the prayer view, highlighting the active call to prayer with instant playback controls.
* **Extensible & Fluid Geometry:** The drawer dynamically adapts its height based on the active tab and track state (e.g., 288 pt for battery & idle media, 350 pt for active player with synced lyrics).

### 🎵 Media Island & Real-Time Synced Lyrics
* **Universal Multi-Source Audio:** Seamlessly tracks playback from desktop players (**Spotify**, **Apple Music**) via lightweight native push notifications, as well as web browsers (**YouTube**, **YouTube Music**, and **Spotify Web** on Safari & Google Chrome).
* **Smart Metadata Resolver (iTunes Search API):** Automatically cleans noisy video titles (stripping `[Official Video]`, `MV`, etc.) and resolves verified track titles, artist names, exact track durations, and crisp 600x600 high-resolution album artwork.
* **Multi-Tier Synced Lyrics (LRCLIB):** Automatically fetches time-synchronized lyrics from [LRCLIB](https://lrclib.net/) with intelligent fallback (track + artist, general query, track-only, and Apple Music local lyrics).
* **Dynamic 3-Line Mini Notch Lyrics:** In its resting notch state, active lyrics display with smooth cross-slide & fade transition animations up to 3 lines, turning the notch into a glanceable karaoke display.
* **Interactive Scrubber & Seekable Lyrics:** Real-time 0.25-second playback tracking with an interactive amber scrubber bar and seekable lyric lines (click any line to jump directly to that timestamp in the track).
* **Auto-Scroll Resume:** When reopening the expanded drawer, the lyric scroll view automatically animates directly to the currently playing line without resetting to the top.

### 🕌 Islamic Prayer Times & Automated Full Adzan
* **Astronomical Accuracy:** Calculates daily prayer times (Subuh, Terbit, Dzuhur, Ashar, Maghrib, Isya) directly on-device using local solar calculation algorithms tailored to the standard Southeast Asian / Kemenag RI methodology (Fajr 20°, Isha 18° with safety ihtiyat adjustment).
* **Automatic Call to Prayer (Adzan):** Plays a complete call to prayer automatically at the exact minute each prayer begins, accompanied by a dynamic visual banner directly from the notch.
* **Streamlined Audio & Volume Control:** Easily toggle Adzan mute, fine-tune volume with an expanded 130 pt slider and real-time percentage readout, test the audio, or immediately dismiss the active call to prayer with a single click.
* **Smart Region Selection:** Choose from major Indonesian city presets (Jakarta, Surabaya, Bandung, Medan, Makassar, and more) or enable optional location detection (`CoreLocation` & `MapKit`) to resolve your city automatically.
* **Integrated Hijri Calendar:** Displays both current Gregorian and Hijri calendar dates accurately within the expanded drawer.

### 🎨 Dual Design Themes & Appearance Modes
* **Liquid Glass:** Cutting-edge macOS aesthetic featuring multi-layered optical frosted glass materials (`.ultraThinMaterial`), directional specular rim-light strokes, and translucent sheen gradients.
* **Zen Serenity:** Warm, tactile, paper-inspired design grounded in earth tones (sage green, amber, cedar wood, and warm sand) designed for calm and mindful focus.
* **Flexible Appearance Modes:** Choose between **Match System**, **Always Dark**, or **Always Light** modes to match your workflow environment.

### 🔋 Battery & Power Health Hub
* **Deep Hardware Metrics:** Interfaces directly with native macOS `IOKit` (`IOPowerSources` and `AppleSmartBattery`) to provide transparent hardware analytics without third-party daemons.
* **Real vs. Design Capacity:** Compares actual nominal full charge capacity against factory design capacity in milliampere-hours (mAh), giving you genuine battery degradation insight.
* **Maximum Health & Cycle Counting:** Live calculation of battery health percentage alongside battery cycle count tracked against rated hardware cycle limits (e.g., 1000 cycles).
* **Smart Power & Charger Detection:** Identifies power sources in real time, automatically detecting connected AC adapter wattage (e.g., 30W / 70W / 96W / 140W) and calculating dynamic time-to-full or time-to-empty estimates.
* **Quick System Access:** One-click refresh and direct shortcut to macOS Battery System Settings.

### 🌐 Multilingual & Instant Language Switching (English Default)
* **Default English:** Designed with an international-first English interface (`Prayer Times`, `Fajr`, `Dhuhr`, `Health`, `Cycle Count`), with comprehensive native support for **Bahasa Indonesia** (`Jadwal Sholat`, `Subuh`, `Dzuhur`, `Kesehatan`, `Siklus`).
* **Zero-Restart Reactive Toggling:** Switch instantly via the macOS Menu Bar `Language` submenu without restarting the application.
* **Full-Stack Localization:** Adapts Gregorian and Hijri calendar date formatters, dynamic prayer names, battery telemetry labels, and system menu bar action items.

### 🏝️ Direct Hardware Notch Extension (Under-Notch Island)
* **Custom-Molded for MacBook Screens:** Engineered to match the exact 208 pt width of MacBook Air and Pro hardware cutouts. In its resting state, Harmonotch extends downward with smooth corner radii, appearing as a natural physical extension of the laptop's display bezel.
* **Zero Menu Bar Interference:** Positioned directly below the camera cutout with selective hit-testing. Your active application menus on the left (*File, Edit, View...*) and system status items on the right (*Wi-Fi, Battery, Clock*) remain 100% unobstructed and fully clickable.

### ✨ Fluid Morphing Spring Animation
* **Continuous Surface Expansion:** Rather than a simple crossfade, the black notch body itself physically stretches and expands from a compact pill into a spacious 540 pt drawer using Apple's fluid spring dynamics (`dampingFraction: 0.76`).
* **Snappy Dismiss:** The moment your cursor leaves the drawer, the notch immediately snaps back into its compact shape with an intentional 0.14-second debounce to ensure an effortless, lag-free user experience.

### 🍎 macOS Menu Bar Companion & Quick Controls
* **App Logo Status Item:** Features the official Harmonotch app logo in the menu bar, keeping the menu bar clutter-free without distracting text or emojis.
* **Polished Dropdown Menu:** Displays an integrated header card with live app status, quick drawer toggles, and direct tab navigation (`Cmd+1`, `Cmd+2`, `Cmd+3`).
* **Instant Adzan Controls:** Mute/unmute Adzan audio (`Cmd+M`) and test audio playback directly from the menu bar.
* **Complete Notch Hide Option:** Toggle **"Hide Notch on Screen"** (`Cmd+H`) to dismiss the floating notch overlay entirely while continuing to run in the background.

---

## ⚡ Performance & Battery Architecture

Harmonotch is engineered from the ground up for zero-overhead, whisper-quiet background operation:

* **0.0% CPU When Idle:** Eliminates continuous timer redraw loops. Astronomical solar equations are computed only once upon launch, when switching cities, or automatically at midnight (`NSCalendarDayChanged`). Battery metrics refresh once every 30 seconds on a low-priority background publisher.
* **Precompiled Caching:** AppleScripts used for media and browser tab queries are precompiled and cached in memory, preventing continuous XProtect rule parsing and eliminating unnecessary I/O.
* **Battery-Safe Single-Shot GPS:** CoreLocation automatically deactivates (`stopUpdatingLocation()`) as soon as the first coordinate fix is resolved, preventing continuous battery drain on MacBook hardware.
* **100% Offline-First for Prayers:** Operates completely standalone with zero external API dependencies or network connectivity required for prayer calculations and audio playback.
* **Anti-Clash AppKit Canvas:** Utilizes a fixed transparent canvas (`PassThroughHostingView`), eliminating Auto Layout constraint recursion and ensuring rock-solid stability.

---

## 📁 Project Structure

```text
Harmonotch/
├── App/
│   ├── HarmonotchApp.swift           // Application entry point (Accessory Scene)
│   └── AppDelegate.swift             // AppKit lifecycle & macOS Menu Bar Status Item
├── NotchUI/
│   ├── NotchGeometryHelper.swift     // Dynamic hardware notch geometry detection
│   ├── NotchWindowController.swift   // Floating NSPanel with selective hit-testing
│   ├── NotchViewModel.swift          // Fluid hover and snappy dismiss state management
│   ├── NotchContainerView.swift      // Morphing black body & multi-tab drawer
│   ├── NotchTab.swift                // DrawerTab enum & Segmented Control Tab Bar
│   ├── NotchPillView.swift           // Direct hardware notch extension (Lyrics & Status)
│   └── LiquidGlassBackground.swift   // Liquid glass and paper theme background layers
├── Features/
│   ├── Theme/
│   │   ├── ThemeManager.swift        // Style and appearance mode reactive state engine
│   │   └── AppTheme.swift            // Dynamic color tokens and theme styling palettes
│   ├── Localization/
│   │   ├── LanguageManager.swift     // Reactive language state engine (UserDefaults backed)
│   │   └── L10n.swift                // Type-safe localized string keys and helpers
│   ├── Prayer/
│   │   ├── Adhan/                    // Bundled offline astronomical calculation engine
│   │   ├── CityPreset.swift          // Indonesian major cities with coordinates & timezones
│   │   ├── PrayerManager.swift       // Core scheduler, MapKit reverse geocoding & GPS
│   │   ├── AdzanPlayer.swift         // AVAudioPlayer engine with mute & volume control
│   │   ├── PrayerCardView.swift      // Compact individual prayer card view
│   │   └── PrayerDrawerView.swift    // Expanded 5-time prayer drawer with location & controls
│   ├── Battery/
│   │   ├── BatteryMonitor.swift      // IOKit & AppleSmartBattery hardware monitor
│   │   └── BatteryDrawerView.swift   // Capacity, cycles, health %, and charger status
│   ├── Media/
│   │   ├── MediaManager.swift        // Native/Web media tracking, iTunes resolver & LRCLIB engine
│   │   └── MediaDrawerView.swift     // Active player card, scrubber bar & floating synced lyrics
│   └── About/
│       ├── AboutView.swift           // Clean app branding & open-source credits view
│       └── AboutWindowController.swift // Floating dedicated about window controller
├── Assets.xcassets/
│   ├── AppIcon.appiconset/           // Production macOS AppIcon assets (16x16 to 1024x1024 px)
│   ├── AppLogo.imageset/             // High-resolution app branding logo & status item icon
│   └── AccentColor.colorset/
├── Resources/
│   ├── adzan.m4a                     // Standard Adzan audio (AAC 48kHz from IslamDownload.net)
│   └── adzan_subuh.m4a               // Specialized Fajr Adzan audio (AAC 48kHz from IslamDownload.net)
└── .github/
    └── workflows/
        ├── ci.yml                    // Continuous integration & compile check on PRs
        └── release.yml               // Manual DMG packaging, ad-hoc signing & GitHub Release
```

---

## 🚀 Getting Started

### Requirements
* Mac running **macOS 14.0 (Sonoma)** or later.
* **Xcode 16.0+** with the Swift 6 toolchain.

### Build & Run
1. Clone the repository:
   ```bash
   git clone https://github.com/ssajudn/Harmonotch.git
   cd Harmonotch
   ```
2. Open the project in Xcode:
   ```bash
   open Harmonotch.xcodeproj
   ```
3. Press **`Cmd + R`** to compile and run.

### Build from Command Line (Optimized Release)
```bash
xcodebuild -project Harmonotch.xcodeproj -scheme Harmonotch -configuration Release -destination 'platform=macOS' build
```

---

## 💖 Acknowledgements & Open Source Credits

Harmonotch is built with respect and gratitude for the open-source community:

* **[Adhan-Swift](https://github.com/batoulapps/adhan-swift)** by [Batoul Apps](https://github.com/batoulapps) (MIT License) — Powers astronomical prayer times and sunnah calculations offline.
* **[LRCLIB](https://lrclib.net/)** by [tranxuanthang](https://github.com/tranxuanthang/lrcget) — Open community-driven database powering synchronized LRC lyrics matching.
* **[IslamDownload.net](https://islamdownload.net/123801-download-suara-adzan.html)** — High quality audio recordings for daily calls to prayer (`adzan.m4a`, `adzan_subuh.m4a`).
* **Apple iTunes Search API, SF Symbols & IOKit** — Powering metadata resolution, native iconography, and hardware power telemetry.

For full license texts and copyright notices, see [ACKNOWLEDGEMENTS.md](ACKNOWLEDGEMENTS.md).

---

## 📄 License

Distributed under the MIT License. See [LICENSE](LICENSE) for more information.

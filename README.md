# 🏔️ Harmonotch

> **Harmonotch** *(Harmony + Notch)* is an intelligent macOS utility that transforms your MacBook's hardware camera cutout into an elegant, mindful Dynamic Island—blending Islamic prayer awareness seamlessly with native Apple design.

[![macOS 14.0+](https://img.shields.io/badge/macOS-14.0%2B-black?logo=apple&style=flat-square)](https://apple.com/macos)
[![Swift 6](https://img.shields.io/badge/Swift-6.0%2B-F05138?logo=swift&logoColor=white&style=flat-square)](https://swift.org)
[![SwiftUI & AppKit](https://img.shields.io/badge/UI-SwiftUI%20%2B%20AppKit-blue?style=flat-square)](https://developer.apple.com/swiftui/)
[![Offline First](https://img.shields.io/badge/Offline--First-100%25-brightgreen?style=flat-square)](#)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg?style=flat-square)](LICENSE)

---

## 🌟 Features & Everyday Utility

### 🕌 Islamic Prayer Times & Automated Full Adzan
* **Astronomical Accuracy:** Calculates daily prayer times (Subuh, Terbit, Dzuhur, Ashar, Maghrib, Isya) directly on-device using local solar calculation algorithms tailored to the standard Southeast Asian / Kemenag RI methodology (Fajr 20°, Isha 18° with safety ihtiyat adjustment).
* **Automatic Call to Prayer (Adzan):** Plays a complete call to prayer automatically at the exact minute each prayer begins, accompanied by a dynamic visual banner directly from the notch.
* **Instant Audio Control:** Adjust playback volume, mute notifications, test the audio, or immediately dismiss the active call to prayer with a single click.
* **Smart Region Selection:** Choose from major Indonesian city presets (Jakarta, Surabaya, Bandung, Medan, Makassar, and more) or enable optional location detection (`CoreLocation`) to resolve your city automatically.
* **Integrated Hijri Calendar:** Displays both current Gregorian and Hijri calendar dates accurately within the expanded drawer.

### 🏝️ Direct Hardware Notch Extension (Under-Notch Island)
* **Custom-Molded for MacBook Screens:** Engineered to match the exact 208 pt width of MacBook Air and Pro hardware cutouts. In its resting state, Harmonotch extends 26 pt downward with smooth corner radii, appearing as a natural physical extension of the laptop's display bezel.
* **Zero Menu Bar Interference:** Positioned directly below the camera cutout with selective hit-testing. Your active application menus on the left (*File, Edit, View...*) and system status items on the right (*Wi-Fi, Battery, Clock*) remain 100% unobstructed and fully clickable.

### ✨ Fluid Morphing Spring Animation
* **Continuous Surface Expansion:** Rather than a simple crossfade, the black notch body itself physically stretches and expands from a compact 208 pt pill into a spacious 540 pt prayer drawer using Apple's fluid spring dynamics (`dampingFraction: 0.76`).
* **Ultra-Responsive Snap-Back:** The moment your cursor leaves the drawer, the notch immediately snaps back into its compact shape with an intentional 0.14-second debounce to ensure an effortless, lag-free user experience.

### 🌙 macOS Menu Bar Companion & Visibility Toggle
* **Live Status Bar Display:** Displays the crescent icon alongside the upcoming prayer schedule (e.g., `🌙 Ashar 14:52`) following Apple Human Interface Guidelines (*Icon Leading, Text Trailing*). During Adzan, the status bar dynamically transitions to `🔊 Adzan Ashar`.
* **Complete Notch Hide Option:** Need an entirely distraction-free workspace? Toggle **"Sembunyikan Notch di Layar"** from the menu bar to dismiss the floating notch overlay entirely, while continuing to track prayer times quietly from your Menu Bar.

---

## ⚡ Performance & Battery Architecture

Harmonotch is engineered from the ground up for zero-overhead, whisper-quiet background operation:

* **0.0% CPU When Idle:** Eliminates continuous timer redraw loops. Astronomical solar equations are computed only once upon launch, when switching cities, or automatically at midnight (`NSCalendarDayChanged`). Periodic timer ticks only perform lightweight numeric timestamp comparisons.
* **Battery-Safe Single-Shot GPS:** CoreLocation automatically deactivates (`stopUpdatingLocation()`) as soon as the first coordinate fix is resolved, preventing continuous battery drain on MacBook hardware.
* **100% Offline-First:** Operates completely standalone with zero external API dependencies or network connectivity required for prayer calculations and audio playback.
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
│   ├── NotchContainerView.swift      // The Morphing Black Body spring animation canvas
│   └── NotchPillView.swift           // 208pt direct hardware notch extension
├── Features/
│   └── Prayer/
│       ├── Adhan/                    // Bundled offline astronomical calculation engine
│       ├── CityPreset.swift          // Indonesian major cities with coordinates & timezones
│       ├── PrayerManager.swift       // Core scheduler, midnight rollover, and GPS manager
│       ├── AdzanPlayer.swift         // AVAudioPlayer engine with mute & volume control
│       ├── PrayerCardView.swift      // Compact individual prayer card view
│       └── PrayerDrawerView.swift    // Expanded 5-time prayer drawer with location & controls
└── Resources/
    ├── Assets.xcassets
    ├── adzan.m4a                     // Standard Adzan audio (AAC 48kHz from equran-app)
    └── adzan_subuh.m4a               // Specialized Fajr Adzan audio (AAC 48kHz from equran-app)
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

## 📄 License

Distributed under the MIT License. See [LICENSE](LICENSE) for more information.

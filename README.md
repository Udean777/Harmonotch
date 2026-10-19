# 🏔️ Harmonotch

> **Harmonotch** *(Harmony + Notch)* is a native macOS utility that transforms your MacBook's hardware notch into an intelligent, fluid, and mindful Dynamic Island.

[![macOS 14.0+](https://img.shields.io/badge/macOS-14.0%2B-black?logo=apple&style=flat-square)](https://apple.com/macos)
[![Swift 6](https://img.shields.io/badge/Swift-6.0%2B-F05138?logo=swift&logoColor=white&style=flat-square)](https://swift.org)
[![SwiftUI & AppKit](https://img.shields.io/badge/UI-SwiftUI%20%2B%20AppKit-blue?style=flat-square)](https://developer.apple.com/swiftui/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg?style=flat-square)](LICENSE)
[![Zero External Network Dep](https://img.shields.io/badge/Offline%20First-100%25-brightgreen?style=flat-square)](#)

---

## ✨ Features (MVP)

### 🕌 1. Islamic Prayer Schedule & Automatic Adzan Player
* **High-Precision Astronomy:** Computes exact daily prayer times (Subuh, Terbit, Dzuhur, Ashar, Maghrib, Isya) using local astronomical algorithms with the standard Kemenag RI / Southeast Asia methodology (Fajr 20°, Isha 18° + 2-minute safety buffer).
* **Automatic Full Adzan:** Plays a full, high-fidelity Adzan automatically when prayer time arrives, accompanied by an animated notch alert.
* **Smart Region Resolver:** Works instantly with Indonesian city presets (Jakarta, Surabaya, Bandung, Medan, etc.) and optional single-shot battery-friendly GPS (`CoreLocation`).
* **Interactive Controls:** Toggle mute, adjust volume, test playback, or stop an active adzan with a single click.

### 🏝️ 2. Direct Hardware Notch Extension (Under-Notch Dynamic Island)
* **Tailored for MacBook Hardware:** Exact 1:1 width matching (208 pt on MacBook Air M4) that naturally extends 26 pt downward from the physical camera cutout.
* **100% Zero Menu Bar Interference:** Selective hit-testing ensures that application menus on the left (*File, Edit, View...*) and system icons on the right (*Wi-Fi, Battery, Clock*) are completely unobstructed.
* **Apple Fluid Spring Morphing:** Continuous black surface animation that organically stretches and expands into the prayer drawer on hover, with a snappy, instantaneous snap-back on cursor departure.

---

## ⚡ Performance & Battery Optimizations

Harmonotch was architected from day one to be ultra-lightweight and battery-conscious:

* **0.0% CPU When Idle:** Eliminates continuous timer redraw loops. Astronomical prayer equations are computed only once upon startup, on city selection, or automatically at midnight (`NSCalendarDayChanged`). Periodic timer ticks only perform simple integer comparisons.
* **Zero GPS Battery Drain:** CoreLocation immediately shuts down (`stopUpdatingLocation()`) as soon as the first coordinate fix is resolved.
* **Zero Constraint Clashing:** Utilizes a fixed transparent AppKit canvas (`PassThroughHostingView`), permanently preventing Auto Layout recursion and `NSGenericException` constraint loops.
* **Memory Efficient:** Pure local audio streaming via `AVAudioPlayer` with immediate deallocation upon stop.

---

## 📁 Project Architecture

```text
Harmonotch/
├── App/
│   ├── HarmonotchApp.swift           // SwiftUI App entry point (Settings scene)
│   └── AppDelegate.swift             // AppKit lifecycle & macOS Menu Bar Status Item
├── NotchUI/
│   ├── NotchGeometryHelper.swift     // Dynamic hardware notch detector (auxiliaryTopLeft/Right)
│   ├── NotchWindowController.swift   // NSPanel with PassThroughHostingView selective hit-testing
│   ├── NotchViewModel.swift          // Reactive state manager for fluid hover & snappy collapse
│   ├── NotchContainerView.swift      // The Morphing Black Body spring animation container
│   └── NotchPillView.swift           // 208pt idle under-notch extension view
├── Features/
│   └── Prayer/
│       ├── Adhan/                    // Bundled offline astronomical calculation engine
│       ├── CityPreset.swift          // Indonesian major cities with coordinates & timezones
│       ├── PrayerManager.swift       // Core scheduler, midnight listener, GPS manager
│       ├── AdzanPlayer.swift         // AVAudioPlayer engine with mute & volume control
│       ├── PrayerCardView.swift      // Compact individual prayer card view
│       └── PrayerDrawerView.swift    // Expanded 5-time prayer drawer with location & controls
└── Resources/
    ├── Assets.xcassets
    └── adzan.mp3                     // Bundled full-length call to prayer audio
```

---

## 🚀 Getting Started

### Prerequisites
* Mac running **macOS 14.0 (Sonoma)** or later.
* **Xcode 16.0+** with the Swift 6 toolchain installed.

### Build & Run
1. Clone the repository:
   ```bash
   git clone https://github.com/ssajudn/Harmonotch.git
   cd Harmonotch
   ```
2. Open in Xcode:
   ```bash
   open Harmonotch.xcodeproj
   ```
3. Press **`Cmd + R`** to build and run in Debug mode.

### Build from Command Line (Release)
```bash
xcodebuild -project Harmonotch.xcodeproj -scheme Harmonotch -configuration Release -destination 'platform=macOS' build
```

---

## 🗺️ Roadmap (Next Milestones)

- [x] **Milestone 1:** Islamic Prayer Times, Automatic Full Adzan, & Under-Notch Dynamic Island.
- [ ] **Milestone 2:** Media Island & Synced Floating Lyrics (Spotify & Apple Music Desktop integration via AppleScript + LRCLIB).
- [ ] **Milestone 3:** Power & Battery Health Hub (Real-time wattage, battery health %, cycle count, and temperature via `IOKit`).

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

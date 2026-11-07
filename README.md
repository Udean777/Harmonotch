<div align="center">
  <img src="assets/logo.png" width="128" alt="Logo Harmonotch">
  <h1>Harmonotch</h1>
  <p>A macOS menu bar and notch companion for prayer times, battery status, media playback, AI agent quotas, and hardware satellite controls.</p>

[![macOS 14.0+](https://img.shields.io/badge/macOS-14.0%2B-black?logo=apple&style=flat-square)](https://apple.com/macos)
[![Swift 6](https://img.shields.io/badge/Swift-6.0%2B-F05138?logo=swift&logoColor=white&style=flat-square)](https://swift.org)
[![SwiftUI & AppKit](https://img.shields.io/badge/UI-SwiftUI%20%2B%20AppKit-blue?style=flat-square)](https://developer.apple.com/swiftui/)
[![Website](https://img.shields.io/badge/Website-harmonotch--web.vercel.app-black?logo=vercel&style=flat-square)](https://harmonotch-web.vercel.app)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg?style=flat-square)](LICENSE)

</div>

Harmonotch turns the camera cutout on a MacBook into a powerful, elegant control surface. Hover the notch to open a drawer with four tabs: battery status, media with synced lyrics, prayer times, and AI agent quota monitoring. On a Mac without a notch, the same controls live in a floating top pill and the menu bar dashboard.

Prayer times and battery telemetry are calculated and monitored 100% on device. The app has no accounts, no analytics, and no tracking servers. Lyrics, release updates, and agent quota probes use local system tools and direct APIs.

## Features

### AI Agents Monitor (CLI Quotas & Active Models)

- **Multi-Agent Discovery**: Automatically detects installed AI CLI developer tools on your system:
  - **Claude Code** (`claude`)
  - **OpenAI Codex** (`codex`)
  - **OpenCode CLI** (`opencode`)
  - **Antigravity / Gemini CLI** (`agy`)
  - **GitHub Copilot** (`gh copilot`)
- **Live Quota & Usage Tracking**:
  - Claude: 5-hour utilization window and 7-day weekly quota percentages with countdown reset timestamps via OAuth usage APIs or startup session analytics.
  - Codex: Primary and secondary rate-limit windows (`% left`), reset timers, account plan tier, and available reset credits.
  - OpenCode: Connected providers count, primary balance, and active model lists.
  - Gemini / Antigravity: Multi-bucket 5-hour and weekly quota fractions, reset countdowns, and active model identities.
  - Copilot: GitHub CLI authentication status and account details.
- **Model Tracking & Diagnostics**: Displays active model name, reasoning effort, tier, provider details, and quick CLI login hints (e.g. `claude auth login`, `codex login`, `agy --login`) when authentication is required.
- **Dual Interface**: Full interactive drawer tab in the notch (`AIAgentDrawerView`) and inline expandable cards with agent switcher in the Menu Bar Dashboard (`DashboardAgentsSection`).

### Battery & Power Management

- Reads percentage, charging state, and power source from IOKit (`AppleSmartBattery`).
- Computes battery health aligned with macOS System Settings (`NominalChargeCapacity` / `AppleRawMaxCapacity` against `DesignCapacity`) alongside cycle count, temperature, and voltage.
- Shows time to full or time to empty, and the connected adapter wattage.
- **Hardware Charge Limiter (80% Cap / AC Bypass)**:
  - Caps charging at 80% (or custom 70% / 90% / 100%) to preserve battery chemistry and extend lifespan.
  - Controls hardware SMC registers (`CH0B` for Apple Silicon M1–M4 in bypass mode; `BCLM` for Intel Macs) across macOS versions (Tahoe / Golden Gate, Sequoia, Sonoma, and Ventura).
  - Smart hysteresis (2% buffer) prevents rapid charging on/off cycles when hovering at the threshold.
  - Automatic fail-safe: restores normal charging state when quitting the app or unplugging the power cable.
  - One-click privilege setup via `/etc/sudoers.d/harmonotch` scoped to your user UID, with fallbacks to CLI tools (`battery`, `smc`) and smart audio/visual notifications.
- **Clamshell Mode (Stay Awake with Lid Closed)**:
  - Keeps the Mac awake and the external monitor active as the primary display when the MacBook lid is closed.
  - **Requirements**: An external display must be connected; without an external display, the mode stays in `Standby (No Display)` and never disables system sleep.
  - **Battery & Power Adapter Policy**: Connecting a power adapter is recommended. When running on battery power, Harmonotch sends a warning notification at `60%` and automatically pauses Clamshell Mode at `≤ 50%`, restoring normal sleep (`SleepDisabled 0`) and putting the Mac to sleep if the lid is closed. Reconnecting the power adapter automatically resumes the session.
  - **Ownership & Crash Recovery**: Tracks override ownership (`Harmonotch_ClamshellOverrideOwned`) before enabling `disablesleep 1`, restores sleep synchronously on app termination, and recovers stale state on next launch without interfering with `disablesleep` set by other tools.
  - **Admin Permission & Manual Cleanup**: Uses a dedicated sudoers file at `/etc/sudoers.d/harmonotch-clamshell` scoped to your user UID for `/usr/bin/pmset -a disablesleep 1` and `0` only (separate from the Charge Limiter rule at `/etc/sudoers.d/harmonotch`). To remove and reset manually without the app:
    ```bash
    sudo rm -f /etc/sudoers.d/harmonotch-clamshell
    sudo /usr/bin/pmset -a disablesleep 0
    defaults delete com.ssajudn.Harmonotch Harmonotch_ClamshellOverrideOwned 2>/dev/null || true
    ```
- Shortcuts to refresh telemetry or open macOS Battery settings.

### Media & Synced Lyrics

- Playback monitoring and transport control (`play/pause`, `next`, `previous`, `seek`) for Apple Music, Spotify, QuickTime, Podcasts, and browsers through a MediaRemote bridge: a small adapter loaded into Apple's `/usr/bin/perl` because macOS no longer answers MediaRemote directly from third-party apps. The technique was inspired by [Vorssaint](https://github.com/vorssaint/vorssaint-utils), licensed GPL-3.0-or-later, and is used with the author's written permission. Harmonotch's adapter is an independent implementation and contains no Vorssaint source code. When the bridge is unavailable, the app falls back to AppleScript and Safari/Chromium Apple Events.
- Collapsed notch narrows toward the hardware notch while playing, showing the artwork thumbnail on the left wing with a live equalizer waveform on the right, then restores the battery layout when playback ends.
- Expanded notch drawer displays high-resolution artwork, track metadata, interactive progress scrubber, playback transport controls, and time-synchronized karaoke lyrics from [LRCLIB](https://lrclib.net/).
- Lets you click any lyric line to seek directly to its timestamp.

### Satellite Sliders & Volume HUD

- **Vertical Satellite Sliders**:
  - Two vertical capsule sliders flank the notch drawer (`NotchSatelliteSlider`).
  - **Display Brightness Slider**: Integrates with `SystemBrightnessService` for instant hardware brightness adjustments.
  - **System Volume Slider**: Integrates with `SystemAudioService` for volume level control and mute toggling.
  - Supports continuous mouse drag and smooth trackpad/mouse scroll wheel stepping (`SatelliteScrollHandler`).
- **Volume HUD in Notch (Single-Owner)**:
  - Clean volume indicator seamlessly rendered in the notch when volume keys (up, down, mute) are pressed.
  - **Strict Single Ownership Architecture**: Per keypress, only one HUD owns the screen. When Harmonotch handles volume, the native macOS OSD is intercepted without showing dual/duplicate HUDs.
  - **Hardware Fallback**: Directly writes to CoreAudio (`AudioObjectSetPropertyData`). If the active device does not support software volume or write fails, control immediately falls back to native macOS with an automatic grace period.
  - **Native Feedback Parity**: Honors macOS "Play feedback when volume is changed" setting and Shift key inversion using Apple's official `volume.aiff` audio sample.

### Prayer Times & Adzan

- Six daily times (Fajr, Sunrise, Dhuhr, Asr, Maghrib, Isha) calculated locally with [Adhan-Swift](https://github.com/batoulapps/adhan-swift).
- Calculation methods: Kemenag, Muslim World League, ISNA, Umm Al-Qura, Egyptian General Authority, University of Islamic Sciences Karachi, Dubai, Qatar, Kuwait, Singapore, and Turkey.
- Manual minute offsets, an Imsak time, and a Hijri date in the drawer.
- Automatic adhan playback at each prayer, with mute, volume, test playback, and a stop button.
- Indonesian city presets, or optional location lookup through CoreLocation and MapKit.

### Interface & Experience

- Pure monochrome black-and-white (`#000000` / `#FFFFFF`) and Catppuccin theme palettes engineered to blend cleanly into the MacBook camera housing.
- Fluid spring shrink/expand geometry (`NotchMotion`) with selective cursor hit-testing so the macOS menu bar only activates outside the notch radius.
- Dynamic floating island pill for Macs without a physical notch.
- English and Indonesian, switched from the menu bar without a restart.
- Streamlined menu bar dashboard with quick summary cards, quick rows, inline expandable agent cards, battery telemetry, language switcher, clamshell mode, and update checks.
- Notch drawer with keyboard shortcuts for tabs, adhan mute, and hiding the overlay.

## Architecture

- **Feature Managers & State:** UI state is owned by main-actor-isolated observable managers (`PrayerManager`, `BatteryMonitor`, `ClamshellManager`, `BatteryChargeLimiter`, `MediaManager`, `VolumeHUDController`, `AIAgentQuotaService`, `SystemBrightnessService`, `SystemAudioService`, `UpdateManager`, `ThemeManager`, `LanguageManager`). Heavy I/O (process execution, AppleScript, network requests, IOKit/pmset probes) is delegated to dedicated background queues and shared helpers (`ProcessRunner`, `AppleScriptRunner`, `SudoersRuleInstaller`).
- **AI Agent Pipeline:** `AIAgentDiscoveryService` inspects local CLI binaries, configuration files (`~/.claude.json`, `~/.codex/`, `~/.config/opencode/`, `~/.config/gemini/`, `~/.config/gh/`), and authorization tokens. `AIAgentQuotaService` asynchronously fetches usage quotas and rate limits across agents in parallel via background task groups.
- **Media Pipeline:** `MediaManager` ingests candidates from three sources: (1) the Perl/Objective-C `NowPlayingBridge` (`MediaNotificationIngest`), (2) local AppleScript & distributed notifications (`MediaScriptRunner`), and (3) browser tab probes (`MediaWebProbe` + `BrowserCatalog`), plus CoreAudio active-process detection (`AudioProcessPresence`). `MediaSelector` arbitrates a single winning `MediaCandidate` into a `MediaPresentation`, while `MediaArtworkService` and `MediaLyricsService` asynchronously resolve artwork palettes and synced LRCLIB/Apple Music lyrics.
- **Prayer Pipeline:** `PrayerManager` resolves coordinates from Indonesian `CityPreset` entries or CoreLocation, computes daily schedules and Qibla direction via `Adhan` and `PrayerScheduleResolver`, schedules system notifications via `UserNotificationService`, and triggers `AdzanPlayer` at prayer times.

## Requirements

- macOS 14.0 (Sonoma) or later. Verified up to macOS 27.
- Xcode 16.3 or later (Swift 6.1+, needed for `nonisolated` types).

## Build and run

```bash
git clone https://github.com/Udean777/Harmonotch.git
cd Harmonotch
open Harmonotch.xcodeproj
```

Press `Cmd + R` in Xcode. For a release build from the command line:

```bash
xcodebuild -project Harmonotch.xcodeproj -scheme Harmonotch -configuration Release -destination 'platform=macOS' build
```

## Release signing

The release workflow signs with a stable certificate when these secrets are set:

| Secret | Value |
| --- | --- |
| `SIGNING_CERT_P12` | base64 of the `.p12` (single line) |
| `SIGNING_CERT_PASSWORD` | password used when exporting the `.p12` |

Without them the workflow falls back to ad-hoc signing. Do not ship that way: an ad-hoc signature makes every TCC grant (microphone, Automation, Input Monitoring) cdhash-based, so each update resets them until the app is removed and re-added in System Settings.

To create a free self-signed certificate:

1. Keychain Access → Certificate Assistant → Create a Certificate…
   Name `Harmonotch Release`, Identity Type *Self Signed Root*, Certificate Type *Code Signing*.
2. Export it as `.p12` with a password, then run `base64 -i HarmonotchRelease.p12 | pbcopy` and paste it into `SIGNING_CERT_P12`.

After a release, verify the identity is stable:

```bash
codesign -d -r- /Applications/Harmonotch.app
# expect: identifier "com.ssajudn.Harmonotch" and certificate leaf = H"..."
# not:    cdhash H"..."
```

Users upgrading from an ad-hoc build must remove and re-add the app in System Settings → Privacy & Security once.

## Test

```bash
./Tests/run-tests.sh
```

The test runner discovers all domain suites in `Tests/` (`PrayerTests`, `MediaTests`, `MediaSelectionTests`, `BatteryTests`, `AudioTests`, `AIAgentTests`, `UpdateTests`, `GeometryTests`, `DefaultsTests`) and verifies prayer calculations, version & update installer policies, LRC parsing, media candidate arbitration, browser catalog lookup, clamshell & charge limit policies, battery presentation, AI agent discovery & quota extraction, volume key routing, notch geometry, and typed `UserDefaults` keys.

## Project structure

```text
Harmonotch/
├── App/
│   ├── AppDelegate.swift             // AppKit lifecycle and status item observer
│   ├── StatusBarMenuBuilder.swift    // Status bar context menu construction
│   ├── AppMenuActions.swift          // Status bar menu @objc actions
│   └── UserDefaultsKeys.swift        // Centralized typed UserDefaults keys
├── Shared/
│   ├── ProcessRunner.swift           // Safe subprocess execution & pipe draining
│   ├── AppleScriptRunner.swift       // Serial cached NSAppleScript & admin shell runner
│   ├── SudoersRuleInstaller.swift    // UID-scoped /etc/sudoers.d installer & probe
│   ├── AppLauncher.swift             // Bundle activation and URL fallback
│   ├── UserNotificationService.swift // UNUserNotificationCenter wrapper
│   └── TimeFormatting.swift          // Playback clock, countdown & quota time formatting
├── HarmonotchApp.swift               // App entry point
├── NotchUI/
│   ├── NotchGeometryHelper.swift     // Notch geometry detection & layout tokens
│   ├── NotchWindowController.swift   // Floating panel with selective hit testing
│   ├── NotchViewModel.swift          // Hover, tab, and dismiss state
│   ├── NotchContainerView.swift      // Drawer and tab container
│   ├── NotchTab.swift                // Tab enum and segmented control
│   ├── NotchChip.swift               // Shared chip and motion tokens
│   ├── NotchPillView.swift           // Collapsed notch content
│   ├── NotchSatelliteSlider.swift    // Reusable vertical satellite slider
│   ├── NotchSatelliteBrightnessSlider.swift // Brightness satellite control
│   ├── NotchVerticalVolumeSlider.swift // Volume satellite control
│   ├── VolumeNoticeView.swift        // In-notch volume HUD badge
│   └── PureBlackSurface.swift        // Notch surface fill
├── Features/
│   ├── AIAgents/                     // CLI discovery, models, and quota tracking
│   │   ├── AIAgentDiscoveryService.swift
│   │   ├── AIAgentModels.swift
│   │   ├── AIAgentQuotaService.swift
│   │   └── AIAgentDrawerView.swift
│   ├── Brightness/                   // System display brightness service
│   ├── MenuBar/                      // Menu bar dashboard and modular sections
│   │   ├── Sections/                 // Agents, Battery, Prayer, Now sections
│   │   │   ├── DashboardAgentsSection.swift
│   │   │   ├── DashboardBatterySection.swift
│   │   │   ├── DashboardNowSection.swift
│   │   │   ├── DashboardPrayerSection.swift
│   │   │   └── Now/                  // Summary cards & quick action rows
│   │   ├── MenuBarDashboardView.swift
│   │   ├── MenuBarDashboardViewModel.swift
│   │   └── MenuBarPanelController.swift
│   ├── Theme/                        // Monochrome/Catppuccin palettes, AppTypography
│   ├── Localization/                 // Language state and localized strings (L10n)
│   ├── Prayer/                       // Astronomical prayer engine, adhan audio, city presets
│   ├── Battery/                      // IOKit monitor, SMC charge limiter, and Clamshell mode
│   ├── Audio/                        // CoreAudio service, volume key router, CGEventTap, TCC
│   ├── Media/                        // MediaRemote bridge, web probe, artwork, lyrics, and drawer views
│   ├── Update/                       // GitHub release checks, bounded downloader, and installer
│   └── About/                        // About window and credits
├── web/                              // Landing page (HTML, CSS, JS)
├── Assets.xcassets/
├── Resources/
│   ├── adzan.m4a
│   └── adzan_subuh.m4a
└── Tests/
    ├── main.swift                    // Test harness entry point
    ├── AIAgentTests.swift
    ├── AudioTests.swift
    ├── BatteryTests.swift
    ├── DefaultsTests.swift
    ├── GeometryTests.swift
    ├── MediaSelectionTests.swift
    ├── MediaTests.swift
    ├── PrayerTests.swift
    └── UpdateTests.swift
```

## Credits

- [Adhan-Swift](https://github.com/batoulapps/adhan-swift) by Batoul Apps (MIT License) for astronomical prayer calculations.
- [LRCLIB](https://lrclib.net/) for synced lyrics.
- [IslamDownload.net](https://islamdownload.net/123801-download-suara-adzan.html) for the adhan recordings.
- [Vorssaint](https://github.com/vorssaint/vorssaint-utils) (GPL-3.0-or-later) for the MediaRemote-through-Perl technique, client process identifier resolution, debounced serial playback state reconciliation, research into demand-driven monitoring and modular utility panels, and for the clamshell, volume-key HUD, and accessibility permission patterns that informed Harmonotch's implementations. Harmonotch's implementations are written independently from Apple documentation, original testing, and observed runtime behavior; no Vorssaint source code, assets, strings, type names, or trade dress are included. Harmonotch is not affiliated with or endorsed by Vorssaint.
- [actuallymentor/battery](https://github.com/actuallymentor/battery) & [smcFanControl](https://github.com/hholtmann/smcFanControl) for research into Apple SMC registers (`CH0B` and `BCLM`).
- CLI developer ecosystems: Anthropic Claude Code, OpenAI Codex, OpenCode, Google Antigravity & Gemini CLI, and GitHub Copilot.
- Apple for the iTunes Search API, `MediaRemote`, DisplayServices, SF Symbols, and IOKit.

Full license texts and attributions are in [ACKNOWLEDGEMENTS.md](ACKNOWLEDGEMENTS.md).

## License

MIT. See [LICENSE](LICENSE).

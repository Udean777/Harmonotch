# Code Quality Remediation Plan

Audit of the Swift app (47 files, ~8.6k LOC) and the web site (3 files, ~3.7k LOC).
Each phase is independently shippable. Phases run in the order below.

Legend: `[ ]` pending, `[x]` done.

---

## Phase 1 — User-visible bugs (P0)

- [x] Persist Adzan volume `0` instead of resetting to `0.85`
      (`Features/Prayer/AdzanPlayer.swift`).
- [x] Fix the sudo probe so the "Authorize Sudo" button disappears after setup
      (`Features/Battery/ClamshellManager.swift`). Probe the allowed command with
      `sudo -n -l`, and remember a successful setup in `UserDefaults`.
- [x] Actually load Apple Music artwork instead of the empty `if let raw` branch
      (`Features/Media/MediaManager.swift`). Added a binary AppleScript result path.
- [x] Make web seek / play-pause work in Chrome, not just Safari
      (`Features/Media/MediaManager.swift`).
- [x] Localize the prayer notification title and body
      (`Features/Prayer/PrayerManager.swift`, `Features/Localization/L10n.swift`).
- [x] Stop the web download button from downloading *and* opening GitHub on a failed
      probe (`web/js/main.js`).
- [x] Do not call `res.redirect()` after the stream headers are sent
      (`web/api/download.js`).

## Phase 2 — Correctness and lifecycle (P1)

- [x] Release the clamshell sleep assertion / `pmset disablesleep` on app quit
      (`App/AppDelegate.swift`, `Features/Battery/ClamshellManager.swift`).
- [x] Validate the sudoers drop-in with `visudo -c` before trusting it
      (`Features/Battery/ClamshellManager.swift`). Written to a temp file first, so a
      bad rule never lands in `/etc/sudoers.d`.
- [x] Clear stale update URLs when a check finds no newer release; move version
      comparison into a pure helper (`Features/Update/Version.swift`,
      `Features/Update/UpdateManager.swift`).
- [x] Re-sync `isPlaying` with the player after a play/pause command
      (`Features/Media/MediaManager.swift`).
- [x] Format prayer times in the selected city's time zone
      (`Features/Prayer/PrayerManager.swift`, uses `CityPreset.timeZoneIdentifier`).
- [x] Build localized battery strings on the main thread
      (`Features/Battery/BatteryMonitor.swift`).
- [x] Cache the status-bar logo instead of redrawing it on every published change
      (`App/AppDelegate.swift`).
- [x] Collapse the 14 identical status-bar Combine sinks into one pipeline
      (`App/AppDelegate.swift`).

## Phase 3 — Dead code removal

- [x] `NativeVisualEffectView`, `LiquidGlassSurface.material`, `innerBorderColor`
      (`NotchUI/LiquidGlassBackground.swift`).
- [x] `NotchWindowController.toggleVisibility`
      (`NotchUI/NotchWindowController.swift`).
- [x] `BatteryMonitor.conditionString` (`Features/Battery/BatteryMonitor.swift`).
- [x] `AppLanguage.shortCode` (`Features/Localization/LanguageManager.swift`).
- [x] Unused `L10n` entries: `Prayer.imsakDetail`, `Menu.appTitle`,
      `Menu.cyclesSuffix`, `Menu.quickPreferences`.
- [x] Unused `AppTheme` entries: `surfaceInnerHighlight`, `surfaceShadowColor`,
      `surfaceShadowRadius`, `cardHoverBackground`, `tabBarBorder`, `tabActiveBorder`.
- [x] `CityPreset.coordinates` (kept `timeZoneIdentifier`, now used by Phase 2).
- [x] Rename `Adhan/Models/Rouding.swift` to `Rounding.swift`.

Note: the `#if compiler(>=6.4)` MapKit branch is **kept** — the local toolchain is
Swift 6.4 and the branch is live there; it only degrades to `CLGeocoder` on older Xcode.

## Phase 4 — Web cleanup

- [x] Take over navigation, then probe before downloading, and let the browser retry
      on a network error (`web/js/main.js`).
- [x] Guard the stream error path with `res.headersSent` (`web/api/download.js`).

## Phase 5 — Localization

- [x] Keep English in the generated `NS*UsageDescription` build settings and override
      them per system language with `Harmonotch/{en,id}.lproj/InfoPlist.strings`;
      mention the browsers the app scripts (`project.pbxproj`, `knownRegions = id`).
      System permission dialogs follow the macOS language, not the in-app setting.
- [x] Localize prayer notifications (done in Phase 1).
- [x] Replace hard-coded Indonesian UI strings: `"Lokasi Saya"`, `"Uji Coba"`
      (`L10n.Prayer.myLocation`, `L10n.Prayer.testPrayer`).

"Liquid Glass", "Zen Serenity", "Glass", and "Zen" are brand names for the two
visual styles and stay identical in both languages.

## Phase 6 — Comment and log hygiene

- [x] Drop numbered workflow narration and line-by-line restatements.
- [x] Keep the comments that explain *why* (Kemenag ihtiyat, quarantine, idempotency,
      license headers).
- [x] Use English for code comments and log messages; Indonesian stays in `L10n` only.

## Phase 7 — Tests and CI

- [x] Extract pure helpers: `Features/Update/Version.swift`,
      `Features/Media/LRCParser.swift`, `Features/Prayer/Compass.swift`,
      `Features/Battery/ClamshellPolicy.swift`.
- [x] Add `Tests/main.swift` with assertion-based checks for:
      prayer times (golden values for Jakarta, Kemenag adjustments), `Version`,
      `LRCParser`, `Compass.cardinal` (including headings below 0°), and
      `ClamshellPolicy` (off / standby / active / 50% cutoff).
- [x] Add `Tests/run-tests.sh` compiling the pure sources with `swiftc`.
- [x] Run the harness in CI, and stop mutating `project.pbxproj` with `sed`.
      The project is committed as `objectVersion = 77`, which Xcode 16 runners read.

The clamshell decision is now pure and tested. The I/O side (IOKit assertion,
`pmset`, screen detection) still runs only on real hardware.

Rationale for a compiled assertion harness instead of an XCTest bundle: the project
uses a synchronized-folder target and has no shared scheme. A standalone harness
tests the pure logic with zero `.pbxproj` surgery and runs on any macOS runner.

## Phase 8 — Hardening the skipped items

- [x] Clear a stale `disablesleep 1` on launch whenever the resolved state is not
      active (`Features/Battery/ClamshellManager.swift`). Covers crash and force-quit,
      which skip `applicationWillTerminate`; the silent `sudo -n` path is used, so an
      unconfigured machine only logs instead of prompting at startup.
- [x] Move the clamshell decision into `ClamshellPolicy` and test every branch.
- [x] Ship localized `InfoPlist.strings` for `en` and `id`; verified they land in
      `Harmonotch.app/Contents/Resources/{en,id}.lproj/`.
- [x] Syntax-check both web scripts in CI with `node --check`.

---

## Phase 9 — UI remediation

- [x] Web: removed the hero eyebrow badge, section kickers, filler trust strip, and
      decorative gradients; hero is a static preview instead of a fake live loop.
- [x] Web: flagship feature card is full-width, the remaining five are supporting cards.
- [x] Web: muted text now meets WCAG AA (`#8e8e93`); version badge hides when the
      GitHub API fails instead of claiming a fabricated latest release.
- [x] Web: cut backdrop-filter to the nav and mockup chrome; removed unused tokens.
- [x] Swift: shared `NotchChip`, centralized `NotchLayout` heights, removed the broken
      static `@ObservedObject` in `AppTheme`, split `NotchPillView` by tab.
- [x] Swift: the adzan volume control expands to fill the control row.
- [x] Deleted section/divider/restating comments across web and Swift.

---

## Not verified / known gaps

- AppleScript control paths (Spotify, Apple Music, Safari, Chrome) were compiled, not
  exercised against running apps. Needs a manual smoke test on a Mac with music open.
- Clamshell behaviour (`pmset`, external display, lid close) needs real hardware; only
  the pure policy is covered by tests.
- Crash cleanup is best-effort: if `disablesleep` was set without the passwordless
  sudoers rule, the launch repair cannot clear it silently and only logs.
- No accessibility pass yet.
- The web site is syntax-checked, not rendered or served in CI.

---

## Out of scope

- Rewriting singletons as injected dependencies (would unlock clamshell tests).
- Splitting `MediaManager` into smaller services; the parser and version logic are
  already extracted, but the manager still owns a lot of I/O.
- Full accessibility pass (needs a UI review).

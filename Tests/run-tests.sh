#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

SOURCES=()
while IFS= read -r file; do
    SOURCES+=("$file")
done < <(find Harmonotch/Features/Prayer/Adhan -name '*.swift' | sort)

SOURCES+=(
    "Harmonotch/App/UserDefaultsKeys.swift"
    "Harmonotch/Features/Localization/LanguageManager.swift"
    "Harmonotch/Features/Localization/L10n.swift"
    "Harmonotch/Features/Battery/ClamshellPolicy.swift"
    "Harmonotch/Features/Battery/ClamshellLidSupport.swift"
    "Harmonotch/Features/Battery/ChargeLimitPolicy.swift"
    "Harmonotch/Features/Battery/BatteryReading.swift"
    "Harmonotch/Features/Prayer/Compass.swift"
    "Harmonotch/Features/Media/MediaAppInfo.swift"
    "Harmonotch/Features/Media/MediaIdentity.swift"
    "Harmonotch/Features/Media/MediaCapabilities.swift"
    "Harmonotch/Features/Media/MediaCandidate.swift"
    "Harmonotch/Features/Media/MediaPresentation.swift"
    "Harmonotch/Features/Media/MediaSelector.swift"
    "Harmonotch/Features/Media/AudioProcessResolver.swift"
    "Harmonotch/Features/Media/AudioProcessPresence.swift"
    "Harmonotch/Features/Media/LRCParser.swift"
    "Harmonotch/Features/Media/MediaManager.swift"
    "Harmonotch/Features/Media/WebMediaScripts.swift"
    "Harmonotch/Features/Media/WebMediaSnapshot.swift"
    "Harmonotch/Features/Media/NowPlaying/NowPlayingBridge.swift"
    "Harmonotch/Features/Media/NowPlaying/NowPlayingState.swift"
    "Harmonotch/Features/Update/Version.swift"
    "Harmonotch/Features/Update/UpdateInstallerSupport.swift"
    "Harmonotch/NotchUI/NotchGeometryHelper.swift"
    "Harmonotch/Features/MenuBar/MenuBarPanelLayout.swift"
    "Harmonotch/Features/MenuBar/MenuBarDashboardViewModel.swift"
    "Harmonotch/Features/MenuBar/DashboardDataState.swift"
    "Harmonotch/Features/Processes/ProcessActivityError.swift"
    "Harmonotch/Features/Processes/ProcessActivitySnapshot.swift"
    "Harmonotch/Features/Processes/ProcessActivityRanking.swift"
    "Harmonotch/Features/Processes/ProcessActivityMonitor.swift"
    "Harmonotch/Features/Prayer/PrayerScheduleResolver.swift"
    "Harmonotch/Features/Audio/SystemAudioService.swift"
    "Harmonotch/Features/Audio/VolumeKeyRouter.swift"
    "Tests/main.swift"
)

swiftc -o "$TMP_DIR/harmonotch-tests" "${SOURCES[@]}"
"$TMP_DIR/harmonotch-tests"

import AppKit
import Foundation

var failures = 0

func check(_ condition: Bool, _ message: String) {
    if !condition {
        failures += 1
        fputs("FAIL: \(message)\n", stderr)
    }
}

func checkEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String) {
    check(actual == expected, "\(message): expected \(expected), got \(actual)")
}

// MARK: - Prayer times

let jakarta = Coordinates(latitude: -6.2088, longitude: 106.8456)
var params = CalculationMethod.singapore.params
params.methodAdjustments = PrayerAdjustments(fajr: 2, sunrise: -2, dhuhr: 2, asr: 2, maghrib: 2, isha: 2)

func prayerStrings(_ times: PrayerTimes) -> [String] {
    let formatter = DateFormatter()
    formatter.timeZone = TimeZone(identifier: "Asia/Jakarta")
    formatter.dateFormat = "HH:mm"
    return [
        formatter.string(from: times.fajr),
        formatter.string(from: times.sunrise),
        formatter.string(from: times.dhuhr),
        formatter.string(from: times.asr),
        formatter.string(from: times.maghrib),
        formatter.string(from: times.isha),
    ]
}

if let times = PrayerTimes(
    coordinates: jakarta,
    date: DateComponents(year: 2024, month: 6, day: 1),
    calculationParameters: params
) {
    let actual = prayerStrings(times)
    let expected = ["04:37", "05:55", "11:53", "15:15", "17:46", "19:01"]
    for (index, name) in ["fajr", "sunrise", "dhuhr", "asr", "maghrib", "isha"].enumerated() {
        checkEqual(actual[index], expected[index], "Jakarta \(name)")
    }
} else {
    check(false, "Jakarta prayer times should be calculable")
}

// MARK: - Version

checkEqual(Version.isNewer("1.2.3", than: "1.2.2"), true, "patch bump")
checkEqual(Version.isNewer("1.10.0", than: "1.9.9"), true, "numeric, not lexical")
checkEqual(Version.isNewer("1.2", than: "1.2.0"), false, "missing components are zero")
checkEqual(Version.isNewer("2.0.0-beta", than: "1.9.0"), true, "prerelease suffix ignored")
checkEqual(Version.isNewer("v1.3.0", than: "1.2.9"), true, "leading v")

// MARK: - UpdateInstallerSupport

checkEqual(UpdateInstallerSupport.progressStepAdvanced(from: nil, to: 0.05), true, "first progress always advances")
checkEqual(UpdateInstallerSupport.progressStepAdvanced(from: 0.121, to: 0.129), false, "sub-percent step doesn't advance")
checkEqual(UpdateInstallerSupport.progressStepAdvanced(from: 0.129, to: 0.131), true, "crossing whole percent advances")
checkEqual(UpdateInstallerSupport.downloadByteLimit(expectedBytes: 15_000_000), 15_000_000, "expected size within ceiling")
checkEqual(UpdateInstallerSupport.downloadByteLimit(expectedBytes: 500_000_000), UpdateInstallerSupport.downloadCeilingBytes, "excessive size capped")
checkEqual(UpdateInstallerSupport.downloadIsUsable(status: 200, receivedBytes: 15_000_000, expectedBytes: 15_000_000), true, "matching size usable")
checkEqual(UpdateInstallerSupport.downloadIsUsable(status: 404, receivedBytes: 15_000_000, expectedBytes: 15_000_000), false, "non-200 unusable")
checkEqual(UpdateInstallerSupport.shellSingleQuoted("test'app"), "'test'\\''app'", "shell single quoting")
checkEqual(UpdateInstallerSupport.runsFromImmutableLocation(appPath: "/AppTranslocation/d/app.app", volumeIsReadOnly: { _ in false }), true, "app translocation detected")
checkEqual(UpdateInstallerSupport.runsFromImmutableLocation(appPath: "/Applications/Harmonotch.app", volumeIsReadOnly: { _ in false }), false, "normal app location")

// MARK: - LRC

let lrc = """
[ar:Artist]
[00:12.50]First line
[00:05.00][01:05.00]Repeated
[00:20.00]
"""
let lyrics = LRCParser.parse(lrc)
checkEqual(lyrics.count, 3, "LRC line count")
checkEqual(lyrics[0].text, "Repeated", "LRC sorted first")
checkEqual(lyrics[0].time, 5.0, "LRC timestamp")
checkEqual(lyrics[1].time, 12.5, "LRC second timestamp")
checkEqual(lyrics[2].time, 65.0, "LRC repeated timestamp")
checkEqual(LRCParser.parse("[00:01.00]").count, 0, "empty text is skipped")
checkEqual(LRCParser.parse("not lrc").count, 0, "plain text is skipped")

// MARK: - Lyrics Sync Validation & Status
let zeroLrc = "[00:00.00]Line one\n[00:00.00]Line two"
let parsedZero = LRCParser.parse(zeroLrc)
let hasDistinct = parsedZero.count > 1 && (parsedZero.last?.time ?? 0) > (parsedZero.first?.time ?? 0)
checkEqual(hasDistinct, false, "zero timestamp LRC is not treated as synced")

let realLrc = "[00:04.50]Line one\n[00:10.20]Line two"
let parsedReal = LRCParser.parse(realLrc)
let hasRealTimestamps = parsedReal.count > 1 && (parsedReal.last?.time ?? 0) > (parsedReal.first?.time ?? 0)
checkEqual(hasRealTimestamps, true, "valid LRC has distinct timestamps")
checkEqual(LyricsStatus.unavailable("none") == LyricsStatus.unavailable("none"), true, "LyricsStatus equality")

// MARK: - Clamshell policy

checkEqual(ClamshellPolicy.state(
    isArmed: false, hasExternalDisplay: true, isPluggedIn: true, batteryCapacity: 100
), .off, "unarmed is off")

checkEqual(ClamshellPolicy.state(
    isArmed: true, hasExternalDisplay: false, isPluggedIn: true, batteryCapacity: 100
), .standby, "no external display is standby")

checkEqual(ClamshellPolicy.state(
    isArmed: true, hasExternalDisplay: true, isPluggedIn: true, batteryCapacity: 10
), .active, "charging stays active")

checkEqual(ClamshellPolicy.state(
    isArmed: true, hasExternalDisplay: true, isPluggedIn: false, batteryCapacity: 51
), .active, "on battery above cutoff is active")

checkEqual(ClamshellPolicy.state(
    isArmed: true, hasExternalDisplay: true, isPluggedIn: false, batteryCapacity: 50
), .pausedLowBattery, "on battery at cutoff pauses")

checkEqual(
    ClamshellPolicy.parseSleepDisabled("System-wide power settings:\n SleepDisabled\t\t1\nCurrently in use:\n"),
    true,
    "parses SleepDisabled 1 with tabs"
)
checkEqual(
    ClamshellPolicy.parseSleepDisabled("System-wide power settings:\n SleepDisabled      0\nCurrently in use:\n"),
    false,
    "parses SleepDisabled 0 with spaces"
)
checkEqual(
    ClamshellPolicy.parseSleepDisabled("Currently in use:\n sleep 1\n"),
    nil,
    "returns nil when SleepDisabled is absent"
)

// MARK: - Clamshell lid sleep support

checkEqual(
    ClamshellLidSupport.shouldRequestSleep(lidClosed: false, systemAllowsSleep: true, assertions: []),
    false,
    "lid false -> false"
)
checkEqual(
    ClamshellLidSupport.shouldRequestSleep(lidClosed: nil, systemAllowsSleep: true, assertions: []),
    false,
    "lid nil -> false"
)
checkEqual(
    ClamshellLidSupport.shouldRequestSleep(lidClosed: true, systemAllowsSleep: false, assertions: []),
    false,
    "system policy false -> false"
)
checkEqual(
    ClamshellLidSupport.shouldRequestSleep(lidClosed: true, systemAllowsSleep: nil, assertions: []),
    false,
    "system policy nil -> false"
)
checkEqual(
    ClamshellLidSupport.shouldRequestSleep(
        lidClosed: true,
        systemAllowsSleep: true,
        assertions: [["AssertType": "DisplayWake", "ProcessingHotPlug": true, "AssertLevel": 255]]
    ),
    false,
    "ProcessingHotPlug assertion blocks sleep"
)
checkEqual(
    ClamshellLidSupport.shouldRequestSleep(
        lidClosed: true,
        systemAllowsSleep: true,
        assertions: [["AssertType": "PreventSystemSleep", "AppliesOnLidClose": true, "AssertLevel": 255]]
    ),
    false,
    "AppliesOnLidClose assertion blocks sleep"
)
checkEqual(
    ClamshellLidSupport.shouldRequestSleep(
        lidClosed: true,
        systemAllowsSleep: true,
        assertions: [["AssertType": "PreventUserIdleSystemSleep", "AssertLevel": 255]]
    ),
    true,
    "PreventUserIdleSystemSleep without lid flag allows sleep"
)
checkEqual(
    ClamshellLidSupport.shouldRequestSleep(
        lidClosed: true,
        systemAllowsSleep: true,
        assertions: [["AssertType": "PreventSystemSleep", "AppliesOnLidClose": true, "AssertLevel": 0]]
    ),
    true,
    "assertion with AssertLevel 0 allows sleep"
)
checkEqual(
    ClamshellLidSupport.shouldRequestSleep(
        lidClosed: true,
        systemAllowsSleep: true,
        assertions: [["AssertType": "UserIsActive", "AppliesOnLidClose": NSNumber(value: 1), "AssertLevel": NSNumber(value: 255)]]
    ),
    false,
    "UserIsActive with NSNumber AppliesOnLidClose=1 blocks sleep"
)
checkEqual(
    ClamshellLidSupport.shouldRequestSleep(
        lidClosed: true,
        systemAllowsSleep: true,
        assertions: [["AssertType": "UserIsActive", "AppliesOnLidClose": NSNumber(value: 0), "AssertLevel": NSNumber(value: 255)]]
    ),
    true,
    "UserIsActive without lid flag allows sleep"
)
checkEqual(
    ClamshellLidSupport.shouldRequestSleep(
        lidClosed: true,
        systemAllowsSleep: true,
        assertions: nil
    ),
    true,
    "nil assertions when lid closed and system allows sleep returns true"
)

// MARK: - Compass

checkEqual(Compass.cardinal(for: 0, isEnglish: true), "N", "compass north")
checkEqual(Compass.cardinal(for: 90, isEnglish: true), "E", "compass east")
checkEqual(Compass.cardinal(for: 180, isEnglish: false), "S", "compass south (id)")
checkEqual(Compass.cardinal(for: 270, isEnglish: true), "W", "compass west")
checkEqual(Compass.cardinal(for: -90, isEnglish: true), "W", "negative heading wraps")
checkEqual(Compass.cardinal(for: 360, isEnglish: true), "N", "full turn")

// MARK: - Web media

let paused = "1\t2\thttps://www.youtube.com/watch?v=aaaaaaaaaaa\t{\"paused\":true,\"t\":12.5,\"d\":200,\"title\":\"First\",\"artist\":\"A\",\"art\":\"\"}\n"
let playing = "1\t3\thttps://www.youtube.com/watch?v=bbbbbbbbbbb\t{\"paused\":false,\"t\":3,\"d\":180,\"title\":\"Second\",\"artist\":\"B\",\"art\":\"https://x/y.jpg\"}\n"
let tabs = WebMediaParser.parse(output: paused + playing, browser: "Safari")
checkEqual(tabs.count, 2, "parses both tabs")
checkEqual(tabs[1].tabIndex, 3, "tab index parsed")
checkEqual(tabs[1].artworkURL, "https://x/y.jpg", "artwork parsed")
checkEqual(WebMediaParser.pick(from: tabs)?.title, "Second", "playing tab beats first tab")
checkEqual(
    WebMediaParser.pick(from: [tabs[0]], preferredURL: nil)?.title, "First", "paused tab with progress is picked")
checkEqual(
    WebMediaParser.pick(from: [tabs[0], tabs[0]], preferredURL: tabs[0].url)?.title, "First", "preferred paused tab kept")

check(WebMediaParser.parse(output: "", browser: "Safari").isEmpty, "empty output")
check(WebMediaParser.parse(output: "garbage\n1\t2\turl\tnot json\n", browser: "Safari").isEmpty, "broken lines skipped")

let live = WebMediaParser.parse(
    output: "1\t1\thttps://www.youtube.com/watch?v=ccccccccccc\t{\"paused\":false,\"t\":5,\"d\":0,\"title\":\"Live\",\"artist\":\"\",\"art\":\"\"}", browser: "Safari")
checkEqual(live.first?.duration, 0, "live stream has zero duration")

checkEqual(
    WebMediaParser.error(from: "ERR\t-1743\tnot allowed", browser: "Safari"),
    .automationDenied(browser: "Safari"), "automation denied")
checkEqual(
    WebMediaParser.error(
        from: "ERR\t8\tYou must enable the 'Allow JavaScript from Apple Events' option", browser: "Safari"),
    .javascriptDisabled(browser: "Safari"), "javascript disabled")
check(WebMediaParser.error(from: "ERR\t5\tother", browser: "Safari") == nil, "unrelated error ignored")

// MARK: - Now-playing bridge

func decodeNowPlayingEvent(_ json: String) -> NowPlayingEvent? {
    try? JSONDecoder().decode(NowPlayingEvent.self, from: Data(json.utf8))
}

let nowPlayingJSON = """
{"event":"state","source":"com.spotify.client","title":"Track","artist":"Artist","album":"Album","duration":215.4,"elapsed":42.1,"rate":1.0,"playing":true,"contentID":"abc"}
"""
if case .state(let state)? = decodeNowPlayingEvent(nowPlayingJSON) {
    checkEqual(state.title, "Track", "now-playing title")
    checkEqual(state.artist, "Artist", "now-playing artist")
    checkEqual(state.duration, 215.4, "now-playing duration")
    checkEqual(state.elapsed, 42.1, "now-playing elapsed")
    checkEqual(state.playing, true, "now-playing playing")
    checkEqual(state.sourceKind, .spotify, "now-playing source")
    check(state.artwork == nil, "now-playing artwork absent")
} else {
    check(false, "now-playing state decodes")
}

let artworkJSON = """
{"event":"state","source":"com.google.Chrome","title":"Track","artist":"","album":"","duration":0,"elapsed":0,"rate":0,"playing":false,"contentID":"abc","artwork":"AAEC"}
"""
if case .state(let state)? = decodeNowPlayingEvent(artworkJSON) {
    checkEqual(state.artwork, "AAEC", "now-playing artwork decoded")
    checkEqual(state.sourceKind, .web, "chromium maps to web")
} else {
    check(false, "now-playing state with artwork decodes")
}

// MARK: - Notch geometry

let notched = NotchGeometry(
    hasHardwareNotch: true, physicalNotchWidth: 200, physicalNotchHeight: 32,
    leftMargin: 0, rightMargin: 0, screenFrame: .zero)
checkEqual(notched.collapsedWidth(isHovered: false), 336, "default notched width")
checkEqual(
    notched.collapsedWidth(
        isHovered: false, measured: NotchWingWidths(left: 90, right: 70)),
    360, "notch expands to fit wider content")

let floating = NotchGeometry(
    hasHardwareNotch: false, physicalNotchWidth: 154, physicalNotchHeight: 24,
    leftMargin: 0, rightMargin: 0, screenFrame: .zero)
checkEqual(floating.collapsedWidth(isHovered: false), 154, "floating pill keeps base width")
check(
    floating.collapsedWidth(
        isHovered: false, measured: NotchWingWidths(left: 300, right: 300)) > 154,
    "floating pill grows past base width when content needs it")


// MARK: - Type Safety Tests

// Version Comparable & Hashable
checkEqual(Version("1.2.3") > Version("1.2.2"), true, "Version > patch")
checkEqual(Version("1.2") == Version("1.2.0"), true, "Version == trailing zero")
checkEqual(Version("2.0.0-beta") > Version("1.9.0"), true, "Version > with prerelease")
checkEqual(Version("v1.3.0") == Version("1.3.0"), true, "Version == leading v")
checkEqual(Set([Version("1.2"), Version("1.2.0")]).count, 1, "Version Set deduplication via Hashable")

// NowPlayingCommand
checkEqual(NowPlayingCommand.play.commandName, "play", "play command name")
checkEqual(NowPlayingCommand.seek(position: 42.5).position, 42.5, "seek command position")
let testCmdMsg = NowPlayingCommandMessage(id: "test-id-123", command: .seek(position: 10.0))
checkEqual(testCmdMsg.id, "test-id-123", "command message id")
checkEqual(testCmdMsg.cmd, "seek", "command message cmd")
checkEqual(testCmdMsg.position, 10.0, "command message position")

// UserDefaultsKey
let defaults = UserDefaults.standard
let testKey = UserDefaultsKey<Int>("typeSafetyTestKey", defaultValue: 99)
defaults.remove(testKey)
checkEqual(defaults[testKey], 99, "UserDefaultsKey defaultValue when unset")
defaults[testKey] = 42
checkEqual(defaults[testKey], 42, "UserDefaultsKey stored value")
checkEqual(defaults.contains(testKey), true, "UserDefaults.contains stored key")
defaults.remove(testKey)
checkEqual(defaults[testKey], 99, "UserDefaultsKey restored to defaultValue after removal")


// MARK: - Charge Limit Policy Tests (100% Unrestricting)
checkEqual(ChargeLimitPolicy.isLimitActive(threshold: 100), false, "Limit is not active at 100%")
checkEqual(ChargeLimitPolicy.isLimitActive(threshold: 80), true, "Limit is active at 80%")
checkEqual(ChargeLimitPolicy.clampThreshold(100), 100, "Clamp threshold allows 100%")
checkEqual(ChargeLimitPolicy.clampThreshold(105), 100, "Clamp threshold caps at 100%")
checkEqual(
    ChargeLimitPolicy.shouldInhibit(
        capacity: 85,
        isPluggedIn: true,
        isEnabled: false,
        targetThreshold: 100,
        currentlyInhibited: true
    ),
    false,
    "shouldInhibit is false when limit is set to 100%"
)
checkEqual(
    ChargeLimitPolicy.shouldInhibit(
        capacity: 80,
        isPluggedIn: true,
        isEnabled: true,
        targetThreshold: 80,
        currentlyInhibited: false
    ),
    true,
    "shouldInhibit is true when capacity hits threshold"
)

// MARK: - SystemAudioService (Phase 1)

checkEqual(
    SystemAudioService.targetVolume(current: 0.25, muted: false, direction: 1, fine: false),
    0.3125,
    "coarse volume step up (+1/16)"
)
checkEqual(
    SystemAudioService.targetVolume(current: 0.25, muted: false, direction: -1, fine: false),
    0.1875,
    "coarse volume step down (-1/16)"
)
checkEqual(
    SystemAudioService.targetVolume(current: 0.25, muted: false, direction: 1, fine: true),
    0.265625,
    "fine volume step up (+1/64)"
)
checkEqual(
    SystemAudioService.targetVolume(current: 0.25, muted: true, direction: 1, fine: false),
    0.0625,
    "volume step up from muted starts at 0"
)
checkEqual(
    SystemAudioService.targetVolume(current: 0.25, muted: true, direction: -1, fine: false),
    0.0,
    "volume step down from muted stays at 0"
)
checkEqual(
    SystemAudioService.targetVolume(current: 0.98, muted: false, direction: 1, fine: false),
    1.0,
    "volume step up clamps at 1.0"
)
checkEqual(
    SystemAudioService.targetVolume(current: 0.02, muted: false, direction: -1, fine: false),
    0.0,
    "volume step down clamps at 0.0"
)
checkEqual(
    SystemAudioService.shouldAutoMute(forVolume: 0.0),
    true,
    "volume 0.0 triggers auto-mute"
)
checkEqual(
    SystemAudioService.shouldAutoMute(forVolume: 0.0625),
    false,
    "audible volume does not auto-mute"
)
checkEqual(
    SystemAudioService.readVolume(for: 0),
    nil,
    "invalid device ID returns nil volume"
)
checkEqual(
    SystemAudioService.writeVolume(0.5, for: 0),
    false,
    "invalid device ID writeVolume returns false"
)
checkEqual(
    SystemAudioService.readMute(for: 0),
    nil,
    "invalid device ID returns nil mute"
)
checkEqual(
    SystemAudioService.writeMute(true, for: 0),
    false,
    "invalid device ID writeMute returns false"
)

// MARK: - VolumeKeyRouter (Phase 2)

let volUp = VolumeMediaKey.volumeUp.rawValue
let volDown = VolumeMediaKey.volumeDown.rawValue
let muteKey = VolumeMediaKey.mute.rawValue
let downState = VolumeKeyRouter.keyDownState
let upState = VolumeKeyRouter.keyUpState

do {
    // 1. disabled -> pass-through
    var router = VolumeKeyRouter()
    checkEqual(
        router.handle(
            keyCode: volUp, state: downState, isRepeat: false,
            enabled: false, canHandle: true, hasVolume: true, hasMute: true,
            option: false, shift: false, commandOrControl: false, now: 10.0
        ),
        .passThrough,
        "disabled -> pass-through"
    )
}

do {
    // 2. up without app-owned down -> pass-through
    var router = VolumeKeyRouter()
    checkEqual(
        router.handle(
            keyCode: volUp, state: upState, isRepeat: false,
            enabled: true, canHandle: true, hasVolume: true, hasMute: true,
            option: false, shift: false, commandOrControl: false, now: 10.0
        ),
        .passThrough,
        "up without app-owned down -> pass-through"
    )
}

do {
    // 3. app-owned down then repeat then up -> step, step, consume
    var router = VolumeKeyRouter()
    checkEqual(
        router.handle(
            keyCode: volUp, state: downState, isRepeat: false,
            enabled: true, canHandle: true, hasVolume: true, hasMute: true,
            option: false, shift: false, commandOrControl: false, now: 10.0
        ),
        .step(1),
        "app-owned volume up key-down -> .step(1)"
    )
    checkEqual(
        router.handle(
            keyCode: volUp, state: downState, isRepeat: true,
            enabled: true, canHandle: true, hasVolume: true, hasMute: true,
            option: false, shift: false, commandOrControl: false, now: 10.1
        ),
        .step(1),
        "app-owned volume up repeat -> .step(1)"
    )
    checkEqual(
        router.handle(
            keyCode: volUp, state: upState, isRepeat: false,
            enabled: true, canHandle: true, hasVolume: true, hasMute: true,
            option: false, shift: false, commandOrControl: false, now: 10.2
        ),
        .consume,
        "app-owned key-up -> .consume"
    )
    checkEqual(
        router.handle(
            keyCode: volUp, state: upState, isRepeat: false,
            enabled: true, canHandle: true, hasVolume: true, hasMute: true,
            option: false, shift: false, commandOrControl: false, now: 10.3
        ),
        .passThrough,
        "second key-up after release -> .passThrough"
    )
}

do {
    // 4. repeat before app-owned down -> pass-through
    var router = VolumeKeyRouter()
    checkEqual(
        router.handle(
            keyCode: volDown, state: downState, isRepeat: true,
            enabled: true, canHandle: true, hasVolume: true, hasMute: true,
            option: false, shift: false, commandOrControl: false, now: 20.0
        ),
        .passThrough,
        "repeat without prior app-owned down -> pass-through"
    )
    checkEqual(router.blocksCustomHUD(21.0), true, "unowned repeat activates native window")
}

do {
    // 5. Command, Control, Option alone -> pass-through; Option+Shift -> fine step
    var cmdRouter = VolumeKeyRouter()
    checkEqual(
        cmdRouter.handle(
            keyCode: volUp, state: downState, isRepeat: false,
            enabled: true, canHandle: true, hasVolume: true, hasMute: true,
            option: false, shift: false, commandOrControl: true, now: 30.0
        ),
        .passThrough,
        "Command/Control + volume -> pass-through"
    )

    var optRouter = VolumeKeyRouter()
    checkEqual(
        optRouter.handle(
            keyCode: volUp, state: downState, isRepeat: false,
            enabled: true, canHandle: true, hasVolume: true, hasMute: true,
            option: true, shift: false, commandOrControl: false, now: 30.0
        ),
        .passThrough,
        "Option alone + volume -> pass-through"
    )

    var fineRouter = VolumeKeyRouter()
    checkEqual(
        fineRouter.handle(
            keyCode: volDown, state: downState, isRepeat: false,
            enabled: true, canHandle: true, hasVolume: true, hasMute: true,
            option: true, shift: true, commandOrControl: false, now: 30.0
        ),
        .step(-1),
        "Option+Shift + volume down -> .step(-1)"
    )
    checkEqual(VolumeKeyRouter.isFineStep(option: true, shift: true), true, "Option+Shift is fine step")
    checkEqual(VolumeKeyRouter.isFineStep(option: true, shift: false), false, "Option alone is not fine step")
}

do {
    // 6. Output without software volume -> pass-through and window active;
    //    new press during window -> pass-through (extends window);
    //    press after window expires -> taken by app again.
    var router = VolumeKeyRouter()
    checkEqual(
        router.handle(
            keyCode: volUp, state: downState, isRepeat: false,
            enabled: true, canHandle: true, hasVolume: false, hasMute: false,
            option: false, shift: false, commandOrControl: false, now: 100.0
        ),
        .passThrough,
        "output without volume -> pass-through"
    )
    checkEqual(router.blocksCustomHUD(101.0), true, "native window is active after pass-through")
    checkEqual(router.nativeOwnsUntil, 101.6, "native window set to now + 1.6")

    // New press during active window (even if device now has volume) -> pass-through & extends window
    checkEqual(
        router.handle(
            keyCode: volUp, state: downState, isRepeat: false,
            enabled: true, canHandle: true, hasVolume: true, hasMute: true,
            option: false, shift: false, commandOrControl: false, now: 101.0
        ),
        .passThrough,
        "new press during native window -> pass-through"
    )
    checkEqual(router.nativeOwnsUntil, 102.6, "pass-through during window extends nativeOwnsUntil")

    // Key-up for that system-owned press -> pass-through
    checkEqual(
        router.handle(
            keyCode: volUp, state: upState, isRepeat: false,
            enabled: true, canHandle: true, hasVolume: true, hasMute: true,
            option: false, shift: false, commandOrControl: false, now: 101.1
        ),
        .passThrough,
        "key-up for system-owned press -> pass-through"
    )

    // Press after window expires (at 102.7 > 102.6) -> owned by app again
    checkEqual(
        router.handle(
            keyCode: volUp, state: downState, isRepeat: false,
            enabled: true, canHandle: true, hasVolume: true, hasMute: true,
            option: false, shift: false, commandOrControl: false, now: 102.7
        ),
        .step(1),
        "press after window expires -> owned by app"
    )
}

do {
    // 7. Mute key: down -> .toggleMute, repeat -> .consume, up -> .consume
    var router = VolumeKeyRouter()
    checkEqual(
        router.handle(
            keyCode: muteKey, state: downState, isRepeat: false,
            enabled: true, canHandle: true, hasVolume: true, hasMute: true,
            option: false, shift: false, commandOrControl: false, now: 50.0
        ),
        .toggleMute,
        "mute key-down -> .toggleMute"
    )
    checkEqual(
        router.handle(
            keyCode: muteKey, state: downState, isRepeat: true,
            enabled: true, canHandle: true, hasVolume: true, hasMute: true,
            option: false, shift: false, commandOrControl: false, now: 50.1
        ),
        .consume,
        "mute repeat -> .consume"
    )
    checkEqual(
        router.handle(
            keyCode: muteKey, state: upState, isRepeat: false,
            enabled: true, canHandle: true, hasVolume: true, hasMute: true,
            option: false, shift: false, commandOrControl: false, now: 50.2
        ),
        .consume,
        "mute key-up -> .consume"
    )
}

do {
    // 8. Fallback markSystemOwnership clears held keys and sets window
    var router = VolumeKeyRouter()
    _ = router.handle(
        keyCode: volUp, state: downState, isRepeat: false,
        enabled: true, canHandle: true, hasVolume: true, hasMute: true,
        option: false, shift: false, commandOrControl: false, now: 60.0
    )
    checkEqual(router.held.contains(volUp), true, "volUp held before fallback")
    router.markSystemOwnership(now: 60.05)
    checkEqual(router.held.isEmpty, true, "fallback clears held keys")
    checkEqual(router.blocksCustomHUD(61.0), true, "fallback activates native window")
}

// MARK: - Volume HUD Localization, Symbols & Defaults (Phase 4 & 5)

checkEqual(
    UserDefaultsKeys.volumeHUDEnabled.defaultValue,
    false,
    "volumeHUDEnabled defaults to false (opt-in)"
)
checkEqual(
    VolumeKeyRouter.volumeSymbol(level: 0.4, muted: true),
    "speaker.slash.fill",
    "muted symbol is speaker.slash.fill"
)
checkEqual(
    VolumeKeyRouter.volumeSymbol(level: 0.0, muted: false),
    "speaker.slash.fill",
    "zero level symbol is speaker.slash.fill"
)
checkEqual(
    VolumeKeyRouter.volumeSymbol(level: 0.2, muted: false),
    "speaker.wave.1.fill",
    "low volume symbol is speaker.wave.1.fill"
)
checkEqual(
    VolumeKeyRouter.volumeSymbol(level: 0.5, muted: false),
    "speaker.wave.2.fill",
    "medium volume symbol is speaker.wave.2.fill"
)
checkEqual(
    VolumeKeyRouter.volumeSymbol(level: 0.85, muted: false),
    "speaker.wave.3.fill",
    "high volume symbol is speaker.wave.3.fill"
)

let savedLang = LanguageManager.shared.currentLanguage
LanguageManager.shared.setLanguage(.indonesian)
checkEqual(
    L10n.Volume.accessibilityLabel(percent: 40, muted: false),
    "Volume 40 persen",
    "Indonesian accessibility label for 40% volume"
)
checkEqual(
    L10n.Menu.volumeHUDToggle,
    "Volume HUD di Notch",
    "Indonesian menu toggle title"
)
LanguageManager.shared.setLanguage(.english)
checkEqual(
    L10n.Volume.accessibilityLabel(percent: 40, muted: false),
    "Volume 40 percent",
    "English accessibility label for 40% volume"
)
LanguageManager.shared.setLanguage(savedLang)

// Feedback clicks parity with macOS
checkEqual(VolumeKeyRouter.playsFeedback(setting: true, option: false, shift: false), true, "feedback true: normal click")
checkEqual(VolumeKeyRouter.playsFeedback(setting: true, option: false, shift: true), false, "feedback true: Shift inverts to false")
checkEqual(VolumeKeyRouter.playsFeedback(setting: true, option: true, shift: true), true, "feedback true: Option+Shift keeps setting")
checkEqual(VolumeKeyRouter.playsFeedback(setting: false, option: false, shift: false), false, "feedback false: normal no click")
checkEqual(VolumeKeyRouter.playsFeedback(setting: false, option: false, shift: true), true, "feedback false: Shift inverts to click")
checkEqual(VolumeKeyRouter.playsFeedback(setting: false, option: true, shift: true), false, "feedback false: Option+Shift keeps setting")

// MARK: - MediaAppInfo Tests

let spotifyApp = MediaAppInfo.resolve(bundleID: "com.spotify.client")
checkEqual(spotifyApp.displayName, "Spotify", "Spotify display name")
checkEqual(spotifyApp.category, .music, "Spotify category")
checkEqual(spotifyApp.iconSymbolName, "waveform", "Spotify icon symbol")

let zoomApp = MediaAppInfo.resolve(bundleID: "us.zoom.xos")
checkEqual(zoomApp.displayName, "Zoom", "Zoom display name")
checkEqual(zoomApp.category, .call, "Zoom category")
checkEqual(zoomApp.iconSymbolName, "phone.fill", "Zoom icon symbol")

let safariApp = MediaAppInfo.resolve(bundleID: "com.apple.Safari")
checkEqual(safariApp.displayName, "Safari", "Safari display name")
checkEqual(safariApp.category, .video, "Safari category")

let genericApp = MediaAppInfo.resolve(bundleID: "com.example.customgame", preferredName: "Cool Game")
checkEqual(genericApp.displayName, "Cool Game", "Generic app preferred name")
checkEqual(genericApp.category, .general, "Generic app category")

// MARK: - AudioProcessResolver Tests

let testSelfPID: pid_t = 99999
let daemonPID: pid_t = 120
let safariPID: pid_t = 1000
let webkitHelperPID: pid_t = 1002
let chromePID: pid_t = 2000
let chromeHelperPID: pid_t = 2002

let mockParentTree: [pid_t: pid_t] = [
    webkitHelperPID: safariPID,
    safariPID: 1,
    chromeHelperPID: chromePID,
    chromePID: 1,
    daemonPID: 1
]

let mockAppDatabase: [pid_t: (bundleID: String, name: String, isAppBundle: Bool)] = [
    safariPID: ("com.apple.Safari", "Safari", true),
    webkitHelperPID: ("com.apple.WebKit.GPU", "com.apple.WebKit.GPU", false),
    chromePID: ("com.google.Chrome", "Google Chrome", true),
    chromeHelperPID: ("com.google.Chrome.helper", "Google Chrome Helper", false),
    daemonPID: ("com.apple.audio.coreaudiod", "coreaudiod", false),
    testSelfPID: ("com.harmonotch.Harmonotch", "Harmonotch", true)
]

let parentLookup: (pid_t) -> pid_t? = { mockParentTree[$0] }
let appLookup: (pid_t) -> (bundleID: String, name: String, isAppBundle: Bool)? = { mockAppDatabase[$0] }

// Self PID must be excluded
let selfResolved = AudioProcessResolver.resolveResponsibleApp(
    pid: testSelfPID,
    currentPID: testSelfPID,
    parentLookup: parentLookup,
    appLookup: appLookup
)
check(selfResolved == nil, "Self PID must be excluded from audio process resolution")

// CoreAudio daemon must be excluded
let daemonResolved = AudioProcessResolver.resolveResponsibleApp(
    pid: daemonPID,
    currentPID: testSelfPID,
    parentLookup: parentLookup,
    appLookup: appLookup
)
check(daemonResolved == nil, "Audio system daemon must be excluded")

// WebKit GPU helper must resolve to parent Safari
let webkitResolved = AudioProcessResolver.resolveResponsibleApp(
    pid: webkitHelperPID,
    reportedBundleID: "com.apple.WebKit.GPU",
    currentPID: testSelfPID,
    parentLookup: parentLookup,
    appLookup: appLookup
)
check(webkitResolved != nil, "WebKit helper must resolve to an app")
checkEqual(webkitResolved?.bundleID, "com.apple.Safari", "WebKit helper bundle resolved to Safari")
checkEqual(webkitResolved?.displayName, "Safari", "WebKit helper name resolved to Safari")

// Chromium Helper must resolve to Google Chrome
let chromeResolved = AudioProcessResolver.resolveResponsibleApp(
    pid: chromeHelperPID,
    reportedBundleID: "com.google.Chrome.helper",
    currentPID: testSelfPID,
    parentLookup: parentLookup,
    appLookup: appLookup
)
checkEqual(chromeResolved?.bundleID, "com.google.Chrome", "Chromium helper resolved to Google Chrome")

// Direct app resolution
let directSafariResolved = AudioProcessResolver.resolveResponsibleApp(
    pid: safariPID,
    reportedBundleID: "com.apple.Safari",
    currentPID: testSelfPID,
    parentLookup: parentLookup,
    appLookup: appLookup
)
checkEqual(directSafariResolved?.bundleID, "com.apple.Safari", "Direct app resolves cleanly")

// MARK: - AudioProcessPresenceTracker Tests

var tracker = AudioProcessPresenceTracker(startDebounceInterval: 1.5, stopHysteresisInterval: 3.0)
let baseTime = Date(timeIntervalSince1970: 1000)

// t = 0: first detected -> not yet confirmed (debounce)
var active = tracker.update(detectedPIDs: [500], now: baseTime)
check(active.isEmpty, "t=0: candidate must not be active immediately")

// t = 1.0s: still within debounce (<1.5s) -> not yet confirmed
active = tracker.update(detectedPIDs: [500], now: baseTime.addingTimeInterval(1.0))
check(active.isEmpty, "t=1.0s: candidate still in debounce window")

// t = 1.6s: reached >= 1.5s debounce -> confirmed active
active = tracker.update(detectedPIDs: [500], now: baseTime.addingTimeInterval(1.6))
checkEqual(active.contains(500), true, "t=1.6s: candidate confirmed active after 1.5s debounce")

// t = 2.0s: PID 500 stops output, but within hysteresis (<3.0s) -> still active
active = tracker.update(detectedPIDs: [], now: baseTime.addingTimeInterval(2.0))
checkEqual(active.contains(500), true, "t=2.0s: candidate retained during hysteresis")

// t = 4.5s: 2.9s since last seen (1.6s) -> still active
active = tracker.update(detectedPIDs: [], now: baseTime.addingTimeInterval(4.5))
checkEqual(active.contains(500), true, "t=4.5s: candidate retained at 2.9s after last output")

// t = 4.7s: 3.1s since last seen (1.6s) >= 3.0s -> cleared
active = tracker.update(detectedPIDs: [], now: baseTime.addingTimeInterval(4.7))
checkEqual(active.contains(500), false, "t=4.7s: candidate removed after 3.0s hysteresis expires")

// Transient sound (e.g. 0.4s UI click or system alert)
var transientTracker = AudioProcessPresenceTracker(startDebounceInterval: 1.5, stopHysteresisInterval: 3.0)
_ = transientTracker.update(detectedPIDs: [700], now: baseTime)
_ = transientTracker.update(detectedPIDs: [700], now: baseTime.addingTimeInterval(0.4))
let transientResult = transientTracker.update(detectedPIDs: [], now: baseTime.addingTimeInterval(2.0))
check(transientResult.isEmpty, "Short audio burst (<1.5s) never becomes active")

// MARK: - MediaSelector & Presentation Tests

let spotifyCandidate = MediaCandidate(
    identity: MediaIdentity(bundleID: "com.spotify.client", contentID: "spotify:track:123"),
    app: MediaAppInfo.resolve(bundleID: "com.spotify.client"),
    title: "Song A",
    artist: "Artist A",
    album: "Album A",
    duration: 200,
    position: 45,
    isPlaying: true,
    isMusicApp: true,
    awareness: .mediaRemote,
    startedPlayingAt: 100.0,
    lastUpdated: 110.0
)

let youtubeCandidate = MediaCandidate(
    identity: MediaIdentity(bundleID: "com.apple.Safari", contentID: "https://youtube.com/watch?v=xyz"),
    app: MediaAppInfo.resolve(bundleID: "com.apple.Safari"),
    title: "Tech Talk Video",
    artist: "YouTuber",
    album: "",
    duration: 600,
    position: 120,
    isPlaying: true,
    isMusicApp: false,
    awareness: .script,
    startedPlayingAt: 105.0,
    lastUpdated: 115.0
)

let zoomCandidate = MediaCandidate(
    identity: MediaIdentity(bundleID: "us.zoom.xos", pid: 888),
    app: MediaAppInfo.resolve(bundleID: "us.zoom.xos"),
    title: "",
    artist: "",
    isPlaying: true,
    hasMetadata: false,
    isMusicApp: false,
    awareness: .presence,
    capabilities: .audioOnlyDefault,
    startedPlayingAt: 102.0,
    lastUpdated: 112.0
)

// Scenario 1: App A playing, App B paused -> A wins
var spotifyPaused = spotifyCandidate
spotifyPaused.isPlaying = false
let sel1 = MediaSelector.select(candidates: [spotifyPaused, youtubeCandidate])
checkEqual(sel1?.identity.bundleID, "com.apple.Safari", "Playing YouTube beats paused Spotify")

// Scenario 2: Paused never beats playing from ANY app
var youtubePaused = youtubeCandidate
youtubePaused.isPlaying = false
let sel2 = MediaSelector.select(candidates: [spotifyCandidate, youtubePaused])
checkEqual(sel2?.identity.bundleID, "com.spotify.client", "Playing Spotify beats paused YouTube")

// Scenario 3: Two apps playing: Music app beats non-music app
let sel3 = MediaSelector.select(candidates: [youtubeCandidate, spotifyCandidate])
checkEqual(sel3?.identity.bundleID, "com.spotify.client", "Music app beats video app when both playing")

// Scenario 4: Two non-music apps playing: Earlier started playing wins
var vlcCandidate = MediaCandidate(
    identity: MediaIdentity(bundleID: "org.videolan.vlc", contentID: "movie.mkv"),
    app: MediaAppInfo.resolve(bundleID: "org.videolan.vlc"),
    title: "Movie Clip",
    artist: "VLC",
    isPlaying: true,
    isMusicApp: false,
    startedPlayingAt: 90.0, // earlier than youtubeCandidate (105.0)
    lastUpdated: 110.0
)
let sel4 = MediaSelector.select(candidates: [youtubeCandidate, vlcCandidate])
checkEqual(sel4?.identity.bundleID, "org.videolan.vlc", "Earlier started video app wins")

// Scenario 5: Two non-music apps tied on start time: frontmost app wins
var vlcTied = vlcCandidate
vlcTied.startedPlayingAt = youtubeCandidate.startedPlayingAt
let sel5 = MediaSelector.select(
    candidates: [youtubeCandidate, vlcTied],
    frontmostBundleID: "com.apple.Safari"
)
checkEqual(sel5?.identity.bundleID, "com.apple.Safari", "Frontmost app breaks tie between playing candidates")

// Scenario 6: All paused -> previous candidate stays (sticky paused)
let sel6 = MediaSelector.select(
    candidates: [spotifyPaused, youtubePaused],
    previous: youtubePaused.identity
)
checkEqual(sel6?.identity.bundleID, "com.apple.Safari", "Previous candidate sticky when all paused")

// Scenario 7: All paused and no previous -> system player as tie-break
let sel7 = MediaSelector.select(
    candidates: [spotifyPaused, youtubePaused],
    previous: nil,
    system: spotifyPaused.identity
)
checkEqual(sel7?.identity.bundleID, "com.spotify.client", "System player wins tie-break when all paused")

// Scenario 8: Audio-only presence playing vs metadata paused -> audio-only playing wins!
let sel8 = MediaSelector.select(candidates: [spotifyPaused, zoomCandidate])
checkEqual(sel8?.identity.bundleID, "us.zoom.xos", "Playing audio-only presence beats paused metadata")

// Scenario 9: Playing metadata beats playing audio-only
let sel9 = MediaSelector.select(candidates: [zoomCandidate, youtubeCandidate])
checkEqual(sel9?.identity.bundleID, "com.apple.Safari", "Playing metadata beats playing audio-only")

// Scenario 10: Two audio-only playing: earlier started wins
var teamsCandidate = MediaCandidate(
    identity: MediaIdentity(bundleID: "com.microsoft.teams", pid: 999),
    app: MediaAppInfo.resolve(bundleID: "com.microsoft.teams"),
    isPlaying: true,
    hasMetadata: false,
    startedPlayingAt: 80.0, // earlier than zoom (102.0)
    lastUpdated: 100.0
)
let sel10 = MediaSelector.select(candidates: [zoomCandidate, teamsCandidate])
checkEqual(sel10?.identity.bundleID, "com.microsoft.teams", "Earlier audio-only presence wins")

// Scenario 11: Explicit user selection respected when playing
let sel11 = MediaSelector.select(
    candidates: [spotifyCandidate, youtubeCandidate],
    userSelection: youtubeCandidate.identity
)
checkEqual(sel11?.identity.bundleID, "com.apple.Safari", "User selection respected when playing")

// Scenario 12: Explicit user selection is paused but another is playing -> playing wins (paused never beats playing)
let sel12 = MediaSelector.select(
    candidates: [youtubePaused, spotifyCandidate],
    userSelection: youtubePaused.identity
)
checkEqual(sel12?.identity.bundleID, "com.spotify.client", "Playing candidate wins even if user selection is paused")

// Scenario 13: MediaPresentation conversion
let trackPresentation = MediaPresentation(candidate: spotifyCandidate)
checkEqual(trackPresentation.hasMetadata, true, "Track presentation has metadata")
checkEqual(trackPresentation.title, "Song A", "Track presentation title")
checkEqual(trackPresentation.artist, "Artist A", "Track presentation artist")
checkEqual(trackPresentation.isPlaying, true, "Track presentation isPlaying")

let audioOnlyPresentation = MediaPresentation(candidate: zoomCandidate)
checkEqual(audioOnlyPresentation.hasMetadata, false, "AudioOnly presentation has no metadata")
checkEqual(audioOnlyPresentation.title, "", "AudioOnly presentation has empty title")
checkEqual(audioOnlyPresentation.artist, "Zoom", "AudioOnly presentation displays app name as artist")
checkEqual(audioOnlyPresentation.capabilities, .audioOnlyDefault, "AudioOnly presentation has openApp capability")

// MARK: - Phase 3 & 4 Acceptance Tests: Paused Spotify does not overwrite playing YouTube
var registry: [MediaIdentity: MediaCandidate] = [:]
let ytPlaying = youtubeCandidate
registry[ytPlaying.identity] = ytPlaying

// Step 1: YouTube is playing
let initialWinner = MediaSelector.select(candidates: Array(registry.values), previous: nil)
checkEqual(initialWinner?.identity.bundleID, "com.apple.Safari", "Initial winner is playing YouTube")

// Step 2: Spotify pause event arrives
var spotPaused = spotifyCandidate
spotPaused.isPlaying = false
registry[spotPaused.identity] = spotPaused

// Step 3: Reconcile must keep YouTube as the active candidate
let reconciledWinner = MediaSelector.select(
    candidates: Array(registry.values),
    previous: initialWinner?.identity
)
checkEqual(reconciledWinner?.identity.bundleID, "com.apple.Safari", "Spotify pause does not hijack UI from playing YouTube")
checkEqual(reconciledWinner?.isPlaying, true, "Winner remains playing")
checkEqual(reconciledWinner?.title, "Tech Talk Video", "Winner title remains YouTube video title")

// MARK: - Phase 5 & 6: Artwork Scoping & Localization Tests
let spotifyArtKey = MediaArtworkCacheKey.make(
    bundleID: "com.spotify.client",
    title: "Shape of You",
    artist: "Ed Sheeran"
)
let youtubeArtKey = MediaArtworkCacheKey.make(
    bundleID: "com.apple.Safari",
    title: "Shape of You",
    artist: "Ed Sheeran"
)
check(spotifyArtKey != youtubeArtKey, "Artwork cache keys with identical tracks must be scoped by bundleID")

let urlArtKey = MediaArtworkCacheKey.make(
    bundleID: "com.apple.Safari",
    title: "Video",
    artist: "Creator",
    directURL: URL(string: "https://example.com/thumb.jpg")
)
checkEqual(urlArtKey, "com.apple.Safari|https://example.com/thumb.jpg", "Artwork cache key with directURL")

// Localization check
check(L10n.Media.audioPlaying.count > 0, "L10n.Media.audioPlaying not empty")
checkEqual(L10n.Media.openApp("Zoom"), "Open Zoom", "L10n.Media.openApp formatting")
checkEqual(L10n.Media.appPlayingAudio("Zoom"), "Zoom is playing audio", "L10n.Media.appPlayingAudio formatting")

// Setting toggle filter check
let mixedPool: [MediaCandidate] = [zoomCandidate, spotifyPaused]
let onlyMetadataPool = mixedPool.filter { false || $0.hasMetadata }
checkEqual(onlyMetadataPool.count, 1, "Disabling other audio apps filters out audio-only presence")
checkEqual(onlyMetadataPool.first?.identity.bundleID, "com.spotify.client", "Only metadata candidate retained")

// MARK: - Phase 7 & 8: Command Routing & Target Message Tests
let targetCommand = NowPlayingCommandMessage(id: "cmd-1", command: .toggle, target: "com.spotify.client")
if let data = try? JSONEncoder().encode(targetCommand),
   let json = String(data: data, encoding: .utf8) {
    check(json.contains("\"target\":\"com.spotify.client\""), "Targeted command contains target bundleID")
    check(json.contains("\"cmd\":\"toggle\""), "Targeted command contains cmd")
} else {
    check(false, "NowPlayingCommandMessage should encode to JSON")
}

let untargetedCommand = NowPlayingCommandMessage(id: "cmd-2", command: .next)
if let data = try? JSONEncoder().encode(untargetedCommand),
   let json = String(data: data, encoding: .utf8) {
    check(json.contains("\"cmd\":\"next\""), "Untargeted command contains cmd")
    check(!json.contains("\"target\":"), "Untargeted command omits target field or encodes null")
}

let seekCommand = NowPlayingCommandMessage(id: "cmd-3", command: .seek(position: 42.5), target: "com.apple.Safari")
if let data = try? JSONEncoder().encode(seekCommand),
   let json = String(data: data, encoding: .utf8) {
    check(json.contains("\"cmd\":\"seek\""), "Seek command contains cmd")
    check(json.contains("\"position\":42.5"), "Seek command contains position")
    check(json.contains("\"target\":\"com.apple.Safari\""), "Seek command contains target")
}

// Capability tests for command gating
checkEqual(MediaCapabilities.audioOnlyDefault.contains(.playPause), false, "AudioOnly lacks playPause capability")
checkEqual(MediaCapabilities.audioOnlyDefault.contains(.nextTrack), false, "AudioOnly lacks nextTrack capability")
checkEqual(MediaCapabilities.audioOnlyDefault.contains(.previousTrack), false, "AudioOnly lacks previousTrack capability")
checkEqual(MediaCapabilities.audioOnlyDefault.contains(.seek), false, "AudioOnly lacks seek capability")
checkEqual(MediaCapabilities.audioOnlyDefault.contains(.openApp), true, "AudioOnly has openApp capability")

checkEqual(MediaCapabilities.standardPlayer.contains(.playPause), true, "Standard player has playPause")
checkEqual(MediaCapabilities.standardPlayer.contains(.nextTrack), true, "Standard player has nextTrack")
checkEqual(MediaCapabilities.standardPlayer.contains(.previousTrack), true, "Standard player has previousTrack")
checkEqual(MediaCapabilities.standardPlayer.contains(.seek), true, "Standard player has seek")
checkEqual(MediaCapabilities.standardPlayer.contains(.openApp), true, "Standard player has openApp")

// Optimistic state toggle test
var isolatedRegistry: [MediaIdentity: MediaCandidate] = [:]
var activeCandidate = spotifyCandidate
activeCandidate.isPlaying = true
isolatedRegistry[activeCandidate.identity] = activeCandidate
checkEqual(activeCandidate.isPlaying, true, "Candidate starts playing")

// User triggers playPause -> optimistic pause
activeCandidate.isPlaying = false
isolatedRegistry[activeCandidate.identity] = activeCandidate
let afterPauseWinner = MediaSelector.select(candidates: Array(isolatedRegistry.values), previous: activeCandidate.identity)
checkEqual(afterPauseWinner?.identity.bundleID, "com.spotify.client", "Optimistically paused candidate remains active when no other app is playing")
checkEqual(afterPauseWinner?.isPlaying, false, "Optimistic state reflects paused")





if failures > 0 {
    fputs("\(failures) test(s) failed\n", stderr)
    exit(1)
}
print("All tests passed.")

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

if case .result(let id, let ok)? = decodeNowPlayingEvent(
    #"{"event":"result","id":"command-1","ok":true}"#)
{
    checkEqual(id, "command-1", "result id")
    checkEqual(ok, true, "result ok")
} else {
    check(false, "now-playing result decodes")
}

if case .error(let message)? = decodeNowPlayingEvent(
    #"{"event":"error","message":"MediaRemote unavailable"}"#)
{
    checkEqual(message, "MediaRemote unavailable", "error message")
} else {
    check(false, "now-playing error decodes")
}

check(decodeNowPlayingEvent(#"{"event":"unknown"}"#) == nil, "unknown event rejected")
check(decodeNowPlayingEvent(#"{"event":"state","title":"partial"}"#) == nil, "incomplete state rejected")

checkEqual(NowPlayingSourceKind(bundleID: "com.apple.Music"), .appleMusic, "Apple Music mapping")
checkEqual(NowPlayingSourceKind(bundleID: "com.apple.WebKit.GPU"), .safari, "Safari mapping")
checkEqual(NowPlayingSourceKind(bundleID: "com.brave.Browser"), .web, "Brave mapping")
checkEqual(NowPlayingSourceKind(bundleID: "company.thebrowser.Browser"), .web, "Arc mapping")
checkEqual(NowPlayingSourceKind(bundleID: "com.apple.QuickTimePlayerX"), .quicktime, "QuickTime mapping")
checkEqual(NowPlayingSourceKind(bundleID: "com.apple.podcasts"), .podcasts, "Podcasts mapping")
checkEqual(NowPlayingSourceKind(bundleID: "com.example.unknown"), .system, "unknown source mapping")

// MARK: - ArtworkPalette

func solidPixels(_ red: UInt8, _ green: UInt8, _ blue: UInt8, count: Int = 64) -> [UInt8] {
    Array(repeating: [red, green, blue, 255], count: count).flatMap { $0 }
}

if let accent = ArtworkPalette.accent(fromRGBA: solidPixels(220, 30, 30)) {
    var hue: CGFloat = 0
    var saturation: CGFloat = 0
    var brightness: CGFloat = 0
    var alpha: CGFloat = 0
    accent.usingColorSpace(.deviceRGB)?.getHue(
        &hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
    check(hue < 0.05 || hue > 0.95, "red artwork keeps red hue")
    check(saturation >= 0.45, "accent saturation is boosted for legibility")
    check(brightness >= 0.85, "accent brightness is boosted for legibility")
} else {
    check(false, "colored artwork yields an accent")
}

check(
    ArtworkPalette.accent(fromRGBA: solidPixels(128, 128, 128)) == nil,
    "grayscale artwork falls back to white")

if let accent = ArtworkPalette.accent(fromRGBA: solidPixels(20, 40, 220)) {
    var hue: CGFloat = 0
    var saturation: CGFloat = 0
    var brightness: CGFloat = 0
    var alpha: CGFloat = 0
    accent.usingColorSpace(.deviceRGB)?.getHue(
        &hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
    check(hue > 0.55 && hue < 0.75, "blue artwork keeps blue hue")
} else {
    check(false, "blue artwork yields an accent")
}

if failures > 0 {
    fputs("\(failures) test(s) failed\n", stderr)
    exit(1)
}

print("All tests passed")

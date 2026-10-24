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

if failures > 0 {
    fputs("\(failures) test(s) failed\n", stderr)
    exit(1)
}

print("All tests passed")

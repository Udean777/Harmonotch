import Foundation

func runPrayerTests() {
  // MARK: - Prayer times

  let jakarta = Coordinates(latitude: -6.2088, longitude: 106.8456)
  var params = CalculationMethod.singapore.params
  params.methodAdjustments = PrayerAdjustments(
    fajr: 2, sunrise: -2, dhuhr: 2, asr: 2, maghrib: 2, isha: 2)

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

  // MARK: - Compass

  checkEqual(Compass.cardinal(for: 0, isEnglish: true), "N", "compass north")
  checkEqual(Compass.cardinal(for: 90, isEnglish: true), "E", "compass east")
  checkEqual(Compass.cardinal(for: 180, isEnglish: false), "S", "compass south (id)")
  checkEqual(Compass.cardinal(for: 270, isEnglish: true), "W", "compass west")
  checkEqual(Compass.cardinal(for: -90, isEnglish: true), "W", "negative heading wraps")
  checkEqual(Compass.cardinal(for: 360, isEnglish: true), "N", "full turn")
}

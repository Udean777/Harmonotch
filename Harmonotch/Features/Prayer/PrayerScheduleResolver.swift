import Foundation

struct PrayerMoment: Equatable {
  let id: String
  let date: Date
}

struct PrayerPosition: Equatable {
  let current: PrayerMoment?
  let next: PrayerMoment?
}

enum PrayerScheduleResolver {
  /// Finds the current and next obligatory prayer for `now`.
  ///
  /// `today` must be sorted ascending and exclude sunrise. Before Fajr the current
  /// prayer is yesterday's Isha; after Isha the next prayer is tomorrow's Fajr.
  /// Nothing is invented: a missing input yields `nil`.
  static func position(
    now: Date,
    yesterdayIsha: PrayerMoment?,
    today: [PrayerMoment],
    tomorrowFajr: PrayerMoment?
  ) -> PrayerPosition {
    if let index = today.firstIndex(where: { now < $0.date }) {
      return PrayerPosition(
        current: index > 0 ? today[index - 1] : yesterdayIsha,
        next: today[index]
      )
    }
    return PrayerPosition(current: today.last, next: tomorrowFajr)
  }
}

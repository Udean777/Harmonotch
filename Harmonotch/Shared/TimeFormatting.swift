import Foundation

enum TimeFormatting {
  static func clock(_ seconds: TimeInterval, includeHours: Bool = true) -> String {
    let total = max(0, Int(seconds))
    if includeHours {
      let hours = total / 3600
      let mins = (total % 3600) / 60
      let secs = total % 60
      if hours > 0 {
        return String(format: "%d:%02d:%02d", hours, mins, secs)
      }
      return String(format: "%d:%02d", mins, secs)
    } else {
      let mins = total / 60
      let secs = total % 60
      return String(format: "%d:%02d", mins, secs)
    }
  }

  static func countdownText(to target: Date, now: Date) -> String {
    let remainingMinutes = Int(ceil(max(0, target.timeIntervalSince(now)) / 60))
    return L10n.Dashboard.countdown(
      hours: remainingMinutes / 60,
      minutes: remainingMinutes % 60
    )
  }
}

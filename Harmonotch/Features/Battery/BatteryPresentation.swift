import SwiftUI

enum BatteryPresentation {
  /// Only `battery.100.bolt` exists in SF Symbols; lower bolt variants are not available.
  static func iconName(capacity: Int, isCharging: Bool) -> String {
    if isCharging && capacity >= 90 { return "battery.100.bolt" }
    if capacity >= 60 { return "battery.75" }
    if capacity >= 35 { return "battery.50" }
    if capacity >= 10 { return "battery.25" }
    return "battery.0"
  }

  static func progressColor(capacity: Int, isCharging: Bool) -> Color {
    if isCharging || capacity >= 35 { return AppTheme.accentGreen }
    if capacity >= 15 { return AppTheme.accentAmber }
    return AppTheme.accentRed
  }

  static func healthColor(percent: Int?) -> Color {
    guard let percent else { return AppTheme.textTertiary }
    if percent >= 80 { return AppTheme.accentGreen }
    if percent >= 50 { return AppTheme.accentAmber }
    return AppTheme.accentRed
  }
}

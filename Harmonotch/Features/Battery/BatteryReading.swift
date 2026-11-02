import Foundation

/// Pure value describing one successful battery read. Fields that the hardware
/// does not report stay `nil` instead of being replaced by invented numbers.
struct BatteryReading: Equatable {
  enum PowerSource: Equatable {
    case battery
    case ac
    case unknown
  }

  enum TimeEstimate: Equatable {
    case toEmpty(minutes: Int)
    case toFull(minutes: Int)
    case fullyCharged
    case pluggedIn
    case onBattery
  }

  /// A reading older than this is considered stale by the UI.
  static let staleAfter: TimeInterval = 120
  /// Plugged-in, not charging, and at or above this percentage counts as fully charged.
  static let fullChargeThreshold = 95

  var capacity: Int
  var isCharging: Bool
  var powerSource: PowerSource
  var timeEstimate: TimeEstimate
  var adapterWatts: Int?
  var healthPercent: Int?
  var cycleCount: Int?
  var designCycleCount: Int?
  var nominalCapacity: Int?
  var designCapacity: Int?
  var voltageVolts: Double?
  var amperageAmps: Double?
  var temperatureCelsius: Double?
  var refreshedAt: Date

  var isPluggedIn: Bool { powerSource == .ac }

  /// Instantaneous power in watts, only when both voltage and current were reported.
  /// Negative values mean the battery is discharging.
  var powerWatts: Double? {
    guard let voltageVolts, let amperageAmps else { return nil }
    return voltageVolts * amperageAmps
  }

  func isStale(now: Date = Date()) -> Bool {
    Self.isStale(refreshedAt: refreshedAt, now: now)
  }

  static func isStale(refreshedAt: Date, now: Date, threshold: TimeInterval = staleAfter) -> Bool {
    now.timeIntervalSince(refreshedAt) > threshold
  }

  /// Battery health as nominal/design capacity, clamped to 0...100.
  /// Returns `nil` unless both capacities are positive.
  static func healthPercent(nominal: Int?, design: Int?) -> Int? {
    guard let nominal, let design, nominal > 0, design > 0 else { return nil }
    let value = Int((Double(nominal) / Double(design) * 100).rounded())
    return min(100, max(0, value))
  }

  static func timeEstimate(
    capacity: Int,
    isCharging: Bool,
    isPluggedIn: Bool,
    timeToEmptyMinutes: Int?,
    timeToFullMinutes: Int?
  ) -> TimeEstimate {
    if !isPluggedIn, let minutes = timeToEmptyMinutes, minutes > 0 {
      return .toEmpty(minutes: minutes)
    }
    if isCharging, let minutes = timeToFullMinutes, minutes > 0 {
      return .toFull(minutes: minutes)
    }
    if isPluggedIn && !isCharging && capacity >= fullChargeThreshold {
      return .fullyCharged
    }
    return isPluggedIn ? .pluggedIn : .onBattery
  }

  /// `Amperage` is a signed value that IOKit may hand back as an unsigned 64-bit
  /// number; reinterpreting through `Int64` restores the sign.
  static func signedMilliamps(_ raw: UInt64) -> Int64 {
    Int64(bitPattern: raw)
  }
}

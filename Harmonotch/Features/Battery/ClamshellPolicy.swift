import Foundation

enum ClamshellState: Equatable {
    case off
    case active
    case standby
    case pausedLowBattery
}

enum ClamshellPolicy {
    /// Armed + external display + (charging or above 50%) keeps the Mac awake.
    /// Everything else falls back to a safe state so an unplugged laptop can sleep.
    static func state(
        isArmed: Bool,
        hasExternalDisplay: Bool,
        isPluggedIn: Bool,
        batteryCapacity: Int
    ) -> ClamshellState {
        guard isArmed else { return .off }
        guard hasExternalDisplay else { return .standby }
        if isPluggedIn { return .active }
        return batteryCapacity <= 50 ? .pausedLowBattery : .active
    }
}

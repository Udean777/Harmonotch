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

    /// Parses the output of `pmset -g` to determine whether `SleepDisabled` is `1` (true) or `0` (false).
    /// Returns `nil` if `SleepDisabled` is not present or cannot be parsed.
    static func parseSleepDisabled(_ pmsetOutput: String) -> Bool? {
        guard let regex = try? NSRegularExpression(pattern: #"(?m)^\s*SleepDisabled\s+([01])\b"#) else {
            return nil
        }
        let range = NSRange(pmsetOutput.startIndex..<pmsetOutput.endIndex, in: pmsetOutput)
        guard let match = regex.firstMatch(in: pmsetOutput, options: [], range: range),
              let valueRange = Range(match.range(at: 1), in: pmsetOutput)
        else {
            return nil
        }
        let token = pmsetOutput[valueRange]
        if token == "1" { return true }
        if token == "0" { return false }
        return nil
    }
}

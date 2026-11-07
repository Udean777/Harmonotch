import Foundation

enum ChargeLimitPolicy {
    static let defaultThreshold = 80
    static let minThreshold = 50
    static let maxThreshold = 100
    static let hysteresisMargin = 2

    /// Available preset limit thresholds for the UI: 80% to 100% (Full)
    static let availableThresholds = [80, 85, 90, 95, 100]

    /// True if the threshold represents an active charge limit (< 100%).
    /// 100% means unrestricted charging.
    static func isLimitActive(threshold: Int) -> Bool {
        threshold < maxThreshold
    }

    /// Determines whether battery charging should be inhibited (stopped/bypassed to AC).
    /// Uses hysteresis so charging doesn't rapidly toggle on and off when battery hovers
    /// right at the boundary.
    static func shouldInhibit(
        capacity: Int,
        isPluggedIn: Bool,
        isEnabled: Bool,
        targetThreshold: Int,
        currentlyInhibited: Bool
    ) -> Bool {
        guard isEnabled && isPluggedIn else {
            return false
        }

        let clampedTarget = min(maxThreshold, max(minThreshold, targetThreshold))
        if clampedTarget >= maxThreshold {
            return false
        }

        if currentlyInhibited {
            // Stay inhibited until battery drops strictly below (target - hysteresis)
            // e.g. at target 80, stay inhibited down to 78, only resume at <= 77.
            return capacity > (clampedTarget - hysteresisMargin)
        } else {
            // Trigger inhibition once battery reaches or exceeds target
            return capacity >= clampedTarget
        }
    }

    /// Clamps an arbitrary user-chosen percentage to the valid threshold range [50, 100].
    static func clampThreshold(_ value: Int) -> Int {
        min(maxThreshold, max(minThreshold, value))
    }

    /// Determines whether the user can change or pick custom charge limits (80, 85, 90, 95).
    /// Custom limits can only be configured if the charger is not connected and the current
    /// battery capacity is strictly below the default threshold (80%).
    static func canConfigureCustomLimit(capacity: Int, isPluggedIn: Bool) -> Bool {
        !isPluggedIn && capacity < defaultThreshold
    }

    /// Determines whether the battery has reached and is currently holding at or near the target limit.
    static func isHoldingAtLimit(
        capacity: Int,
        isPluggedIn: Bool,
        targetThreshold: Int,
        isCharging: Bool
    ) -> Bool {
        guard isPluggedIn && isLimitActive(threshold: targetThreshold) else {
            return false
        }
        return !isCharging && capacity >= (targetThreshold - hysteresisMargin)
    }

    /// True when charging is currently inhibited in hardware and must be restored to normal.
    static func needsRestore(currentlyInhibited: Bool, shouldInhibit: Bool) -> Bool {
        currentlyInhibited && !shouldInhibit
    }
}

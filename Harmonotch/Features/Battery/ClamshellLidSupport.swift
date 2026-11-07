import Foundation
import IOKit
import IOKit.pwr_mgt

enum ClamshellLidSupport {
    private static let checkedAssertionTypes: Set<String> = [
        "UserIsActive",
        "DisplayWake",
        "PreventSystemSleep",
    ]

    /// Pure decision helper that determines whether Harmonotch should explicitly request
    /// system sleep (`IOPMSleepSystem`) after releasing its `disablesleep` override.
    static func shouldRequestSleep(
        lidClosed: Bool?,
        systemAllowsSleep: Bool?,
        assertions: [[String: Any]]?
    ) -> Bool {
        guard lidClosed == true else { return false }
        guard systemAllowsSleep == true else { return false }

        guard let assertions else { return true }

        for assertion in assertions {
            if let level = intValue(from: assertion["AssertLevel"]), level == 0 {
                continue
            }

            if let assertType = assertion["AssertType"] as? String,
               !checkedAssertionTypes.contains(assertType)
            {
                continue
            }

            let appliesOnLidClose = boolValue(from: assertion["AppliesOnLidClose"]) == true
            let processingHotPlug = boolValue(from: assertion["ProcessingHotPlug"]) == true

            if appliesOnLidClose || processingHotPlug {
                return false
            }
        }

        return true
    }

    // MARK: - IOKit Readers

    /// Reads `AppleClamshellState` from `IOPMrootDomain` (`true` = lid closed, `false` = lid open).
    static func isLidClosed() -> Bool? {
        readRootDomainBool(key: "AppleClamshellState")
    }

    /// Reads `AppleClamshellCausesSleep` from `IOPMrootDomain` (`true` = closing lid should sleep).
    static func systemAllowsClamshellSleep() -> Bool? {
        readRootDomainBool(key: "AppleClamshellCausesSleep")
    }

    /// Reads active power assertions across all processes via `IOPMCopyAssertionsByProcess`.
    static func activeAssertions() -> [[String: Any]]? {
        var unmanagedAssertions: Unmanaged<CFDictionary>?
        let status = IOPMCopyAssertionsByProcess(&unmanagedAssertions)
        guard status == kIOReturnSuccess,
              let cfDict = unmanagedAssertions?.takeRetainedValue() as? [AnyHashable: Any]
        else {
            return nil
        }

        var flattened: [[String: Any]] = []
        for value in cfDict.values {
            if let list = value as? [[String: Any]] {
                flattened.append(contentsOf: list)
            } else if let nsArray = value as? NSArray {
                for element in nsArray {
                    if let dict = element as? [String: Any] {
                        flattened.append(dict)
                    }
                }
            }
        }
        return flattened
    }

    /// Evaluates current IOKit state to decide whether sleep should be requested now.
    static func shouldRequestSleepNow() -> Bool {
        shouldRequestSleep(
            lidClosed: isLidClosed(),
            systemAllowsSleep: systemAllowsClamshellSleep(),
            assertions: activeAssertions()
        )
    }

    /// Requests immediate system sleep via `IOPMSleepSystem`.
    /// Returns `true` if `IOPMSleepSystem` returned `kIOReturnSuccess`.
    static func triggerSystemSleep() -> Bool {
        let port = IOPMFindPowerManagement(mach_port_t(MACH_PORT_NULL))
        guard port != IO_OBJECT_NULL else { return false }
        defer { IOServiceClose(port) }

        let err = IOPMSleepSystem(port)
        return err == kIOReturnSuccess
    }

    // MARK: - Private Helpers

    private static func readRootDomainBool(key: String) -> Bool? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
        guard service != IO_OBJECT_NULL else { return nil }
        defer { IOObjectRelease(service) }

        guard let cfProp = IORegistryEntryCreateCFProperty(
            service,
            key as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() else {
            return nil
        }

        return boolValue(from: cfProp)
    }

    private static func boolValue(from value: Any?) -> Bool? {
        if let b = value as? Bool {
            return b
        }
        if let n = value as? NSNumber {
            return n.intValue != 0
        }
        return nil
    }

    private static func intValue(from value: Any?) -> Int? {
        if let i = value as? Int {
            return i
        }
        if let n = value as? NSNumber {
            return n.intValue
        }
        return nil
    }
}

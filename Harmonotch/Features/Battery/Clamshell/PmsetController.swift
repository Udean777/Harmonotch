import Foundation

enum PmsetController {
    @discardableResult
    static func setDisableSleep(_ disableSleep: Bool) -> Bool {
        let value = disableSleep ? "1" : "0"
        return ProcessRunner.runQuietly("/usr/bin/sudo", ["-n", "/usr/bin/pmset", "-a", "disablesleep", value])
    }

    static func sleepDisabled() -> Bool? {
        let result = ProcessRunner.run("/usr/bin/pmset", ["-g"])
        guard result.succeeded else { return nil }
        let parsed = ClamshellPolicy.parseSleepDisabled(result.stdout)
        if let parsed {
            UserDefaults.standard[UserDefaultsKeys.clamshellLastKnownDisabled] = parsed
        }
        return parsed
    }
}

extension ClamshellManager {
    func runPmsetCommand(disableSleep: Bool) -> Bool {
        PmsetController.setDisableSleep(disableSleep)
    }

    static func pmsetSleepDisabled() -> Bool? {
        PmsetController.sleepDisabled()
    }
}

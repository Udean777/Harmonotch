import Foundation
import AppKit
import Combine
import UserNotifications
import IOKit.pwr_mgt

final class ClamshellManager: ObservableObject {
    static let shared = ClamshellManager()

    @Published var isArmed: Bool {
        didSet {
            UserDefaults.standard.set(isArmed, forKey: UserDefaultsKeys.clamshellArmed)
            recalculateState()
        }
    }

    @Published private(set) var currentState: ClamshellState = .off
    @Published private(set) var hasExternalDisplay: Bool = false
    @Published private(set) var externalDisplayCount: Int = 0
    @Published private(set) var externalDisplayName: String = ""
    @Published private(set) var isSudoConfigured: Bool = false
    @Published var isPerformingSetup: Bool = false

    private static let batteryResetThreshold = 62
    private static let batteryWarningThreshold = 60

    private var cancellables = Set<AnyCancellable>()
    private var assertionID: IOPMAssertionID = 0
    private var hasActiveAssertion: Bool = false
    private var isSleepCurrentlyDisabled: Bool = false
    private var hasWarnedAt60: Bool = false

    private init() {
        self.isArmed = UserDefaults.standard.bool(forKey: UserDefaultsKeys.clamshellArmed)

        checkSudoConfiguration()
        setupObservers()
        recalculateState()
        repairStaleSleepState()
    }

    private func setupObservers() {
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.recalculateState()
            }
            .store(in: &cancellables)

        BatteryMonitor.shared.$currentCapacity
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleBatteryUpdate()
            }
            .store(in: &cancellables)

        BatteryMonitor.shared.$isPluggedIn
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleBatteryUpdate()
            }
            .store(in: &cancellables)
    }


    private func inspectScreens() {
        var externalCount = 0
        var firstExternalName = ""

        for screen in NSScreen.screens {
            guard let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
                continue
            }

            if CGDisplayIsBuiltin(screenNumber) == 0 {
                externalCount += 1
                if firstExternalName.isEmpty {
                    firstExternalName = screen.localizedName
                }
            }
        }

        self.hasExternalDisplay = externalCount > 0
        self.externalDisplayCount = externalCount
        self.externalDisplayName = firstExternalName
    }


    func recalculateState() {
        inspectScreens()

        let capacity = BatteryMonitor.shared.currentCapacity
        let isPlugged = BatteryMonitor.shared.isPluggedIn

        if isPlugged || capacity > Self.batteryResetThreshold {
            hasWarnedAt60 = false
        }

        transition(to: ClamshellPolicy.state(
            isArmed: isArmed,
            hasExternalDisplay: hasExternalDisplay,
            isPluggedIn: isPlugged,
            batteryCapacity: capacity
        ))
    }

    private func handleBatteryUpdate() {
        let capacity = BatteryMonitor.shared.currentCapacity
        let isPlugged = BatteryMonitor.shared.isPluggedIn

        if isArmed && currentState == .active && !isPlugged && capacity <= Self.batteryWarningThreshold && !hasWarnedAt60 {
            sendLowBatteryWarningNotification(capacity: capacity)
            hasWarnedAt60 = true
        }

        recalculateState()
    }

    private func transition(to newState: ClamshellState) {
        let oldState = currentState
        currentState = newState

        if newState == .active {
            if !isSleepCurrentlyDisabled {
                activateSleepPrevention()
            }
        } else {
            if isSleepCurrentlyDisabled || oldState == .active {
                deactivateSleepPrevention()
            }
        }
    }


    private func activateSleepPrevention() {
        if !hasActiveAssertion {
            let reason = "Harmonotch Clamshell Stay Awake" as CFString
            let result = IOPMAssertionCreateWithName(
                kIOPMAssertionTypeNoDisplaySleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                reason,
                &assertionID
            )
            if result == kIOReturnSuccess {
                hasActiveAssertion = true
            }
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let success = self?.runPmsetCommand(disableSleep: true) ?? false
            DispatchQueue.main.async {
                self?.isSleepCurrentlyDisabled = success
            }
        }
    }

    private func deactivateSleepPrevention() {
        if hasActiveAssertion {
            IOPMAssertionRelease(assertionID)
            hasActiveAssertion = false
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            _ = self?.runPmsetCommand(disableSleep: false)
            DispatchQueue.main.async {
                self?.isSleepCurrentlyDisabled = false
            }
        }
    }

    private func runPmsetCommand(disableSleep: Bool, allowPrompt: Bool = true) -> Bool {
        let value = disableSleep ? "1" : "0"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        process.arguments = ["-n", "/usr/bin/pmset", "-a", "disablesleep", value]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                return true
            }
        } catch {
            NSLog("[Harmonotch:Clamshell] Failed to run pmset command: %@", error.localizedDescription)
        }

        guard allowPrompt else { return false }

        let scriptSource = "do shell script \"/usr/bin/pmset -a disablesleep \(value)\" with administrator privileges"
        var errorDict: NSDictionary?
        if let appleScript = NSAppleScript(source: scriptSource) {
            let result = appleScript.executeAndReturnError(&errorDict)
            return errorDict == nil && result.stringValue != nil
        }

        return false
    }


    func checkSudoConfiguration() {
        if UserDefaults.standard.bool(forKey: UserDefaultsKeys.sudoConfigured) {
            isSudoConfigured = true
            return
        }

        DispatchQueue.global(qos: .utility).async { [weak self] in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
            // Check rule without running it.
            process.arguments = ["-n", "-l", "--", "/usr/bin/pmset", "-a", "disablesleep", "1"]

            var configured = false
            do {
                try process.run()
                process.waitUntilExit()
                configured = (process.terminationStatus == 0)
            } catch {
                NSLog("[Harmonotch:Clamshell] Sudo rule probe failed: %@", error.localizedDescription)
                configured = false
            }

            DispatchQueue.main.async {
                guard let self else { return }
                if configured {
                    UserDefaults.standard.set(true, forKey: UserDefaultsKeys.sudoConfigured)
                }
                self.isSudoConfigured = configured
            }
        }
    }

    func prepareForTermination() {
        if hasActiveAssertion {
            IOPMAssertionRelease(assertionID)
            hasActiveAssertion = false
        }
        if isSleepCurrentlyDisabled {
            _ = runPmsetCommand(disableSleep: false, allowPrompt: false)
            isSleepCurrentlyDisabled = false
        }
    }

    private func repairStaleSleepState() {
        guard currentState != .active else { return }

        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard Self.isSleepDisabled() else { return }

            let restored = self?.runPmsetCommand(disableSleep: false, allowPrompt: false) ?? false
            if !restored {
                NSLog("[Harmonotch:Clamshell] Could not clear a stale disablesleep without a password")
            }
        }
    }

    private static func isSleepDisabled() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = ["-g"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(decoding: data, as: UTF8.self)
            return output.split(separator: "\n").contains { line in
                let parts = line.split(whereSeparator: \.isWhitespace)
                return parts.count >= 2 && parts[0] == "disablesleep" && parts[1] == "1"
            }
        } catch {
            NSLog("[Harmonotch:Clamshell] Failed to check pmset sleep status: %@", error.localizedDescription)
            return false
        }
    }

    func setupPasswordlessSudo(completion: @escaping (Bool) -> Void) {
        isPerformingSetup = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let ruleContent = "%admin ALL=(ALL) NOPASSWD: /usr/bin/pmset -a disablesleep *"
            // Validate with visudo before installing to prevent breaking sudo.
            let shell = "tmp=$(mktemp) && echo '\(ruleContent)' > \"$tmp\" && chmod 440 \"$tmp\" "
                + "&& visudo -c -f \"$tmp\" && mv \"$tmp\" /etc/sudoers.d/harmonotch"
            let scriptSource = "do shell script \"\(shell.replacingOccurrences(of: "\"", with: "\\\""))\" with administrator privileges"

            var errorDict: NSDictionary?
            var success = false
            if let appleScript = NSAppleScript(source: scriptSource) {
                _ = appleScript.executeAndReturnError(&errorDict)
                success = (errorDict == nil)
            }

            DispatchQueue.main.async {
                guard let self else { return }
                self.isPerformingSetup = false
                self.isSudoConfigured = success
                UserDefaults.standard.set(success, forKey: UserDefaultsKeys.sudoConfigured)
                if success {
                    self.recalculateState()
                }
                completion(success)
            }
        }
    }


    private func sendLowBatteryWarningNotification(capacity: Int) {
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = L10n.Clamshell.warningNotificationTitle
        content.body = L10n.Clamshell.warningNotificationBody(capacity: capacity)
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "Harmonotch_Clamshell_60Warning",
            content: content,
            trigger: nil
        )

        center.add(request) { error in
            if let error = error {
                NSLog("[Harmonotch:Clamshell] Failed to deliver clamshell battery notification: %@", error.localizedDescription)
            }
        }
    }
}

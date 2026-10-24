import Foundation
import AppKit
import Combine
import UserNotifications
import IOKit.pwr_mgt

enum ClamshellState: Equatable {
    case off
    case active
    case standby
    case pausedLowBattery
}

final class ClamshellManager: ObservableObject {
    static let shared = ClamshellManager()

    @Published var isArmed: Bool {
        didSet {
            UserDefaults.standard.set(isArmed, forKey: userDefaultsKey)
            recalculateState()
        }
    }

    @Published private(set) var currentState: ClamshellState = .off
    @Published private(set) var hasExternalDisplay: Bool = false
    @Published private(set) var externalDisplayCount: Int = 0
    @Published private(set) var externalDisplayName: String = ""
    @Published private(set) var isSudoConfigured: Bool = false
    @Published var isPerformingSetup: Bool = false

    private let userDefaultsKey = "Harmonotch_ClamshellArmed"
    private var cancellables = Set<AnyCancellable>()
    private var assertionID: IOPMAssertionID = 0
    private var hasActiveAssertion: Bool = false
    private var isSleepCurrentlyDisabled: Bool = false
    private var hasWarnedAt60: Bool = false

    private init() {
        self.isArmed = UserDefaults.standard.bool(forKey: userDefaultsKey)

        checkSudoConfiguration()
        setupObservers()
        recalculateState()
    }

    private func setupObservers() {
        // Monitor screen connect / disconnect events
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.recalculateState()
            }
            .store(in: &cancellables)

        // Monitor battery changes
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

    // MARK: - Screen Detection

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

    // MARK: - State Calculation

    func recalculateState() {
        inspectScreens()

        let capacity = BatteryMonitor.shared.currentCapacity
        let isPlugged = BatteryMonitor.shared.isPluggedIn

        // Reset 60% warning flag when plugged in or charged above 62%
        if isPlugged || capacity > 62 {
            hasWarnedAt60 = false
        }

        guard isArmed else {
            transition(to: .off)
            return
        }

        guard hasExternalDisplay else {
            // Armed, but external display unplugged -> Standby (safe in bag!)
            transition(to: .standby)
            return
        }

        // External display is connected
        if isPlugged {
            // Charging: completely safe to stay active
            transition(to: .active)
        } else {
            // On battery: enforce 50% cutoff
            if capacity <= 50 {
                transition(to: .pausedLowBattery)
            } else {
                transition(to: .active)
            }
        }
    }

    private func handleBatteryUpdate() {
        let capacity = BatteryMonitor.shared.currentCapacity
        let isPlugged = BatteryMonitor.shared.isPluggedIn

        // Check for 60% early warning on battery
        if isArmed && currentState == .active && !isPlugged && capacity <= 60 && !hasWarnedAt60 {
            sendLowBatteryWarningNotification()
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

    // MARK: - Sleep Prevention Execution

    private func activateSleepPrevention() {
        // 1. IOKit Assertion for idle display sleep
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

        // 2. Kernel pmset disablesleep 1
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let success = self?.runPmsetCommand(disableSleep: true) ?? false
            DispatchQueue.main.async {
                self?.isSleepCurrentlyDisabled = success
            }
        }
    }

    private func deactivateSleepPrevention() {
        // 1. Release IOKit Assertion
        if hasActiveAssertion {
            IOPMAssertionRelease(assertionID)
            hasActiveAssertion = false
        }

        // 2. Kernel pmset disablesleep 0
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            _ = self?.runPmsetCommand(disableSleep: false)
            DispatchQueue.main.async {
                self?.isSleepCurrentlyDisabled = false
            }
        }
    }

    private func runPmsetCommand(disableSleep: Bool) -> Bool {
        let value = disableSleep ? "1" : "0"

        // First attempt: Non-interactive sudo (fastest if sudoers rule exists)
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
            // Process launch failed
        }

        // Fallback: If non-interactive sudo fails, execute via AppleScript with administrator privileges
        let scriptSource = "do shell script \"/usr/bin/pmset -a disablesleep \(value)\" with administrator privileges"
        var errorDict: NSDictionary?
        if let appleScript = NSAppleScript(source: scriptSource) {
            let result = appleScript.executeAndReturnError(&errorDict)
            return errorDict == nil && result.stringValue != nil
        }

        return false
    }

    // MARK: - Sudoers One-Time Setup

    func checkSudoConfiguration() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
            process.arguments = ["-n", "/usr/bin/pmset", "-g"]

            do {
                try process.run()
                process.waitUntilExit()
                let isConfigured = (process.terminationStatus == 0)
                DispatchQueue.main.async {
                    self?.isSudoConfigured = isConfigured
                }
            } catch {
                DispatchQueue.main.async {
                    self?.isSudoConfigured = false
                }
            }
        }
    }

    func setupPasswordlessSudo(completion: @escaping (Bool) -> Void) {
        isPerformingSetup = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let ruleContent = "%admin ALL=(ALL) NOPASSWD: /usr/bin/pmset -a disablesleep *"
            let scriptSource = "do shell script \"echo '\(ruleContent)' > /etc/sudoers.d/harmonotch && chmod 440 /etc/sudoers.d/harmonotch\" with administrator privileges"

            var errorDict: NSDictionary?
            var success = false
            if let appleScript = NSAppleScript(source: scriptSource) {
                _ = appleScript.executeAndReturnError(&errorDict)
                success = (errorDict == nil)
            }

            DispatchQueue.main.async {
                self?.isPerformingSetup = false
                self?.isSudoConfigured = success
                if success {
                    self?.recalculateState()
                }
                completion(success)
            }
        }
    }

    // MARK: - Notifications

    private func sendLowBatteryWarningNotification() {
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = L10n.Clamshell.warningNotificationTitle
        content.body = L10n.Clamshell.warningNotificationBody
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "Harmonotch_Clamshell_60Warning",
            content: content,
            trigger: nil
        )

        center.add(request) { error in
            if let error = error {
                print("Failed to deliver clamshell battery notification: \(error)")
            }
        }
    }
}

import Foundation
import AppKit
import Combine
import UserNotifications
import IOKit.pwr_mgt

final class ClamshellManager: ObservableObject {
    static let shared = ClamshellManager()
    static let sudoersFilePath = "/etc/sudoers.d/harmonotch-clamshell"

    @Published var isArmed: Bool {
        didSet {
            UserDefaults.standard[UserDefaultsKeys.clamshellArmed] = isArmed
            recalculateState()
        }
    }

    @Published private(set) var currentState: ClamshellState = .off
    @Published private(set) var hasExternalDisplay: Bool = false
    @Published private(set) var externalDisplayCount: Int = 0
    @Published private(set) var externalDisplayName: String = ""
    @Published private(set) var isSudoConfigured: Bool = false
    @Published var isPerformingSetup: Bool = false
    @Published private(set) var setupFailed: Bool = false

    private static let batteryResetThreshold = 62
    private static let batteryWarningThreshold = 60
    private static let terminationTimeoutSeconds: TimeInterval = 3.0
    private static let maxSleepRetries = 10
    private static let sleepRetryIntervalSeconds: TimeInterval = 0.5

    private let clamshellQueue = DispatchQueue(label: "harmonotch.battery.clamshell", qos: .userInitiated)
    private let stateLock = NSLock()

    private var cancellables = Set<AnyCancellable>()
    private var systemAssertionID: IOPMAssertionID = 0
    private var displayAssertionID: IOPMAssertionID = 0
    private var hasSystemAssertion: Bool = false
    private var hasDisplayAssertion: Bool = false

    private(set) var isSleepCurrentlyDisabled: Bool = false
    private(set) var isEnablePending: Bool = false
    private(set) var isRestorePending: Bool = false
    private var _isTerminating: Bool = false
    private var _overrideOwned: Bool = false
    private var operationGeneration: UInt64 = 0
    private var isInitialRecoveryComplete: Bool = false
    private var hasWarnedAt60: Bool = false

    var isTerminating: Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return _isTerminating
    }

    var overrideOwned: Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return _overrideOwned
    }

    private func setOverrideOwned(_ owned: Bool) {
        stateLock.lock()
        _overrideOwned = owned
        stateLock.unlock()
        if owned {
            UserDefaults.standard[UserDefaultsKeys.clamshellOverrideOwned] = true
        } else {
            UserDefaults.standard.remove(UserDefaultsKeys.clamshellOverrideOwned)
        }
    }

    private func setTerminating(_ terminating: Bool) {
        stateLock.lock()
        _isTerminating = terminating
        stateLock.unlock()
    }

    private func nextGeneration() -> UInt64 {
        stateLock.lock()
        defer { stateLock.unlock() }
        operationGeneration &+= 1
        return operationGeneration
    }

    private func currentGeneration() -> UInt64 {
        stateLock.lock()
        defer { stateLock.unlock() }
        return operationGeneration
    }

    private init() {
        self._overrideOwned = UserDefaults.standard[UserDefaultsKeys.clamshellOverrideOwned]
        self.isArmed = UserDefaults.standard[UserDefaultsKeys.clamshellArmed]

        setupObservers()
        recoverIfNeeded { [weak self] in
            guard let self else { return }
            self.isInitialRecoveryComplete = true
            self.checkSudoConfiguration()
            self.recalculateState()
        }
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
        guard isInitialRecoveryComplete, !isTerminating else { return }

        let capacity = BatteryMonitor.shared.currentCapacity
        let isPlugged = BatteryMonitor.shared.isPluggedIn

        if isPlugged || capacity > Self.batteryResetThreshold {
            hasWarnedAt60 = false
        }

        let targetState = ClamshellPolicy.state(
            isArmed: isArmed,
            hasExternalDisplay: hasExternalDisplay,
            isPluggedIn: isPlugged,
            batteryCapacity: capacity
        )
        transition(to: targetState)
    }

    private func handleBatteryUpdate() {
        guard isInitialRecoveryComplete, !isTerminating else { return }

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

        if newState == .active {
            if isSleepCurrentlyDisabled && !isRestorePending {
                acquireAssertionsIfNeeded()
                currentState = .active
            } else if !isEnablePending {
                activateSleepPrevention()
            }
        } else {
            currentState = newState
            if isSleepCurrentlyDisabled || isEnablePending || oldState == .active || overrideOwned {
                deactivateSleepPrevention(targetState: newState)
            } else {
                releaseAssertionsIfNeeded()
            }
        }
    }

    // MARK: - Assertions

    private func acquireAssertionsIfNeeded() {
        let reason = "Harmonotch Clamshell Stay Awake" as CFString
        if !hasSystemAssertion {
            let res = IOPMAssertionCreateWithName(
                kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                reason,
                &systemAssertionID
            )
            if res == kIOReturnSuccess {
                hasSystemAssertion = true
            }
        }
        if !hasDisplayAssertion {
            let res = IOPMAssertionCreateWithName(
                kIOPMAssertionTypeNoDisplaySleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                reason,
                &displayAssertionID
            )
            if res == kIOReturnSuccess {
                hasDisplayAssertion = true
            }
        }
    }

    private func releaseAssertionsIfNeeded() {
        if hasSystemAssertion {
            IOPMAssertionRelease(systemAssertionID)
            systemAssertionID = 0
            hasSystemAssertion = false
        }
        if hasDisplayAssertion {
            IOPMAssertionRelease(displayAssertionID)
            displayAssertionID = 0
            hasDisplayAssertion = false
        }
    }

    // MARK: - Enable / Disable Sleep Prevention

    private func activateSleepPrevention() {
        let gen = nextGeneration()
        isEnablePending = true
        isRestorePending = false

        clamshellQueue.async { [weak self] in
            guard let self, !self.isTerminating, self.currentGeneration() == gen else { return }

            // Mark ownership BEFORE running the enable command so crashes/force-quits can recover.
            self.setOverrideOwned(true)

            let cmdSuccess = self.runPmsetCommand(disableSleep: true)
            let reportedDisabled = Self.pmsetSleepDisabled()
            let verifiedSuccess = cmdSuccess && (reportedDisabled == true)

            DispatchQueue.main.async { [weak self] in
                guard let self, !self.isTerminating, self.currentGeneration() == gen else { return }
                self.isEnablePending = false

                if verifiedSuccess {
                    self.isSleepCurrentlyDisabled = true
                    self.isSudoConfigured = true
                    self.acquireAssertionsIfNeeded()
                    self.currentState = .active
                } else {
                    self.isSleepCurrentlyDisabled = (reportedDisabled == true)
                    self.releaseAssertionsIfNeeded()
                    self.currentState = .off
                    self.checkSudoConfiguration()
                }
            }
        }
    }

    private func deactivateSleepPrevention(targetState: ClamshellState) {
        let gen = nextGeneration()
        isEnablePending = false
        isRestorePending = true
        releaseAssertionsIfNeeded()

        clamshellQueue.async { [weak self] in
            guard let self, !self.isTerminating else { return }

            let cmdSuccess = self.runPmsetCommand(disableSleep: false)
            let reportedDisabled = Self.pmsetSleepDisabled()

            // Disable succeeds if exit code is 0 and SleepDisabled is 0 (or unreadable).
            // Ownership flag is cleared ONLY when SleepDisabled is confirmed 0.
            let restoreVerified = cmdSuccess && (reportedDisabled == false)
            let restoreSucceeded = cmdSuccess && (reportedDisabled == false || reportedDisabled == nil)

            if restoreVerified {
                self.setOverrideOwned(false)
            }

            DispatchQueue.main.async { [weak self] in
                guard let self, !self.isTerminating, self.currentGeneration() == gen else { return }
                self.isRestorePending = false
                if restoreSucceeded {
                    self.isSleepCurrentlyDisabled = false
                    self.currentState = targetState
                    self.requestSleepIfLidClosed(generation: gen)
                } else {
                    NSLog("[Harmonotch:Clamshell] Failed to restore SleepDisabled to 0; keeping recovery state active")
                }
            }
        }
    }

    // MARK: - Lid-Closed Sleep Enforcement

    func requestSleepIfLidClosed(generation: UInt64? = nil) {
        let activeGen = generation ?? currentGeneration()
        attemptSleepIfLidClosed(generation: activeGen, attempt: 1)
    }

    private func attemptSleepIfLidClosed(generation: UInt64, attempt: Int) {
        guard attempt <= Self.maxSleepRetries else { return }

        clamshellQueue.async { [weak self] in
            guard let self, !self.isTerminating, self.currentGeneration() == generation else { return }

            // Re-read session state: never force sleep if session became active again.
            var sessionActiveOrEnabling = false
            DispatchQueue.main.sync {
                sessionActiveOrEnabling = self.currentState == .active
                    || self.isSleepCurrentlyDisabled
                    || self.isEnablePending
                    || self.hasSystemAssertion
                    || self.hasDisplayAssertion
            }
            guard !sessionActiveOrEnabling else { return }

            let lidClosed = ClamshellLidSupport.isLidClosed()
            guard lidClosed == true else { return }

            let systemAllowsSleep = ClamshellLidSupport.systemAllowsClamshellSleep()
            let assertions = ClamshellLidSupport.activeAssertions()

            guard ClamshellLidSupport.shouldRequestSleep(
                lidClosed: lidClosed,
                systemAllowsSleep: systemAllowsSleep,
                assertions: assertions
            ) else {
                return
            }

            if ClamshellLidSupport.triggerSystemSleep() {
                return
            }

            guard attempt < Self.maxSleepRetries else { return }
            self.clamshellQueue.asyncAfter(deadline: .now() + Self.sleepRetryIntervalSeconds) { [weak self] in
                self?.attemptSleepIfLidClosed(generation: generation, attempt: attempt + 1)
            }
        }
    }

    private func requestSleepIfLidClosedSync() {
        for attempt in 1...Self.maxSleepRetries {
            guard !isSleepCurrentlyDisabled, !hasSystemAssertion, !hasDisplayAssertion else { return }

            let lidClosed = ClamshellLidSupport.isLidClosed()
            guard lidClosed == true else { return }

            let systemAllowsSleep = ClamshellLidSupport.systemAllowsClamshellSleep()
            let assertions = ClamshellLidSupport.activeAssertions()

            guard ClamshellLidSupport.shouldRequestSleep(
                lidClosed: lidClosed,
                systemAllowsSleep: systemAllowsSleep,
                assertions: assertions
            ) else {
                return
            }

            if ClamshellLidSupport.triggerSystemSleep() {
                return
            }

            if attempt < Self.maxSleepRetries {
                Thread.sleep(forTimeInterval: Self.sleepRetryIntervalSeconds)
            }
        }
    }

    private func runPmsetCommand(disableSleep: Bool) -> Bool {
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
            return process.terminationStatus == 0
        } catch {
            NSLog("[Harmonotch:Clamshell] Failed to run pmset command: %@", error.localizedDescription)
            return false
        }
    }

    static func pmsetSleepDisabled() -> Bool? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = ["-g"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(decoding: data, as: UTF8.self)
            let parsed = ClamshellPolicy.parseSleepDisabled(output)
            if let parsed {
                UserDefaults.standard[UserDefaultsKeys.clamshellLastKnownDisabled] = parsed
            }
            return parsed
        } catch {
            NSLog("[Harmonotch:Clamshell] Failed to check pmset sleep status: %@", error.localizedDescription)
            return nil
        }
    }

    // MARK: - Sudo Probe & Setup

    func checkSudoConfiguration() {
        clamshellQueue.async { [weak self] in
            guard let self, !self.isTerminating else { return }
            let configured = self.probeSudoConfigurationSync()
            DispatchQueue.main.async { [weak self] in
                guard let self, !self.isTerminating else { return }
                self.isSudoConfigured = configured
                if configured {
                    self.setupFailed = false
                }
            }
        }
    }

    private func probeSudoConfigurationSync() -> Bool {
        guard let currentDisabled = Self.pmsetSleepDisabled() else {
            return false
        }
        return runPmsetCommand(disableSleep: currentDisabled)
    }

    func setupPasswordlessSudo(completion: @escaping (Bool) -> Void) {
        isPerformingSetup = true
        setupFailed = false
        clamshellQueue.async { [weak self] in
            guard let self, !self.isTerminating else {
                DispatchQueue.main.async {
                    self?.isPerformingSetup = false
                    self?.setupFailed = true
                    completion(false)
                }
                return
            }

            let uid = getuid()
            let ruleContent = "#\(uid) ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 1, /usr/bin/pmset -a disablesleep 0"
            let targetPath = Self.sudoersFilePath

            let shell = "tmp=$(mktemp) && printf '%s\\n' '\(ruleContent)' > \"$tmp\" "
                + "&& chown root:wheel \"$tmp\" && chmod 0440 \"$tmp\" "
                + "&& visudo -c -f \"$tmp\" && mv \"$tmp\" \(targetPath)"
            let scriptSource = "do shell script \"\(shell.replacingOccurrences(of: "\"", with: "\\\""))\" with administrator privileges"

            var errorDict: NSDictionary?
            var scriptSucceeded = false
            if let appleScript = NSAppleScript(source: scriptSource) {
                _ = appleScript.executeAndReturnError(&errorDict)
                scriptSucceeded = (errorDict == nil)
            }

            let verified = scriptSucceeded && self.probeSudoConfigurationSync()

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.isPerformingSetup = false
                self.isSudoConfigured = verified
                self.setupFailed = !verified
                if verified {
                    self.recalculateState()
                }
                completion(verified)
            }
        }
    }

    func removePasswordlessSudo(completion: ((Bool) -> Void)? = nil) {
        clamshellQueue.async { [weak self] in
            let targetPath = Self.sudoersFilePath
            let shell = "rm -f \(targetPath)"
            let scriptSource = "do shell script \"\(shell)\" with administrator privileges"

            var errorDict: NSDictionary?
            var removed = false
            if let appleScript = NSAppleScript(source: scriptSource) {
                _ = appleScript.executeAndReturnError(&errorDict)
                removed = (errorDict == nil)
            }

            let stillConfigured = self?.probeSudoConfigurationSync() ?? false
            DispatchQueue.main.async { [weak self] in
                self?.isSudoConfigured = stillConfigured
                completion?(removed && !stillConfigured)
            }
        }
    }

    // MARK: - Recovery & Termination

    func recoverIfNeeded(completion: (() -> Void)? = nil) {
        clamshellQueue.async { [weak self] in
            guard let self else {
                DispatchQueue.main.async { completion?() }
                return
            }

            // Never touch pmset if Harmonotch does not own the override.
            guard self.overrideOwned else {
                DispatchQueue.main.async { completion?() }
                return
            }

            let currentDisabled = Self.pmsetSleepDisabled()
            if currentDisabled == false {
                // Already back to normal sleep policy.
                self.setOverrideOwned(false)
                DispatchQueue.main.async { [weak self] in
                    self?.isSleepCurrentlyDisabled = false
                    completion?()
                }
                return
            }

            // SleepDisabled is 1 (or unreadable while overrideOwned is true): attempt restore.
            let cmdSuccess = self.runPmsetCommand(disableSleep: false)
            let afterDisabled = Self.pmsetSleepDisabled()
            let verifiedRestored = cmdSuccess && (afterDisabled == false)

            if verifiedRestored {
                self.setOverrideOwned(false)
            } else {
                NSLog("[Harmonotch:Clamshell] Recovery could not verify SleepDisabled=0; keeping ownership flag for retry")
            }

            DispatchQueue.main.async { [weak self] in
                self?.isSleepCurrentlyDisabled = !verifiedRestored
                completion?()
            }
        }
    }

    func repairStaleSleepState() {
        guard currentState != .active, overrideOwned else { return }
        recoverIfNeeded()
    }

    func prepareForTermination() {
        setTerminating(true)
        _ = nextGeneration()
        releaseAssertionsIfNeeded()

        let needsRestore = overrideOwned || isSleepCurrentlyDisabled || isEnablePending
        guard needsRestore else { return }

        var restored = false
        let semaphore = DispatchSemaphore(value: 0)
        clamshellQueue.async { [weak self] in
            defer { semaphore.signal() }
            guard let self else { return }
            guard self.overrideOwned || self.isSleepCurrentlyDisabled || self.isEnablePending else { return }

            let cmdSuccess = self.runPmsetCommand(disableSleep: false)
            let afterDisabled = Self.pmsetSleepDisabled()
            if cmdSuccess && afterDisabled == false {
                self.setOverrideOwned(false)
                self.isSleepCurrentlyDisabled = false
                restored = true
            } else if cmdSuccess && afterDisabled == nil {
                self.isSleepCurrentlyDisabled = false
                restored = true
            }
        }

        let waitResult = semaphore.wait(timeout: .now() + Self.terminationTimeoutSeconds)
        if waitResult == .timedOut {
            NSLog("[Harmonotch:Clamshell] Timed out waiting for clamshellQueue during termination; attempting direct restore")
            let cmdSuccess = runPmsetCommand(disableSleep: false)
            let afterDisabled = Self.pmsetSleepDisabled()
            if cmdSuccess && afterDisabled == false {
                setOverrideOwned(false)
                isSleepCurrentlyDisabled = false
                restored = true
            } else if cmdSuccess && afterDisabled == nil {
                isSleepCurrentlyDisabled = false
                restored = true
            }
        }

        if restored {
            requestSleepIfLidClosedSync()
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

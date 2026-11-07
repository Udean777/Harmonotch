import Foundation
import AppKit
import Combine
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

    @Published var currentState: ClamshellState = .off {
        didSet { updateSessionBlockingFlag() }
    }
    @Published private(set) var hasExternalDisplay: Bool = false
    @Published private(set) var externalDisplayCount: Int = 0
    @Published private(set) var externalDisplayName: String = ""
    @Published var isSudoConfigured: Bool = false
    @Published var isPerformingSetup: Bool = false
    @Published var setupFailed: Bool = false

    private static let batteryResetThreshold = 62
    private static let batteryWarningThreshold = 60
    private static let terminationTimeoutSeconds: TimeInterval = 3.0
    private static let maxSleepRetries = 10
    private static let sleepRetryIntervalSeconds: TimeInterval = 0.5

    let clamshellQueue = DispatchQueue(label: "harmonotch.battery.clamshell", qos: .userInitiated)
    private let stateLock = NSLock()

    private var cancellables = Set<AnyCancellable>()
    private var systemAssertionID: IOPMAssertionID = 0
    private var displayAssertionID: IOPMAssertionID = 0
    private var hasSystemAssertion: Bool = false {
        didSet { updateSessionBlockingFlag() }
    }
    private var hasDisplayAssertion: Bool = false {
        didSet { updateSessionBlockingFlag() }
    }

    private(set) var isSleepCurrentlyDisabled: Bool = false {
        didSet { updateSessionBlockingFlag() }
    }
    private(set) var isEnablePending: Bool = false {
        didSet { updateSessionBlockingFlag() }
    }
    private(set) var isRestorePending: Bool = false
    private var _isTerminating: Bool = false
    private var _overrideOwned: Bool = false
    private var _sessionBlocksSleep: Bool = false
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

    var sessionBlocksSleep: Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return _sessionBlocksSleep
    }

    private func updateSessionBlockingFlag() {
        let blocks = currentState == .active
            || isSleepCurrentlyDisabled
            || isEnablePending
            || hasSystemAssertion
            || hasDisplayAssertion
        stateLock.lock()
        _sessionBlocksSleep = blocks
        stateLock.unlock()
    }

    func setOverrideOwned(_ owned: Bool) {
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

    func currentGeneration() -> UInt64 {
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
            ClamshellNotifier.sendLowBatteryWarning(capacity: capacity)
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

            let cmdSuccess = PmsetController.setDisableSleep(true)
            let reportedDisabled = PmsetController.sleepDisabled()
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

            let cmdSuccess = PmsetController.setDisableSleep(false)
            let reportedDisabled = PmsetController.sleepDisabled()

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
                    self.requestSleepIfLidClosed(generation: gen, synchronous: false)
                } else {
                    NSLog("[Harmonotch:Clamshell] Failed to restore SleepDisabled to 0; keeping recovery state active")
                }
            }
        }
    }

    // MARK: - Lid-Closed Sleep Enforcement

    func requestSleepIfLidClosed(generation: UInt64? = nil, synchronous: Bool = false) {
        if synchronous {
            for attempt in 1...Self.maxSleepRetries {
                guard !sessionBlocksSleep else { return }
                guard let triggered = Self.evaluateAndTriggerLidSleepOnce() else { return }
                if triggered { return }
                if attempt < Self.maxSleepRetries {
                    Thread.sleep(forTimeInterval: Self.sleepRetryIntervalSeconds)
                }
            }
        } else {
            let activeGen = generation ?? currentGeneration()
            attemptSleepIfLidClosedAsync(generation: activeGen, attempt: 1)
        }
    }

    private func attemptSleepIfLidClosedAsync(generation: UInt64, attempt: Int) {
        guard attempt <= Self.maxSleepRetries else { return }

        clamshellQueue.async { [weak self] in
            guard let self, !self.isTerminating, self.currentGeneration() == generation else { return }
            guard !self.sessionBlocksSleep else { return }
            guard let triggered = Self.evaluateAndTriggerLidSleepOnce() else { return }
            if triggered { return }

            guard attempt < Self.maxSleepRetries else { return }
            self.clamshellQueue.asyncAfter(deadline: .now() + Self.sleepRetryIntervalSeconds) { [weak self] in
                self?.attemptSleepIfLidClosedAsync(generation: generation, attempt: attempt + 1)
            }
        }
    }

    /// Returns `nil` when sleep should not be requested, `true` when triggered, or `false` to retry.
    private static func evaluateAndTriggerLidSleepOnce() -> Bool? {
        let lidClosed = ClamshellLidSupport.isLidClosed()
        guard lidClosed == true else { return nil }

        let systemAllowsSleep = ClamshellLidSupport.systemAllowsClamshellSleep()
        let assertions = ClamshellLidSupport.activeAssertions()

        guard ClamshellLidSupport.shouldRequestSleep(
            lidClosed: lidClosed,
            systemAllowsSleep: systemAllowsSleep,
            assertions: assertions
        ) else {
            return nil
        }

        return ClamshellLidSupport.triggerSystemSleep()
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

            let currentDisabled = PmsetController.sleepDisabled()
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
            let cmdSuccess = PmsetController.setDisableSleep(false)
            let afterDisabled = PmsetController.sleepDisabled()
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

            let cmdSuccess = PmsetController.setDisableSleep(false)
            let afterDisabled = PmsetController.sleepDisabled()
            if cmdSuccess && afterDisabled == false {
                self.setOverrideOwned(false)
                restored = true
            } else if cmdSuccess && afterDisabled == nil {
                restored = true
            }
        }

        let waitResult = semaphore.wait(timeout: .now() + Self.terminationTimeoutSeconds)
        if waitResult == .timedOut {
            NSLog("[Harmonotch:Clamshell] Timed out waiting for clamshellQueue during termination; attempting direct restore")
            let cmdSuccess = PmsetController.setDisableSleep(false)
            let afterDisabled = PmsetController.sleepDisabled()
            if cmdSuccess && afterDisabled == false {
                setOverrideOwned(false)
                restored = true
            } else if cmdSuccess && afterDisabled == nil {
                restored = true
            }
        }

        if restored {
            isSleepCurrentlyDisabled = false
            requestSleepIfLidClosed(synchronous: true)
        }
    }
}

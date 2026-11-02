import Foundation
import AppKit
import Combine
import UserNotifications

final class BatteryChargeLimiter: ObservableObject {
    static let shared = BatteryChargeLimiter()

    /// Target charge percentage chosen by user: 80, 85, 90, 95, 100 (Full/Unrestricted)
    @Published var targetThreshold: Int {
        didSet {
            let clamped = ChargeLimitPolicy.clampThreshold(targetThreshold)
            if clamped != targetThreshold {
                targetThreshold = clamped
                return
            }
            UserDefaults.standard.set(targetThreshold, forKey: UserDefaultsKeys.chargeLimitThreshold)
            UserDefaults.standard.set(isLimitActive, forKey: UserDefaultsKeys.chargeLimitEnabled)

            // If user selects 80% on macOS with native support, sync preference
            if targetThreshold <= 80 {
                Self.writeNativeChargeLimit(targetThreshold)
            }

            evaluateLimit()
        }
    }

    /// Whether charging is actively capped (< 100%). When 100%, charge to full is enabled.
    var isLimitActive: Bool {
        ChargeLimitPolicy.isLimitActive(threshold: targetThreshold)
    }

    /// Backwards-compatibility alias for views that check isEnabled
    var isEnabled: Bool {
        get { isLimitActive }
        set {
            if !newValue {
                targetThreshold = 100
            } else if targetThreshold >= 100 {
                targetThreshold = nativeLimitValue ?? ChargeLimitPolicy.defaultThreshold
            }
        }
    }

    @Published private(set) var hasNativeLimit: Bool = false
    @Published private(set) var nativeLimitValue: Int? = nil
    @Published private(set) var isChargingInhibited: Bool = false
    @Published private(set) var isSudoConfigured: Bool = false
    @Published var isPerformingSetup: Bool = false
    @Published private(set) var lastErrorMessage: String? = nil

    private var cancellables = Set<AnyCancellable>()
    private let executionQueue = DispatchQueue(label: "harmonotch.battery.chargelimiter", qos: .userInitiated)
    private var hasNotifiedReachedLimit = false

    private init() {
        let nativeLimit = Self.readNativeChargeLimit()
        self.nativeLimitValue = nativeLimit
        self.hasNativeLimit = (nativeLimit != nil && nativeLimit! < 100)

        // Initialize target threshold:
        // Priority 1: User's explicitly saved Harmonotch threshold
        // Priority 2: Detected native macOS charge limit (e.g. 80%)
        // Priority 3: Default 80%
        let initialThreshold: Int
        if let savedLimit = UserDefaults.standard.object(forKey: UserDefaultsKeys.chargeLimitThreshold) as? Int {
            initialThreshold = ChargeLimitPolicy.clampThreshold(savedLimit)
        } else if let native = nativeLimit, native < 100 {
            initialThreshold = native
            UserDefaults.standard.set(initialThreshold, forKey: UserDefaultsKeys.chargeLimitThreshold)
            UserDefaults.standard.set(true, forKey: UserDefaultsKeys.chargeLimitEnabled)
        } else {
            initialThreshold = ChargeLimitPolicy.defaultThreshold
        }

        self.targetThreshold = initialThreshold

        checkSudoConfiguration()
        setupObservers()

        // Ensure helper binary is compiled in background so it is ready
        executionQueue.async { [weak self] in
            _ = self?.resolveHelperBinaryPath()
        }
    }

    private func setupObservers() {
        BatteryMonitor.shared.$currentCapacity
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.evaluateLimit()
            }
            .store(in: &cancellables)

        BatteryMonitor.shared.$isPluggedIn
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isPlugged in
                guard let self else { return }
                if !isPlugged && self.isChargingInhibited {
                    self.isChargingInhibited = false
                }
                self.evaluateLimit()
            }
            .store(in: &cancellables)
    }

    // MARK: - Core Limit Evaluation

    func evaluateLimit() {
        let capacity = BatteryMonitor.shared.currentCapacity
        let isPluggedIn = BatteryMonitor.shared.isPluggedIn
        let isCharging = BatteryMonitor.shared.isCharging

        // Determine if limit is active (< 100%) and plugged in
        let shouldInhibit = ChargeLimitPolicy.shouldInhibit(
            capacity: capacity,
            isPluggedIn: isPluggedIn,
            isEnabled: isLimitActive,
            targetThreshold: targetThreshold,
            currentlyInhibited: isChargingInhibited
        )

        // Check if macOS native power daemon is holding this limit (e.g. at 80%)
        let isNativeHandled = hasNativeLimit && targetThreshold == (nativeLimitValue ?? 80)

        if shouldInhibit != isChargingInhibited {
            applyInhibit(shouldInhibit, targetLimit: targetThreshold, isNativeHandled: isNativeHandled)
        } else if isNativeHandled && isPluggedIn && capacity >= targetThreshold && !isCharging && !isChargingInhibited {
            // Recognize native bypass state even before manual inhibit command
            self.isChargingInhibited = true
        }

        // Notification assistance when reaching target threshold
        if isLimitActive && isPluggedIn && capacity >= targetThreshold {
            if !hasNotifiedReachedLimit {
                sendLimitReachedNotification(capacity: capacity)
                hasNotifiedReachedLimit = true
            }
        } else if capacity < targetThreshold - ChargeLimitPolicy.hysteresisMargin {
            hasNotifiedReachedLimit = false
        }
    }

    private func applyInhibit(_ inhibit: Bool, targetLimit: Int, isNativeHandled: Bool) {
        executionQueue.async { [weak self] in
            guard let self else { return }
            let success = self.executeInhibitCommand(inhibit: inhibit, targetLimit: targetLimit)
            DispatchQueue.main.async {
                if success || isNativeHandled {
                    self.isChargingInhibited = inhibit
                    self.lastErrorMessage = nil
                } else if self.isLimitActive {
                    self.lastErrorMessage = "Helper execution failed or requires sudo configuration."
                }
            }
        }
    }

    // MARK: - Lifecycle Termination Cleanup

    func prepareForTermination() {
        if isChargingInhibited {
            _ = executeInhibitCommand(inhibit: false, targetLimit: 100)
            isChargingInhibited = false
        }
    }

    // MARK: - SMC Execution Engine

    private func executeInhibitCommand(inhibit: Bool, targetLimit: Int) -> Bool {
        guard let helperPath = resolveHelperBinaryPath() else {
            return false
        }

        let argInhibit = inhibit ? "1" : "0"
        let argLimit = String(targetLimit)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        process.arguments = ["-n", helperPath, "inhibit", argInhibit, argLimit]

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
            NSLog("[Harmonotch:ChargeLimiter] sudo -n failed: %@", error.localizedDescription)
        }

        // Fallback: check if standard third-party tools are installed (battery / smc)
        if executeThirdPartyFallback(inhibit: inhibit, targetLimit: targetLimit) {
            return true
        }

        return false
    }

    private func executeThirdPartyFallback(inhibit: Bool, targetLimit: Int) -> Bool {
        for path in ["/usr/local/bin/battery", "/opt/homebrew/bin/battery"] {
            if FileManager.default.isExecutableFile(atPath: path) {
                let proc = Process()
                proc.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
                proc.arguments = inhibit
                    ? ["-n", path, "charging", "off"]
                    : ["-n", path, "charging", "on"]
                if (try? proc.run()) != nil {
                    proc.waitUntilExit()
                    if proc.terminationStatus == 0 { return true }
                }
            }
        }

        for path in ["/usr/local/bin/smc", "/opt/homebrew/bin/smc"] {
            if FileManager.default.isExecutableFile(atPath: path) {
                let proc = Process()
                proc.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
                let hexVal = inhibit ? "02" : "00"
                proc.arguments = ["-n", path, "-k", "CH0B", "-w", hexVal]
                if (try? proc.run()) != nil {
                    proc.waitUntilExit()
                    if proc.terminationStatus == 0 { return true }
                }
            }
        }

        return false
    }

    // MARK: - Binary Helper Resolution & Compilation

    private func resolveHelperBinaryPath() -> String? {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let binDir = appSupport.appendingPathComponent("Harmonotch/bin", isDirectory: true)
        let helperBinary = binDir.appendingPathComponent("harmonotch-smc")

        if FileManager.default.isExecutableFile(atPath: helperBinary.path) {
            return helperBinary.path
        }

        try? FileManager.default.createDirectory(at: binDir, withIntermediateDirectories: true)

        let sourcePath: String?
        if let bundlePath = Bundle.main.path(forResource: "harmonotch-smc", ofType: "c") {
            sourcePath = bundlePath
        } else {
            let devPath = "/Users/ssajudn/projects/Harmonotch/Harmonotch/Features/Battery/Helper/harmonotch-smc.c"
            sourcePath = FileManager.default.fileExists(atPath: devPath) ? devPath : nil
        }

        guard let source = sourcePath else {
            NSLog("[Harmonotch:ChargeLimiter] Could not locate harmonotch-smc.c source")
            return nil
        }

        let clangProc = Process()
        clangProc.executableURL = URL(fileURLWithPath: "/usr/bin/clang")
        clangProc.arguments = ["-O2", "-DSTANDALONE_HELPER", "-framework", "IOKit", source, "-o", helperBinary.path]

        do {
            try clangProc.run()
            clangProc.waitUntilExit()
            if clangProc.terminationStatus == 0 && FileManager.default.isExecutableFile(atPath: helperBinary.path) {
                NSLog("[Harmonotch:ChargeLimiter] Successfully compiled harmonotch-smc at %@", helperBinary.path)
                return helperBinary.path
            }
        } catch {
            NSLog("[Harmonotch:ChargeLimiter] clang compilation failed: %@", error.localizedDescription)
        }

        return nil
    }

    // MARK: - Native macOS Limit Detection & Sync

    static func readNativeChargeLimit() -> Int? {
        if let cfVal = CFPreferencesCopyAppValue(
            "com.apple.batteryui.charging.mac.prior.limit" as CFString,
            "com.apple.batteryui.charging.mac" as CFString
        ) {
            if let num = cfVal as? NSNumber {
                let val = num.intValue
                if val >= 50 && val <= 100 {
                    return val
                }
            }
        }

        if let val = UserDefaults(suiteName: "com.apple.batteryui.charging.mac")?.object(forKey: "com.apple.batteryui.charging.mac.prior.limit") as? Int {
            if val >= 50 && val <= 100 {
                return val
            }
        }

        return nil
    }

    static func writeNativeChargeLimit(_ limit: Int) {
        let domain = "com.apple.batteryui.charging.mac" as CFString
        let key = "com.apple.batteryui.charging.mac.prior.limit" as CFString
        CFPreferencesSetAppValue(key, limit as CFNumber, domain)
        CFPreferencesAppSynchronize(domain)
    }

    // MARK: - Sudo Configuration

    func checkSudoConfiguration() {
        if UserDefaults.standard.bool(forKey: UserDefaultsKeys.chargeLimitSudoConfigured) {
            isSudoConfigured = true
            return
        }

        executionQueue.async { [weak self] in
            guard let self, let helperPath = self.resolveHelperBinaryPath() else { return }

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
            process.arguments = ["-n", "-l", "--", helperPath, "inhibit", "0", "100"]

            var configured = false
            do {
                try process.run()
                process.waitUntilExit()
                configured = (process.terminationStatus == 0)
            } catch {
                configured = false
            }

            DispatchQueue.main.async {
                if configured {
                    UserDefaults.standard.set(true, forKey: UserDefaultsKeys.chargeLimitSudoConfigured)
                }
                self.isSudoConfigured = configured
            }
        }
    }

    func setupPasswordlessSudo(completion: @escaping (Bool) -> Void) {
        isPerformingSetup = true
        executionQueue.async { [weak self] in
            guard let self, let helperPath = self.resolveHelperBinaryPath() else {
                DispatchQueue.main.async {
                    self?.isPerformingSetup = false
                    completion(false)
                }
                return
            }

            let escapedHelper = helperPath.replacingOccurrences(of: " ", with: "\\ ")
            let ruleContent = "%admin ALL=(ALL) NOPASSWD: /usr/bin/pmset -a disablesleep *, \(escapedHelper) *"

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
                self.isPerformingSetup = false
                self.isSudoConfigured = success
                UserDefaults.standard.set(success, forKey: UserDefaultsKeys.chargeLimitSudoConfigured)
                if success {
                    self.evaluateLimit()
                }
                completion(success)
            }
        }
    }

    // MARK: - Notifications

    private func sendLimitReachedNotification(capacity: Int) {
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = "Battery Charge Limit Reached"
        content.body = "Battery has reached \(capacity)%. Power is now drawn directly from the adapter to preserve battery health."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "Harmonotch_ChargeLimit_Reached",
            content: content,
            trigger: nil
        )

        center.add(request) { error in
            if let error {
                NSLog("[Harmonotch:ChargeLimiter] Notification error: %@", error.localizedDescription)
            }
        }
    }
}

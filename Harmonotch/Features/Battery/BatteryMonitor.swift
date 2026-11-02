import Foundation
import IOKit
import IOKit.ps
import Combine

final class BatteryMonitor: ObservableObject {
    static let shared = BatteryMonitor()

    private static let healthCacheDuration: TimeInterval = 300

    /// Dashboard-facing state. Stays `.loading` until the first read finishes, so
    /// no number is shown before it is real.
    @Published private(set) var state: DashboardDataState<BatteryReading> = .loading
    /// Set when the latest refresh failed while an earlier reading is still shown.
    @Published private(set) var refreshError: String? = nil
    @Published private(set) var isRefreshing = false

    // Legacy fields consumed by the notch pill, drawer and companion views.
    @Published var currentCapacity: Int = 100
    @Published var isCharging: Bool = false
    @Published var isPluggedIn: Bool = false
    @Published var powerSourceState: String = "Battery Power"
    @Published var healthPercent: Int = 100
    @Published var cycleCount: Int = 0
    @Published var maxCycleCount: Int = 1000
    @Published var nominalCapacity: Int = 0
    @Published var designCapacity: Int = 0
    @Published var timeRemainingFormatted: String = ""
    @Published var adapterWatts: Int? = nil
    @Published private(set) var hasBattery: Bool? = nil
    @Published private(set) var lastBatteryUpdate: Date? = nil

    private var refreshTimer: AnyCancellable?
    private var languageCancellable: AnyCancellable?
    private var powerSourceRunLoopSource: CFRunLoopSource?

    /// Probe work runs on one serial queue, so the health cache below needs no lock.
    private let probeQueue = DispatchQueue(label: "harmonotch.battery.probe", qos: .utility)
    private var lastHealthQueryTime: Date?
    private var cachedOfficialHealth: Int?
    private var pendingRefresh = false

    init() {
        refreshBatteryInfo()
        startPeriodicRefresh()
        observePowerSourceChanges()

        languageCancellable = NotificationCenter.default.publisher(for: .languageDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.applyLegacyFields()
            }
    }

    deinit {
        if let source = powerSourceRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode)
        }
    }

    static func localizedTimeEstimate(_ estimate: BatteryReading.TimeEstimate) -> String {
        switch estimate {
        case let .toEmpty(minutes):
            return L10n.Battery.timeRemaining(hours: minutes / 60, mins: minutes % 60)
        case let .toFull(minutes):
            return L10n.Battery.timeToFull(hours: minutes / 60, mins: minutes % 60)
        case .fullyCharged:
            return L10n.Battery.fullChargeAc
        case .pluggedIn:
            return L10n.Battery.connectedCharger
        case .onBattery:
            return L10n.Battery.onBattery
        }
    }

    private func observePowerSourceChanges() {
        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let source = IOPSNotificationCreateRunLoopSource({ context in
            guard let context else { return }
            let monitor = Unmanaged<BatteryMonitor>.fromOpaque(context).takeUnretainedValue()
            monitor.refreshBatteryInfo()
        }, context)?.takeRetainedValue() else { return }
        powerSourceRunLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
    }

    /// Expensive probe; the caller must go through `fetchOfficialHealthIfNeeded`.
    private func queryOfficialBatteryHealth() -> Int? {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        proc.arguments = ["SPPowerDataType"]
        let pipe = Pipe()
        proc.standardOutput = pipe
        do {
            try proc.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            proc.waitUntilExit()
            if let str = String(data: data, encoding: .utf8) {
                let pattern = "Maximum Capacity:\\s*(\\d+)%"
                if let regex = try? NSRegularExpression(pattern: pattern),
                   let match = regex.firstMatch(in: str, range: NSRange(str.startIndex..., in: str)),
                   let range = Range(match.range(at: 1), in: str),
                   let val = Int(str[range]) {
                    return val
                }
            }
        } catch {
            NSLog("[Harmonotch:Battery] Failed to query battery health: %@", error.localizedDescription)
        }
        return nil
    }

    /// Cached for `healthCacheDuration`, including failed probes, so a missing
    /// value never causes `system_profiler` to run on every refresh.
    private func fetchOfficialHealthIfNeeded() -> Int? {
        if let last = lastHealthQueryTime,
           Date().timeIntervalSince(last) < Self.healthCacheDuration {
            return cachedOfficialHealth
        }
        let official = queryOfficialBatteryHealth()
        lastHealthQueryTime = Date()
        if let official { cachedOfficialHealth = official }
        return cachedOfficialHealth
    }

    func startPeriodicRefresh() {
        guard refreshTimer == nil else { return }
        refreshTimer = Timer.publish(every: 30, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.refreshBatteryInfo()
            }
    }

    func stopPeriodicRefresh() {
        refreshTimer?.cancel()
        refreshTimer = nil
    }

    private enum ProbeResult {
        case reading(BatteryReading)
        case noBattery
        case failure(String)
    }

    func refreshBatteryInfo() {
        if Thread.isMainThread {
            beginRefresh()
        } else {
            DispatchQueue.main.async { [weak self] in self?.beginRefresh() }
        }
    }

    private func beginRefresh() {
        // Collapse overlapping triggers into at most one follow-up probe.
        guard !isRefreshing else {
            pendingRefresh = true
            return
        }
        isRefreshing = true
        probeQueue.async { [weak self] in
            guard let self else { return }
            let result = self.probe()
            DispatchQueue.main.async {
                self.apply(result)
                self.isRefreshing = false
                if self.pendingRefresh {
                    self.pendingRefresh = false
                    self.beginRefresh()
                }
            }
        }
    }

    private func probe() -> ProbeResult {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef] else {
            return .failure(L10n.Dashboard.batteryReadFailed)
        }

        var capacity: Int?
        var isCharging = false
        var powerState: String?
        var timeToEmpty: Int?
        var timeToFull: Int?
        var sawBattery = false

        for source in sources {
            guard let desc = IOPSGetPowerSourceDescription(blob, source)?.takeUnretainedValue() as? [String: Any],
                  (desc[kIOPSTypeKey] as? String) == kIOPSInternalBatteryType else { continue }
            sawBattery = true
            capacity = desc[kIOPSCurrentCapacityKey] as? Int
            if let charging = desc[kIOPSIsChargingKey] as? Bool {
                isCharging = charging
            } else if let chargingInt = desc[kIOPSIsChargingKey] as? Int {
                isCharging = chargingInt == 1
            }
            powerState = desc[kIOPSPowerSourceStateKey] as? String
            timeToEmpty = desc[kIOPSTimeToEmptyKey] as? Int
            timeToFull = desc[kIOPSTimeToFullChargeKey] as? Int
        }

        guard sawBattery else { return .noBattery }
        guard let capacity else { return .failure(L10n.Dashboard.batteryReadFailed) }

        let source: BatteryReading.PowerSource
        switch powerState {
        case kIOPSACPowerValue: source = .ac
        case kIOPSBatteryPowerValue: source = .battery
        default: source = .unknown
        }
        let plugged = source == .ac

        var reading = BatteryReading(
            capacity: capacity,
            isCharging: isCharging,
            powerSource: source,
            timeEstimate: BatteryReading.timeEstimate(
                capacity: capacity,
                isCharging: isCharging,
                isPluggedIn: plugged,
                timeToEmptyMinutes: timeToEmpty,
                timeToFullMinutes: timeToFull
            ),
            refreshedAt: Date()
        )

        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        if service != 0 {
            defer { IOObjectRelease(service) }
            var props: Unmanaged<CFMutableDictionary>?
            if IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
               let dict = props?.takeRetainedValue() as? [String: Any] {
                reading.cycleCount = dict["CycleCount"] as? Int
                reading.designCycleCount = dict["DesignCycleCount9C"] as? Int

                if let bData = dict["BatteryData"] as? [String: Any] {
                    reading.nominalCapacity = (bData["NominalChargeCapacity"] as? Int) ?? (bData["FullChargeCapacity"] as? Int)
                    reading.designCapacity = bData["DesignCapacity"] as? Int
                }
                reading.healthPercent = BatteryReading.healthPercent(
                    nominal: reading.nominalCapacity,
                    design: reading.designCapacity
                )
                if let official = fetchOfficialHealthIfNeeded() {
                    reading.healthPercent = official
                }

                if let adapter = dict["AdapterDetails"] as? [String: Any],
                   let watts = adapter["Watts"] as? Int, watts > 0 {
                    reading.adapterWatts = watts
                }

                if let millivolts = (dict["Voltage"] as? NSNumber)?.intValue, millivolts > 0 {
                    reading.voltageVolts = Double(millivolts) / 1000
                }
                if let raw = dict["Amperage"] as? NSNumber {
                    reading.amperageAmps = Double(BatteryReading.signedMilliamps(raw.uint64Value)) / 1000
                }
                // Reported in hundredths of a degree Celsius.
                if let centi = (dict["Temperature"] as? NSNumber)?.intValue, centi > 0 {
                    reading.temperatureCelsius = Double(centi) / 100
                }
            }
        }

        return .reading(reading)
    }

    private func apply(_ result: ProbeResult) {
        switch result {
        case let .reading(reading):
            hasBattery = true
            refreshError = nil
            lastBatteryUpdate = reading.refreshedAt
            state = .loaded(reading, refreshedAt: reading.refreshedAt)
        case .noBattery:
            hasBattery = false
            refreshError = nil
            state = .unavailable(L10n.Dashboard.noInternalBattery)
        case let .failure(message):
            // Keep the last known reading visible; the UI marks it with the error.
            if case .loaded = state {
                refreshError = message
            } else {
                state = .failed(message)
            }
        }
        applyLegacyFields()
    }

    private func applyLegacyFields() {
        guard case let .loaded(reading, _) = state else { return }
        if currentCapacity != reading.capacity { currentCapacity = reading.capacity }
        if isCharging != reading.isCharging { isCharging = reading.isCharging }
        if isPluggedIn != reading.isPluggedIn { isPluggedIn = reading.isPluggedIn }
        let newPowerSourceState = reading.isPluggedIn ? "AC Power" : "Battery Power"
        if powerSourceState != newPowerSourceState { powerSourceState = newPowerSourceState }
        let newTimeFormatted = Self.localizedTimeEstimate(reading.timeEstimate)
        if timeRemainingFormatted != newTimeFormatted { timeRemainingFormatted = newTimeFormatted }
        if let health = reading.healthPercent, healthPercent != health { healthPercent = health }
        if let cycles = reading.cycleCount, cycleCount != cycles { cycleCount = cycles }
        if let maxCycles = reading.designCycleCount, maxCycleCount != maxCycles { maxCycleCount = maxCycles }
        if let nominal = reading.nominalCapacity, nominalCapacity != nominal { nominalCapacity = nominal }
        if let design = reading.designCapacity, designCapacity != design { designCapacity = design }
        if adapterWatts != reading.adapterWatts { adapterWatts = reading.adapterWatts }
    }
}

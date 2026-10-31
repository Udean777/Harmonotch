import Foundation
import IOKit
import IOKit.ps
import Combine

private enum TimeRemaining {
    case toEmpty(hours: Int, mins: Int)
    case toFull(hours: Int, mins: Int)
    case fullChargeAC
    case connectedCharger
    case onBattery

    var localized: String {
        switch self {
        case let .toEmpty(hours, mins):
            return L10n.Battery.timeRemaining(hours: hours, mins: mins)
        case let .toFull(hours, mins):
            return L10n.Battery.timeToFull(hours: hours, mins: mins)
        case .fullChargeAC:
            return L10n.Battery.fullChargeAc
        case .connectedCharger:
            return L10n.Battery.connectedCharger
        case .onBattery:
            return L10n.Battery.onBattery
        }
    }
}

final class BatteryMonitor: ObservableObject {
    static let shared = BatteryMonitor()

    private static let healthCacheDuration: TimeInterval = 300
    private static let fullChargeACThreshold = 95

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

    private var refreshTimer: AnyCancellable?
    private var languageCancellable: AnyCancellable?
    private var lastHealthQueryTime: Date?
    private var cachedOfficialHealth: Int?

    init() {
        refreshBatteryInfo()
        startPeriodicRefresh()

        languageCancellable = NotificationCenter.default.publisher(for: .languageDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshBatteryInfo()
            }
    }

    private func queryOfficialBatteryHealth() -> Int? {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        proc.arguments = ["SPPowerDataType"]
        let pipe = Pipe()
        proc.standardOutput = pipe
        do {
            try proc.run()
            proc.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
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
            return nil
        }
        return nil
    }

    private func fetchOfficialHealthIfNeeded() -> Int? {
        if let cached = cachedOfficialHealth,
           let last = lastHealthQueryTime,
           Date().timeIntervalSince(last) < Self.healthCacheDuration {
            return cached
        }
        if let official = queryOfficialBatteryHealth() {
            cachedOfficialHealth = official
            lastHealthQueryTime = Date()
            return official
        }
        return cachedOfficialHealth
    }

    func startPeriodicRefresh() {
        refreshTimer = Timer.publish(every: 30, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.refreshBatteryInfo()
            }
    }

    func refreshBatteryInfo() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }

            var newCurrentCapacity: Int?
            var newIsCharging: Bool?
            var newIsPluggedIn: Bool?
            var newPowerSourceState: String?
            var newTimeRemaining: TimeRemaining?

            var newCycleCount: Int?
            var newMaxCycleCount: Int?
            var newNominalCapacity: Int?
            var newDesignCapacity: Int?
            var newHealthPercent: Int?
            var newAdapterWatts: Int?

            if let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
               let sources = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef] {
                for source in sources {
                    if let desc = IOPSGetPowerSourceDescription(blob, source)?.takeUnretainedValue() as? [String: Any] {
                        if let cap = desc[kIOPSCurrentCapacityKey] as? Int {
                            newCurrentCapacity = cap
                        }
                        if let charging = desc[kIOPSIsChargingKey] as? Bool {
                            newIsCharging = charging
                        } else if let chargingInt = desc[kIOPSIsChargingKey] as? Int {
                            newIsCharging = chargingInt == 1
                        }
                        if let state = desc[kIOPSPowerSourceStateKey] as? String {
                            newPowerSourceState = state
                            newIsPluggedIn = (state == kIOPSACPowerValue)
                        }

                        let cap = newCurrentCapacity ?? self.currentCapacity
                        let plugged = newIsPluggedIn ?? self.isPluggedIn
                        let charging = newIsCharging ?? self.isCharging

                        // Only capture numbers here; L10n state must be read on the main thread.
                        if let timeToEmpty = desc[kIOPSTimeToEmptyKey] as? Int, timeToEmpty > 0, !plugged {
                            newTimeRemaining = .toEmpty(hours: timeToEmpty / 60, mins: timeToEmpty % 60)
                        } else if let timeToFull = desc[kIOPSTimeToFullChargeKey] as? Int, timeToFull > 0, charging {
                            newTimeRemaining = .toFull(hours: timeToFull / 60, mins: timeToFull % 60)
                        } else if plugged && !charging && cap >= Self.fullChargeACThreshold {
                            newTimeRemaining = .fullChargeAC
                        } else {
                            newTimeRemaining = plugged ? .connectedCharger : .onBattery
                        }
                    }
                }
            }

            let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
            if service != 0 {
                var props: Unmanaged<CFMutableDictionary>?
                if IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
                   let dict = props?.takeRetainedValue() as? [String: Any] {

                    if let cycle = dict["CycleCount"] as? Int {
                        newCycleCount = cycle
                    }
                    if let designCycle = dict["DesignCycleCount9C"] as? Int {
                        newMaxCycleCount = designCycle
                    }

                    if let bData = dict["BatteryData"] as? [String: Any] {
                        let nominal = (bData["NominalChargeCapacity"] as? Int) ?? (bData["FullChargeCapacity"] as? Int) ?? 0
                        let design = bData["DesignCapacity"] as? Int ?? 0

                        if nominal > 0 && design > 0 {
                            newNominalCapacity = nominal
                            newDesignCapacity = design
                            let calculatedHealth = Int(round((Double(nominal) / Double(design)) * 100.0))
                            newHealthPercent = min(100, max(0, calculatedHealth))
                        }
                    }

                    if let official = self.fetchOfficialHealthIfNeeded() {
                        newHealthPercent = official
                    }

                    if let adapter = dict["AdapterDetails"] as? [String: Any], let watts = adapter["Watts"] as? Int {
                        newAdapterWatts = watts
                    }
                }
                IOObjectRelease(service)
            }

            DispatchQueue.main.async {
                if let cap = newCurrentCapacity { self.currentCapacity = cap }
                if let charging = newIsCharging { self.isCharging = charging }
                if let plugged = newIsPluggedIn { self.isPluggedIn = plugged }
                if let state = newPowerSourceState { self.powerSourceState = state }
                if let tr = newTimeRemaining { self.timeRemainingFormatted = tr.localized }
                if let cycle = newCycleCount { self.cycleCount = cycle }
                if let maxCycle = newMaxCycleCount { self.maxCycleCount = maxCycle }
                if let nominal = newNominalCapacity { self.nominalCapacity = nominal }
                if let design = newDesignCapacity { self.designCapacity = design }
                if let health = newHealthPercent { self.healthPercent = health }
                if let watts = newAdapterWatts { self.adapterWatts = watts }
            }
        }
    }
}

//
//  BatteryMonitor.swift
//  Harmonotch
//

import Foundation
import IOKit
import IOKit.ps
import Combine

final class BatteryMonitor: ObservableObject {
    static let shared = BatteryMonitor()

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
    @Published var conditionString: String = "Normal"
    @Published var adapterWatts: Int? = nil

    private var refreshTimer: AnyCancellable?
    private var languageCancellable: AnyCancellable?

    init() {
        refreshBatteryInfo()
        startPeriodicRefresh()

        languageCancellable = NotificationCenter.default.publisher(for: .languageDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshBatteryInfo()
            }
    }

    func startPeriodicRefresh() {
        // Refresh tiap 30 detik untuk menghemat daya
        refreshTimer = Timer.publish(every: 30, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.refreshBatteryInfo()
            }
    }

    func refreshBatteryInfo() {
        // 1. Ambil data dari IOPowerSources
        if let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
           let sources = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef] {
            for source in sources {
                if let desc = IOPSGetPowerSourceDescription(blob, source)?.takeUnretainedValue() as? [String: Any] {
                    if let cap = desc[kIOPSCurrentCapacityKey] as? Int {
                        self.currentCapacity = cap
                    }
                    if let charging = desc[kIOPSIsChargingKey] as? Bool {
                        self.isCharging = charging
                    } else if let chargingInt = desc[kIOPSIsChargingKey] as? Int {
                        self.isCharging = chargingInt == 1
                    }
                    if let state = desc[kIOPSPowerSourceStateKey] as? String {
                        self.powerSourceState = state
                        self.isPluggedIn = (state == kIOPSACPowerValue)
                    }
                    if let timeToEmpty = desc[kIOPSTimeToEmptyKey] as? Int, timeToEmpty > 0, !isPluggedIn {
                        let hours = timeToEmpty / 60
                        let mins = timeToEmpty % 60
                        self.timeRemainingFormatted = L10n.Battery.timeRemaining(hours: hours, mins: mins)
                    } else if let timeToFull = desc[kIOPSTimeToFullChargeKey] as? Int, timeToFull > 0, isCharging {
                        let hours = timeToFull / 60
                        let mins = timeToFull % 60
                        self.timeRemainingFormatted = L10n.Battery.timeToFull(hours: hours, mins: mins)
                    } else if isPluggedIn && !isCharging && currentCapacity >= 95 {
                        self.timeRemainingFormatted = L10n.Battery.fullChargeAc
                    } else {
                        self.timeRemainingFormatted = isPluggedIn ? L10n.Battery.connectedCharger : L10n.Battery.onBattery
                    }
                }
            }
        }

        // 2. Ambil data detail dari AppleSmartBattery (Cycle, Health, Capacity)
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        if service != 0 {
            var props: Unmanaged<CFMutableDictionary>?
            if IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
               let dict = props?.takeRetainedValue() as? [String: Any] {

                if let cycle = dict["CycleCount"] as? Int {
                    self.cycleCount = cycle
                }
                if let designCycle = dict["DesignCycleCount9C"] as? Int {
                    self.maxCycleCount = designCycle
                }

                // Apple Silicon BatteryData dictionary
                if let bData = dict["BatteryData"] as? [String: Any] {
                    let nominal = (bData["NominalChargeCapacity"] as? Int) ?? (bData["FullChargeCapacity"] as? Int) ?? 0
                    let design = bData["DesignCapacity"] as? Int ?? 0

                    if nominal > 0 && design > 0 {
                        self.nominalCapacity = nominal
                        self.designCapacity = design
                        let calculatedHealth = Int(round((Double(nominal) / Double(design)) * 100.0))
                        self.healthPercent = min(100, max(0, calculatedHealth))
                    }
                }

                // Adapter details
                if let adapter = dict["AdapterDetails"] as? [String: Any], let watts = adapter["Watts"] as? Int {
                    self.adapterWatts = watts
                }
            }
            IOObjectRelease(service)
        }
    }
}

import Foundation

public struct UserDefaultsKey<Value>: Hashable, CustomStringConvertible {
    public let name: String
    public let defaultValue: Value

    public var description: String { name }

    public init(name: String, defaultValue: Value) {
        self.name = name
        self.defaultValue = defaultValue
    }

    public init(_ name: String, defaultValue: Value) {
        self.name = name
        self.defaultValue = defaultValue
    }

    public static func == (lhs: UserDefaultsKey<Value>, rhs: UserDefaultsKey<Value>) -> Bool {
        lhs.name == rhs.name
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
}

enum UserDefaultsKeys {
    static let isNotchHidden = UserDefaultsKey<Bool>(name: "Harmonotch_IsNotchHidden", defaultValue: false)
    static let selectedCityId = UserDefaultsKey<String>(name: "Harmonotch_SelectedCityId", defaultValue: "jkt")
    static let useGPS = UserDefaultsKey<Bool>(name: "Harmonotch_UseGPS", defaultValue: false)
    static let jumatOffsetMinutes = UserDefaultsKey<Int>(name: "Harmonotch_JumatOffsetMinutes", defaultValue: 0)
    static let adzanVolume = UserDefaultsKey<Float>(name: "Harmonotch_AdzanVolume", defaultValue: 0.85)
    static let adzanMuted = UserDefaultsKey<Bool>(name: "Harmonotch_AdzanMuted", defaultValue: false)
    static let clamshellArmed = UserDefaultsKey<Bool>(name: "Harmonotch_ClamshellArmed", defaultValue: false)
    static let clamshellOverrideOwned = UserDefaultsKey<Bool>(name: "Harmonotch_ClamshellOverrideOwned", defaultValue: false)
    static let clamshellLastKnownDisabled = UserDefaultsKey<Bool>(name: "Harmonotch_ClamshellLastKnownDisabled", defaultValue: false)
    // Kept only for legacy migration; ClamshellManager no longer reads or writes this key.
    static let sudoConfigured = UserDefaultsKey<Bool>(name: "Harmonotch_SudoConfigured", defaultValue: false)
    static let chargeLimitEnabled = UserDefaultsKey<Bool>(name: "Harmonotch_ChargeLimitEnabled", defaultValue: false)
    static let chargeLimitThreshold = UserDefaultsKey<Int>(name: "Harmonotch_ChargeLimitThreshold", defaultValue: 80)
    static let chargeLimitSudoConfigured = UserDefaultsKey<Bool>(name: "Harmonotch_ChargeLimitSudoConfigured", defaultValue: false)
    static let volumeHUDEnabled = UserDefaultsKey<Bool>(name: "Harmonotch_VolumeHUDEnabled", defaultValue: false)
    static let includeOtherAudioApps = UserDefaultsKey<Bool>(name: "Harmonotch_IncludeOtherAudioApps", defaultValue: true)
    static let notchAIAgentFilter = UserDefaultsKey<String>(name: "Harmonotch_NotchAIAgentFilter", defaultValue: "all")
    static let selectedNotchAIAgent = UserDefaultsKey<String>(name: "Harmonotch_SelectedNotchAIAgent", defaultValue: "gemini")
}

extension Notification.Name {
    static let notchAIAgentChanged = Notification.Name("Harmonotch_NotchAIAgentChanged")
}

extension UserDefaults {
    subscript(key: UserDefaultsKey<Bool>) -> Bool {
        get {
            object(forKey: key.name) as? Bool ?? key.defaultValue
        }
        set {
            set(newValue, forKey: key.name)
        }
    }

    subscript(key: UserDefaultsKey<Int>) -> Int {
        get {
            object(forKey: key.name) as? Int ?? key.defaultValue
        }
        set {
            set(newValue, forKey: key.name)
        }
    }

    subscript(key: UserDefaultsKey<Float>) -> Float {
        get {
            object(forKey: key.name) as? Float ?? key.defaultValue
        }
        set {
            set(newValue, forKey: key.name)
        }
    }

    subscript(key: UserDefaultsKey<Double>) -> Double {
        get {
            object(forKey: key.name) as? Double ?? key.defaultValue
        }
        set {
            set(newValue, forKey: key.name)
        }
    }

    subscript(key: UserDefaultsKey<String>) -> String {
        get {
            string(forKey: key.name) ?? key.defaultValue
        }
        set {
            set(newValue, forKey: key.name)
        }
    }

    subscript<T: RawRepresentable>(key: UserDefaultsKey<T>) -> T where T.RawValue == String {
        get {
            guard let raw = string(forKey: key.name), let value = T(rawValue: raw) else {
                return key.defaultValue
            }
            return value
        }
        set {
            set(newValue.rawValue, forKey: key.name)
        }
    }

    func contains<T>(_ key: UserDefaultsKey<T>) -> Bool {
        object(forKey: key.name) != nil
    }

    func remove<T>(_ key: UserDefaultsKey<T>) {
        removeObject(forKey: key.name)
    }
}

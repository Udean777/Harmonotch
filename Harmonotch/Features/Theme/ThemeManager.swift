import SwiftUI
import AppKit
import Combine

enum ThemeStyle: String, CaseIterable, Identifiable {
    case liquidGlass = "liquidGlass"
    case zenSerenity = "zenSerenity"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .liquidGlass:
            return "drop.fill"
        case .zenSerenity:
            return "leaf.fill"
        }
    }
}

enum AppThemeMode: String, CaseIterable, Identifiable {
    case system = "system"
    case dark = "dark"
    case light = "light"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .system:
            return "display"
        case .dark:
            return "moon.fill"
        case .light:
            return "sun.max.fill"
        }
    }
}

final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    private let themeKey = "Harmonotch_AppTheme"
    private let styleKey = "Harmonotch_ThemeStyle"

    @Published var currentStyle: ThemeStyle {
        didSet {
            UserDefaults.standard.set(currentStyle.rawValue, forKey: styleKey)
        }
    }

    @Published var currentMode: AppThemeMode {
        didSet {
            UserDefaults.standard.set(currentMode.rawValue, forKey: themeKey)
            updateEffectiveAppearance()
        }
    }

    @Published private(set) var isDarkMode: Bool = true

    private var cancellables = Set<AnyCancellable>()

    private init() {
        let savedStyle = UserDefaults.standard.string(forKey: styleKey) ?? ThemeStyle.liquidGlass.rawValue
        self.currentStyle = ThemeStyle(rawValue: savedStyle) ?? .liquidGlass

        let saved = UserDefaults.standard.string(forKey: themeKey) ?? AppThemeMode.system.rawValue
        self.currentMode = AppThemeMode(rawValue: saved) ?? .system

        updateEffectiveAppearance()
        observeSystemThemeChanges()
    }

    var colorScheme: ColorScheme? {
        switch currentMode {
        case .system:
            return nil
        case .dark:
            return .dark
        case .light:
            return .light
        }
    }

    func setThemeStyle(_ style: ThemeStyle) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            self.currentStyle = style
        }
    }

    func setTheme(_ mode: AppThemeMode) {
        withAnimation(.easeInOut(duration: 0.25)) {
            self.currentMode = mode
        }
    }

    func toggleTheme() {
        switch currentMode {
        case .system:
            setTheme(.dark)
        case .dark:
            setTheme(.light)
        case .light:
            setTheme(.system)
        }
    }

    private func updateEffectiveAppearance() {
        switch currentMode {
        case .dark:
            isDarkMode = true
        case .light:
            isDarkMode = false
        case .system:
            isDarkMode = detectSystemDarkMode()
        }
    }

    private func detectSystemDarkMode() -> Bool {
        if let appearance = NSApp?.effectiveAppearance {
            let match = appearance.bestMatch(from: [.darkAqua, .aqua])
            return match == .darkAqua
        }
        return true
    }

    private func observeSystemThemeChanges() {
        // macOS notification saat user mengganti Dark / Light mode di System Settings
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            if self.currentMode == .system {
                withAnimation(.easeInOut(duration: 0.25)) {
                    self.isDarkMode = self.detectSystemDarkMode()
                }
            }
        }
    }
}

import AppKit
import Combine
import SwiftUI

enum ThemeStyle: String, CaseIterable, Identifiable {
  case monochrome = "monochrome"
  case catppuccin = "catppuccin"

  var id: String { rawValue }
}

enum AppThemeMode: String, CaseIterable, Identifiable {
  case system = "system"
  case dark = "dark"
  case light = "light"

  var id: String { rawValue }
}

extension UserDefaultsKeys {
  static let themeStyle = UserDefaultsKey<ThemeStyle>(name: "Harmonotch_ThemeStyle", defaultValue: .monochrome)
  static let themeMode = UserDefaultsKey<AppThemeMode>(name: "Harmonotch_AppTheme", defaultValue: .system)
}

final class ThemeManager: ObservableObject {
  static let shared = ThemeManager()

  @Published var currentStyle: ThemeStyle {
    didSet {
      UserDefaults.standard[UserDefaultsKeys.themeStyle] = currentStyle
    }
  }

  @Published var currentMode: AppThemeMode {
    didSet {
      UserDefaults.standard[UserDefaultsKeys.themeMode] = currentMode
      updateEffectiveAppearance()
    }
  }

  @Published private(set) var isDarkMode: Bool = true

  private var cancellables = Set<AnyCancellable>()

  private init() {
    // Monochrome is the only user-facing style. Keep the persisted key for a
    // future style system without allowing an old selection to change the UI.
    self.currentStyle = .monochrome
    UserDefaults.standard[UserDefaultsKeys.themeStyle] = .monochrome
    self.currentMode = UserDefaults.standard[UserDefaultsKeys.themeMode]

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

  func setStyle(_ style: ThemeStyle) {
    currentStyle = style
  }

  func setMode(_ mode: AppThemeMode) {
    currentMode = mode
  }

  private func updateEffectiveAppearance() {
    switch currentMode {
    case .system:
      isDarkMode = detectSystemDarkMode()
    case .dark:
      isDarkMode = true
    case .light:
      isDarkMode = false
    }

    if let app = NSApp {
      switch currentMode {
      case .system:
        app.appearance = nil
      case .dark:
        app.appearance = NSAppearance(named: .darkAqua)
      case .light:
        app.appearance = NSAppearance(named: .aqua)
      }
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
    // System Settings posts this when the user changes Dark / Light mode
    DistributedNotificationCenter.default().addObserver(
      forName: .appleInterfaceThemeChanged,
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

extension Notification.Name {
  static let appleInterfaceThemeChanged = Notification.Name("AppleInterfaceThemeChangedNotification")
}

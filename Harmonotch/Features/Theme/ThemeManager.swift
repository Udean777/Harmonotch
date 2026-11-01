import AppKit
import Combine
import SwiftUI

enum ThemeStyle: String, CaseIterable, Identifiable {
  case monochrome = "monochrome"
  case catppuccin = "catppuccin"

  var id: String { rawValue }

  var displayName: String {
    switch self {
    case .monochrome:
      return "Monochrome"
    case .catppuccin:
      return "Catppuccin"
    }
  }

  var icon: String {
    switch self {
    case .monochrome:
      return "circle.lefthalf.filled"
    case .catppuccin:
      return "paintpalette.fill"
    }
  }
}

enum AppThemeMode: String, CaseIterable, Identifiable {
  case system = "system"
  case dark = "dark"
  case light = "light"

  var id: String { rawValue }

  var displayName: String {
    switch self {
    case .system:
      return "System"
    case .dark:
      return "Dark"
    case .light:
      return "Light"
    }
  }

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

  @Published var currentStyle: ThemeStyle {
    didSet {
      UserDefaults.standard.set(currentStyle.rawValue, forKey: UserDefaultsKeys.themeStyle)
    }
  }

  @Published var currentMode: AppThemeMode {
    didSet {
      UserDefaults.standard.set(currentMode.rawValue, forKey: UserDefaultsKeys.themeMode)
      updateEffectiveAppearance()
    }
  }

  @Published private(set) var isDarkMode: Bool = true

  private var cancellables = Set<AnyCancellable>()

  private init() {
    // Monochrome is the only user-facing style. Keep the persisted key for a
    // future style system without allowing an old selection to change the UI.
    self.currentStyle = .monochrome
    UserDefaults.standard.set(ThemeStyle.monochrome.rawValue, forKey: UserDefaultsKeys.themeStyle)

    let saved =
      UserDefaults.standard.string(forKey: UserDefaultsKeys.themeMode)
      ?? AppThemeMode.system.rawValue
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
    // System Settings posts this when the user changes Dark / Light mode
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

import SwiftUI

import AppKit
import SwiftUI

struct AppTheme {
  static var isDark: Bool {
    ThemeManager.shared.isDarkMode
  }

  // MARK: - Surfaces & Backgrounds (Soft, Eye-Friendly Palette)

  /// Main window/container surface:
  /// Dark: Pure black for seamless physical Notch integration.
  /// Light: Warm soft paper white (#F6F6F8) rather than harsh blinding pure white.
  static var surfaceBackground: Color {
    Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
      appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        ? .black
        : NSColor(srgbRed: 0.965, green: 0.965, blue: 0.972, alpha: 1.0)
    }))
  }

  /// Subtle container outline.
  static var surfaceBorder: Color {
    Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
      appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        ? NSColor(white: 1.0, alpha: 0.12)
        : NSColor(white: 0.0, alpha: 0.10)
    }))
  }

  /// Cards embedded inside dashboard/drawer:
  /// Dark: Soft dark graphite (#1A1A1E) instead of pitch black.
  /// Light: Gentle muted background (#ECECEF) reducing glare.
  static var cardBackground: Color {
    Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
      appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        ? NSColor(srgbRed: 0.102, green: 0.102, blue: 0.118, alpha: 1.0)
        : NSColor(srgbRed: 0.925, green: 0.925, blue: 0.938, alpha: 1.0)
    }))
  }

  /// Gentle card border.
  static var cardBorder: Color {
    Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
      appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        ? NSColor(white: 1.0, alpha: 0.12)
        : NSColor(white: 0.0, alpha: 0.10)
    }))
  }

  /// Interactive chips, icon containers, and badges: soft matte fill.
  static var badgeBackground: Color {
    Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
      appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        ? NSColor(srgbRed: 0.155, green: 0.155, blue: 0.175, alpha: 1.0)
        : NSColor(srgbRed: 0.865, green: 0.865, blue: 0.885, alpha: 1.0)
    }))
  }

  /// Dividers separating sections.
  static var divider: Color {
    Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
      appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        ? NSColor(white: 1.0, alpha: 0.10)
        : NSColor(white: 0.0, alpha: 0.08)
    }))
  }

  // MARK: - Typography & Labels (Comfortable Reading, Zero Glare)

  /// Primary text:
  /// Dark: Calming soft white (#D8D8DC) rather than sharp 100% white.
  /// Light: Gentle deep charcoal (#28282C) rather than stark 100% black.
  static var textPrimary: Color {
    Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
      appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        ? NSColor(srgbRed: 0.85, green: 0.85, blue: 0.87, alpha: 1.0)
        : NSColor(srgbRed: 0.16, green: 0.16, blue: 0.18, alpha: 1.0)
    }))
  }

  /// Secondary text: muted, soothing tone.
  static var textSecondary: Color {
    Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
      appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        ? NSColor(srgbRed: 0.62, green: 0.62, blue: 0.66, alpha: 1.0)
        : NSColor(srgbRed: 0.38, green: 0.38, blue: 0.42, alpha: 1.0)
    }))
  }

  /// Tertiary supporting metadata: subtle, calm tone.
  static var textTertiary: Color {
    Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
      appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        ? NSColor(srgbRed: 0.52, green: 0.52, blue: 0.56, alpha: 1.0)
        : NSColor(srgbRed: 0.46, green: 0.46, blue: 0.50, alpha: 1.0)
    }))
  }

  // MARK: - Soft System Theme Accent Color (Follows macOS Accent Color)

  /// The active macOS accent color set in System Settings, softened to avoid eye fatigue.
  static var accent: Color {
    Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
      let base = NSColor.controlAccentColor.usingColorSpace(.sRGB) ?? NSColor.systemBlue
      if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
        // Soften slightly with warm white tone so it does not feel neon in dark mode
        return base.blended(withFraction: 0.18, of: NSColor(white: 0.95, alpha: 1.0)) ?? base
      } else {
        // Comfortably saturated in light mode so it does not glow or strain
        return base.blended(withFraction: 0.20, of: NSColor(white: 0.08, alpha: 1.0)) ?? base
      }
    }))
  }

  /// Warning / Pending / Prayer highlight follows the softened macOS Accent Color.
  static var accentAmber: Color {
    accent
  }

  /// Success / Charging / Active status follows the softened macOS Accent Color.
  static var accentGreen: Color {
    accent
  }

  /// Info / Current / System highlight follows the softened macOS Accent Color.
  static var accentCyan: Color {
    accent
  }

  /// High priority / Destructive status (softened systemRed that does not hurt the eyes).
  static var accentRed: Color {
    Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
      appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        ? NSColor(srgbRed: 0.92, green: 0.38, blue: 0.40, alpha: 1.0)
        : NSColor(srgbRed: 0.78, green: 0.16, blue: 0.20, alpha: 1.0)
    }))
  }

  // MARK: - Tab Bar Navigation

  static var tabBarBackground: Color {
    Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
      appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        ? NSColor(srgbRed: 0.09, green: 0.09, blue: 0.10, alpha: 1.0)
        : NSColor(srgbRed: 0.90, green: 0.90, blue: 0.92, alpha: 1.0)
    }))
  }

  static var tabActiveBackground: Color {
    Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
      appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        ? NSColor(white: 0.20, alpha: 1.0)
        : NSColor(white: 0.98, alpha: 1.0)
    }))
  }

  static var tabActiveText: Color {
    textPrimary
  }

  static var tabInactiveText: Color {
    textSecondary
  }
}

enum AppTypography {
  static func micro(_ weight: Font.Weight = .medium, design: Font.Design = .default) -> Font {
    .system(size: 10, weight: weight, design: design)
  }

  static func caption2(_ weight: Font.Weight = .medium, design: Font.Design = .default) -> Font {
    .system(size: 10.5, weight: weight, design: design)
  }

  static func caption(_ weight: Font.Weight = .medium, design: Font.Design = .default) -> Font {
    .system(size: 11, weight: weight, design: design)
  }

  static func footnote(_ weight: Font.Weight = .medium, design: Font.Design = .default) -> Font {
    .system(size: 11.5, weight: weight, design: design)
  }

  static func subheadline(_ weight: Font.Weight = .medium, design: Font.Design = .default) -> Font {
    .system(size: 12, weight: weight, design: design)
  }

  static func body(_ weight: Font.Weight = .medium, design: Font.Design = .default) -> Font {
    .system(size: 13, weight: weight, design: design)
  }
}

private struct CardChromeModifier: ViewModifier {
  let cornerRadius: CGFloat
  let horizontalPadding: CGFloat?
  let verticalPadding: CGFloat?
  let lineWidth: CGFloat

  func body(content: Content) -> some View {
    content
      .padding(.horizontal, horizontalPadding ?? 0)
      .padding(.vertical, verticalPadding ?? 0)
      .background(
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
          .fill(AppTheme.cardBackground)
          .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
              .stroke(AppTheme.cardBorder, lineWidth: lineWidth)
          )
      )
  }
}

private struct LocalizedThemedRootModifier: ViewModifier {
  @ObservedObject private var themeManager = ThemeManager.shared
  @ObservedObject private var languageManager = LanguageManager.shared

  func body(content: Content) -> some View {
    content
      .environmentObject(themeManager)
      .environmentObject(languageManager)
      .environment(\.locale, Locale(identifier: languageManager.currentLanguage.rawValue))
      .preferredColorScheme(themeManager.colorScheme)
  }
}

extension View {
  func cardChrome(
    cornerRadius: CGFloat = 10,
    padding: CGFloat? = nil,
    horizontalPadding: CGFloat? = nil,
    verticalPadding: CGFloat? = nil,
    lineWidth: CGFloat = 0.6
  ) -> some View {
    modifier(
      CardChromeModifier(
        cornerRadius: cornerRadius,
        horizontalPadding: horizontalPadding ?? padding,
        verticalPadding: verticalPadding ?? padding,
        lineWidth: lineWidth
      )
    )
  }

  func localizedThemedRoot() -> some View {
    modifier(LocalizedThemedRootModifier())
  }
}

import SwiftUI

struct ThemePalette {
  let surfaceBackground: Color
  let surfaceBorder: Color
  let cardBackground: Color
  let cardBorder: Color
  let badgeBackground: Color
  let divider: Color
  let textPrimary: Color
  let textSecondary: Color
  let textTertiary: Color
  let accentAmber: Color
  let accentGreen: Color
  let accentCyan: Color
  let accentRed: Color
  let tabBarBackground: Color
  let tabActiveBackground: Color
  let tabActiveText: Color
  let tabInactiveText: Color
}

struct AppTheme {
  static var isDark: Bool {
    ThemeManager.shared.isDarkMode
  }

  private static var palette: ThemePalette {
    switch ThemeManager.shared.currentStyle {
    case .monochrome:
      return isDark ? .monochromeDark : .monochromeLight
    case .catppuccin:
      return isDark ? .catppuccinMocha : .catppuccinLatte
    }
  }

  static var surfaceBackground: Color { palette.surfaceBackground }
  static var surfaceBorder: Color { palette.surfaceBorder }
  static var cardBackground: Color { palette.cardBackground }
  static var cardBorder: Color { palette.cardBorder }
  static var badgeBackground: Color { palette.badgeBackground }
  static var divider: Color { palette.divider }
  static var textPrimary: Color { palette.textPrimary }
  static var textSecondary: Color { palette.textSecondary }
  static var textTertiary: Color { palette.textTertiary }
  static var accentAmber: Color { palette.accentAmber }
  static var accentGreen: Color { palette.accentGreen }
  static var accentCyan: Color { palette.accentCyan }
  static var accentRed: Color { palette.accentRed }
  static var tabBarBackground: Color { palette.tabBarBackground }
  static var tabActiveBackground: Color { palette.tabActiveBackground }
  static var tabActiveText: Color { palette.tabActiveText }
  static var tabInactiveText: Color { palette.tabInactiveText }
}

extension ThemePalette {
  fileprivate static let monochromeDark = ThemePalette(
    surfaceBackground: .black,
    surfaceBorder: .white.opacity(0.12),
    cardBackground: Color(red: 0.08, green: 0.08, blue: 0.08),
    cardBorder: .white.opacity(0.10),
    badgeBackground: Color(red: 0.12, green: 0.12, blue: 0.12),
    divider: .white.opacity(0.10),
    textPrimary: .white,
    textSecondary: .white.opacity(0.70),
    textTertiary: .white.opacity(0.45),
    accentAmber: Color(hex: 0xF2C14E),
    accentGreen: Color(hex: 0x6FCF97),
    accentCyan: Color(hex: 0x6EC6E8),
    accentRed: Color(hex: 0xFF7B87),
    tabBarBackground: Color(red: 0.06, green: 0.06, blue: 0.06),
    tabActiveBackground: Color(hex: 0x3A2D10),
    tabActiveText: Color(hex: 0xF2C14E),
    tabInactiveText: .white.opacity(0.55)
  )

  fileprivate static let monochromeLight = ThemePalette(
    surfaceBackground: .white,
    surfaceBorder: .black.opacity(0.14),
    cardBackground: Color(red: 0.95, green: 0.95, blue: 0.95),
    cardBorder: .black.opacity(0.12),
    badgeBackground: Color(red: 0.90, green: 0.90, blue: 0.90),
    divider: .black.opacity(0.12),
    textPrimary: .black,
    textSecondary: .black.opacity(0.70),
    textTertiary: .black.opacity(0.52),
    accentAmber: Color(hex: 0x9A6700),
    accentGreen: Color(hex: 0x2E7D32),
    accentCyan: Color(hex: 0x006D77),
    accentRed: Color(hex: 0xB3261E),
    tabBarBackground: Color(red: 0.93, green: 0.93, blue: 0.93),
    tabActiveBackground: Color(hex: 0xF5E8BE),
    tabActiveText: Color(hex: 0x7A5200),
    tabInactiveText: .black.opacity(0.55)
  )

  // Catppuccin uses mauve as the product accent, with semantic green, peach,
  // blue, and red reserved for status and feature-specific feedback.
  fileprivate static let catppuccinMocha = ThemePalette(
    surfaceBackground: Color(hex: 0x1E1E2E),
    surfaceBorder: Color(hex: 0x585B70),
    cardBackground: Color(hex: 0x313244),
    cardBorder: Color(hex: 0x45475A),
    badgeBackground: Color(hex: 0x45475A),
    divider: Color(hex: 0x45475A),
    textPrimary: Color(hex: 0xCDD6F4),
    textSecondary: Color(hex: 0xBAC2DE),
    textTertiary: Color(hex: 0xA6ADC8),
    accentAmber: Color(hex: 0xFAB387),
    accentGreen: Color(hex: 0xA6E3A1),
    accentCyan: Color(hex: 0x89DCEB),
    accentRed: Color(hex: 0xF38BA8),
    tabBarBackground: Color(hex: 0x181825),
    tabActiveBackground: Color(hex: 0x45475A),
    tabActiveText: Color(hex: 0xF5C2E7),
    tabInactiveText: Color(hex: 0xA6ADC8)
  )

  fileprivate static let catppuccinLatte = ThemePalette(
    surfaceBackground: Color(hex: 0xEFF1F5),
    surfaceBorder: Color(hex: 0x9CA0B0),
    cardBackground: Color(hex: 0xE6E9EF),
    cardBorder: Color(hex: 0xBCC0CC),
    badgeBackground: Color(hex: 0xDCE0E8),
    divider: Color(hex: 0xBCC0CC),
    textPrimary: Color(hex: 0x4C4F69),
    textSecondary: Color(hex: 0x5C5F77),
    textTertiary: Color(hex: 0x6C6F85),
    accentAmber: Color(hex: 0xFE640B),
    accentGreen: Color(hex: 0x40A02B),
    accentCyan: Color(hex: 0x179299),
    accentRed: Color(hex: 0xD20F39),
    tabBarBackground: Color(hex: 0xE6E9EF),
    tabActiveBackground: Color(hex: 0xCCD0DA),
    tabActiveText: Color(hex: 0x8839EF),
    tabInactiveText: Color(hex: 0x6C6F85)
  )
}

extension Color {
  fileprivate init(hex: UInt32) {
    self.init(
      red: Double((hex >> 16) & 0xFF) / 255,
      green: Double((hex >> 8) & 0xFF) / 255,
      blue: Double(hex & 0xFF) / 255
    )
  }
}

import SwiftUI

struct AppTheme {
    static var isDark: Bool {
        ThemeManager.shared.isDarkMode
    }

    static var isZen: Bool {
        ThemeManager.shared.currentStyle == .zenSerenity
    }

    static var surfaceBackground: Color {
        if isZen {
            return isDark
                ? Color(red: 0.11, green: 0.10, blue: 0.10) // Roasted Charcoal
                : Color(red: 0.96, green: 0.95, blue: 0.92) // Warm Alabaster Paper
        } else {
            return isDark
                ? Color(red: 0.08, green: 0.09, blue: 0.11).opacity(0.88) // Deep Obsidian Glass
                : Color(red: 0.98, green: 0.98, blue: 0.99).opacity(0.85) // Pure Alabaster Glass
        }
    }

    static var surfaceBorder: Color {
        if isZen {
            return isDark
                ? Color(red: 0.22, green: 0.20, blue: 0.19)
                : Color(red: 0.86, green: 0.84, blue: 0.79)
        } else {
            return isDark ? Color.white.opacity(0.16) : Color.black.opacity(0.08)
        }
    }

    static var cardBackground: Color {
        if isZen {
            return isDark
                ? Color(red: 0.16, green: 0.15, blue: 0.14)
                : Color.white
        } else {
            return isDark
                ? Color.white.opacity(0.06)
                : Color.white.opacity(0.75)
        }
    }

    static var cardBorder: Color {
        if isZen {
            return isDark
                ? Color(red: 0.24, green: 0.22, blue: 0.21)
                : Color(red: 0.88, green: 0.86, blue: 0.82)
        } else {
            return isDark ? Color.white.opacity(0.10) : Color.black.opacity(0.06)
        }
    }

    static var badgeBackground: Color {
        if isZen {
            return isDark
                ? Color(red: 0.19, green: 0.18, blue: 0.17)
                : Color(red: 0.91, green: 0.89, blue: 0.85)
        } else {
            return isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.04)
        }
    }

    static var divider: Color {
        if isZen {
            return isDark
                ? Color(red: 0.20, green: 0.19, blue: 0.18)
                : Color(red: 0.88, green: 0.86, blue: 0.82)
        } else {
            return isDark ? Color.white.opacity(0.10) : Color.black.opacity(0.07)
        }
    }

    static var textPrimary: Color {
        if isZen {
            return isDark
                ? Color(red: 0.95, green: 0.94, blue: 0.91) // #F3EFE8 Warm Parchment
                : Color(red: 0.17, green: 0.15, blue: 0.14) // #2B2624 Warm Espresso Ink
        } else {
            return isDark ? Color.white : Color(red: 0.11, green: 0.11, blue: 0.13)
        }
    }

    static var textSecondary: Color {
        if isZen {
            return isDark
                ? Color(red: 0.68, green: 0.65, blue: 0.62)
                : Color(red: 0.43, green: 0.40, blue: 0.38)
        } else {
            return isDark ? Color.white.opacity(0.72) : Color(red: 0.38, green: 0.38, blue: 0.42)
        }
    }

    static var textTertiary: Color {
        if isZen {
            return isDark
                ? Color(red: 0.48, green: 0.45, blue: 0.43)
                : Color(red: 0.58, green: 0.55, blue: 0.52)
        } else {
            return isDark ? Color.white.opacity(0.40) : Color(red: 0.58, green: 0.58, blue: 0.62)
        }
    }

    static var accentAmber: Color {
        if isZen {
            return isDark
                ? Color(red: 0.92, green: 0.65, blue: 0.25) // Luminous Brass Gold
                : Color(red: 0.78, green: 0.44, blue: 0.12) // Warm Terracotta Amber
        } else {
            return isDark
                ? Color(red: 0.96, green: 0.68, blue: 0.24) // Honey Amber (#F5AD3D)
                : Color(red: 0.82, green: 0.46, blue: 0.08) // Terracotta Gold (#D17614)
        }
    }

    static var accentGreen: Color {
        if isZen {
            return isDark
                ? Color(red: 0.38, green: 0.72, blue: 0.50) // Warm Sage
                : Color(red: 0.22, green: 0.50, blue: 0.32) // Deep Forest Sage
        } else {
            return isDark
                ? Color(red: 0.20, green: 0.82, blue: 0.48) // Nordic Mint (#33D17A)
                : Color(red: 0.10, green: 0.62, blue: 0.32) // Forest Emerald (#15803D)
        }
    }

    static var accentCyan: Color {
        if isZen {
            return isDark
                ? Color(red: 0.35, green: 0.70, blue: 0.82)
                : Color(red: 0.18, green: 0.46, blue: 0.58)
        } else {
            return isDark
                ? Color(red: 0.36, green: 0.72, blue: 0.94) // Sky Slate (#5CB8F0)
                : Color(red: 0.08, green: 0.50, blue: 0.74) // Ocean Blue (#0284C7)
        }
    }

    static var accentRed: Color {
        if isZen {
            return isDark
                ? Color(red: 0.92, green: 0.40, blue: 0.40)
                : Color(red: 0.78, green: 0.22, blue: 0.22)
        } else {
            return isDark
                ? Color(red: 0.95, green: 0.40, blue: 0.40) // Coral Crimson (#F26666)
                : Color(red: 0.85, green: 0.22, blue: 0.22) // Crimson (#DC2626)
        }
    }

    static var tabBarBackground: Color {
        if isZen {
            return isDark
                ? Color(red: 0.13, green: 0.12, blue: 0.12)
                : Color(red: 0.91, green: 0.89, blue: 0.85)
        } else {
            return isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.05)
        }
    }

    static var tabActiveBackground: Color {
        if isZen {
            return isDark
                ? Color(red: 0.22, green: 0.20, blue: 0.20)
                : Color.white
        } else {
            return isDark ? Color.white.opacity(0.20) : Color.white.opacity(0.92)
        }
    }

    static var tabActiveText: Color {
        if isZen {
            return isDark
                ? Color(red: 0.95, green: 0.94, blue: 0.91)
                : Color(red: 0.17, green: 0.15, blue: 0.14)
        } else {
            return isDark ? Color.white : Color(red: 0.11, green: 0.11, blue: 0.13)
        }
    }

    static var tabInactiveText: Color {
        if isZen {
            return isDark
                ? Color(red: 0.55, green: 0.52, blue: 0.50)
                : Color(red: 0.50, green: 0.47, blue: 0.44)
        } else {
            return isDark ? Color.white.opacity(0.55) : Color(red: 0.42, green: 0.42, blue: 0.46)
        }
    }
}

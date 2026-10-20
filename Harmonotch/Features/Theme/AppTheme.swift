//
//  AppTheme.swift
//  Harmonotch
//
//  Multi-style semantic design system supporting Liquid Glass & Zen Serenity.
//

import SwiftUI

struct AppTheme {
    @ObservedObject private static var themeManager = ThemeManager.shared

    static var isDark: Bool {
        themeManager.isDarkMode
    }

    static var isZen: Bool {
        themeManager.currentStyle == .zenSerenity
    }

    // MARK: - Surfaces
    static var surfaceBackground: Color {
        if isZen {
            return isDark
                ? Color(red: 0.10, green: 0.09, blue: 0.09) // #191817 Roasted Charcoal
                : Color(red: 0.97, green: 0.96, blue: 0.93) // #F7F5EE Warm Alabaster Paper
        } else {
            return isDark ? Color.black.opacity(0.72) : Color.white.opacity(0.68)
        }
    }

    static var surfaceBorder: Color {
        if isZen {
            return isDark
                ? Color(red: 0.24, green: 0.22, blue: 0.21)
                : Color(red: 0.88, green: 0.86, blue: 0.81)
        } else {
            return isDark ? Color.white.opacity(0.14) : Color.black.opacity(0.10)
        }
    }

    static var surfaceInnerHighlight: Color {
        if isZen {
            return isDark ? Color.white.opacity(0.04) : Color.white.opacity(0.60)
        } else {
            return isDark ? Color.white.opacity(0.08) : Color.white.opacity(0.75)
        }
    }

    static var surfaceShadowColor: Color {
        if isZen {
            return isDark
                ? Color.black.opacity(0.60)
                : Color(red: 0.25, green: 0.20, blue: 0.15).opacity(0.12)
        } else {
            return isDark ? Color.black.opacity(0.50) : Color.black.opacity(0.14)
        }
    }

    static var surfaceShadowRadius: CGFloat {
        if isZen {
            return isDark ? 16 : 14
        } else {
            return isDark ? 14 : 18
        }
    }

    // MARK: - Cards & Badges
    static var cardBackground: Color {
        if isZen {
            return isDark
                ? Color(red: 0.15, green: 0.14, blue: 0.13) // #262422
                : Color.white
        } else {
            return isDark ? Color.white.opacity(0.07) : Color.black.opacity(0.04)
        }
    }

    static var cardHoverBackground: Color {
        if isZen {
            return isDark
                ? Color(red: 0.19, green: 0.18, blue: 0.17)
                : Color(red: 0.95, green: 0.94, blue: 0.91)
        } else {
            return isDark ? Color.white.opacity(0.12) : Color.black.opacity(0.07)
        }
    }

    static var cardBorder: Color {
        if isZen {
            return isDark
                ? Color(red: 0.22, green: 0.20, blue: 0.19)
                : Color(red: 0.89, green: 0.87, blue: 0.83)
        } else {
            return isDark ? Color.white.opacity(0.10) : Color.black.opacity(0.06)
        }
    }

    static var badgeBackground: Color {
        if isZen {
            return isDark
                ? Color(red: 0.18, green: 0.17, blue: 0.16)
                : Color(red: 0.92, green: 0.90, blue: 0.86)
        } else {
            return isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.05)
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

    // MARK: - Typography Hierarchy
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

    // MARK: - Semantic Accent Colors
    static var accentAmber: Color {
        if isZen {
            return isDark
                ? Color(red: 0.90, green: 0.63, blue: 0.22) // Luminous Brass Gold
                : Color(red: 0.78, green: 0.42, blue: 0.10) // Warm Terracotta Amber
        } else {
            return isDark ? Color(red: 1.0, green: 0.75, blue: 0.20) : Color(red: 0.85, green: 0.48, blue: 0.04)
        }
    }

    static var accentGreen: Color {
        if isZen {
            return isDark
                ? Color(red: 0.36, green: 0.70, blue: 0.48) // Warm Sage
                : Color(red: 0.24, green: 0.49, blue: 0.33) // Deep Forest Sage
        } else {
            return isDark ? Color(red: 0.22, green: 0.84, blue: 0.44) : Color(red: 0.10, green: 0.58, blue: 0.24)
        }
    }

    static var accentCyan: Color {
        if isZen {
            return isDark
                ? Color(red: 0.32, green: 0.68, blue: 0.80)
                : Color(red: 0.18, green: 0.45, blue: 0.56)
        } else {
            return isDark ? Color.cyan : Color(red: 0.05, green: 0.52, blue: 0.75)
        }
    }

    static var accentRed: Color {
        if isZen {
            return isDark
                ? Color(red: 0.92, green: 0.38, blue: 0.38)
                : Color(red: 0.78, green: 0.22, blue: 0.22)
        } else {
            return isDark ? Color(red: 1.0, green: 0.35, blue: 0.35) : Color(red: 0.85, green: 0.20, blue: 0.20)
        }
    }

    // MARK: - Segmented Tab Bar
    static var tabBarBackground: Color {
        if isZen {
            return isDark
                ? Color(red: 0.13, green: 0.12, blue: 0.12)
                : Color(red: 0.91, green: 0.89, blue: 0.85)
        } else {
            return isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.05)
        }
    }

    static var tabBarBorder: Color {
        if isZen {
            return isDark
                ? Color(red: 0.20, green: 0.19, blue: 0.18)
                : Color(red: 0.85, green: 0.83, blue: 0.78)
        } else {
            return isDark ? Color.white.opacity(0.10) : Color.black.opacity(0.07)
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

    static var tabActiveBorder: Color {
        if isZen {
            return isDark
                ? Color(red: 0.30, green: 0.28, blue: 0.27)
                : Color(red: 0.83, green: 0.80, blue: 0.75)
        } else {
            return isDark ? Color.white.opacity(0.25) : Color.black.opacity(0.08)
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

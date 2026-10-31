import SwiftUI

struct AppTheme {
    static var isDark: Bool {
        true
    }

    // Pure black surface (#000000)
    static var surfaceBackground: Color {
        Color.black
    }

    // Subtle crisp hairline border
    static var surfaceBorder: Color {
        Color.white.opacity(0.12)
    }

    // Solid dark card background - zero glass translucency, pure opaque dark surface
    static var cardBackground: Color {
        Color(red: 0.08, green: 0.08, blue: 0.08)
    }

    static var cardBorder: Color {
        Color.white.opacity(0.10)
    }

    static var badgeBackground: Color {
        Color(red: 0.12, green: 0.12, blue: 0.12)
    }

    static var divider: Color {
        Color.white.opacity(0.10)
    }

    static var textPrimary: Color {
        Color.white
    }

    static var textSecondary: Color {
        Color.white.opacity(0.70)
    }

    static var textTertiary: Color {
        Color.white.opacity(0.45)
    }

    // Strict Monochrome Black & White Palette
    static var accentAmber: Color {
        Color.white
    }

    static var accentGreen: Color {
        Color.white
    }

    static var accentCyan: Color {
        Color.white
    }

    static var accentRed: Color {
        Color.white.opacity(0.85)
    }

    static var tabBarBackground: Color {
        Color(red: 0.06, green: 0.06, blue: 0.06)
    }

    static var tabActiveBackground: Color {
        Color(red: 0.18, green: 0.18, blue: 0.18)
    }

    static var tabActiveText: Color {
        Color.white
    }

    static var tabInactiveText: Color {
        Color.white.opacity(0.55)
    }
}

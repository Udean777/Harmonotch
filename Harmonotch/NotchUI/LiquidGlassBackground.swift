import SwiftUI
import AppKit

struct NativeVisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    var state: NSVisualEffectView.State = .active
    var emphasized: Bool = true

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = state
        view.isEmphasized = emphasized
        view.wantsLayer = true
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        if nsView.material != material {
            nsView.material = material
        }
        if nsView.blendingMode != blendingMode {
            nsView.blendingMode = blendingMode
        }
        if nsView.state != state {
            nsView.state = state
        }
        if nsView.isEmphasized != emphasized {
            nsView.isEmphasized = emphasized
        }
    }
}

struct LiquidGlassSurface<ShapeType: Shape>: View {
    let shape: ShapeType
    let isExpanded: Bool
    @ObservedObject var themeManager = ThemeManager.shared

    var body: some View {
        ZStack {
            if isExpanded {
                NativeVisualEffectView(
                    material: themeManager.isDarkMode ? .hudWindow : .popover,
                    blendingMode: .behindWindow,
                    state: .active
                )
                .clipShape(shape)

                shape
                    .fill(
                        LinearGradient(
                            stops: themeManager.isDarkMode ? [
                                .init(color: Color.white.opacity(0.12), location: 0.0),
                                .init(color: Color.white.opacity(0.04), location: 0.35),
                                .init(color: Color.black.opacity(0.20), location: 0.70),
                                .init(color: Color.black.opacity(0.42), location: 1.0)
                            ] : [
                                .init(color: Color.white.opacity(0.55), location: 0.0),
                                .init(color: Color.white.opacity(0.35), location: 0.40),
                                .init(color: Color.white.opacity(0.18), location: 0.75),
                                .init(color: Color.white.opacity(0.28), location: 1.0)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                shape
                    .fill(
                        themeManager.isDarkMode
                            ? Color(red: 0.06, green: 0.06, blue: 0.09).opacity(0.32)
                            : Color(red: 0.95, green: 0.96, blue: 0.98).opacity(0.22)
                    )

                shape
                    .stroke(
                        LinearGradient(
                            stops: themeManager.isDarkMode ? [
                                .init(color: Color.white.opacity(0.68), location: 0.0),
                                .init(color: Color.white.opacity(0.22), location: 0.25),
                                .init(color: Color.white.opacity(0.06), location: 0.60),
                                .init(color: Color.white.opacity(0.28), location: 1.0)
                            ] : [
                                .init(color: Color.white.opacity(0.95), location: 0.0),
                                .init(color: Color.white.opacity(0.42), location: 0.25),
                                .init(color: Color.black.opacity(0.08), location: 0.65),
                                .init(color: Color.white.opacity(0.55), location: 1.0)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.0
                    )

                shape
                    .stroke(
                        themeManager.isDarkMode
                            ? Color.white.opacity(0.06)
                            : Color.white.opacity(0.50),
                        lineWidth: 0.5
                    )
                    .padding(0.7)
            } else {
                shape
                    .fill(Color.black)
                    .overlay(
                        shape
                            .stroke(Color.white.opacity(0.12), lineWidth: 0.8)
                    )
            }
        }
        .shadow(
            color: isExpanded
                ? (themeManager.isDarkMode ? Color.black.opacity(0.55) : Color(red: 0.1, green: 0.1, blue: 0.2).opacity(0.15))
                : Color.black.opacity(0.35),
            radius: isExpanded ? 24 : 6,
            x: 0,
            y: isExpanded ? 12 : 3
        )
        .shadow(
            color: isExpanded
                ? (themeManager.isDarkMode ? Color.black.opacity(0.30) : Color.black.opacity(0.06))
                : Color.clear,
            radius: 4,
            x: 0,
            y: 2
        )
    }
}

struct ZenSerenitySurface<ShapeType: Shape>: View {
    let shape: ShapeType
    let isExpanded: Bool
    @ObservedObject var themeManager = ThemeManager.shared

    var body: some View {
        ZStack {
            if isExpanded {
                shape
                    .fill(AppTheme.surfaceBackground)

                shape
                    .fill(
                        LinearGradient(
                            colors: themeManager.isDarkMode
                                ? [Color.white.opacity(0.04), Color.black.opacity(0.18)]
                                : [Color.white.opacity(0.35), Color.black.opacity(0.03)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                shape
                    .stroke(AppTheme.surfaceBorder, lineWidth: 1.0)

                shape
                    .stroke(AppTheme.surfaceInnerHighlight, lineWidth: 0.5)
                    .padding(0.6)
            } else {
                shape
                    .fill(Color.black)
                    .overlay(
                        shape.stroke(Color.white.opacity(0.12), lineWidth: 0.8)
                    )
            }
        }
        .shadow(
            color: isExpanded ? AppTheme.surfaceShadowColor : Color.black.opacity(0.35),
            radius: isExpanded ? AppTheme.surfaceShadowRadius : 6,
            x: 0,
            y: isExpanded ? 8 : 3
        )
    }
}

struct HarmonotchSurface<ShapeType: Shape>: View {
    let shape: ShapeType
    let isExpanded: Bool
    @ObservedObject var themeManager = ThemeManager.shared

    var body: some View {
        switch themeManager.currentStyle {
        case .liquidGlass:
            LiquidGlassSurface(shape: shape, isExpanded: isExpanded)
        case .zenSerenity:
            ZenSerenitySurface(shape: shape, isExpanded: isExpanded)
        }
    }
}

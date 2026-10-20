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
                    material: material,
                    blendingMode: .behindWindow,
                    state: .active
                )
                .clipShape(shape)

                shape.fill(fillGradient)
                shape.fill(tintColor)
                shape.stroke(borderGradient, lineWidth: 1.0)
                shape.stroke(innerBorderColor, lineWidth: 0.5).padding(0.7)
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
            color: shadowColor,
            radius: isExpanded ? 24 : 6,
            x: 0,
            y: isExpanded ? 12 : 3
        )
        .shadow(
            color: secondaryShadowColor,
            radius: 4,
            x: 0,
            y: 2
        )
    }

    private var dark: Bool { themeManager.isDarkMode }

    private var material: NSVisualEffectView.Material {
        dark ? .hudWindow : .popover
    }

    private var fillGradient: LinearGradient {
        let stops: [Gradient.Stop]
        if dark {
            stops = [
                Gradient.Stop(color: Color.white.opacity(0.12), location: 0.0),
                Gradient.Stop(color: Color.white.opacity(0.04), location: 0.35),
                Gradient.Stop(color: Color.black.opacity(0.20), location: 0.70),
                Gradient.Stop(color: Color.black.opacity(0.42), location: 1.0)
            ]
        } else {
            stops = [
                Gradient.Stop(color: Color.white.opacity(0.55), location: 0.0),
                Gradient.Stop(color: Color.white.opacity(0.35), location: 0.40),
                Gradient.Stop(color: Color.white.opacity(0.18), location: 0.75),
                Gradient.Stop(color: Color.white.opacity(0.28), location: 1.0)
            ]
        }
        return LinearGradient(stops: stops, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private var tintColor: Color {
        if dark {
            return Color(red: 0.06, green: 0.06, blue: 0.09).opacity(0.32)
        }
        return Color(red: 0.95, green: 0.96, blue: 0.98).opacity(0.22)
    }

    private var borderGradient: LinearGradient {
        let stops: [Gradient.Stop]
        if dark {
            stops = [
                Gradient.Stop(color: Color.white.opacity(0.68), location: 0.0),
                Gradient.Stop(color: Color.white.opacity(0.22), location: 0.25),
                Gradient.Stop(color: Color.white.opacity(0.06), location: 0.60),
                Gradient.Stop(color: Color.white.opacity(0.28), location: 1.0)
            ]
        } else {
            stops = [
                Gradient.Stop(color: Color.white.opacity(0.95), location: 0.0),
                Gradient.Stop(color: Color.white.opacity(0.42), location: 0.25),
                Gradient.Stop(color: Color.black.opacity(0.08), location: 0.65),
                Gradient.Stop(color: Color.white.opacity(0.55), location: 1.0)
            ]
        }
        return LinearGradient(stops: stops, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private var innerBorderColor: Color {
        if dark {
            return Color.white.opacity(0.06)
        }
        return Color.white.opacity(0.50)
    }

    private var shadowColor: Color {
        guard isExpanded else { return Color.black.opacity(0.35) }
        if dark {
            return Color.black.opacity(0.55)
        }
        return Color(red: 0.1, green: 0.1, blue: 0.2).opacity(0.15)
    }

    private var secondaryShadowColor: Color {
        guard isExpanded else { return Color.clear }
        if dark {
            return Color.black.opacity(0.30)
        }
        return Color.black.opacity(0.06)
    }
}

struct ZenSerenitySurface<ShapeType: Shape>: View {
    let shape: ShapeType
    let isExpanded: Bool
    @ObservedObject var themeManager = ThemeManager.shared

    var body: some View {
        ZStack {
            if isExpanded {
                shape.fill(AppTheme.surfaceBackground)
                shape.fill(overlayGradient)
                shape.stroke(AppTheme.surfaceBorder, lineWidth: 1.0)
                shape.stroke(AppTheme.surfaceInnerHighlight, lineWidth: 0.5).padding(0.6)
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

    private var overlayGradient: LinearGradient {
        let colors: [Color]
        if themeManager.isDarkMode {
            colors = [Color.white.opacity(0.04), Color.black.opacity(0.18)]
        } else {
            colors = [Color.white.opacity(0.35), Color.black.opacity(0.03)]
        }
        return LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
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

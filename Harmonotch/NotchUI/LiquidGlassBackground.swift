//
//  LiquidGlassBackground.swift
//  Harmonotch
//
//  True Liquid Glass & Zen Serenity Optical Architecture for macOS.
//

import SwiftUI
import AppKit

// MARK: - Native AppKit Visual Effect View (Behind-Window Hardware Blur)
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
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = state
        nsView.isEmphasized = emphasized
    }
}

// MARK: - True Liquid Glass Optical Surface Component
struct LiquidGlassSurface<ShapeType: Shape>: View {
    let shape: ShapeType
    let isExpanded: Bool
    @ObservedObject var themeManager = ThemeManager.shared

    var body: some View {
        ZStack {
            if isExpanded {
                // Layer 1: Hardware-Accelerated Desktop Blur (WindowServer Compositor)
                NativeVisualEffectView(
                    material: themeManager.isDarkMode ? .hudWindow : .popover,
                    blendingMode: .behindWindow,
                    state: .active
                )
                .clipShape(shape)

                // Layer 2: Specular Refraction Sheen (Diagonal Optical Gradient Wash)
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

                // Layer 3: Ambient Color Bloom
                shape
                    .fill(
                        themeManager.isDarkMode
                            ? Color(red: 0.06, green: 0.06, blue: 0.09).opacity(0.32)
                            : Color(red: 0.95, green: 0.96, blue: 0.98).opacity(0.22)
                    )

                // Layer 4: Directional Specular Rim Light (Top-Left Specular Reflection)
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

                // Layer 5: Delicate Inner Bevel
                shape
                    .stroke(
                        themeManager.isDarkMode
                            ? Color.white.opacity(0.06)
                            : Color.white.opacity(0.50),
                        lineWidth: 0.5
                    )
                    .padding(0.7)
            } else {
                // Collapsed Resting State:
                // Pitch black body matching the physical hardware MacBook camera notch bezel
                shape
                    .fill(Color.black)
                    .overlay(
                        shape
                            .stroke(Color.white.opacity(0.12), lineWidth: 0.8)
                    )
            }
        }
        // Layer 6: Dual-Stage Floating Shadows
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

// MARK: - Zen Serenity Surface Component (Non-Glass Tactile Matte Paper)
struct ZenSerenitySurface<ShapeType: Shape>: View {
    let shape: ShapeType
    let isExpanded: Bool
    @ObservedObject var themeManager = ThemeManager.shared

    var body: some View {
        ZStack {
            if isExpanded {
                // Layer 1: Solid Tactile Paper Foundation (No Glass Blur)
                shape
                    .fill(AppTheme.surfaceBackground)

                // Layer 2: Subtle Fiber & Ambient Tone
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

                // Layer 3: Warm Tactile Edge Contour
                shape
                    .stroke(AppTheme.surfaceBorder, lineWidth: 1.0)

                // Layer 4: Delicate Inner Highlight
                shape
                    .stroke(AppTheme.surfaceInnerHighlight, lineWidth: 0.5)
                    .padding(0.6)
            } else {
                // Collapsed Resting State: Solid Black matching Hardware Camera Notch
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

// MARK: - Adaptive Surface Router
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

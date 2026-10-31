import SwiftUI

/// Pure Black Surface for Harmonotch Dynamic Island.
/// Full OLED pure black (#000000) with no liquid glass, no gradients, and no translucency.
/// Features a subtle hairline border matching Apple's hardware notch bezel.
struct PureBlackSurface: View {
    let shape: NotchShape
    let isExpanded: Bool

    private var openBorder: NotchOpenBorderShape {
        NotchOpenBorderShape(radius: shape.radius, shoulder: shape.shoulder)
    }

    var body: some View {
        ZStack {
            // Pure solid black fill - zero gradient, zero glass translucency
            shape
                .fill(Color.black)

            // Crisp subtle border matching Apple hardware notch
            openBorder
                .stroke(Color.white.opacity(0.12), lineWidth: 0.8)
        }
    }
}

struct HarmonotchSurface: View {
    let shape: NotchShape
    let isExpanded: Bool

    var body: some View {
        PureBlackSurface(shape: shape, isExpanded: isExpanded)
    }
}

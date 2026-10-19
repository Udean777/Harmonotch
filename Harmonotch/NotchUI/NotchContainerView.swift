//
//  NotchContainerView.swift
//  Harmonotch
//

import SwiftUI

struct NotchContainerView: View {
    @ObservedObject var notchVM = NotchViewModel.shared
    @ObservedObject var adzanPlayer = AdzanPlayer.shared

    let geometry = NotchGeometry.current()

    private var targetWidth: CGFloat {
        notchVM.isExpanded ? 540 : geometry.physicalNotchWidth
    }

    private var targetHeight: CGFloat {
        if notchVM.isExpanded {
            // Ruang vertikal yang cukup lapang agar seluruh kartu dan footer tidak terpotong
            return geometry.hasHardwareNotch ? (geometry.physicalNotchHeight + 255) : 265
        } else {
            return geometry.hasHardwareNotch ? (geometry.physicalNotchHeight + 26) : 32
        }
    }

    private var targetRadius: CGFloat {
        notchVM.isExpanded ? 20 : 12
    }

    var body: some View {
        ZStack(alignment: .top) {
            // MARK: - 1. The Morphing Black Body
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: targetRadius,
                bottomTrailingRadius: targetRadius,
                topTrailingRadius: 0,
                style: .continuous
            )
            .fill(Color.black)
            .overlay(
                UnevenRoundedRectangle(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: targetRadius,
                    bottomTrailingRadius: targetRadius,
                    topTrailingRadius: 0,
                    style: .continuous
                )
                .stroke(Color.white.opacity(notchVM.isExpanded ? 0.14 : 0.12), lineWidth: 0.8)
            )
            .shadow(
                color: Color.black.opacity(notchVM.isExpanded ? 0.5 : 0.35),
                radius: notchVM.isExpanded ? 14 : 6,
                x: 0,
                y: notchVM.isExpanded ? 8 : 3
            )
            .frame(width: targetWidth, height: targetHeight)

            // MARK: - 2. Konten
            Group {
                if notchVM.isExpanded {
                    PrayerDrawerView()
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .offset(y: -6)),
                            removal: .opacity
                        ))
                        .onHover { isHovered in
                            notchVM.setHovered(isHovered)
                        }
                } else {
                    NotchPillView()
                        .transition(.asymmetric(
                            insertion: .opacity,
                            removal: .opacity.combined(with: .scale(scale: 0.9, anchor: .top))
                        ))
                        .onHover { isHovered in
                            if isHovered {
                                notchVM.setHovered(true)
                            }
                        }
                }
            }
        }
        .frame(width: targetWidth, height: targetHeight, alignment: .top)
        .clipped()
        .frame(width: NotchWindowController.canvasWidth, alignment: .top)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // Animasi asimetris: Expand lembut & elastis, Close super snappy & responsif
        .animation(
            notchVM.isExpanded
                ? .spring(response: 0.34, dampingFraction: 0.76, blendDuration: 0.08)
                : .spring(response: 0.25, dampingFraction: 0.88, blendDuration: 0.05),
            value: notchVM.isExpanded
        )
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: adzanPlayer.isPlaying)
    }
}

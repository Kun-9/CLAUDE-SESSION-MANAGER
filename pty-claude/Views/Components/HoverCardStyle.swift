import SwiftUI

struct HoverCardStyle: ViewModifier {
    let cornerRadius: CGFloat
    let baseStrokeOpacity: Double
    let hoverStrokeOpacity: Double
    let baseShadowOpacity: Double
    let hoverShadowOpacity: Double
    let shadowRadius: CGFloat
    let shadowYOffset: CGFloat

    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.primary.opacity(isHovered ? hoverStrokeOpacity : baseStrokeOpacity), lineWidth: 1)
            )
            .shadow(
                color: Color.black.opacity(isHovered ? hoverShadowOpacity : baseShadowOpacity),
                radius: shadowRadius,
                x: 0,
                y: shadowYOffset
            )
            .onHover { hovering in
                withAnimation(.easeOut(duration: 0.15)) {
                    isHovered = hovering
                }
            }
    }
}

extension View {
    func hoverCardStyle(
        cornerRadius: CGFloat,
        baseStrokeOpacity: Double = 0.08,
        hoverStrokeOpacity: Double = 0.16,
        baseShadowOpacity: Double = 0.06,
        hoverShadowOpacity: Double = 0.12,
        shadowRadius: CGFloat = 8,
        shadowYOffset: CGFloat = 4
    ) -> some View {
        modifier(
            HoverCardStyle(
                cornerRadius: cornerRadius,
                baseStrokeOpacity: baseStrokeOpacity,
                hoverStrokeOpacity: hoverStrokeOpacity,
                baseShadowOpacity: baseShadowOpacity,
                hoverShadowOpacity: hoverShadowOpacity,
                shadowRadius: shadowRadius,
                shadowYOffset: shadowYOffset
            )
        )
    }
}

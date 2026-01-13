import SwiftUI

struct SessionStatusBar: View {
    let status: SessionStatus
    @State private var isAnimating = false

    var body: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(status.tint)
            .overlay(animatedHighlight)
            .frame(width: 6)
            .padding(.vertical, 2)
            .onAppear {
                guard status == .running else { return }
                isAnimating = true
            }
    }

    @ViewBuilder
    private var animatedHighlight: some View {
        if status == .running {
            LinearGradient(
                colors: [
                    Color.white.opacity(0.1),
                    Color.white.opacity(0.7),
                    Color.white.opacity(0.1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .offset(y: isAnimating ? 20 : -20)
            .animation(
                .linear(duration: 1.0).repeatForever(autoreverses: false),
                value: isAnimating
            )
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
    }
}

struct SessionStatusBadge: View {
    let status: SessionStatus

    var body: some View {
        Text(status.label)
            .font(.caption.weight(.semibold))
            .foregroundStyle(status.tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(status.tint.opacity(0.12))
            )
    }
}

struct RunningProgressIndicator: View {
    let tint: Color

    var body: some View {
        ProgressView()
            .progressViewStyle(.circular)
            .tint(tint)
            .scaleEffect(0.65)
    }
}

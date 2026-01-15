import Combine
import SwiftUI

final class ToastCenter: ObservableObject {
    @Published var message: String?
    private var hideWorkItem: DispatchWorkItem?

    func show(_ message: String, duration: TimeInterval = 1.6) {
        hideWorkItem?.cancel()
        withAnimation(.easeOut(duration: 0.2)) {
            self.message = message
        }
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            withAnimation(.easeIn(duration: 0.2)) {
                self.message = nil
            }
        }
        hideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: workItem)
    }
}

struct ToastOverlayView: View {
    @EnvironmentObject private var toastCenter: ToastCenter

    var body: some View {
        if let message = toastCenter.message {
            Text(message)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.primary.opacity(0.12))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

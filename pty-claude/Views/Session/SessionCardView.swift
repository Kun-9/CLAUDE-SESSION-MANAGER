import AppKit
import SwiftUI

struct SessionCardView: View {
    let session: SessionItem
    @State private var cardWidth: CGFloat = 0

    var body: some View {
        HStack(spacing: 14) {
            SessionStatusBar(status: session.status)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(session.name)
                        .font(.headline)
                    Spacer()
                    SessionStatusBadge(status: session.status)
                }
                Text(session.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if session.lastPrompt != nil || session.lastResponse != nil {
                    SessionSummaryView(
                        prompt: session.lastPrompt,
                        response: session.lastResponse
                    )
                    .frame(
                        width: cardWidth > 0 ? cardWidth * 0.85 : nil,
                        alignment: .leading
                    )
                }
                Text("Updated \(session.updatedText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(LinearGradient(
                        colors: [
                            session.status.background,
                            Color(NSColor.windowBackgroundColor),
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                GeometryReader { proxy in
                    Color.clear
                        .preference(key: SessionCardWidthKey.self, value: proxy.size.width)
                }
            }
        }
        .onPreferenceChange(SessionCardWidthKey.self) { cardWidth = $0 }
        .overlay(alignment: .bottomTrailing) {
            if session.status == .running {
                RunningProgressIndicator(tint: session.status.tint)
                    .padding(.trailing, 12)
                    .padding(.bottom, 10)
            }
        }
        .hoverCardStyle(cornerRadius: 18)
    }
}

private struct SessionCardWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

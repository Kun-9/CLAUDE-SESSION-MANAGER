import AppKit
import SwiftUI

struct SessionCardView: View {
    let session: SessionItem

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
                if let lastPrompt = session.lastPrompt {
                    Text(lastPrompt)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                Text("Updated \(session.updatedText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(LinearGradient(
                    colors: [
                        session.status.background,
                        Color(NSColor.windowBackgroundColor),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                ))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .overlay(alignment: .bottomTrailing) {
            if session.status == .running {
                RunningProgressIndicator(tint: session.status.tint)
                    .padding(.trailing, 12)
                    .padding(.bottom, 10)
            }
        }
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 4)
    }
}

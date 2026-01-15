import SwiftUI

struct TranscriptRowView: View {
    let entry: TranscriptEntry
    @State private var isExpanded = false

    private let collapsedLineLimit = 4
    private let expandThreshold = 240

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(roleLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(roleColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule(style: .continuous)
                            .fill(roleColor.opacity(0.12))
                    )
                if let timestampText {
                    Text(timestampText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            Text(entry.text)
                .font(.body)
                .foregroundStyle(.primary)
                .padding(.vertical, 8)
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(roleColor.opacity(0.12))
                )
                .lineLimit(isExpanded ? nil : collapsedLineLimit)
                .textSelection(.enabled)

            if shouldShowToggle {
                Button(isExpanded ? "접기" : "더보기") {
                    isExpanded.toggle()
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var roleLabel: String {
        switch entry.role {
        case .user:
            return "User"
        case .assistant:
            return "Assistant"
        case .system:
            return "System"
        case .unknown:
            return "Unknown"
        }
    }

    private var roleColor: Color {
        switch entry.role {
        case .user:
            return Color.blue
        case .assistant:
            return Color.green
        case .system:
            return Color.gray
        case .unknown:
            return Color.gray
        }
    }

    private var timestampText: String? {
        guard let createdAt = entry.createdAt else {
            return nil
        }
        let date = Date(timeIntervalSince1970: createdAt)
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private var shouldShowToggle: Bool {
        if entry.text.count > expandThreshold {
            return true
        }
        let lineCount = entry.text.split(whereSeparator: \.isNewline).count
        return lineCount > collapsedLineLimit
    }
}

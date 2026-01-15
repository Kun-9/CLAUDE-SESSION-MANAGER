import SwiftUI

struct SessionSection: Identifiable {
    let id: String
    let title: String
    let subtitle: String?
    let sessions: [SessionItem]
    let isFavorite: Bool
}

struct SessionSectionHeader: View {
    let title: String
    let subtitle: String?
    let count: Int
    let isCollapsed: Bool
    let isFavorite: Bool
    var onFavoriteTap: (() -> Void)?
    var onTerminalTap: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                // 즐겨찾기 별 아이콘 (타이틀 앞)
                if let onFavoriteTap {
                    Button {
                        onFavoriteTap()
                    } label: {
                        Image(systemName: isFavorite ? "star.fill" : "star")
                            .font(.caption)
                            .foregroundStyle(isFavorite ? Color.yellow : Color.secondary.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                    .help(isFavorite ? "즐겨찾기 해제" : "즐겨찾기 추가")
                }
                Text(title)
                    .font(.headline)
                Text("\(count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.primary.opacity(0.08))
                    )
                if let onTerminalTap {
                    Button {
                        onTerminalTap()
                    } label: {
                        Image(systemName: "terminal")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                    .help("iTerm에서 디렉토리 열기")
                }
            }
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

import AppKit
import Foundation
import SwiftUI

// 마크다운 텍스트를 블록 단위로 나눠 렌더링하는 뷰
struct MarkdownMessageView: View {
    private let blocks: [MarkdownParser.Block]

    init(text: String) {
        blocks = MarkdownParser.parseBlocks(text)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(blocks) { block in
                switch block.kind {
                case .text(let value):
                    // 일반 텍스트 블록 렌더링
                    MarkdownTextBlockView(text: value)
                case .code(let value):
                    // 코드 블록 렌더링
                    MarkdownCodeBlockView(code: value)
                }
            }
        }
        .textSelection(.enabled)
    }
}

// 제목/리스트 등을 포함한 일반 텍스트 렌더링
private struct MarkdownTextBlockView: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(lines.indices, id: \.self) { index in
                lineView(lines[index])
            }
        }
    }

    private var lines: [String] {
        text.split(
            maxSplits: Int.max,
            omittingEmptySubsequences: false,
            whereSeparator: \.isNewline
        ).map(String.init)
    }

    @ViewBuilder
    private func lineView(_ line: String) -> some View {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            Color.clear.frame(height: 6)
        } else if trimmed.hasPrefix("### ") {
            Text(String(trimmed.dropFirst(4)))
                .font(.headline)
                .foregroundStyle(.primary)
        } else if trimmed.hasPrefix("## ") {
            Text(String(trimmed.dropFirst(3)))
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
        } else if trimmed.hasPrefix("# ") {
            Text(String(trimmed.dropFirst(2)))
                .font(.title2.weight(.semibold))
                .foregroundStyle(.primary)
        } else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
            let content = String(trimmed.dropFirst(2))
            (Text("• ") + MarkdownParser.parseInlineMarkdown(content))
                .font(.body)
                .foregroundStyle(.primary)
        } else if let ordered = MarkdownParser.parseOrderedListItem(from: trimmed) {
            (Text("\(ordered.number). ") + MarkdownParser.parseInlineMarkdown(ordered.content))
                .font(.body)
                .foregroundStyle(.primary)
        } else {
            MarkdownParser.parseInlineMarkdown(trimmed)
                .font(.body)
                .foregroundStyle(.primary)
        }
    }
}

// 코드 블록 전용 렌더링
private struct MarkdownCodeBlockView: View {
    let code: String
    @EnvironmentObject private var toastCenter: ToastCenter

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Text(code)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(nil)
                .padding(10)
                .padding(.trailing, 24)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                ClipboardService.copy(code)
                toastCenter.show("클립보드에 복사됨")
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 12, weight: .semibold))
                    .padding(6)
            }
            .buttonStyle(.plain)
            .padding(6)
            .help("복사")
            .accessibilityLabel("복사")
        }
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.06))
        )
    }
}

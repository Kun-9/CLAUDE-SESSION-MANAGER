import Foundation
import SwiftUI

// 마크다운 텍스트를 블록 단위로 나눠 렌더링하는 뷰
struct MarkdownMessageView: View {
    private let blocks: [MarkdownBlock]

    init(text: String) {
        blocks = MarkdownMessageView.parseBlocks(text)
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

    // 코드 블록과 일반 텍스트 블록을 분리
    private static func parseBlocks(_ text: String) -> [MarkdownBlock] {
        let lines = text.split(
            maxSplits: Int.max,
            omittingEmptySubsequences: false,
            whereSeparator: \.isNewline
        )
        var blocks: [MarkdownBlock] = []
        var current = ""
        var isCode = false

        for lineSub in lines {
            let line = String(lineSub)
            if line.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).hasPrefix("```") {
                if isCode {
                    if !current.isEmpty {
                        blocks.append(MarkdownBlock(kind: .code(current)))
                        current = ""
                    }
                } else if !current.isEmpty {
                    blocks.append(MarkdownBlock(kind: .text(current)))
                    current = ""
                }
                isCode.toggle()
                continue
            }

            if !current.isEmpty {
                current.append("\n")
            }
            current.append(line)
        }

        if !current.isEmpty {
            blocks.append(MarkdownBlock(kind: isCode ? .code(current) : .text(current)))
        }

        return blocks
    }
}

// 블록 단위 데이터 모델
private struct MarkdownBlock: Identifiable {
    let id = UUID()
    let kind: Kind

    enum Kind {
        case text(String)
        case code(String)
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
            (Text("• ") + markdownText(content))
                .font(.body)
                .foregroundStyle(.primary)
        } else if let ordered = orderedListItem(from: trimmed) {
            (Text("\(ordered.number). ") + markdownText(ordered.content))
                .font(.body)
                .foregroundStyle(.primary)
        } else {
            markdownText(trimmed)
                .font(.body)
                .foregroundStyle(.primary)
        }
    }

    // 숫자 목록 포맷 검출
    private func orderedListItem(from line: String) -> (number: String, content: String)? {
        guard let dotIndex = line.firstIndex(of: ".") else {
            return nil
        }
        let numberPart = line[..<dotIndex]
        guard !numberPart.isEmpty, numberPart.allSatisfy({ $0.isNumber }) else {
            return nil
        }
        let afterDot = line.index(after: dotIndex)
        guard afterDot < line.endIndex, line[afterDot] == " " else {
            return nil
        }
        let content = line[line.index(after: afterDot)...]
        return (String(numberPart), String(content))
    }

    // 인라인 마크다운 스타일 파싱
    private func markdownText(_ text: String) -> Text {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .full,
            failurePolicy: .returnPartiallyParsedIfPossible
        )
        if let attributed = try? AttributedString(markdown: text, options: options) {
            return Text(attributed)
        }
        return Text(text)
    }
}

// 코드 블록 전용 렌더링
private struct MarkdownCodeBlockView: View {
    let code: String

    var body: some View {
        ScrollView(.horizontal) {
            Text(code)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.primary)
                .padding(10)
        }
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.06))
        )
    }
}

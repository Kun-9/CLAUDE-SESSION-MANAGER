import Foundation
import SwiftUI

/// 마크다운 파싱 유틸리티
enum MarkdownParser {
    /// 마크다운 블록 단위 데이터 모델
    struct Block: Identifiable {
        let id = UUID()
        let kind: Kind

        enum Kind {
            case text(String)
            case code(String)
        }
    }

    /// 코드 블록과 일반 텍스트 블록을 분리
    static func parseBlocks(_ text: String) -> [Block] {
        let lines = text.split(
            maxSplits: Int.max,
            omittingEmptySubsequences: false,
            whereSeparator: \.isNewline
        )
        var blocks: [Block] = []
        var current = ""
        var isCode = false

        for lineSub in lines {
            let line = String(lineSub)
            if line.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).hasPrefix("```") {
                if isCode {
                    if !current.isEmpty {
                        blocks.append(Block(kind: .code(current)))
                        current = ""
                    }
                } else if !current.isEmpty {
                    blocks.append(Block(kind: .text(current)))
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
            blocks.append(Block(kind: isCode ? .code(current) : .text(current)))
        }

        return blocks
    }

    /// 숫자 목록 포맷 검출 (예: "1. item")
    static func parseOrderedListItem(from line: String) -> (number: String, content: String)? {
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

    /// 인라인 마크다운 스타일 파싱
    static func parseInlineMarkdown(_ text: String) -> Text {
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

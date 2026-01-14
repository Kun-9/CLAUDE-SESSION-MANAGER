// MARK: - 파일 설명
// MarkdownParser: 마크다운 텍스트 파싱 유틸리티
// - 코드 블록(```)과 일반 텍스트 블록 분리
// - 순서 목록(1. item) 감지
// - 인라인 마크다운(굵게, 기울임 등) 파싱

import Foundation
import SwiftUI

enum MarkdownParser {
    // MARK: - Constants

    private enum Delimiter {
        static let codeBlock = "```"
    }

    // MARK: - Types

    /// 마크다운 블록 단위 데이터 모델
    struct Block: Identifiable {
        let id = UUID()
        let kind: Kind

        enum Kind {
            case text(String)
            case code(String)
        }
    }

    // MARK: - Public Methods

    /// 마크다운 텍스트를 코드/텍스트 블록으로 분리
    /// - Parameter text: 원본 마크다운 텍스트
    /// - Returns: 블록 배열 (코드 블록과 텍스트 블록)
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

            // 코드 블록 구분자 감지
            if line.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).hasPrefix(Delimiter.codeBlock) {
                if isCode {
                    // 코드 블록 종료
                    if !current.isEmpty {
                        blocks.append(Block(kind: .code(current)))
                        current = ""
                    }
                } else if !current.isEmpty {
                    // 텍스트 블록 종료
                    blocks.append(Block(kind: .text(current)))
                    current = ""
                }
                isCode.toggle()
                continue
            }

            // 현재 블록에 라인 추가
            if !current.isEmpty {
                current.append("\n")
            }
            current.append(line)
        }

        // 마지막 블록 처리
        if !current.isEmpty {
            blocks.append(Block(kind: isCode ? .code(current) : .text(current)))
        }

        return blocks
    }

    /// 순서 목록 항목 파싱 (예: "1. item")
    /// - Parameter line: 파싱할 라인
    /// - Returns: 번호와 내용 튜플, 순서 목록이 아니면 nil
    static func parseOrderedListItem(from line: String) -> (number: String, content: String)? {
        // 점(.) 위치 찾기
        guard let dotIndex = line.firstIndex(of: ".") else {
            return nil
        }

        // 점 앞부분이 숫자인지 확인
        let numberPart = line[..<dotIndex]
        guard !numberPart.isEmpty, numberPart.allSatisfy({ $0.isNumber }) else {
            return nil
        }

        // 점 다음에 공백이 있는지 확인
        let afterDot = line.index(after: dotIndex)
        guard afterDot < line.endIndex, line[afterDot] == " " else {
            return nil
        }

        let content = line[line.index(after: afterDot)...]
        return (String(numberPart), String(content))
    }

    /// 인라인 마크다운 파싱 (굵게, 기울임 등)
    /// - Parameter text: 파싱할 텍스트
    /// - Returns: 스타일이 적용된 Text, 파싱 실패 시 원본 Text
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

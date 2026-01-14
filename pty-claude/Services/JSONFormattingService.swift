// MARK: - 파일 설명
// JSONFormattingService: JSON 포맷팅 및 구문 하이라이팅
// - JSON pretty-print 변환
// - 최상위 키/요소 카운트
// - 정규식 기반 구문 하이라이팅 (키, 문자열, 숫자, 불린)

import Foundation
import SwiftUI

enum JSONFormattingService {
    // MARK: - Constants

    private enum HighlightPattern {
        /// JSON 키 패턴: "key":
        static let key = #"("([^"\\]|\\.)*")\s*:"#
        /// 문자열 값 패턴: : "value"
        static let stringValue = #":\s*("([^"\\]|\\.)*")"#
        /// 숫자 값 패턴: : 123, : -1.5, : 1e10
        static let numberValue = #":\s*(-?\d+(\.\d+)?([eE][+-]?\d+)?)"#
        /// 불린/null 값 패턴: : true, : false, : null
        static let booleanNull = #":\s*(true|false|null)"#
    }

    private enum HighlightColor {
        static let key: Color = .blue
        static let string: Color = .green
        static let number: Color = .orange
        static let booleanNull: Color = .secondary
    }

    // MARK: - Public Methods

    /// JSON 문자열을 pretty-print 포맷으로 변환
    /// - Parameter raw: 원본 JSON 문자열
    /// - Returns: 정렬된 pretty-print JSON, 파싱 실패 시 원본 반환
    static func prettyPrint(_ raw: String) -> String {
        guard let data = raw.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let prettyData = try? JSONSerialization.data(
                withJSONObject: object,
                options: [.prettyPrinted, .sortedKeys]
              ),
              let pretty = String(data: prettyData, encoding: .utf8) else {
            return raw
        }
        return pretty
    }

    /// JSON 최상위 키/요소 개수 반환
    /// - Parameter raw: 원본 JSON 문자열
    /// - Returns: Dictionary의 경우 키 개수, Array의 경우 요소 개수, 그 외 0
    static func keyCount(_ raw: String) -> Int {
        guard let data = raw.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) else {
            return 0
        }
        if let dict = object as? [String: Any] {
            return dict.keys.count
        }
        if let array = object as? [Any] {
            return array.count
        }
        return 0
    }

    /// JSON 문자열에 구문 하이라이팅 적용
    /// - Parameter raw: 원본 JSON 문자열
    /// - Returns: 색상이 적용된 AttributedString
    static func highlighted(_ raw: String) -> AttributedString {
        let pretty = prettyPrint(raw)
        var attributed = AttributedString(pretty)

        // 순서 중요: 키 → 문자열 → 숫자 → 불린/null
        applyHighlight(to: &attributed, in: pretty, pattern: HighlightPattern.key,
                       captureGroup: 1, color: HighlightColor.key)
        applyHighlight(to: &attributed, in: pretty, pattern: HighlightPattern.stringValue,
                       captureGroup: 1, color: HighlightColor.string)
        applyHighlight(to: &attributed, in: pretty, pattern: HighlightPattern.numberValue,
                       captureGroup: 1, color: HighlightColor.number)
        applyHighlight(to: &attributed, in: pretty, pattern: HighlightPattern.booleanNull,
                       captureGroup: 1, color: HighlightColor.booleanNull)

        return attributed
    }

    // MARK: - Private Helpers

    /// 정규식 패턴에 매칭되는 부분에 색상 적용
    private static func applyHighlight(
        to attributed: inout AttributedString,
        in source: String,
        pattern: String,
        captureGroup: Int,
        color: Color
    ) {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return
        }

        let matches = regex.matches(in: source, range: NSRange(source.startIndex..., in: source))
        for match in matches {
            guard match.numberOfRanges > captureGroup else { continue }

            let range = match.range(at: captureGroup)
            guard let stringRange = Range(range, in: source),
                  let attrRange = Range(stringRange, in: attributed) else {
                continue
            }
            attributed[attrRange].foregroundColor = color
        }
    }
}

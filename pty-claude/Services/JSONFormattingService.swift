import Foundation
import SwiftUI

enum JSONFormattingService {
    /// JSON 문자열을 pretty-print 포맷으로 변환
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
    static func highlighted(_ raw: String) -> AttributedString {
        let pretty = prettyPrint(raw)
        var attributed = AttributedString(pretty)

        applyHighlight(to: &attributed, in: pretty, pattern: #"("([^"\\]|\\.)*")\s*:"#,
                       captureGroup: 1, color: .blue)
        applyHighlight(to: &attributed, in: pretty, pattern: #":\s*("([^"\\]|\\.)*")"#,
                       captureGroup: 1, color: .green)
        applyHighlight(to: &attributed, in: pretty, pattern: #":\s*(-?\d+(\.\d+)?([eE][+-]?\d+)?)"#,
                       captureGroup: 1, color: .orange)
        applyHighlight(to: &attributed, in: pretty, pattern: #":\s*(true|false|null)"#,
                       captureGroup: 1, color: .secondary)

        return attributed
    }

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
            guard match.numberOfRanges > captureGroup else {
                continue
            }
            let range = match.range(at: captureGroup)
            guard let stringRange = Range(range, in: source),
                  let attrRange = Range(stringRange, in: attributed) else {
                continue
            }
            attributed[attrRange].foregroundColor = color
        }
    }
}

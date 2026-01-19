import AppKit
import Foundation
import SwiftUI
import Textual

// MARK: - 파일 설명
// MarkdownMessageView: 마크다운 텍스트 렌더링 뷰
// - Textual 라이브러리 기반 전체 렌더링
// - 코드 블록 문법 하이라이팅 + 복사 버튼
// - 표, 구분선 커스텀 스타일

struct MarkdownMessageView: View {
    let text: String

    var body: some View {
        StructuredText(markdown: text)
            .font(.body)
            .foregroundStyle(.primary)
            .textual.codeBlockStyle(CustomCodeBlockStyle())
            .textual.tableStyle(CustomTableStyle())
            .textual.tableCellStyle(CustomTableCellStyle())
            .textual.thematicBreakStyle(CustomThematicBreakStyle())
            .textSelection(.enabled)
    }
}

// MARK: - 코드 블록 스타일 (문법 하이라이팅 + 복사 버튼)

private struct CustomCodeBlockStyle: StructuredText.CodeBlockStyle {
    func makeBody(configuration: Configuration) -> some View {
        ZStack(alignment: .topTrailing) {
            // 코드 내용 (Textual 문법 하이라이팅 적용)
            Overflow {
                configuration.label
                    .textual.lineSpacing(.fontScaled(0.2))
                    .textual.fontScale(0.85)
                    .fixedSize(horizontal: false, vertical: true)
                    .monospaced()
                    .padding(12)
                    .padding(.trailing, 28)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // 복사 버튼
            Button {
                configuration.codeBlock.copyToPasteboard()
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(6)
            }
            .buttonStyle(.plain)
            .padding(6)
            .help("복사")
            .accessibilityLabel("복사")
        }
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.06))
        )
        .textual.blockSpacing(.init(top: 12, bottom: 12))
    }
}

// MARK: - 테이블 스타일

private struct CustomTableStyle: StructuredText.TableStyle {
    private static let borderWidth: CGFloat = 1
    private static let borderColor = Color.primary.opacity(0.2)
    private static let rowBackground = Color.primary.opacity(0.03)

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .textual.tableCellSpacing(horizontal: Self.borderWidth, vertical: Self.borderWidth)
            .textual.blockSpacing(.init(top: 16, bottom: 16))
            .padding(Self.borderWidth)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Self.borderColor, lineWidth: Self.borderWidth)
            )
    }

    func makeBackground(layout: StructuredText.TableLayout) -> some View {
        Canvas { context, _ in
            for bounds in layout.rowIndices.dropFirst().filter({ $0.isMultiple(of: 2) }).map({ layout.rowBounds($0) }) {
                context.fill(
                    Path(bounds.integral),
                    with: .color(Self.rowBackground)
                )
            }
        }
    }

    func makeOverlay(layout: StructuredText.TableLayout) -> some View {
        Canvas { context, _ in
            for divider in layout.dividers() {
                context.fill(
                    Path(divider),
                    with: .color(Self.borderColor)
                )
            }
        }
    }
}

// MARK: - 테이블 셀 스타일

private struct CustomTableCellStyle: StructuredText.TableCellStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .fontWeight(configuration.row == 0 ? .semibold : .regular)
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(configuration.row == 0 ? Color.primary.opacity(0.06) : Color.clear)
    }
}

// MARK: - 구분선 스타일

private struct CustomThematicBreakStyle: StructuredText.ThematicBreakStyle {
    func makeBody(configuration _: Configuration) -> some View {
        Divider()
            .textual.frame(height: .fontScaled(0.25))
            .overlay(Color.primary.opacity(0.2))
            .textual.blockSpacing(.init(top: 16, bottom: 16))
    }
}

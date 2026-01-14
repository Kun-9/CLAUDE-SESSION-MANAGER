import SwiftUI

struct SessionSummaryView: View {
    let prompt: String?
    let response: String?
    let maxResponseCharacters: Int?

    init(prompt: String?, response: String?, maxResponseCharacters: Int? = nil) {
        self.prompt = prompt
        self.response = response
        self.maxResponseCharacters = maxResponseCharacters
    }

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 4, verticalSpacing: 4) {
            if let prompt {
                summaryRow(label: "Q", text: trimmed(prompt), color: .primary)
            }
            if let response {
                summaryRow(label: "A", text: trimmed(response), color: .secondary)
            }
        }
    }

    private func trimmed(_ value: String) -> String {
        guard let maxResponseCharacters, value.count > maxResponseCharacters else {
            return value
        }
        let cutoff = max(0, maxResponseCharacters - 3)
        let prefix = value.prefix(cutoff)
        return "\(prefix)..."
    }

    @ViewBuilder
    private func summaryRow(label: String, text: String, color: Color) -> some View {
        GridRow {
            Text("\(label):")
                .font(.subheadline)
                .foregroundStyle(color)
                .gridColumnAlignment(.trailing)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(color)
                .lineLimit(1)
                .truncationMode(.tail)
                .gridColumnAlignment(.leading)
        }
    }
}

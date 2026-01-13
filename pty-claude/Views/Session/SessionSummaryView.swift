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
        VStack(alignment: .leading, spacing: 4) {
            if let prompt {
                Text("Q: \(prompt)")
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            if let response {
                Text("A: \(trimmed(response))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
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
}

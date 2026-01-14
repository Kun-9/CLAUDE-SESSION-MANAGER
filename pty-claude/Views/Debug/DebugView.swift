import Combine
import SwiftUI

private let debugTimestampFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy.MM.dd HH:mm:ss"
    return formatter
}()

struct DebugView: View {
    @EnvironmentObject private var debugLogStore: DebugLogStore
    @AppStorage(SettingsKeys.debugEnabled, store: SettingsStore.defaults) private var debugEnabled = false
    @State private var expandedPayloadIds: Set<UUID> = []
    private let refreshTimer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeaderView(
                    title: "Debug",
                    subtitle: "Inspect incoming hook payloads."
                )

                HStack(spacing: 12) {
                    Toggle("Debug mode", isOn: $debugEnabled)
                        .toggleStyle(.switch)
                    Spacer()
                    Button("Refresh") {
                        debugLogStore.reload()
                    }
                    .buttonStyle(.bordered)
                    Button("Clear") {
                        debugLogStore.clear()
                    }
                    .buttonStyle(.bordered)
                    .disabled(debugLogStore.entries.isEmpty)
                }

                if debugLogStore.entries.isEmpty {
                    Text("No logs yet.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(debugLogStore.entries.reversed()) { entry in
                            debugCard(for: entry)
                        }
                    }
                }
            }
            .padding(24)
        }
        .onAppear {
            debugLogStore.reload()
        }
        .onChange(of: debugEnabled) { _, _ in
            debugLogStore.reload()
        }
        .onReceive(refreshTimer) { _ in
            guard debugEnabled else { return }
            debugLogStore.reload()
        }
    }

    private func debugCard(for entry: DebugLogEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(entry.hookName)
                    .font(.headline)
                Spacer()
                Text(debugTimestampFormatter.string(from: Date(timeIntervalSince1970: entry.timestamp)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let toolName = entry.toolName, !toolName.isEmpty {
                metaRow(label: "Tool", value: toolName)
            }
            if let sessionId = entry.sessionId, !sessionId.isEmpty {
                metaRow(label: "Session", value: sessionId)
            }
            if let cwd = entry.cwd, !cwd.isEmpty {
                metaRow(label: "CWD", value: cwd)
            }
            if let transcriptPath = entry.transcriptPath, !transcriptPath.isEmpty {
                metaRow(label: "Transcript", value: transcriptPath, emphasized: true)
            }
            if let prompt = entry.prompt, !prompt.isEmpty {
                metaRow(label: "Prompt", value: prompt)
            }

            Button {
                togglePayload(entry.id)
            } label: {
                payloadHeader(for: entry)
            }
            .buttonStyle(.plain)

            if expandedPayloadIds.contains(entry.id) {
                Text(highlightedPayload(entry.rawPayload))
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.primary.opacity(0.04))
                    )
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    private func togglePayload(_ id: UUID) {
        if expandedPayloadIds.contains(id) {
            expandedPayloadIds.remove(id)
        } else {
            expandedPayloadIds.insert(id)
        }
    }

    private func payloadHeader(for entry: DebugLogEntry) -> some View {
        let isExpanded = expandedPayloadIds.contains(entry.id)
        let sizeText = "\(payloadKeyCount(entry.rawPayload))"

        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text("Payload")
                    .font(.headline)
                Text(sizeText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.primary.opacity(0.08))
                    )
            }
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func metaRow(label: String, value: String, emphasized: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("\(label):")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption)
                .padding(.horizontal, emphasized ? 6 : 0)
                .padding(.vertical, emphasized ? 2 : 0)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(emphasized ? Color.accentColor.opacity(0.14) : Color.clear)
                )
                .textSelection(.enabled)
        }
    }

    private func highlightedPayload(_ rawPayload: String) -> AttributedString {
        let pretty = prettyPrintedJSON(from: rawPayload)
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

    private func prettyPrintedJSON(from raw: String) -> String {
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

    private func payloadKeyCount(_ rawPayload: String) -> Int {
        guard let data = rawPayload.data(using: .utf8),
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

    private func applyHighlight(
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

#Preview {
    DebugView()
        .environmentObject(DebugLogStore())
}

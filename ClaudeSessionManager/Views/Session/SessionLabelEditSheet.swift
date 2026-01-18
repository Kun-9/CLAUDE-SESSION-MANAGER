// MARK: - 파일 설명
// SessionLabelEditPopover: 세션 라벨 편집 팝오버
// - 사용자가 세션 이름을 수정할 수 있는 컴팩트한 편집 UI
// - Enter로 저장, Esc로 취소

import SwiftUI

struct SessionLabelEditPopover: View {
    let session: SessionItem
    let onSave: (String) -> Void
    let onCancel: () -> Void

    @State private var draftLabel: String = ""
    @FocusState private var isFocused: Bool

    init(session: SessionItem, onSave: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
        self.session = session
        self.onSave = onSave
        self.onCancel = onCancel
        _draftLabel = State(initialValue: session.name)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("이름 변경")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("세션 이름", text: $draftLabel)
                .textFieldStyle(.roundedBorder)
                .focused($isFocused)
                .frame(width: 220)
                .onChange(of: draftLabel) { _, newValue in
                    if newValue.count > 50 {
                        draftLabel = String(newValue.prefix(50))
                    }
                }
                .onSubmit {
                    save()
                }
                .onExitCommand {
                    onCancel()
                }

            HStack(spacing: 8) {
                Spacer()

                Button("저장") {
                    save()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(!hasChanges)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(12)
        .task {
            // Popover 애니메이션 완료 후 포커스 설정
            try? await Task.sleep(for: .milliseconds(100))
            isFocused = true
        }
    }

    // MARK: - Private Helpers

    private var hasChanges: Bool {
        let trimmed = draftLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed != session.name
    }

    private func save() {
        let trimmed = draftLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != session.name else {
            onCancel()
            return
        }
        onSave(trimmed)
    }
}


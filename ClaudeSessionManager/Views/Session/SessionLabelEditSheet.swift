// MARK: - 파일 설명
// SessionLabelEditSheet: 세션 라벨 편집 시트
// - 사용자가 세션 이름을 수정할 수 있는 간단한 편집 UI
// - 저장/취소 버튼 제공

import SwiftUI

struct SessionLabelEditSheet: View {
    let session: SessionItem
    let onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var draftLabel: String = ""
    @FocusState private var isFocused: Bool

    init(session: SessionItem, onSave: @escaping (String) -> Void) {
        self.session = session
        self.onSave = onSave
        _draftLabel = State(initialValue: session.name)
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("세션 이름 변경")
                .font(.headline)

            TextField("세션 이름", text: $draftLabel)
                .textFieldStyle(.roundedBorder)
                .focused($isFocused)
                .onChange(of: draftLabel) { _, newValue in
                    if newValue.count > 50 {
                        draftLabel = String(newValue.prefix(50))
                    }
                }
                .onSubmit {
                    save()
                }

            HStack {
                Button("취소") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("저장") {
                    save()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!hasChanges)
            }
        }
        .padding(20)
        .frame(width: 300)
        .onAppear {
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
            dismiss()
            return
        }
        onSave(trimmed)
        dismiss()
    }
}

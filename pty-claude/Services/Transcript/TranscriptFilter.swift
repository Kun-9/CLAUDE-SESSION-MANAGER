import Foundation

enum TranscriptFilter {
    // MARK: - Public Methods

    /// 트랜스크립트 필터링
    /// - Parameters:
    ///   - entries: 전체 엔트리
    ///   - showDetail: true면 모든 메시지 표시 (User Detail + Assistant Detail)
    static func filteredEntries(
        _ entries: [TranscriptEntry],
        showDetail: Bool
    ) -> [TranscriptEntry] {
        // 상세보기 모드면 모든 메시지 표시
        if showDetail {
            return entries
        }

        // 1. Assistant 최종 응답 ID 수집 (중간 응답 필터링용)
        let finalAssistantIds = findFinalAssistantIds(entries)

        // 2. 필터링: 직접 입력 user + 최종 assistant만
        return entries.filter { entry in
            if entry.role == .assistant {
                return finalAssistantIds.contains(entry.id)
            }
            return isDirectUserInput(entry)
        }
    }

    /// 중간 응답인지 확인 (UI 표시용)
    static func isIntermediateAssistant(_ entry: TranscriptEntry, in entries: [TranscriptEntry]) -> Bool {
        guard entry.role == .assistant else { return false }
        let finalIds = findFinalAssistantIds(entries)
        return !finalIds.contains(entry.id)
    }

    // MARK: - Private Methods

    /// 각 user 메시지 그룹의 최종 assistant 응답 ID 찾기
    /// - 사용자 직접 입력(user) 이후의 모든 assistant 응답을 그룹화
    /// - 각 그룹에서 마지막 assistant만 최종 응답으로 표시
    private static func findFinalAssistantIds(_ entries: [TranscriptEntry]) -> Set<UUID> {
        var finalIds = Set<UUID>()
        var currentGroupAssistants: [TranscriptEntry] = []

        for entry in entries {
            // 사용자 직접 입력을 만나면 이전 그룹 종료
            if entry.role == .user && isDirectUserInput(entry) {
                // 이전 그룹의 마지막 assistant를 최종으로 마킹
                if let last = currentGroupAssistants.last {
                    finalIds.insert(last.id)
                }
                currentGroupAssistants = []
            } else if entry.role == .assistant {
                currentGroupAssistants.append(entry)
            }
        }

        // 마지막 그룹 처리
        if let last = currentGroupAssistants.last {
            finalIds.insert(last.id)
        }

        return finalIds
    }

    /// 사용자 직접 입력인지 확인 (UI 표시용)
    static func isDirectUserInput(_ entry: TranscriptEntry) -> Bool {
        if let entryType = entry.entryType?.lowercased(),
           let messageRole = entry.messageRole?.lowercased() {
            guard entryType == "user", messageRole == "user" else {
                return false
            }
            if entry.isMeta == true {
                return false
            }
            if entry.messageContentIsString != true {
                return false
            }
        } else if entry.role != .user {
            return false
        }

        let content = entry.text
        let systemTags = [
            "<command-name>", "<command-message>", "<command-args>",
            "<local-command-stdout>", "<local-command-stderr>",
            "<local-command-caveat>", "<system-reminder>",
            "<function_results>", "tool_use_id", "tool_result",
        ]
        return !systemTags.contains(where: { content.contains($0) })
    }
}

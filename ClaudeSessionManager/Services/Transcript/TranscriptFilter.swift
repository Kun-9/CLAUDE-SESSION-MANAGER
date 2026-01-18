import Foundation

/// 트랜스크립트 엔트리별 사전 계산된 메타데이터 캐시
/// - 성능 최적화: O(n) 계산을 한 번만 수행하여 각 셀에서 O(1) 조회
struct TranscriptEntryCache {
    /// 중간 응답 여부 (entry.id -> Bool)
    let isIntermediate: [UUID: Bool]
    /// 최종 응답의 누적 토큰 (entry.id -> TokenUsage)
    let cumulativeUsage: [UUID: TokenUsage]

    static let empty = TranscriptEntryCache(isIntermediate: [:], cumulativeUsage: [:])
}

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
    /// - Note: 성능이 중요한 목록 렌더링에서는 buildCache()로 일괄 계산 후 캐시 사용 권장
    static func isIntermediateAssistant(_ entry: TranscriptEntry, in entries: [TranscriptEntry]) -> Bool {
        guard entry.role == .assistant else { return false }
        let finalIds = findFinalAssistantIds(entries)
        return !finalIds.contains(entry.id)
    }

    // MARK: - Cache Builder (Performance Optimization)

    /// 전체 엔트리에 대해 메타데이터를 일괄 계산하여 캐시 생성
    /// - 목록 렌더링 전 한 번 호출하여 O(n) 계산을 한 번만 수행
    /// - 각 셀에서는 캐시된 값을 O(1)로 조회
    static func buildCache(for entries: [TranscriptEntry]) -> TranscriptEntryCache {
        // 1. 최종 응답 ID 집합 계산
        let finalIds = findFinalAssistantIds(entries)

        // 2. 중간 응답 여부 딕셔너리 생성
        var isIntermediate: [UUID: Bool] = [:]
        for entry in entries where entry.role == .assistant {
            isIntermediate[entry.id] = !finalIds.contains(entry.id)
        }

        // 3. 누적 토큰 계산 (최종 응답에만)
        let cumulativeUsage = calculateAllCumulativeUsages(entries: entries, finalIds: finalIds)

        return TranscriptEntryCache(
            isIntermediate: isIntermediate,
            cumulativeUsage: cumulativeUsage
        )
    }

    /// 모든 최종 응답의 누적 토큰 계산
    private static func calculateAllCumulativeUsages(
        entries: [TranscriptEntry],
        finalIds: Set<UUID>
    ) -> [UUID: TokenUsage] {
        var result: [UUID: TokenUsage] = [:]

        // 프롬프트 그룹 경계 찾기 (직접 사용자 입력 위치)
        var promptBoundaries: [Int] = []
        for (index, entry) in entries.enumerated() {
            if isDirectUserInput(entry) {
                promptBoundaries.append(index)
            }
        }
        // 마지막 경계 추가 (배열 끝)
        promptBoundaries.append(entries.count)

        // 각 프롬프트 그룹별로 누적 토큰 계산
        for i in 0..<(promptBoundaries.count - 1) {
            let startIndex = promptBoundaries[i] + 1  // 사용자 입력 다음부터
            let endIndex = promptBoundaries[i + 1] - 1  // 다음 사용자 입력 전까지

            guard startIndex <= endIndex else { continue }

            // 그룹 내 토큰 합산 (requestId 중복 제거)
            var groupUsage = TokenUsage.zero
            var seenRequestIds = Set<String>()

            for j in startIndex...endIndex {
                let entry = entries[j]
                guard entry.role == .assistant, let usage = entry.usage else { continue }

                if let requestId = entry.requestId {
                    if seenRequestIds.contains(requestId) { continue }
                    seenRequestIds.insert(requestId)
                }
                groupUsage = groupUsage.adding(usage)
            }

            // 그룹의 최종 응답에 누적 토큰 할당
            for j in startIndex...endIndex {
                let entry = entries[j]
                if finalIds.contains(entry.id) {
                    result[entry.id] = groupUsage
                }
            }
        }

        // 첫 번째 프롬프트 경계 이전의 assistant 처리 (시작부터 첫 사용자 입력까지)
        if let firstBoundary = promptBoundaries.first, firstBoundary > 0 {
            var groupUsage = TokenUsage.zero
            var seenRequestIds = Set<String>()

            for j in 0..<firstBoundary {
                let entry = entries[j]
                guard entry.role == .assistant, let usage = entry.usage else { continue }

                if let requestId = entry.requestId {
                    if seenRequestIds.contains(requestId) { continue }
                    seenRequestIds.insert(requestId)
                }
                groupUsage = groupUsage.adding(usage)
            }

            for j in 0..<firstBoundary {
                let entry = entries[j]
                if finalIds.contains(entry.id) {
                    result[entry.id] = groupUsage
                }
            }
        }

        return result
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

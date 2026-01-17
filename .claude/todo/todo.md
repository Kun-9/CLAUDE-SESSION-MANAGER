# Project TODO

<!--
사용법:
- /todo : 목록 조회 및 관리
- /todo add <할일> : 새 항목 추가

비용: S(소) / M(중) / L(대)
영향도: Low / Mid / High
-->

## 보안

- [x] [심각] Command Injection 취약점 수정
  - 설명: ITermService의 AppleScript 문자열 보간에서 입력값(location, sessionId)에 작은따옴표(') 등 특수문자가 포함될 경우 명령 이스케이프 처리가 없어 임의 명령 실행 가능
  - 해결: `escapeForShellSingleQuote`, `escapeForAppleScript` 함수 추가 및 적용
  - 비용: S
  - 영향도: High
  - 관련 파일: `ClaudeSessionManager/Services/ITermService.swift`
  - 완료일: 2026-01-15

- [x] [중간] 경로 인코딩 충돌 가능성
  - 설명: ClaudeSessionService의 encodeProjectPath가 단순 `/` → `-` 치환만 수행
  - 해결: Claude Code와 동일한 방식 확인 완료, 주석으로 의도 명확화 (수정 불필요)
  - 비용: S
  - 영향도: Mid
  - 관련 파일: `ClaudeSessionManager/Services/ClaudeSessionService.swift`
  - 완료일: 2026-01-15

## 버그

- [x] [사소] 배열 삽입 로직 불필요한 min 연산
  - 설명: SessionStore.updateSessionStatus의 191번 라인에서 `min(index, sessions.count)` 사용
  - 해결: min이 필요한 이유를 주석으로 명확화 (remove 후 index가 count와 같아질 수 있음)
  - 비용: S
  - 영향도: Low
  - 관련 파일: `ClaudeSessionManager/Services/SessionStore.swift:191`
  - 완료일: 2026-01-15

## UI 개선

- [x] Compact 카드 Unread 상태 표시 누락
  - 설명: isUnseen 상태일 때 반짝이는 테두리 효과가 full 카드에서만 동작하고 compact 카드(그리드)에서는 onAppear에서 isGlowing 설정이 누락됨
  - 비용: S
  - 영향도: Low
  - 관련 파일: `ClaudeSessionManager/Views/Session/SessionCardView.swift`
  - 완료일: 2026-01-15

- [x] 세션 상태 표시 개선
  - 설명: 진행중/완료/종료 필터 토글의 색상을 중립(gray)으로 변경하고 선택/미선택 피드백 개선
  - 해결: SessionStatusFilter의 tint/background 속성 제거, 토글 스타일을 SessionListModeToggle과 일관성 있게 통일
  - 비용: S
  - 영향도: Mid
  - 관련 파일: `SessionListViewModel.swift`, `SessionView.swift`
  - 완료일: 2026-01-15

- [x] 세션 라벨링 기능
  - 설명: 사용자가 세션에 커스텀 제목을 수동 입력 (선택적, 미입력시 기존 자동 제목 사용)
  - 해결: SessionStore.updateSessionLabel, SessionLabelEditSheet 추가, Context 메뉴에 "이름 변경" 버튼 추가
  - 비용: M
  - 영향도: Mid
  - 관련 파일: `SessionStore.swift`, `SessionLabelEditSheet.swift`, `SessionView.swift`
  - 완료일: 2026-01-15

## 버그

- [x] Compact 카드 인디케이터 위치 불일치
  - 설명: 시간 표시가 한 줄(duration만)일 때와 두 줄(duration + updatedText)일 때 CompactStatusIndicator의 수직 위치가 달라짐. HStack 내 VStack 높이 변화로 인해 발생
  - 해결: HStack에 `.alignment: .bottom` 추가하여 인디케이터가 항상 하단 정렬되도록 수정
  - 비용: S
  - 영향도: Low
  - 관련 파일: `ClaudeSessionManager/Views/Session/SessionCardView.swift:172`
  - 완료일: 2026-01-15

- [x] Command+Hover 오버레이 상태 유지 버그
  - 설명: `isCommandPressed` 상태가 뷰 재사용 시 이전 값 유지됨. cmd+클릭으로 대화 이어가기 후, Command 키를 떼도 "대화 이어하기" 오버레이가 계속 표시되는 문제
  - 해결: `NSApplication.didBecomeActiveNotification` 감지하여 앱 활성화 시 Command 키 상태 재확인
  - 비용: S
  - 영향도: Mid
  - 관련 파일: `ClaudeSessionManager/Views/Session/SessionCardView.swift:300-403`
  - 완료일: 2026-01-15

## UI 기능

- [ ] ~~이미 실행 중인 세션 감지 기능~~ (구현 불가)
  - 설명: Resume 버튼 클릭 시 해당 Claude 세션이 이미 터미널에서 실행 중인지 확인
  - 사유: Claude CLI가 `--resume` 인자를 프로세스 명령줄에 노출하지 않음. 세션 ID가 환경 변수로도 노출되지 않아 특정 세션의 실행 여부를 외부에서 확인할 방법이 없음

- [x] Full 레이아웃(리스트 뷰) 섹션 헤더에 터미널 열기 버튼 추가
  - 설명: 격자(SessionGridView) 섹션 헤더에는 `TerminalService.openDirectory()` 버튼이 있으나, 리스트 뷰(sectionListView)의 섹션 헤더에는 터미널 열기 버튼 없음
  - 해결: sectionListView의 SessionSectionHeader에 `onTerminalTap` 파라미터 추가, 그리드 뷰와 동일하게 디렉토리 이름 옆에 터미널 버튼 표시
  - 비용: XS
  - 영향도: Low
  - 관련 파일: `ClaudeSessionManager/Views/Session/SessionView.swift:103-115`
  - 완료일: 2026-01-17

- [x] 즐겨찾기 섹션 기능
  - 설명: 디렉토리 섹션을 즐겨찾기로 지정 가능. 섹션 헤더 왼쪽에 별(★) 아이콘으로 표시/토글. 즐겨찾기 섹션은 세션이 없어도 '새 세션' 버튼과 함께 항상 표시됨
  - 해결:
    - SessionSection에 isFavorite 속성 추가
    - SessionSectionHeader에 별 아이콘 토글 버튼 추가
    - SessionGroupingService에 즐겨찾기 CRUD 및 정렬 로직 추가
    - 빈 즐겨찾기 섹션 자동 표시 (세션 없어도 표시)
    - 즐겨찾기 섹션 상단 우선 정렬
  - 비용: M
  - 영향도: Mid
  - 관련 파일: `SessionSection.swift`, `SessionGroupingService.swift`, `SessionView.swift`, `SessionGridView.swift`, `SessionListViewModel.swift`, `SettingsStore.swift`
  - 완료일: 2026-01-15

## 설정

- [x] 터미널 앱 선택 기능
  - 설명: 설정에서 사용할 터미널 앱(iTerm, Terminal.app) 선택 및 권한 상태 표시
  - 해결:
    - TerminalApp enum 및 SettingsStore에 터미널 설정 추가
    - TerminalService 생성 (iTerm2, Terminal.app 지원)
    - SettingsSheet에 Terminal 탭 추가
    - 모든 ITermService 호출을 TerminalService로 교체
    - ITermService.swift 파일 삭제 (코드 정리)
  - 비용: M
  - 영향도: Mid
  - 관련 파일: `SettingsStore.swift`, `TerminalService.swift`, `SettingsSheet.swift`, `SessionView.swift`, `SessionCardView.swift`, `SessionGridView.swift`, `SessionDetailSheet.swift`
  - 완료일: 2026-01-16

## 조사/검토

- [x] 터미널 열기 딜레이 개선 방안 조사
  - 설명: 현재 터미널(iTerm)을 열 때마다 새 창/탭을 AppleScript로 생성하여 딜레이 발생. 딜레이 없이 빠르게 터미널을 열 수 있는 방법 모색 필요
  - 해결: **기존 창에 탭 추가 방식으로 변경**
    - 새 창 생성: ~0.9초 → 기존 창에 탭 추가: ~0.1초 (**10배 이상 빠름**)
    - iTerm2, Terminal.app 모두 동일 패턴 적용
    - 창이 없을 때만 새 창 생성, 있으면 탭 추가
  - 비용: M
  - 영향도: Mid
  - 관련 파일: `ClaudeSessionManager/Services/TerminalService.swift`
  - 완료일: 2026-01-16
  - 조사 대상:
    - [x] 기존 iTerm 창/탭 재사용 가능 여부
      - 결론: **채택** - `create tab with default profile` 사용
    - [x] AppleScript 대신 URL Scheme 사용 가능 여부
      - 결론: **불가** - 보안 문제로 2011년 제거됨
    - [x] 백그라운드에서 미리 터미널 세션 준비
      - 결론: **불필요** - 탭 추가 방식이 충분히 빠름 (0.1초)
    - [x] Terminal.app 딜레이 비교 테스트
      - 결론: **동일 패턴 적용** - Terminal.app도 탭 추가 방식으로 개선

- [x] iTerm 세션 호출 방식 개선 검토
  - 설명: `zsh -lc 'command; exec zsh'` 패턴으로 iTerm 세션 시작 가능 여부 확인. 현재 AppleScript 방식 대비 장단점 비교 필요
  - 결론: **현재 방식(AppleScript `write text`) 유지**
    - `zsh -lc` 방식: CLI에서는 동작하나 앱 내 자동화 권한 문제 있음
    - 현재 방식이 히스토리 기록, 명령어 표시(투명성) 면에서 우수
  - 비용: S
  - 영향도: Low
  - 관련 파일: `ClaudeSessionManager/Services/TerminalService.swift`
  - 완료일: 2026-01-16

## 설정 UI

- [x] 설정 탭 이름 변경 (Claude → Hooks)
  - 설명: 설정 시트의 "Claude" 탭 이름을 "Hooks"로 변경. 탭 기능이 Claude 훅 설정이므로 더 명확한 이름으로 수정
  - 해결: SettingsTab enum에서 `.claude` → `.hooks`로 변경, 관련 참조 및 주석 업데이트
  - 비용: XS
  - 영향도: Low
  - 관련 파일: `ClaudeSessionManager/Views/Settings/SettingsSheet.swift`
  - 완료일: 2026-01-16

## 버그

- [x] Preview Changes 첫 클릭 시 빈 화면 버그
  - 설명: 설정 > Hooks 탭에서 "Preview Changes" 버튼을 처음 누르면 빈 화면이 표시되고, 두 번째 클릭에야 정상적으로 미리보기가 표시됨
  - 해결: 상태 업데이트와 시트 표시의 SwiftUI 렌더링 타이밍 문제. `DispatchQueue.main.async`로 시트 표시를 다음 런루프로 지연하여 해결
  - 비용: S
  - 영향도: Mid
  - 관련 파일: `ClaudeSessionManager/Views/Settings/SettingsSheet.swift`
  - 완료일: 2026-01-16

## 마크다운 렌더링

- [ ] 마크다운 렌더링 개선
  - 설명: 현재 자체 파서(MarkdownParser)는 코드/텍스트 블록 분리만 지원. 라이브러리 검토 후 코드 하이라이팅과 표 렌더링 추가
  - 비용: L (하위 합산)
  - 영향도: Mid
  - 관련 파일: `ClaudeSessionManager/Utilities/MarkdownParser.swift`, `ClaudeSessionManager/Views/Session/MarkdownMessageView.swift`
  - 하위 항목:
    - [ ] 마크다운 라이브러리 검토
      - 설명: swift-markdown(Apple), Ink, Down 등 기존 라이브러리 비교 검토
      - 비용: S
    - [ ] 코드 블록 타입별 신택스 하이라이팅
      - 설명: ` ```swift `, ` ```python ` 등 언어 타입 파싱 후 색상 하이라이팅 적용. **HighlightSwift** 라이브러리 사용 (185개 언어, 30+ 테마, SwiftUI 네이티브)
      - 비용: M
    - [ ] 마크다운 표(Table) 렌더링
      - 설명: `| col1 | col2 |` 형식의 GFM 표 파싱 및 렌더링. Grid 또는 HStack/VStack 조합으로 구현
      - 비용: M

## Debug 기능

- [x] Debug 패널 payload 복사 버튼 추가
  - 설명: Payload 헤더 영역에 복사 버튼 추가. 클릭 시 `rawPayload`(JSON 문자열)를 클립보드에 복사. 기존 `ClipboardService.copy()` 활용
  - 해결: Payload 헤더 옆에 `doc.on.doc` 아이콘 버튼 추가, `ClipboardService.copy(entry.rawPayload)` 호출
  - 비용: XS
  - 영향도: Low
  - 관련 파일: `ClaudeSessionManager/Views/Debug/DebugView.swift`
  - 완료일: 2026-01-17

## 버그

- [x] 권한 요청 툴팁 z-index 문제
  - 설명: 선택지(AskUserQuestion) 권한 요청에서 옵션 hover 시 표시되는 description 툴팁이 하단 요소(Submit 버튼 등) 아래에 렌더링됨. 툴팁이 최상위 레이어에 표시되어야 함
  - 원인: 툴팁 오버레이가 InlineQuestionSelectionView 내부에 있어 부모 레벨의 Submit 버튼보다 zIndex가 낮음
  - 해결: `hoveredTooltip` 상태를 `InlinePermissionRequestView`로 이동하여 Submit 버튼과 같은 레벨에서 렌더링. `InlineQuestionSelectionView`는 `onHoverTooltip` 콜백으로 툴팁 정보만 전달
  - 비용: S
  - 영향도: Mid
  - 관련 파일: `ClaudeSessionManager/Views/Components/PermissionRequestView.swift`
  - 완료일: 2026-01-16

## 성능 최적화

- [x] ElapsedTimeText 타이머 → TimelineView 교체
  - 설명: 현재 `Timer.publish(every: 1)` 방식은 세션 카드마다 독립 타이머 생성. 카드 10개면 타이머 10개가 매초 발동하며 백그라운드/화면 밖에서도 계속 실행됨. SwiftUI의 `TimelineView(.periodic)` 사용 시 시스템이 스케줄링 최적화하고 화면 밖이면 자동 중단
  - 해결: `Timer.publish` + `onReceive` → `TimelineView(.periodic(from: .now, by: 1.0))` 교체
  - 비용: S
  - 영향도: High
  - 관련 파일: `ClaudeSessionManager/Views/Session/SessionCardView.swift:237`
  - 완료일: 2026-01-16

- [x] PermissionRequest 폴링 타이머 제거
  - 설명: 현재 1초마다 `loadPendingRequests()` 폴링하여 터미널 권한 응답 감지. 이미 `PostToolUse` 훅에서 `SessionStore.notifySessionsUpdated()` 호출 중이므로 `sessionsDidChangeNotification` 구독으로 대체 가능. 폴링 완전 제거
  - 해결: `refreshTimer` 제거, `SessionStore.sessionsDidChangeNotification` 구독 추가
  - 비용: S
  - 영향도: High
  - 관련 파일: `ClaudeSessionManager/Views/Components/PermissionRequestView.swift:67-95`
  - 완료일: 2026-01-16

## UI 기능 개선

- [ ] 권한/선택 요청 영역 컨텍스트 메뉴 추가
  - 설명: InlinePermissionRequestView(세션 카드 아래 인라인 권한 요청 영역)에서 우클릭 시 기존 SessionContextMenu와 동일한 액션(상태 변경, 이름 변경, 대화 이어하기, 삭제) 제공. 현재는 세션 카드에서만 우클릭 메뉴가 동작하고 권한 요청 영역에서는 동작하지 않음
  - 비용: S
  - 영향도: Low
  - 관련 파일: `ClaudeSessionManager/Views/Components/PermissionRequestView.swift`, `ClaudeSessionManager/Views/Session/SessionGridView.swift`

## UI 일관성

- [x] Unread 상태 표시 개선 (애니메이션 → 정적)
  - 설명: 현재 isUnseen 상태의 세션 카드에 반짝이는(glowing) 테두리 애니메이션이 적용됨. 시각적으로 산만할 수 있으므로 정적 표시(테두리 색상 변화, 뱃지 등)로 변경
  - 해결: `isGlowing` 상태 및 repeatForever 애니메이션 제거, 정적인 2px 두께의 상태 색상 테두리로 변경 (full/compact 카드 모두)
  - 비용: S
  - 영향도: Low
  - 관련 파일: `ClaudeSessionManager/Views/Session/SessionCardView.swift`
  - 완료일: 2026-01-16

- [ ] 권한/선택 요청 버튼 디자인 개선
  - 설명: 권한 요청과 선택 요청의 버튼 디자인 및 라벨 일관성 문제 해결
  - 비용: S (하위 합산)
  - 영향도: Mid
  - 관련 파일: `ClaudeSessionManager/Views/Components/PermissionRequestView.swift`
  - 하위 항목:
    - [ ] 터미널 위임 버튼 라벨 통일
      - 설명: 현재 권한 요청은 "Ask", 선택 요청은 "터미널에서"/"터미널"로 표시됨. 같은 기능(Claude Code 터미널로 위임)인데 라벨이 달라 혼란스러움. 일관된 라벨로 통일 필요 (예: 모두 "터미널에서" 또는 "Ask in Terminal")
      - 비용: XS
    - [ ] ALLOW/DENY/ASK 버튼 스타일 개선
      - 설명: 버튼 색상, 크기, 아이콘 등 디자인 요소 검토 및 개선. 현재 Allow=초록, Deny=빨강은 직관적이나 Ask 버튼이 시각적으로 약함
      - 비용: XS
    - [ ] 선택 화면 Enter 제출 기능
      - 설명: 권한/선택 요청 화면에서 "Other" TextField 입력 후 Enter 키로 제출 가능하도록 개선. 버튼 활성화 조건(canSubmitWithAnswers)과 동일한 조건에서만 제출
      - 비용: S

## 알림

- [ ] ~~알림 클릭 시 앱 활성화 기능~~ (구현 안함)
  - 설명: 훅 발생 시 표시되는 알림을 클릭하면 앱 창으로 이동
  - 사유: CLI 훅에서 AppleScript `display notification` 사용 중이며, 이 방식은 클릭 이벤트를 지원하지 않음. IPC를 통한 앱 위임 방식은 복잡도 대비 효용이 낮음

## 트랜스크립트 기능

- [x] 실시간 트랜스크립트 반영 가능성 조사
  - 설명: 현재 Stop 훅(응답 완료)에서만 transcript.jsonl을 아카이빙하여 UI에 반영. 진행 중인 대화도 실시간으로 표시 가능한지 조사 필요
  - 결론: **실시간 반영 불가능 (현재 방식 유지)**
    - Claude Code는 transcript.jsonl을 **응답 완료(Stop) 시점에 일괄 기록**함
    - 테스트: 세션 진행 중(12:39) transcript 파일 수정 시간이 11:35로 고정 → 실시간 기록 없음
    - stdout 스트리밍은 별도이며, 파일 기록과 분리됨
    - 대안으로 stdout 파싱 구현 가능하나 복잡도 대비 이점 낮음
  - 비용: S
  - 영향도: Mid
  - 관련 파일: `ClaudeSessionManager/Services/Transcript/TranscriptArchiveService.swift`, `ClaudeSessionManager/Services/HookRunner.swift`
  - 완료일: 2026-01-16

- [ ] Assistant 응답별 토큰 사용량 표시
  - 설명: 트랜스크립트에서 각 Assistant 응답에 해당 요청의 토큰 사용량(input/output/cache) 표시. Claude Code transcript.jsonl의 `message.usage` 필드에서 토큰 정보 파싱
  - 비용: M
  - 영향도: Mid
  - 관련 파일: `ClaudeSessionManager/Models/Transcript/TranscriptEntry.swift`, `ClaudeSessionManager/Services/Transcript/TranscriptArchiveService.swift`, `ClaudeSessionManager/Views/Session/TranscriptRowView.swift`
  - 하위 항목:
    - [ ] TranscriptEntry에 토큰 사용량 필드 추가
      - 설명: `TokenUsage` 구조체 정의 (inputTokens, outputTokens, cacheCreationTokens, cacheReadTokens). TranscriptEntry에 옵셔널 `usage: TokenUsage?` 필드 추가
      - 비용: S
    - [ ] TranscriptArchiveService에서 usage 필드 파싱
      - 설명: `buildEntry()` 메서드에서 `message.usage` 객체 파싱. Assistant 메시지에만 존재하므로 조건부 처리
      - 비용: S
    - [ ] TranscriptRowView에 토큰 표시 UI 추가
      - 설명: Assistant 메시지 하단에 토큰 사용량 표시 (예: "↓1.2K ↑350 💾5K"). 접이식 또는 hover로 상세 표시 고려
      - 비용: S

## 리팩토링

- [ ] 훅 의존 경량화
  - 설명: 훅 이벤트 기반으로 단순화하여 폴링/파일 의존 최소화
  - 비용: M (하위 합산)
  - 영향도: Mid
  - 하위 항목:
    - [x] 상태 enum 통합 (SessionRecordStatus → SessionStatus)
      - 설명: 동일 케이스 중복 정의 제거. `SessionStatus`에 `Codable` 추가, `SessionRecordStatus` 삭제
      - 해결:
        - `SessionStatus`를 `Models/SessionStatus.swift`로 분리하여 공용 타입으로 생성
        - `SessionStore.SessionRecordStatus` 삭제
        - `SessionStore.SessionRecord.status` 타입을 `SessionStatus`로 변경
        - `SessionItem.init(recordStatus:)` 변환 extension 삭제
        - `SessionListViewModel.changeSessionStatus()`에서 변환 코드 제거
      - 비용: S
      - 관련 파일: `Models/SessionStatus.swift` (신규), `SessionStore.swift`, `SessionModels.swift`, `SessionListViewModel.swift`
      - 완료일: 2026-01-17
    - [x] .permission → .finished 아카이브 리로드 보장
      - 설명: `handleSessionUpdate()` 조건을 `.running || .permission`으로 개선
      - 해결: 진행 상태(.running/.permission) → 완료(.finished) 전환 시 transcript 리로드하도록 조건 수정
      - 비용: XS
      - 관련 파일: `SessionArchiveViewModel.swift:114-121`
      - 완료일: 2026-01-17
    - [x] DebugView 타이머 제거 → 이벤트 기반 갱신
      - 설명: 1초 폴링 대신 `sessionsDidChangeNotification` 구독으로 훅 이벤트 시에만 갱신
      - 해결: DebugLogStore에 notification 구독 추가, DebugView에서 Timer.publish 및 onReceive 제거
      - 비용: S
      - 관련 파일: `DebugLogStore.swift`, `DebugView.swift`
      - 완료일: 2026-01-17
    - [ ] 세션 파일 삭제 기능 설정 옵션화
      - 설명: `ClaudeSessionService.deleteSession()` 호출을 설정에서 on/off 가능하게. Claude Code 내부 경로 규칙 변경 시 호환성 문제 대비
      - 비용: S
      - 관련 파일: `ClaudeSessionService.swift`, `SettingsStore.swift`, `SessionArchiveViewModel.swift`
    - [ ] [고려] transcript 파일 의존 최소화
      - 설명: Stop 훅 시 transcript.jsonl 파싱 의존도 검토. 훅 페이로드 정보만 사용하거나 아카이빙을 선택적 기능으로 분리 가능성 검토
      - 비용: L (구조 변경 시)
      - 관련 파일: `TranscriptArchiveService.swift`, `HookRunner.swift`

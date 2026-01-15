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

- [ ] Full 레이아웃 카드에 터미널 열기 버튼 추가
  - 설명: 격자(SessionGridView) 섹션 헤더에는 `TerminalService.openDirectory()` 버튼이 있으나, SessionCardView의 full 레이아웃에는 터미널 열기 버튼 없음. 해당 세션 디렉토리에서 새 터미널을 여는 버튼 추가 필요
  - 비용: XS
  - 영향도: Low
  - 관련 파일: `ClaudeSessionManager/Views/Session/SessionCardView.swift`

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

- [ ] Debug 패널 payload 복사 버튼 추가
  - 설명: Payload 헤더 영역에 복사 버튼 추가. 클릭 시 `rawPayload`(JSON 문자열)를 클립보드에 복사. 기존 `ClipboardService.copy()` 활용
  - 비용: XS
  - 영향도: Low
  - 관련 파일: `ClaudeSessionManager/Views/Debug/DebugView.swift`

## 버그

- [ ] 권한 요청 툴팁 z-index 문제
  - 설명: 선택지(AskUserQuestion) 권한 요청에서 옵션 hover 시 표시되는 description 툴팁이 하단 요소(Submit 버튼 등) 아래에 렌더링됨. 툴팁이 최상위 레이어에 표시되어야 함
  - 원인: 툴팁 오버레이가 InlineQuestionSelectionView 내부에 있어 부모 레벨의 Submit 버튼보다 zIndex가 낮음
  - 해결방안: 툴팁 상태를 InlinePermissionRequestView로 올려서 Submit 버튼과 같은 레벨에서 렌더링
  - 비용: S
  - 영향도: Mid
  - 관련 파일: `ClaudeSessionManager/Views/Components/PermissionRequestView.swift`

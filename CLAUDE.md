# pty-claude 프로젝트 규칙

macOS 네이티브 앱으로, Claude Code 세션을 관리하고 훅 이벤트를 처리하는 도구입니다.

## 프로젝트 구조

```
pty-claude/
├── App/                    # 앱 진입점 및 설정
├── Models/                 # 데이터 모델 (Codable 구조체)
│   └── Transcript/         # 트랜스크립트 관련 모델
├── Services/               # 비즈니스 로직 (enum, stateless)
├── Utilities/              # 순수 유틸리티 함수
├── Views/                  # SwiftUI 뷰
│   ├── Components/         # 재사용 가능한 UI 컴포넌트
│   ├── Debug/              # 디버그 패널 관련
│   └── Session/            # 세션 관리 관련
└── Assets.xcassets/        # 이미지, 색상 등 리소스
```

## 아키텍처 패턴

### 레이어 구조

```
View (SwiftUI)
  ↓ @StateObject
ViewModel (@MainActor ObservableObject)
  ↓ static 메서드 호출
Service/Store (enum, stateless)
  ↓
외부 리소스 (UserDefaults, FileSystem, Process)
```

### 타입별 역할

| 타입 | 패턴 | 역할 | 상태 |
|------|------|------|------|
| **Store** | `enum` | 데이터 저장소 접근 (CRUD) | Stateless |
| **Service** | `enum` | 비즈니스 로직, 외부 프로세스 실행 | Stateless |
| **ViewModel** | `@MainActor final class ObservableObject` | UI 상태 관리, View-Service 중재 | Stateful |
| **Model** | `struct Codable` | 데이터 전송 객체 | Immutable |

## 주석 규칙

### 파일 헤더
모든 Swift 파일 상단에 파일 역할 설명 주석 추가:
```swift
// MARK: - 파일 설명
// SessionStore: 세션 메타데이터 CRUD 및 상태 관리
// - UserDefaults 기반 영속화
// - DistributedNotificationCenter로 변경 알림 전파

import Foundation
```

### 메서드 주석
- 모든 public/internal 메서드에 `///` doc comment 필수
- 복잡한 로직은 단계별 `// MARK:` 또는 인라인 주석 추가

```swift
/// 세션 목록을 위치별로 그룹핑
/// - Parameter sessions: 그룹핑할 세션 목록
/// - Returns: 위치별로 그룹화된 섹션 배열 (순서 보존)
static func groupByLocation(_ sessions: [SessionItem]) -> [SessionSection] {
    // 1. 순서 보존을 위한 키 배열
    var order: [String] = []

    // 2. 위치별 세션 그룹화
    var grouped: [String: [SessionItem]] = [:]
    ...
}
```

### MARK 주석
논리적 섹션 구분에 사용:
```swift
// MARK: - Properties
// MARK: - Lifecycle
// MARK: - Public Methods
// MARK: - Private Helpers
```

## 코딩 규칙

### 네이밍

| 대상 | 규칙 | 예시 |
|------|------|------|
| 타입 | PascalCase | `SessionStore`, `HookTestService` |
| 메서드/변수 | camelCase | `loadSessions()`, `sessionId` |
| 상수 | camelCase (static let) | `static let sessionsKey` |
| 키 문자열 | dot notation | `"hook.preToolUse.enabled"` |

### 상수 관리
매직 문자열/숫자 사용 금지. 별도 enum 또는 상수로 정의:
```swift
// 좋음
enum SettingsKeys {
    static let preToolUseEnabled = "hook.preToolUse.enabled"
}

// 나쁨
defaults.bool(forKey: "hook.preToolUse.enabled")
```

### 에러 처리
- `guard let` early return 패턴 선호
- 실패 시 기본값 반환 또는 옵셔널 사용
- 사용자에게 보여줄 에러는 한글로 작성

### 접근 제어
- 기본적으로 `private` 사용
- 외부에서 필요한 것만 `internal` (기본값) 또는 `public`
- Helper 메서드는 반드시 `private`

## SwiftUI 규칙

### View 구조
```swift
struct SessionView: View {
    // MARK: - Properties
    @StateObject private var viewModel = SessionListViewModel()
    @Binding var selectedSession: SessionItem?

    // MARK: - Body
    var body: some View {
        ...
    }

    // MARK: - Subviews
    @ViewBuilder
    private func sessionButton(for session: SessionItem) -> some View {
        ...
    }
}
```

### View에서 금지 사항
- 직접적인 파일 시스템 접근
- 직접적인 Process 실행
- JSONSerialization 직접 호출
- `@AppStorage` 직접 사용 (ViewModel 경유 권장)

위 로직은 모두 Service/ViewModel로 분리

## 서비스 작성 규칙

### 기본 구조
```swift
// MARK: - 파일 설명
// ClipboardService: 시스템 클립보드 접근 통합
// - NSPasteboard 래핑
// - 복사 성공/실패 처리

import AppKit

enum ClipboardService {
    /// 시스템 클립보드에 텍스트 복사
    /// - Parameter text: 복사할 텍스트
    static func copy(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}
```

### 복잡한 서비스
설정/결과를 별도 struct로 정의:
```swift
enum HookTestService {
    /// 훅 테스트 설정
    struct Settings {
        let preToolUseEnabled: Bool
        let stopEnabled: Bool
        ...
    }

    /// 훅 테스트 결과
    struct Result {
        let status: String
        let success: Bool
    }

    /// 훅 테스트 실행
    static func run(command: String, settings: Settings) -> Result {
        ...
    }
}
```

## Git 규칙

### 커밋 메시지 형식
```
TYPE: 간단한 설명 (한글)
```
- 한 줄로 작성
- 예: `FEAT: 세션 카드 삭제 기능 추가`

### TYPE
- `FEAT`: 새 기능
- `FIX`: 버그 수정
- `REFACTOR`: 리팩토링 (기능 변경 없음)
- `STYLE`: 코드 스타일/포맷팅
- `DOCS`: 문서 변경
- `CHORE`: 빌드, 설정 등 기타

## 빌드 타겟

| 타겟 | 설명 |
|------|------|
| `pty-claude` | 메인 macOS 앱 |
| `pty-claude-hook` | CLI 훅 도구 (앱 번들에 포함) |

**주의**: UI 관련 서비스는 `pty-claude` 타겟에만 포함. `pty-claude-hook`에서 UI 타입 참조 시 빌드 오류 발생.

## AI 협업 규칙 (Claude Code + Codex CLI)

이 프로젝트는 Claude Code와 Codex CLI(OpenAI)가 협업하여 개발합니다.

### 역할 분담

| 상황 | 담당 | 이유 |
|------|------|------|
| Swift/SwiftUI 코드 작성 | Claude Code | Apple 생태계 전문성 |
| 코드 리뷰/검증 | Codex CLI | 독립적 시각으로 검토 |
| 복잡한 로직 설계 | 토론 후 결정 | 다양한 관점 확보 |
| 버그 원인 분석 | 양쪽 병렬 조사 | 빠른 원인 파악 |
| 리팩토링 방향 | 토론 후 결정 | 최선의 패턴 선택 |

### 협업 프로세스

1. **설계 토론**: 새 기능이나 리팩토링 시 Codex CLI와 접근 방식 토론
2. **구현**: 합의된 방향으로 Claude Code가 구현
3. **리뷰**: Codex CLI로 코드 리뷰 (`mcp__codex-cli__review` 활용)
4. **개선**: 리뷰 피드백 반영

### Codex CLI 활용 시점

```
# 코드 리뷰 요청
- 커밋 전 변경사항 검토
- PR 생성 전 전체 변경사항 리뷰
- 특정 커밋의 품질 검증

# 설계 토론
- 아키텍처 결정이 필요할 때
- 여러 구현 방식 중 선택이 필요할 때
- 성능/가독성 트레이드오프 판단 시

# 병렬 조사
- 버그 원인을 빠르게 찾아야 할 때
- 코드베이스 탐색이 필요할 때
```

### 토론 규칙

- 각자 의견을 명확히 제시하고 근거 설명
- 의견 충돌 시 프로젝트 규칙과 Swift 컨벤션 우선
- 최종 결정은 사용자가 내림
- 토론 결과는 코드 주석이나 커밋 메시지에 간략히 기록

// MARK: - 파일 설명
// DebugLogStore: 디버그 로그 저장소
// - 훅 페이로드 로그 관리
// - sessionsDidChangeNotification 구독으로 자동 갱신

import Combine
import Foundation

final class DebugLogStore: ObservableObject {
    @Published private(set) var entries: [DebugLogEntry] = []

    private var observer: NSObjectProtocol?

    init() {
        // 훅 이벤트 발생 시 자동 갱신
        observer = DistributedNotificationCenter.default().addObserver(
            forName: SessionStore.sessionsDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.reload()
        }
    }

    deinit {
        if let observer {
            DistributedNotificationCenter.default().removeObserver(observer)
        }
    }

    func reload() {
        entries = SettingsStore.loadDebugLogs()
    }

    func clear() {
        SettingsStore.clearDebugLogs()
        reload()
    }
}

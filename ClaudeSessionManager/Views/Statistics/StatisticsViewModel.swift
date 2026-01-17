// MARK: - 파일 설명
// StatisticsViewModel: 통계 뷰 상태 관리
// - 통계 데이터 로드 및 갱신
// - 세션 변경 알림 구독

import Combine
import Foundation

@MainActor
final class StatisticsViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published private(set) var totalStats: TotalStatistics = .empty
    @Published private(set) var projectUsages: [ProjectUsage] = []
    @Published private(set) var isLoading = false

    // MARK: - Private Properties

    private var notificationObserver: NSObjectProtocol?

    // MARK: - Lifecycle

    init() {
        setupNotificationObserver()
        loadStatistics()
    }

    deinit {
        if let observer = notificationObserver {
            DistributedNotificationCenter.default().removeObserver(observer)
        }
    }

    // MARK: - Public Methods

    /// 통계 새로고침
    func refresh() {
        loadStatistics()
    }

    // MARK: - Private Methods

    private func setupNotificationObserver() {
        notificationObserver = DistributedNotificationCenter.default().addObserver(
            forName: SessionStore.sessionsDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.loadStatistics()
            }
        }
    }

    private func loadStatistics() {
        isLoading = true

        Task.detached(priority: .userInitiated) {
            let result = StatisticsService.calculateStatistics()

            await MainActor.run {
                self.totalStats = result.total
                self.projectUsages = result.projects
                self.isLoading = false
            }
        }
    }
}

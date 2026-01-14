// MARK: - 파일 설명
// DebugViewModel: 디버그 뷰 상태 관리
// - 디버그 모드 활성화 상태 관리
// - SettingsStore와 View 간 중재

import Combine
import Foundation
import SwiftUI

@MainActor
final class DebugViewModel: ObservableObject {
    // MARK: - Published Properties

    /// 디버그 모드 활성화 여부
    @Published var debugEnabled: Bool {
        didSet {
            SettingsStore.defaults.set(debugEnabled, forKey: SettingsKeys.debugEnabled)
        }
    }

    // MARK: - Lifecycle

    init() {
        debugEnabled = SettingsStore.debugEnabled()
    }
}

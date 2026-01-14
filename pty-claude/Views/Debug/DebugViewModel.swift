import Combine
import Foundation
import SwiftUI

@MainActor
final class DebugViewModel: ObservableObject {
    @Published var debugEnabled: Bool {
        didSet {
            SettingsStore.defaults.set(debugEnabled, forKey: SettingsKeys.debugEnabled)
        }
    }

    init() {
        debugEnabled = SettingsStore.debugEnabled()
    }
}

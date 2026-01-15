import Combine
import Foundation

final class DebugLogStore: ObservableObject {
    @Published private(set) var entries: [DebugLogEntry] = []

    func reload() {
        entries = SettingsStore.loadDebugLogs()
    }

    func clear() {
        SettingsStore.clearDebugLogs()
        reload()
    }
}

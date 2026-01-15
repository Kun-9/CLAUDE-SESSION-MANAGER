// MARK: - 파일 설명
// SoundService: 시스템 사운드 재생 통합
// - NSSound 래핑으로 사운드 재생 기능 제공
// - 설정 기반 알림 사운드 재생 지원
// - CLI 훅에서 사운드가 끊기지 않도록 대기 처리

import AppKit
import Foundation

enum SoundService {
    // MARK: - Constants

    private enum Defaults {
        static let playbackTimeout: TimeInterval = 0.8
        static let runLoopInterval: TimeInterval = 0.05
    }

    // MARK: - Public Methods

    /// 지정된 이름과 볼륨으로 사운드 재생
    /// - Parameters:
    ///   - name: 시스템 사운드 이름 (예: "Glass", "Ping")
    ///   - volume: 볼륨 (0.0 ~ 1.0)
    static func play(name: String, volume: Double) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty,
              let sound = NSSound(named: NSSound.Name(trimmedName)) else {
            return
        }
        sound.volume = Float(volume)
        sound.play()
    }

    /// 설정에 따른 사운드 재생 (알림용)
    /// - Note: CLI 훅에서 호출 시 사운드가 끊기지 않도록 재생 완료까지 대기
    static func playIfEnabled() {
        guard SettingsStore.soundEnabled() else { return }

        let soundName = SettingsStore.soundName()
        guard !soundName.isEmpty,
              let sound = NSSound(named: NSSound.Name(soundName)) else {
            return
        }

        sound.volume = Float(SettingsStore.soundVolume())
        sound.play()
        waitForPlayback(sound)
    }

    // MARK: - Private Helpers

    /// 재생이 끝나거나 타임아웃까지 대기
    private static func waitForPlayback(_ sound: NSSound) {
        let timeout = Date().addingTimeInterval(Defaults.playbackTimeout)
        while sound.isPlaying && Date() < timeout {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(Defaults.runLoopInterval))
        }
    }
}

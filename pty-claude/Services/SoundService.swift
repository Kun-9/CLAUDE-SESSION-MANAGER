import AppKit
import Foundation

enum SoundService {
    /// 지정된 이름과 볼륨으로 사운드 재생
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
    static func playIfEnabled() {
        guard SettingsStore.soundEnabled() else { return }
        let soundName = SettingsStore.soundName()
        guard !soundName.isEmpty,
              let sound = NSSound(named: NSSound.Name(soundName)) else {
            return
        }
        sound.volume = Float(SettingsStore.soundVolume())
        sound.play()
        waitForSoundPlayback(sound)
    }

    /// 재생이 끝나거나 타임아웃까지 대기
    private static func waitForSoundPlayback(_ sound: NSSound) {
        let timeout = Date().addingTimeInterval(0.8)
        while sound.isPlaying && Date() < timeout {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
        }
    }
}

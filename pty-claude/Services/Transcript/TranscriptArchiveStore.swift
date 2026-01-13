import CryptoKit
import Foundation

enum TranscriptArchiveStore {
    private static let archiveFolderName = "archives"
    private static let appFolderName = "pty-claude"

    static func save(_ transcript: SessionTranscript) {
        let url = archiveURL(for: transcript.sessionId)
        do {
            let data = try JSONEncoder().encode(transcript)
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: url, options: .atomic)
        } catch {
            return
        }
    }

    static func load(sessionId: String) -> SessionTranscript? {
        let url = archiveURL(for: sessionId)
        if let transcript = loadTranscript(from: url) {
            return transcript
        }

        let legacyURL = legacyArchiveURL(for: sessionId)
        guard let legacyTranscript = loadTranscript(from: legacyURL) else {
            return nil
        }

        migrateLegacyTranscript(legacyTranscript, to: url)
        return legacyTranscript
    }

    static func delete(sessionId: String) {
        let urls = [archiveURL(for: sessionId), legacyArchiveURL(for: sessionId)]
        for url in urls {
            guard FileManager.default.fileExists(atPath: url.path) else {
                continue
            }
            try? FileManager.default.removeItem(at: url)
        }
    }

    private static func archiveURL(for sessionId: String) -> URL {
        let filename = hashedFilename(for: sessionId)
        let base = applicationSupportURL()
        return base
            .appendingPathComponent(archiveFolderName, isDirectory: true)
            .appendingPathComponent("\(filename).json")
    }

    private static func legacyArchiveURL(for sessionId: String) -> URL {
        let filename = safeFilenameLegacy(for: sessionId)
        let base = applicationSupportURL()
        return base
            .appendingPathComponent(archiveFolderName, isDirectory: true)
            .appendingPathComponent("\(filename).json")
    }

    private static func applicationSupportURL() -> URL {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? FileManager.default.homeDirectoryForCurrentUser
        return root.appendingPathComponent(appFolderName, isDirectory: true)
    }

    private static func safeFilenameLegacy(for sessionId: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let scalars = sessionId.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" }
        let candidate = String(scalars)
        return candidate.isEmpty ? "session" : candidate
    }

    private static func hashedFilename(for sessionId: String) -> String {
        let data = Data(sessionId.utf8)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func loadTranscript(from url: URL) -> SessionTranscript? {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }
        return try? JSONDecoder().decode(SessionTranscript.self, from: data)
    }

    private static func migrateLegacyTranscript(_ transcript: SessionTranscript, to url: URL) {
        do {
            let data = try JSONEncoder().encode(transcript)
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: url, options: .atomic)
        } catch {
            return
        }
    }
}

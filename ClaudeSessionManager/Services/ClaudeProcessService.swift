// MARK: - 파일 설명
// ClaudeProcessService: Claude 프로세스 관리 서비스
// - 실행 중인 Claude 프로세스 목록 조회
// - 프로세스 일괄/개별 종료

import Foundation

/// Claude 프로세스 정보
struct ClaudeProcess: Identifiable {
    let id: Int  // PID
    let cpu: Double
    let memory: Double
    let tty: String
    let startTime: String
    let command: String

    /// 백그라운드 프로세스 여부 (터미널 없음)
    var isBackground: Bool {
        tty == "??"
    }

    /// resume 세션 ID (있는 경우)
    var resumeSessionId: String? {
        guard command.contains("--resume") else { return nil }
        let parts = command.split(separator: " ")
        guard let resumeIndex = parts.firstIndex(of: "--resume"),
              resumeIndex + 1 < parts.count else { return nil }
        return String(parts[resumeIndex + 1])
    }

    /// 표시용 설명
    var displayDescription: String {
        if let sessionId = resumeSessionId {
            return "resume: \(sessionId.prefix(8))..."
        } else if command == "claude" {
            return "기본 세션"
        } else {
            return command
        }
    }
}

enum ClaudeProcessService {
    // MARK: - Public Methods

    /// 실행 중인 모든 Claude 프로세스 조회
    static func listProcesses() -> [ClaudeProcess] {
        let output = runCommand("ps aux | grep -E '[c]laude($| )' | grep -v grep")
        return parseProcessList(output)
    }

    /// 백그라운드 프로세스만 조회 (터미널 없음)
    static func listBackgroundProcesses() -> [ClaudeProcess] {
        listProcesses().filter { $0.isBackground }
    }

    /// 특정 프로세스 종료
    static func killProcess(_ process: ClaudeProcess) -> Bool {
        // 종료 전 프로세스가 여전히 Claude인지 재확인 (race condition 방지)
        let verify = runCommand("ps -p \(process.id) -o comm= | grep -E '^claude$'")
        guard !verify.isEmpty else { return false }

        let result = runCommand("kill -9 \(process.id) 2>/dev/null")
        return result.isEmpty || !result.contains("No such process")
    }

    /// 모든 Claude 프로세스 종료
    static func killAllProcesses() -> Int {
        let processes = listProcesses()
        var killedCount = 0

        for process in processes {
            if killProcess(process) {
                killedCount += 1
            }
        }

        return killedCount
    }

    /// 백그라운드 프로세스만 종료
    static func killBackgroundProcesses() -> Int {
        let processes = listBackgroundProcesses()
        var killedCount = 0

        for process in processes {
            if killProcess(process) {
                killedCount += 1
            }
        }

        return killedCount
    }

    // MARK: - Private Helpers

    private static func runCommand(_ command: String) -> String {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", command]
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return ""
        }
    }

    /// ps aux 출력 파싱
    private static func parseProcessList(_ output: String) -> [ClaudeProcess] {
        var processes: [ClaudeProcess] = []
        let lines = output.split(separator: "\n")

        for line in lines {
            let parts = line.split(separator: " ", omittingEmptySubsequences: true)

            // ps aux 형식: USER PID %CPU %MEM VSZ RSS TTY STAT START TIME COMMAND...
            guard parts.count >= 11 else { continue }

            guard let pid = Int(parts[1]),
                  let cpu = Double(parts[2]),
                  let mem = Double(parts[3]) else { continue }

            let tty = String(parts[6])
            let startTime = String(parts[8])
            let command = parts[10...].joined(separator: " ")

            let process = ClaudeProcess(
                id: pid,
                cpu: cpu,
                memory: mem,
                tty: tty,
                startTime: startTime,
                command: command
            )

            processes.append(process)
        }

        // CPU 사용량 기준 내림차순 정렬
        return processes.sorted { $0.cpu > $1.cpu }
    }
}

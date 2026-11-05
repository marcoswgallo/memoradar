import Foundation
import Testing
@testable import MemoRadarCore

private let now = Date(timeIntervalSince1970: 1_000_000)
private let system = SystemMemory(totalBytes: 100, appBytes: 10, wiredBytes: 10, compressedBytes: 0, swapUsedBytes: 0, pressure: .normal)

private func proc(_ pid: Int32, parent: Int32 = 1, exe: String = "/x/claude", bytes: UInt64 = 10, stdin: StdinKind = .other, args: [String] = []) -> ProcessSnapshot {
    ProcessSnapshot(pid: pid, ppid: parent, startTime: .distantPast, footprintBytes: bytes, executablePath: exe, arguments: args, stdin: stdin)
}

private func build(_ processes: [ProcessSnapshot], _ sessions: [ClaudeSession]) -> Dashboard {
    Dashboard.build(processes: processes, sessions: sessions, system: system, now: now, threshold: Forgotten.defaultThreshold)
}

@Suite struct DashboardTests {
    @Test func terminalSessionBytesIncludeChildrenExceptMcps() {
        let processes = [
            proc(1000, bytes: 100),
            proc(1001, parent: 1000, exe: "/bin/zsh", bytes: 20),
            proc(1002, parent: 1000, exe: "/x/node", bytes: 50, stdin: .pipeOrSocket, args: ["npx", "srv"]),
        ]
        let dashboard = build(processes, [ClaudeSession(pid: 1000, cwd: "/x/projeto-a", entrypoint: "cli", status: .idle)])
        #expect(dashboard.terminalSessions.count == 1)
        #expect(dashboard.terminalSessions[0].bytes == 120)
    }

    @Test func vscodeSessionIsNotATerminalSession() {
        let exe = "/Users/t/.vscode/extensions/a/claude"
        let dashboard = build([proc(1000, exe: exe)], [ClaudeSession(pid: 1000, entrypoint: "claude-vscode", status: .idle)])
        #expect(dashboard.terminalSessions.isEmpty)
    }

    @Test func mcpCopiesAreGroupedByServer() {
        let processes = [
            proc(1000), proc(2000),
            proc(1001, parent: 1000, exe: "/x/node", bytes: 30, stdin: .pipeOrSocket, args: ["npx", "srv"]),
            proc(2001, parent: 2000, exe: "/x/node", bytes: 40, stdin: .pipeOrSocket, args: ["npx", "srv"]),
            proc(2002, parent: 2000, exe: "/x/node", bytes: 5, stdin: .pipeOrSocket, args: ["npx", "outro"]),
        ]
        let sessions = [ClaudeSession(pid: 1000, entrypoint: "cli"), ClaudeSession(pid: 2000, entrypoint: "cli")]
        let groups = build(processes, sessions).mcpServers
        #expect(groups.map(\.name) == ["srv", "outro"])
        #expect(groups[0].copies.count == 2)
        #expect(groups[0].bytes == 70)
    }

    @Test func forgottenUsesThreshold() {
        let session = ClaudeSession(pid: 1000, cwd: "/x/projeto-a", entrypoint: "cli", status: .idle, statusUpdatedAt: now.addingTimeInterval(-14400))
        #expect(build([proc(1000)], [session]).forgotten == ["/x/projeto-a"])
    }

    @Test func emptyMacHasNoRows() {
        let dashboard = build([], [])
        #expect(dashboard.rows.isEmpty)
        #expect(dashboard.mcpServers.isEmpty)
        #expect(dashboard.terminalSessions.isEmpty)
        #expect(dashboard.vscode.projects.isEmpty)
    }

    @Test func idleDurationIsLongestCommonIdle() {
        let sessions = [
            ClaudeSession(pid: 1, status: .idle, statusUpdatedAt: now.addingTimeInterval(-100)),
            ClaudeSession(pid: 2, status: .idle, statusUpdatedAt: now.addingTimeInterval(-500)),
        ]
        #expect(Dashboard.idleDuration(sessions: sessions, now: now) == 100)
        #expect(Dashboard.idleDuration(sessions: [], now: now) == nil)
        #expect(Dashboard.idleDuration(sessions: [ClaudeSession(pid: 1, status: .busy)], now: now) == nil)
    }
}

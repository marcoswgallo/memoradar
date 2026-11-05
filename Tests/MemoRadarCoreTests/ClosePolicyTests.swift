import Foundation
import Testing
@testable import MemoRadarCore

private let start = Date(timeIntervalSince1970: 1_000)
private let gb: UInt64 = 1_073_741_824

private func project(
    name: String = "projeto-a", sessions: [ClaudeSession] = [], own: UInt64 = 2 * gb, mcp: UInt64 = 0
) -> VSCodeProject {
    VSCodeProject(hostPid: 10, folder: "/x/\(name)", displayName: name, openSince: start,
                  sessions: sessions, ownBytes: own, mcpBytes: mcp)
}

private func session(_ pid: Int32, _ status: SessionStatus, cwd: String = "/x/projeto-a", entry: String = "claude-vscode") -> ClaudeSession {
    ClaudeSession(pid: pid, cwd: cwd, entrypoint: entry, status: status)
}

private func copy(session: Int32, name: String = "srv") -> McpCopy {
    McpCopy(serverName: name, sessionPid: session, rootPid: session + 100, pids: [session + 100], bytes: gb)
}

@Suite struct ClosePolicyTests {
    @Test func busyWindowIsStrongWithExactCopy() {
        let s = session(1, .busy)
        let c = ClosePolicy.confirmation(for: .vscodeWindow(project(sessions: [s])), allSessions: [s])
        #expect(c.severity == .strong)
        #expect(c.title == "O Claude Code está rodando em projeto-a. Fechar mesmo assim?")
    }

    @Test func unknownStatusIsStrong() {
        let s = session(1, .unknown)
        let c = ClosePolicy.confirmation(for: .vscodeWindow(project(sessions: [s])), allSessions: [s])
        #expect(c.severity == .strong)
        #expect(c.title == "O Claude Code está rodando em projeto-a. Fechar mesmo assim?")
    }

    @Test func idleWindowIsSimple() {
        let s = session(1, .idle)
        let c = ClosePolicy.confirmation(for: .vscodeWindow(project(sessions: [s])), allSessions: [s])
        #expect(c.severity == .simple)
        #expect(c.title == "Fechar projeto-a?")
    }

    @Test func windowWithoutSessionIsSimple() {
        let c = ClosePolicy.confirmation(for: .vscodeWindow(project()), allSessions: [])
        #expect(c.severity == .simple)
    }

    @Test func windowWithBusyCliSessionInSameFolderIsStrong() {
        let terminal = session(2, .busy, entry: "cli")
        let c = ClosePolicy.confirmation(for: .vscodeWindow(project()), allSessions: [terminal])
        #expect(c.severity == .strong)
    }

    @Test func busyCliSessionInOtherFolderDoesNotAffectWindow() {
        let terminal = session(2, .busy, cwd: "/x/projeto-b", entry: "cli")
        let c = ClosePolicy.confirmation(for: .vscodeWindow(project()), allSessions: [terminal])
        #expect(c.severity == .simple)
    }

    @Test func busyTerminalSessionIsStrong() {
        let s = session(2, .busy, entry: "cli")
        let c = ClosePolicy.confirmation(for: .terminalSession(s, bytes: gb), allSessions: [s])
        #expect(c.severity == .strong)
        #expect(c.estimatedBytes == gb)
    }

    @Test func idleTerminalSessionIsSimple() {
        let s = session(2, .idle, entry: "cli")
        #expect(ClosePolicy.confirmation(for: .terminalSession(s, bytes: gb), allSessions: [s]).severity == .simple)
    }

    @Test func mcpServerMixedStatesIsStrongAndListsBusy() {
        let sessions = [session(1, .idle), session(2, .busy, cwd: "/x/projeto-b")]
        let c = ClosePolicy.confirmation(for: .mcpServer(name: "srv", copies: [copy(session: 1), copy(session: 2)]), allSessions: sessions)
        #expect(c.severity == .strong)
        #expect(c.message.contains("projeto-b") || c.title.contains("projeto-b"))
        #expect(c.estimatedBytes == 2 * gb)
    }

    @Test func mcpCopyOfIdleSessionIsSimple() {
        let s = session(1, .idle)
        #expect(ClosePolicy.confirmation(for: .mcpCopy(copy(session: 1)), allSessions: [s]).severity == .simple)
    }

    @Test func mcpCopyWithoutKnownSessionIsStrong() {
        #expect(ClosePolicy.confirmation(for: .mcpCopy(copy(session: 1)), allSessions: []).severity == .strong)
    }

    @Test func mcpMessageWarnsToolsAndReturn() {
        let s = session(1, .idle)
        let c = ClosePolicy.confirmation(for: .mcpCopy(copy(session: 1)), allSessions: [s])
        #expect(c.message.contains("fica sem essas ferramentas"))
        #expect(c.message.contains("sessões novas"))
        let all = ClosePolicy.confirmation(for: .mcpServer(name: "srv", copies: [copy(session: 1)]), allSessions: [s])
        #expect(all.message.contains("fica sem essas ferramentas"))
    }

    @Test func appIsSimple() {
        let c = ClosePolicy.confirmation(for: .app(name: "Foo", pids: [1], bytes: gb), allSessions: [])
        #expect(c.severity == .simple)
        #expect(c.title == "Fechar Foo?")
        #expect(c.estimatedBytes == gb)
    }

    @Test func estimateIncludesMcps() {
        let c = ClosePolicy.confirmation(for: .vscodeWindow(project(own: 2 * gb, mcp: gb)), allSessions: [])
        #expect(c.estimatedBytes == 3 * gb)
    }

    @Test func messageShowsEstimate() {
        let c = ClosePolicy.confirmation(for: .vscodeWindow(project(own: 2 * gb)), allSessions: [])
        #expect(c.message.contains("cerca de 2,0 GB"))
    }

    private func hosted(_ pids: [(Int32, Int32, String)]) -> ProcessTree {
        ProcessTree(pids.map { ProcessSnapshot(pid: $0.0, ppid: $0.1, startTime: start, footprintBytes: 1, executablePath: $0.2) })
    }

    @Test func appHostingBusySessionIsStrong() {
        let tree = hosted([(50, 1, "/Applications/Foo.app/Contents/MacOS/Foo"), (51, 50, "/bin/zsh"), (52, 51, "/x/claude")])
        let s = session(52, .busy, cwd: "/x/projeto-c", entry: "cli")
        let c = ClosePolicy.confirmation(for: .app(name: "Foo", pids: [50], bytes: gb), allSessions: [s], tree: tree)
        #expect(c.severity == .strong)
        #expect(c.title == "O Claude Code está rodando em projeto-c. Fechar mesmo assim?")
    }

    @Test func appHostingUnknownSessionIsStrong() {
        let tree = hosted([(50, 1, "/x/Foo"), (52, 50, "/x/claude")])
        let s = session(52, .unknown, cwd: "/x/projeto-c", entry: "cli")
        #expect(ClosePolicy.confirmation(for: .app(name: "Foo", pids: [50], bytes: gb), allSessions: [s], tree: tree).severity == .strong)
    }

    @Test func appHostingIdleSessionIsSimple() {
        let tree = hosted([(50, 1, "/x/Foo"), (52, 50, "/x/claude")])
        let s = session(52, .idle, cwd: "/x/projeto-c", entry: "cli")
        #expect(ClosePolicy.confirmation(for: .app(name: "Foo", pids: [50], bytes: gb), allSessions: [s], tree: tree).severity == .simple)
    }

    @Test func appWithUnrelatedBusySessionIsSimple() {
        let tree = hosted([(50, 1, "/x/Foo"), (60, 1, "/x/Terminal"), (61, 60, "/x/claude")])
        let s = session(61, .busy, cwd: "/x/projeto-c", entry: "cli")
        #expect(ClosePolicy.confirmation(for: .app(name: "Foo", pids: [50], bytes: gb), allSessions: [s], tree: tree).severity == .simple)
    }

    @Test func windowUsesFreshStatusNotStatusFromClick() {
        let frozen = session(1, .idle)
        let fresh = session(1, .busy)
        let c = ClosePolicy.confirmation(for: .vscodeWindow(project(sessions: [frozen])), allSessions: [fresh])
        #expect(c.severity == .strong)
    }

    @Test func terminalSessionUsesFreshStatusNotStatusFromClick() {
        let frozen = session(2, .idle, entry: "cli")
        let fresh = session(2, .busy, entry: "cli")
        #expect(ClosePolicy.confirmation(for: .terminalSession(frozen, bytes: gb), allSessions: [fresh]).severity == .strong)
    }

    @Test func busyCliSessionInSubfolderIsStrong() {
        let terminal = session(2, .busy, cwd: "/x/projeto-a/packages/api", entry: "cli")
        let c = ClosePolicy.confirmation(for: .vscodeWindow(project()), allSessions: [terminal])
        #expect(c.severity == .strong)
        #expect(c.title.contains("projeto-a"))
    }

    @Test func folderWithSamePrefixIsNotSubfolder() {
        let terminal = session(2, .busy, cwd: "/x/projeto-a2", entry: "cli")
        #expect(ClosePolicy.confirmation(for: .vscodeWindow(project()), allSessions: [terminal]).severity == .simple)
    }

    @Test func busyCliSessionInIntegratedTerminalElsewhereIsStrong() {
        let tree = hosted([
            (5, 1, "/Applications/Visual Studio Code.app/Contents/MacOS/Code"),
            (6, 5, "/bin/zsh"), (7, 6, "/x/claude"),
        ])
        let terminal = session(7, .busy, cwd: "/y/outra-pasta", entry: "cli")
        let c = ClosePolicy.confirmation(for: .vscodeWindow(project()), allSessions: [terminal], tree: tree)
        #expect(c.severity == .strong)
        #expect(c.title.contains("outra-pasta"))
    }

    @Test func sameProcessRequiresPidAndStart() {
        let current = ProcessSnapshot(pid: 5, ppid: 1, startTime: start, footprintBytes: 1, executablePath: "/x")
        #expect(ClosePolicy.isSameProcess(ProcessIdentity(pid: 5, startTime: start), current: current))
        #expect(!ClosePolicy.isSameProcess(ProcessIdentity(pid: 5, startTime: start.addingTimeInterval(9)), current: current))
        #expect(!ClosePolicy.isSameProcess(ProcessIdentity(pid: 6, startTime: start), current: current))
        #expect(!ClosePolicy.isSameProcess(ProcessIdentity(pid: 5, startTime: start), current: nil))
    }

    @Test func stillOpenAfterWaitIsReported() {
        #expect(closeOutcome(stillRunningAfterWait: true, error: nil) == .stillOpen)
        #expect(closeOutcome(stillRunningAfterWait: false, error: nil) == .closed)
    }

    @Test func errorIsReported() {
        #expect(closeOutcome(stillRunningAfterWait: false, error: "falhou") == .failed("falhou"))
        #expect(closeOutcome(stillRunningAfterWait: true, error: "falhou") == .failed("falhou"))
    }
}

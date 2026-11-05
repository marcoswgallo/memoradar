import Foundation
import Testing
@testable import MemoRadarCore

private let codeMain = "/Applications/Visual Studio Code.app/Contents/MacOS/Code"
private let codeRenderer = "/Applications/Visual Studio Code.app/Contents/Frameworks/Code Helper (Renderer).app/Contents/MacOS/Code Helper (Renderer)"
private let extensionClaude = "/Users/teste/.vscode/extensions/anthropic.claude-code-2/resources/native-binary/claude"

private func proc(_ pid: Int32, parent: Int32 = 1, exe: String, bytes: UInt64 = 10) -> ProcessSnapshot {
    ProcessSnapshot(pid: pid, ppid: parent, startTime: .distantPast, footprintBytes: bytes, executablePath: exe)
}

private func row(_ rows: [RankingRow], _ kind: RowKind) -> RankingRow? {
    rows.first { $0.kind == kind }
}

@Suite struct RankingTests {
    @Test func eachProcessCountsOnce() {
        let processes = [
            proc(10, exe: codeMain, bytes: 100),
            proc(11, parent: 10, exe: codeRenderer, bytes: 200),
            proc(12, parent: 10, exe: extensionClaude, bytes: 50),
            proc(13, parent: 12, exe: "/x/node", bytes: 25),
            proc(20, exe: "/x/claude", bytes: 40),
            proc(30, exe: "/Applications/Foo.app/Contents/MacOS/Foo", bytes: 7),
            proc(40, exe: "/opt/homebrew/bin/redis", bytes: 3),
        ]
        let sessions = [
            ClaudeSession(pid: 12, entrypoint: "claude-vscode", status: .idle),
            ClaudeSession(pid: 20, entrypoint: "cli", status: .idle),
        ]
        let mcps = [McpCopy(serverName: "srv", sessionPid: 12, rootPid: 13, pids: [13], bytes: 25)]
        let rows = Ranking.build(processes: processes, sessions: sessions, mcps: mcps)
        let allPids = rows.flatMap(\.pids)
        #expect(allPids.count == Set(allPids).count)
        #expect(rows.reduce(UInt64(0)) { $0 + $1.bytes } == 425)
    }

    @Test func mcpGoesOnlyToMcpRow() {
        let processes = [proc(12, exe: extensionClaude, bytes: 50), proc(13, parent: 12, exe: "/x/node", bytes: 25)]
        let mcps = [McpCopy(serverName: "srv", sessionPid: 12, rootPid: 13, pids: [13], bytes: 25)]
        let rows = Ranking.build(processes: processes, sessions: [ClaudeSession(pid: 12, entrypoint: "claude-vscode")], mcps: mcps)
        #expect(row(rows, .mcps)?.bytes == 25)
        #expect(row(rows, .vscode)?.bytes == 50)
    }

    @Test func cliSessionInsideVSCodeGoesToTerminalRow() {
        let processes = [
            proc(10, exe: codeMain),
            proc(11, parent: 10, exe: "/bin/zsh", bytes: 5),
            proc(12, parent: 11, exe: "/x/claude", bytes: 40),
            proc(13, parent: 12, exe: "/bin/zsh", bytes: 2),
        ]
        let rows = Ranking.build(processes: processes, sessions: [ClaudeSession(pid: 12, entrypoint: "cli")], mcps: [])
        #expect(Set(row(rows, .claudeTerminal)?.pids ?? []) == [12, 13])
        #expect(Set(row(rows, .vscode)?.pids ?? []) == [10, 11])
    }

    @Test func vscodeHelpersAndExtensionsGroup() {
        let processes = [proc(10, exe: codeRenderer), proc(11, exe: "/Users/teste/.vscode/extensions/x/server")]
        let rows = Ranking.build(processes: processes, sessions: [], mcps: [])
        #expect(rows.count == 1)
        #expect(rows[0].kind == .vscode)
        #expect(rows[0].title == "VS Code")
        #expect(!rows[0].closable)
    }

    @Test func nonVSCodeBinaryDescendingFromCodeIsVSCode() {
        let rows = Ranking.build(processes: [proc(10, exe: codeMain), proc(11, parent: 10, exe: "/x/node")], sessions: [], mcps: [])
        #expect(Set(row(rows, .vscode)?.pids ?? []) == [10, 11])
    }

    @Test func appNameUsesOutermostBundle() {
        let exe = "/Applications/Foo.app/Contents/Frameworks/Foo Helper.app/Contents/MacOS/Foo Helper"
        let rows = Ranking.build(processes: [proc(10, exe: exe)], sessions: [], mcps: [])
        #expect(rows[0].kind == .app("Foo"))
        #expect(rows[0].title == "Foo")
        #expect(rows[0].closable)
    }

    @Test func claudeAppIsNamedClaudeDesktop() {
        let rows = Ranking.build(processes: [proc(10, exe: "/Applications/Claude.app/Contents/MacOS/Claude")], sessions: [], mcps: [])
        #expect(rows[0].title == "Claude Desktop")
    }

    @Test func systemAppIsNotClosable() {
        let exe = "/System/Library/CoreServices/Finder.app/Contents/MacOS/Finder"
        let rows = Ranking.build(processes: [proc(10, exe: exe)], sessions: [], mcps: [])
        #expect(rows[0].kind == .app("Finder"))
        #expect(!rows[0].closable)
    }

    @Test func looseUserProcessGoesToOthers() {
        let rows = Ranking.build(processes: [proc(10, exe: "/opt/homebrew/bin/redis")], sessions: [], mcps: [])
        #expect(rows[0].kind == .others)
        #expect(rows[0].title == "Outros")
        #expect(!rows[0].closable)
    }

    @Test("serviços do macOS têm linha própria", arguments: [
        "/usr/libexec/trustd", "/System/Library/PrivateFrameworks/X.framework/Support/x",
        "/usr/sbin/cfprefsd", "/sbin/launchd", "/usr/bin/caffeinate",
    ])
    func macOSServiceRow(exe: String) {
        let rows = Ranking.build(processes: [proc(10, exe: exe)], sessions: [], mcps: [])
        #expect(rows[0].kind == .macOSServices)
        #expect(rows[0].title == "Serviços do macOS")
        #expect(!rows[0].closable)
    }

    @Test func serviceInsideAppBundleStaysWithApp() {
        let exe = "/System/Library/CoreServices/Dock.app/Contents/MacOS/Dock"
        #expect(Ranking.build(processes: [proc(10, exe: exe)], sessions: [], mcps: [])[0].kind == .app("Dock"))
    }

    @Test func rowsSortedByBytesDescending() {
        let processes = [
            proc(1, exe: "/Applications/A.app/Contents/MacOS/A", bytes: 5),
            proc(2, exe: "/Applications/B.app/Contents/MacOS/B", bytes: 50),
            proc(3, exe: "/Applications/C.app/Contents/MacOS/C", bytes: 20),
        ]
        #expect(Ranking.build(processes: processes, sessions: [], mcps: []).map(\.title) == ["B", "C", "A"])
    }

    @Test func helperAppsWithSameBundleAreSummed() {
        let processes = [
            proc(1, exe: "/Applications/Foo.app/Contents/MacOS/Foo", bytes: 5),
            proc(2, exe: "/Applications/Foo.app/Contents/Frameworks/Foo Helper.app/Contents/MacOS/Foo Helper", bytes: 7),
        ]
        let rows = Ranking.build(processes: processes, sessions: [], mcps: [])
        #expect(rows.count == 1)
        #expect(rows[0].bytes == 12)
    }
}

import Foundation
import Testing
@testable import MemoRadarCore

private let mainExe = "/Applications/Visual Studio Code.app/Contents/MacOS/Code"
private let pluginExe = "/Applications/Visual Studio Code.app/Contents/Frameworks/Code Helper (Plugin).app/Contents/MacOS/Code Helper (Plugin)"
private let rendererExe = "/Applications/Visual Studio Code.app/Contents/Frameworks/Code Helper (Renderer).app/Contents/MacOS/Code Helper (Renderer)"
private let helperExe = "/Applications/Visual Studio Code.app/Contents/Frameworks/Code Helper.app/Contents/MacOS/Code Helper"
private let opened = Date(timeIntervalSince1970: 1_000)

private func proc(_ pid: Int32, parent: Int32, exe: String, args: [String] = [], bytes: UInt64 = 10) -> ProcessSnapshot {
    ProcessSnapshot(pid: pid, ppid: parent, startTime: opened, footprintBytes: bytes, executablePath: exe, arguments: args)
}

private func host(_ pid: Int32 = 10, bytes: UInt64 = 100) -> ProcessSnapshot {
    proc(pid, parent: 1, exe: pluginExe, args: ["--type=utility", "--utility-sub-type=node.mojom.NodeService"], bytes: bytes)
}

private func build(_ processes: [ProcessSnapshot], sessions: [ClaudeSession] = [], mcps: [McpCopy] = [],
                   rendererByHost: [Int32: Int32] = [:]) -> VSCodeBreakdown {
    VSCodeProjects.build(tree: ProcessTree(processes), processes: processes, sessions: sessions, mcps: mcps,
                         rendererByHost: rendererByHost)
}

@Suite struct VSCodeProjectsTests {
    @Test func hostIsPluginHelperWithUtilityType() {
        #expect(build([host()]).projects.map(\.hostPid) == [10])
        #expect(build([proc(10, parent: 1, exe: pluginExe)]).projects.isEmpty)
    }

    @Test func ordinaryHelperIsNotHost() {
        #expect(build([proc(10, parent: 1, exe: helperExe, args: ["--type=utility"])]).projects.isEmpty)
    }

    @Test func folderComesFromSessionCwd() {
        let session = ClaudeSession(pid: 11, cwd: "/x/projeto-a", entrypoint: "claude-vscode", status: .idle)
        let project = build([host(), proc(11, parent: 10, exe: "/x/claude")], sessions: [session]).projects[0]
        #expect(project.folder == "/x/projeto-a")
        #expect(project.displayName == "projeto-a")
        #expect(project.sessions == [session])
        #expect(project.openSince == opened)
    }

    @Test func rootCwdDoesNotDefineFolder() {
        let session = ClaudeSession(pid: 11, cwd: "/", entrypoint: "claude-vscode")
        let project = build([host(), proc(11, parent: 10, exe: "/x/claude")], sessions: [session]).projects[0]
        #expect(project.folder == nil)
    }

    @Test func mostFrequentFolderWins() {
        let sessions = [
            ClaudeSession(pid: 11, cwd: "/x/projeto-a"),
            ClaudeSession(pid: 12, cwd: "/x/projeto-b"),
            ClaudeSession(pid: 13, cwd: "/x/projeto-b"),
        ]
        let processes = [host()] + [11, 12, 13].map { proc($0, parent: 10, exe: "/x/claude") }
        #expect(build(processes, sessions: sessions).projects[0].folder == "/x/projeto-b")
    }

    @Test func windowWithoutSessionHasGenericName() {
        let project = build([host()]).projects[0]
        #expect(project.displayName == "Janela do VS Code")
        #expect(project.folder == nil)
    }

    @Test func ownBytesExcludeMcpBytes() {
        let processes = [host(bytes: 100), proc(11, parent: 10, exe: "/x/claude", bytes: 100),
                         proc(12, parent: 11, exe: "/x/node", bytes: 100)]
        let mcp = McpCopy(serverName: "srv", sessionPid: 11, rootPid: 12, pids: [12], bytes: 100)
        let project = build(processes, sessions: [ClaudeSession(pid: 11, entrypoint: "claude-vscode")], mcps: [mcp]).projects[0]
        #expect(project.ownBytes == 200)
        #expect(project.mcpBytes == 100)
        #expect(project.mcps == [mcp])
    }

    @Test func rendererOnlyWithSafeAssociation() {
        let breakdown = build([host(bytes: 100), proc(20, parent: 1, exe: rendererExe, bytes: 50)])
        #expect(breakdown.projects[0].ownBytes == 100)
        #expect(breakdown.projects[0].rendererPid == nil)
        #expect(breakdown.generalBytes == 50)
    }

    @Test func associatedRendererCountsInProject() {
        let breakdown = build([host(bytes: 100), proc(20, parent: 1, exe: rendererExe, bytes: 50)], rendererByHost: [10: 20])
        #expect(breakdown.projects[0].ownBytes == 150)
        #expect(breakdown.projects[0].rendererPid == 20)
        #expect(breakdown.generalBytes == 0)
    }

    @Test func cliSessionNotAttachedToHost() {
        let session = ClaudeSession(pid: 30, cwd: "/x/projeto-a", entrypoint: "cli")
        let project = build([host(), proc(30, parent: 1, exe: "/x/claude")], sessions: [session]).projects[0]
        #expect(project.sessions.isEmpty)
    }

    @Test func sumIsConsistentWithRankingRow() {
        let processes = [
            proc(5, parent: 1, exe: mainExe, bytes: 7),
            proc(10, parent: 5, exe: pluginExe, args: ["--type=utility"], bytes: 100),
            proc(11, parent: 10, exe: "/x/claude", bytes: 30),
            proc(12, parent: 11, exe: "/x/node", bytes: 20),
            proc(20, parent: 5, exe: rendererExe, bytes: 50),
            proc(21, parent: 5, exe: "/bin/zsh", bytes: 4),
            proc(22, parent: 21, exe: "/x/claude", bytes: 9),
        ]
        let sessions = [ClaudeSession(pid: 11, entrypoint: "claude-vscode"), ClaudeSession(pid: 22, entrypoint: "cli")]
        let mcps = [McpCopy(serverName: "srv", sessionPid: 11, rootPid: 12, pids: [12], bytes: 20)]
        let breakdown = build(processes, sessions: sessions, mcps: mcps)
        let row = Ranking.build(processes: processes, sessions: sessions, mcps: mcps).first { $0.kind == .vscode }
        let projectBytes = breakdown.projects.reduce(UInt64(0)) { $0 + $1.ownBytes }
        #expect(projectBytes + breakdown.generalBytes == row?.bytes)
    }
}

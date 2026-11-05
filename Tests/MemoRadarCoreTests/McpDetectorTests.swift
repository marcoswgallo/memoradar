import Foundation
import Testing
@testable import MemoRadarCore

private func proc(
    _ pid: Int32, parent: Int32, exe: String = "/usr/local/bin/node", args: [String] = [],
    bytes: UInt64 = 10, stdin: StdinKind = .pipeOrSocket
) -> ProcessSnapshot {
    ProcessSnapshot(pid: pid, ppid: parent, startTime: .distantPast, footprintBytes: bytes,
                    executablePath: exe, arguments: args, stdin: stdin)
}

private let session = ClaudeSession(pid: 100, status: .idle)
private let sessionProcess = proc(100, parent: 1, exe: "/x/claude", stdin: .other)

@Suite struct ProcessTreeTests {
    @Test func descendantsIncludeGrandchildren() {
        let tree = ProcessTree([proc(1, parent: 0), proc(2, parent: 1), proc(3, parent: 2), proc(4, parent: 9)])
        #expect(Set(tree.descendants(of: 1).map(\.pid)) == [2, 3])
        #expect(tree.isDescendant(3, of: 1))
        #expect(!tree.isDescendant(4, of: 1))
    }

    @Test func cycleDoesNotHang() {
        let tree = ProcessTree([proc(1, parent: 2), proc(2, parent: 1), proc(3, parent: 3)])
        #expect(tree.descendants(of: 1).map(\.pid) == [2])
        #expect(!tree.isDescendant(1, of: 9))
        #expect(!tree.isDescendant(3, of: 9))
    }
}

@Suite struct McpDetectorTests {
    @Test("nome do servidor", arguments: [
        (["npm exec chrome-devtools-mcp@latest --no-usage-statistics"], "/x/node", "chrome-devtools-mcp"),
        (["npm", "exec", "rea-agents@4.0.1", "mcp"], "/x/node", "rea-agents"),
        (["/x/uv", "tool", "uvx", "mcp-obsidian"], "/x/uv", "mcp-obsidian"),
        (["npx", "-y", "@org/server@1.2"], "/x/node", "@org/server"),
        (["/opt/bin/meu-servidor", "--porta", "1"], "/opt/bin/meu-servidor", "meu-servidor"),
        ([String](), "/opt/bin/outro", "outro"),
    ] as [([String], String, String)])
    func serverName(arguments: [String], exe: String, expected: String) {
        #expect(McpDetector.serverName(arguments: arguments, executablePath: exe) == expected)
    }

    @Test func directChildWithPipeIsMcp() {
        let tree = ProcessTree([sessionProcess, proc(101, parent: 100, args: ["npx", "-y", "srv"])])
        let copies = McpDetector.detect(tree: tree, sessions: [session])
        #expect(copies.count == 1)
        #expect(copies.first?.serverName == "srv")
        #expect(copies.first?.sessionPid == 100)
        #expect(copies.first?.rootPid == 101)
    }

    @Test func wrapperAndChildCountAsOneCopy() {
        let tree = ProcessTree([
            sessionProcess,
            proc(101, parent: 100, args: ["npx", "-y", "srv"], bytes: 30),
            proc(102, parent: 101, bytes: 70),
        ])
        let copies = McpDetector.detect(tree: tree, sessions: [session])
        #expect(copies.count == 1)
        #expect(Set(copies[0].pids) == [101, 102])
        #expect(copies[0].bytes == 100)
    }

    @Test func shellChildIsNotMcp() {
        let tree = ProcessTree([sessionProcess, proc(101, parent: 100, exe: "/bin/zsh")])
        #expect(McpDetector.detect(tree: tree, sessions: [session]).isEmpty)
    }

    @Test func grandchildViaShellIsNotMcp() {
        let tree = ProcessTree([sessionProcess, proc(101, parent: 100, exe: "/bin/zsh"), proc(102, parent: 101)])
        #expect(McpDetector.detect(tree: tree, sessions: [session]).isEmpty)
    }

    @Test func childWithoutPipeIsNotMcp() {
        let tree = ProcessTree([sessionProcess, proc(101, parent: 100, exe: "/usr/bin/caffeinate", stdin: .other)])
        #expect(McpDetector.detect(tree: tree, sessions: [session]).isEmpty)
    }

    @Test func unknownStdinIsNotMcp() {
        let tree = ProcessTree([sessionProcess, proc(101, parent: 100, stdin: .unknown)])
        #expect(McpDetector.detect(tree: tree, sessions: [session]).isEmpty)
    }
}

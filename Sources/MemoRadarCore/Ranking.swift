import Foundation

public enum RowKind: Sendable, Hashable {
    case mcps, vscode, claudeTerminal, app(String), appExtensions, macOSServices, others
}

public struct RankingRow: Sendable, Equatable {
    public var kind: RowKind
    public var title: String
    public var bytes: UInt64
    public var pids: [Int32]
    public var closable: Bool

    public init(kind: RowKind, title: String, bytes: UInt64, pids: [Int32], closable: Bool) {
        self.kind = kind
        self.title = title
        self.bytes = bytes
        self.pids = pids
        self.closable = closable
    }
}

/// Cada processo entra em uma única linha, na ordem: MCP, sessão de terminal,
/// VS Code, extensão de app, app, serviço do macOS e, por fim, "Outros".
public enum Ranking {
    private static let displayNames = ["Claude": "Claude Desktop"]

    public static func build(
        processes: [ProcessSnapshot], sessions: [ClaudeSession], mcps: [McpCopy]
    ) -> [RankingRow] {
        let tree = ProcessTree(processes)
        let mcpPids = Set(mcps.flatMap(\.pids))
        let terminalPids = terminalProcessIds(tree: tree, sessions: sessions)
        let vscodeRoots = processes.filter { isVSCodePath($0.executablePath) }.map(\.pid)
        var underVSCode = Set(vscodeRoots)
        for root in vscodeRoots {
            underVSCode.formUnion(tree.descendants(of: root).map(\.pid))
        }

        var rows: [RowKind: RankingRow] = [:]
        func add(_ process: ProcessSnapshot, _ kind: RowKind, _ title: String, closable: Bool = false) {
            var row = rows[kind] ?? RankingRow(kind: kind, title: title, bytes: 0, pids: [], closable: closable)
            row.bytes += process.footprintBytes
            row.pids.append(process.pid)
            rows[kind] = row
        }

        for process in processes {
            if mcpPids.contains(process.pid) {
                add(process, .mcps, "MCPs abertos")
            } else if terminalPids.contains(process.pid) {
                add(process, .claudeTerminal, "Claude Code no terminal")
            } else if underVSCode.contains(process.pid) {
                add(process, .vscode, "VS Code")
            } else if process.executablePath.contains(".appex/") {
                // O macOS mantém as extensões vivas: fechar o app não as encerra.
                if process.executablePath.hasPrefix("/System/") {
                    add(process, .macOSServices, "Serviços do macOS")
                } else {
                    add(process, .appExtensions, "Extensões de apps")
                }
            } else if let bundle = outermostBundleName(process.executablePath) {
                add(process, .app(bundle), displayNames[bundle] ?? bundle,
                    closable: !process.executablePath.hasPrefix("/System/"))
            } else if isMacOSPath(process.executablePath) {
                add(process, .macOSServices, "Serviços do macOS")
            } else {
                add(process, .others, "Outros")
            }
        }
        return rows.values.sorted {
            $0.bytes != $1.bytes ? $0.bytes > $1.bytes : $0.title < $1.title
        }
    }

    static func isVSCodePath(_ path: String) -> Bool {
        path.contains("/Visual Studio Code.app/") || path.contains("/.vscode/extensions/")
    }

    private static func isMacOSPath(_ path: String) -> Bool {
        ["/System/", "/usr/", "/sbin/", "/bin/"].contains { path.hasPrefix($0) }
            && !path.hasPrefix("/usr/local/")
    }

    private static func terminalProcessIds(tree: ProcessTree, sessions: [ClaudeSession]) -> Set<Int32> {
        var result: Set<Int32> = []
        for session in sessions {
            let inVSCode = session.entrypoint == "claude-vscode"
                || (tree.process(session.pid).map { isVSCodePath($0.executablePath) } ?? false)
            guard session.entrypoint == "cli" || !inVSCode else { continue }
            result.insert(session.pid)
            result.formUnion(tree.descendants(of: session.pid).map(\.pid))
        }
        return result
    }

    private static func outermostBundleName(_ path: String) -> String? {
        path.split(separator: "/").first { $0.hasSuffix(".app") }.map { String($0.dropLast(".app".count)) }
    }
}

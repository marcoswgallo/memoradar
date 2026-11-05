import Foundation

public struct VSCodeProject: Sendable, Equatable, Identifiable {
    public var id: Int32 { hostPid }
    public var hostPid: Int32
    public var rendererPid: Int32?
    public var folder: String?
    public var displayName: String
    public var openSince: Date
    public var sessions: [ClaudeSession]
    public var ownBytes: UInt64
    public var mcpBytes: UInt64
    public var mcps: [McpCopy]

    public init(
        hostPid: Int32, rendererPid: Int32? = nil, folder: String? = nil, displayName: String,
        openSince: Date, sessions: [ClaudeSession] = [], ownBytes: UInt64 = 0, mcpBytes: UInt64 = 0,
        mcps: [McpCopy] = []
    ) {
        self.hostPid = hostPid
        self.rendererPid = rendererPid
        self.folder = folder
        self.displayName = displayName
        self.openSince = openSince
        self.sessions = sessions
        self.ownBytes = ownBytes
        self.mcpBytes = mcpBytes
        self.mcps = mcps
    }
}

public struct VSCodeBreakdown: Sendable, Equatable {
    public var projects: [VSCodeProject]
    public var generalBytes: UInt64

    public init(projects: [VSCodeProject] = [], generalBytes: UInt64 = 0) {
        self.projects = projects
        self.generalBytes = generalBytes
    }
}

/// Cada janela do VS Code tem um extension host: `Code Helper (Plugin)` com `--type=utility`.
/// O que não dá para ligar a uma janela com segurança fica em `generalBytes`.
public enum VSCodeProjects {
    public static func build(
        tree: ProcessTree, processes: [ProcessSnapshot], sessions: [ClaudeSession],
        mcps: [McpCopy], rendererByHost: [Int32: Int32]
    ) -> VSCodeBreakdown {
        let row = Ranking.build(processes: processes, sessions: sessions, mcps: mcps)
            .first { $0.kind == .vscode }
        let vscodePids = Set(row?.pids ?? [])

        let projects = processes.filter(isHost).map { host -> VSCodeProject in
            var members = Set(tree.descendants(of: host.pid).map(\.pid))
            members.insert(host.pid)
            let hostSessions = sessions.filter { members.contains($0.pid) && $0.entrypoint != "cli" }
            let hostMcps = mcps.filter { members.contains($0.rootPid) }

            let rendererPid = rendererByHost[host.pid]
            if let rendererPid { members.insert(rendererPid) }

            let own = members.intersection(vscodePids).reduce(UInt64(0)) {
                $0 + (tree.process($1)?.footprintBytes ?? 0)
            }
            let folder = mostFrequentFolder(hostSessions)
            return VSCodeProject(
                hostPid: host.pid,
                rendererPid: rendererPid,
                folder: folder,
                displayName: folder.map { URL(fileURLWithPath: $0).lastPathComponent } ?? "Janela do VS Code",
                openSince: host.startTime,
                sessions: hostSessions,
                ownBytes: own,
                mcpBytes: hostMcps.reduce(0) { $0 + $1.bytes },
                mcps: hostMcps
            )
        }
        let attributed = projects.reduce(UInt64(0)) { $0 + $1.ownBytes }
        return VSCodeBreakdown(
            projects: projects.sorted { $0.ownBytes + $0.mcpBytes > $1.ownBytes + $1.mcpBytes },
            generalBytes: (row?.bytes ?? 0) - min(row?.bytes ?? 0, attributed)
        )
    }

    private static func isHost(_ process: ProcessSnapshot) -> Bool {
        process.executablePath.hasSuffix("/Code Helper (Plugin)")
            && process.arguments.contains("--type=utility")
    }

    private static func mostFrequentFolder(_ sessions: [ClaudeSession]) -> String? {
        let folders = sessions.compactMap(\.cwd).filter { $0 != "/" && !$0.isEmpty }
        let counts = Dictionary(grouping: folders, by: { $0 }).mapValues(\.count)
        return counts.max { ($0.value, $1.key) < ($1.value, $0.key) }?.key
    }
}

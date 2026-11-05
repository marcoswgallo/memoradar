import Foundation

public struct TerminalSessionInfo: Sendable, Equatable, Identifiable {
    public var id: Int32 { session.pid }
    public var session: ClaudeSession
    public var bytes: UInt64
}

public struct McpServerGroup: Sendable, Equatable, Identifiable {
    public var id: String { name }
    public var name: String
    public var copies: [McpCopy]
    public var bytes: UInt64
}

/// Tudo o que o painel mostra em uma atualização.
public struct Dashboard: Sendable, Equatable {
    public var system: SystemMemory
    public var rows: [RankingRow]
    public var vscode: VSCodeBreakdown
    public var mcpServers: [McpServerGroup]
    public var terminalSessions: [TerminalSessionInfo]
    public var sessions: [ClaudeSession]
    public var forgotten: Set<String>
    public var processes: [ProcessSnapshot]
    public var now: Date

    public static func build(
        processes: [ProcessSnapshot], sessions: [ClaudeSession], system: SystemMemory,
        now: Date, threshold: TimeInterval
    ) -> Dashboard {
        let tree = ProcessTree(processes)
        let mcps = McpDetector.detect(tree: tree, sessions: sessions)
        let rows = Ranking.build(processes: processes, sessions: sessions, mcps: mcps)
        return Dashboard(
            system: system,
            rows: rows,
            vscode: VSCodeProjects.build(tree: tree, processes: processes, sessions: sessions, mcps: mcps, rendererByHost: [:]),
            mcpServers: groupByServer(mcps),
            terminalSessions: terminalSessions(tree: tree, sessions: sessions, rows: rows),
            sessions: sessions,
            forgotten: Forgotten.folders(sessions: sessions, now: now, threshold: threshold),
            processes: processes,
            now: now
        )
    }

    /// Há quanto tempo todas as sessões estão paradas. `nil` se alguma não estiver parada.
    public static func idleDuration(sessions: [ClaudeSession], now: Date) -> TimeInterval? {
        guard !sessions.isEmpty else { return nil }
        let durations = sessions.map { session -> TimeInterval? in
            guard session.status == .idle, let updatedAt = session.statusUpdatedAt else { return nil }
            return now.timeIntervalSince(updatedAt)
        }
        guard !durations.contains(where: { $0 == nil }) else { return nil }
        return durations.compactMap { $0 }.min()
    }

    private static func groupByServer(_ mcps: [McpCopy]) -> [McpServerGroup] {
        Dictionary(grouping: mcps, by: \.serverName)
            .map { McpServerGroup(name: $0.key, copies: $0.value, bytes: $0.value.reduce(0) { $0 + $1.bytes }) }
            .sorted { $0.bytes != $1.bytes ? $0.bytes > $1.bytes : $0.name < $1.name }
    }

    private static func terminalSessions(tree: ProcessTree, sessions: [ClaudeSession], rows: [RankingRow]) -> [TerminalSessionInfo] {
        let terminalPids = Set(rows.first { $0.kind == .claudeTerminal }?.pids ?? [])
        return sessions.filter { terminalPids.contains($0.pid) }.map { session in
            let members = [tree.process(session.pid)].compactMap { $0 } + tree.descendants(of: session.pid)
            let bytes = members.filter { terminalPids.contains($0.pid) }.reduce(UInt64(0)) { $0 + $1.footprintBytes }
            return TerminalSessionInfo(session: session, bytes: bytes)
        }
    }
}

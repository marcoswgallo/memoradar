import Foundation

/// Um pedido de fechar, com a identidade dos processos no momento do clique. Assim, o que
/// for fechado é exatamente o que a pessoa viu, mesmo que o painel tenha atualizado depois.
public struct PendingClose: Sendable, Equatable {
    public var target: CloseTarget
    public var identities: [ProcessIdentity]
    public var mainAppCandidates: [Int32]
    private var mainExecutablePaths: Set<String>

    public init(target: CloseTarget, dashboard: Dashboard) {
        self.target = target

        let pids: [Int32]
        switch target {
        case let .app(_, appPids, _): pids = appPids
        case let .vscodeWindow(project): pids = [project.hostPid]
        case let .terminalSession(session, _): pids = [session.pid]
        case let .mcpCopy(copy): pids = copy.pids
        case let .mcpServer(_, copies): pids = copies.flatMap(\.pids)
        }
        let wanted = Set(pids)
        let members = dashboard.processes.filter { wanted.contains($0.pid) }
        identities = members.map { ProcessIdentity(pid: $0.pid, startTime: $0.startTime) }

        // Processos cujo pai está fora do app. Os auxiliares nunca são fechados no lugar dele.
        let roots = members.filter { !wanted.contains($0.ppid) }.sorted { $0.startTime < $1.startTime }
        mainAppCandidates = roots.map(\.pid)
        mainExecutablePaths = Set(roots.map(\.executablePath))
    }

    /// Depois de fechar: existe um processo novo do mesmo programa?
    public func wasReopened(current: [ProcessSnapshot]) -> Bool {
        let original = Set(identities)
        return current.contains { process in
            mainExecutablePaths.contains(process.executablePath)
                && !original.contains(ProcessIdentity(pid: process.pid, startTime: process.startTime))
        }
    }
}

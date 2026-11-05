import Foundation

public enum CloseTarget: Sendable, Equatable {
    case app(name: String, pids: [Int32], bytes: UInt64)
    case vscodeWindow(VSCodeProject)
    case terminalSession(ClaudeSession, bytes: UInt64)
    case mcpCopy(McpCopy)
    case mcpServer(name: String, copies: [McpCopy])
}

public enum ConfirmationSeverity: Sendable, Equatable {
    case simple, strong
}

public struct Confirmation: Sendable, Equatable {
    public var severity: ConfirmationSeverity
    public var title: String
    public var message: String
    public var estimatedBytes: UInt64

    public init(severity: ConfirmationSeverity, title: String, message: String, estimatedBytes: UInt64) {
        self.severity = severity
        self.title = title
        self.message = message
        self.estimatedBytes = estimatedBytes
    }
}

public enum CloseOutcome: Sendable, Equatable {
    case closed, stillOpen, failed(String)
}

public func closeOutcome(stillRunningAfterWait: Bool, error: String?) -> CloseOutcome {
    if let error { return .failed(error) }
    return stillRunningAfterWait ? .stillOpen : .closed
}

/// Só sessão confirmada como parada recebe a confirmação simples. Trabalhando ou em
/// estado desconhecido, o alerta é sempre o forte.
public enum ClosePolicy {
    private static let mcpWarning =
        "Cada sessão fica sem essas ferramentas até reiniciar. Ele volta em sessões novas, se continuar configurado."

    public static func confirmation(for target: CloseTarget, allSessions: [ClaudeSession]) -> Confirmation {
        switch target {
        case let .app(name, _, bytes):
            return confirmation(fallbackTitle: "Fechar \(name)?", atRisk: [], extra: "O app pode pedir para salvar.", bytes: bytes)

        case let .vscodeWindow(project):
            let sameFolderTerminal = allSessions.filter {
                $0.entrypoint == "cli" && project.folder != nil && $0.cwd == project.folder
            }
            let atRisk = (project.sessions + sameFolderTerminal).filter(isAtRisk)
            let names = atRisk.isEmpty ? [] : [project.displayName]
            return confirmation(
                fallbackTitle: "Fechar \(project.displayName)?", atRisk: names,
                extra: "Se houver arquivo sem salvar, o VS Code vai perguntar.",
                bytes: project.ownBytes + project.mcpBytes)

        case let .terminalSession(session, bytes):
            let name = folderName(session)
            return confirmation(
                fallbackTitle: "Encerrar a sessão em \(name)?", atRisk: isAtRisk(session) ? [name] : [],
                extra: nil, bytes: bytes)

        case let .mcpCopy(copy):
            return mcpConfirmation(name: copy.serverName, copies: [copy], allSessions: allSessions)

        case let .mcpServer(name, copies):
            return mcpConfirmation(name: name, copies: copies, allSessions: allSessions)
        }
    }

    public static func isSameProcess(_ identity: ProcessIdentity, current: ProcessSnapshot?) -> Bool {
        current?.pid == identity.pid && current?.startTime == identity.startTime
    }

    private static func mcpConfirmation(name: String, copies: [McpCopy], allSessions: [ClaudeSession]) -> Confirmation {
        let sessionByPid = Dictionary(allSessions.map { ($0.pid, $0) }, uniquingKeysWith: { first, _ in first })
        var atRisk: [String] = []
        for copy in copies {
            guard let session = sessionByPid[copy.sessionPid] else {
                atRisk.append("uma sessão")
                continue
            }
            if isAtRisk(session) { atRisk.append(folderName(session)) }
        }
        var unique: [String] = []
        for item in atRisk where !unique.contains(item) { unique.append(item) }
        return confirmation(
            fallbackTitle: "Fechar \(name)?", atRisk: unique, extra: mcpWarning,
            bytes: copies.reduce(0) { $0 + $1.bytes })
    }

    private static func confirmation(fallbackTitle: String, atRisk: [String], extra: String?, bytes: UInt64) -> Confirmation {
        let estimate = "Libera cerca de \(MemoryFormat.bytes(bytes))."
        let message = [estimate, extra].compactMap { $0 }.joined(separator: " ")
        guard !atRisk.isEmpty else {
            return Confirmation(severity: .simple, title: fallbackTitle, message: message, estimatedBytes: bytes)
        }
        let names = atRisk.joined(separator: ", ")
        return Confirmation(
            severity: .strong,
            title: "O Claude Code está rodando em \(names). Fechar mesmo assim?",
            message: message,
            estimatedBytes: bytes)
    }

    private static func isAtRisk(_ session: ClaudeSession) -> Bool { session.status != .idle }

    private static func folderName(_ session: ClaudeSession) -> String {
        guard let cwd = session.cwd, cwd != "/" else { return "uma sessão" }
        return URL(fileURLWithPath: cwd).lastPathComponent
    }
}

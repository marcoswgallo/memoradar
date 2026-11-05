import Foundation

public struct McpCopy: Sendable, Equatable {
    public var serverName: String
    public var sessionPid: Int32
    public var rootPid: Int32
    public var pids: [Int32]
    public var bytes: UInt64

    public init(serverName: String, sessionPid: Int32, rootPid: Int32, pids: [Int32], bytes: UInt64) {
        self.serverName = serverName
        self.sessionPid = sessionPid
        self.rootPid = rootPid
        self.pids = pids
        self.bytes = bytes
    }
}

/// Reconhece MCPs locais pelo comportamento: filho direto da sessão, que não é shell,
/// com a entrada padrão ligada a pipe ou socket. Na dúvida, não é MCP.
public enum McpDetector {
    private static let shells: Set<String> = ["sh", "bash", "zsh", "dash", "fish"]
    private static let runners: Set<String> = ["npx", "uvx", "bunx", "pnpx"]
    private static let execRunners: Set<String> = ["npm", "pnpm"]

    public static func detect(tree: ProcessTree, sessions: [ClaudeSession]) -> [McpCopy] {
        sessions.flatMap { session in
            tree.children(of: session.pid).compactMap { child -> McpCopy? in
                guard child.stdin == .pipeOrSocket, !shells.contains(baseName(child.executablePath)) else {
                    return nil
                }
                let members = [child] + tree.descendants(of: child.pid)
                return McpCopy(
                    serverName: serverName(arguments: child.arguments, executablePath: child.executablePath),
                    sessionPid: session.pid,
                    rootPid: child.pid,
                    pids: members.map(\.pid),
                    bytes: members.reduce(0) { $0 + $1.footprintBytes }
                )
            }
        }
    }

    public static func serverName(arguments: [String], executablePath: String) -> String {
        // `npm exec` reescreve o título do processo, e os argumentos podem vir em um token só.
        let tokens = arguments.joined(separator: " ").split(separator: " ").map(String.init)
        for (index, token) in tokens.enumerated() {
            let isRunner = runners.contains(baseName(token))
            let isExec = token == "exec" && index > 0 && execRunners.contains(baseName(tokens[index - 1]))
            guard isRunner || isExec else { continue }
            if let package = tokens[(index + 1)...].first(where: { !$0.hasPrefix("-") }) {
                return strippingVersion(package)
            }
        }
        return baseName(executablePath)
    }

    private static func strippingVersion(_ package: String) -> String {
        guard let at = package.lastIndex(of: "@"), at != package.startIndex else { return package }
        return String(package[..<at])
    }

    private static func baseName(_ path: String) -> String {
        path.split(separator: "/").last.map(String.init) ?? path
    }
}

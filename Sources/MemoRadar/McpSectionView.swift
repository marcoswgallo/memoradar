import MemoRadarCore
import SwiftUI

struct McpSectionView: View {
    let servers: [McpServerGroup]
    let sessions: [ClaudeSession]
    let onClose: (CloseTarget) -> Void

    var body: some View {
        ForEach(servers) { server in
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(server.name).lineLimit(1)
                    Spacer(minLength: 8)
                    Text(server.copies.count == 1 ? "1 cópia" : "\(server.copies.count) cópias")
                        .font(.caption).foregroundStyle(.secondary)
                    Text(MemoryFormat.bytes(server.bytes)).monospacedDigit()
                    CloseRowButton(title: server.copies.count > 1 ? "Fechar todos" : "Fechar") {
                        onClose(.mcpServer(name: server.name, copies: server.copies))
                    }
                }
                ForEach(server.copies, id: \.rootPid) { copy in
                    HStack {
                        Text(sessionName(copy.sessionPid)).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        Spacer(minLength: 8)
                        Text(MemoryFormat.bytes(copy.bytes)).font(.caption).monospacedDigit().foregroundStyle(.secondary)
                        if server.copies.count > 1 {
                            CloseRowButton { onClose(.mcpCopy(copy)) }
                        }
                    }
                    .padding(.leading, 10)
                }
            }
        }
    }

    private func sessionName(_ pid: Int32) -> String {
        guard let cwd = sessions.first(where: { $0.pid == pid })?.cwd, cwd != "/" else { return "Sessão" }
        return URL(fileURLWithPath: cwd).lastPathComponent
    }
}

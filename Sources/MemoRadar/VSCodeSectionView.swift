import MemoRadarCore
import SwiftUI

struct VSCodeSectionView: View {
    let breakdown: VSCodeBreakdown
    let forgotten: Set<String>
    let now: Date
    let onClose: (CloseTarget) -> Void

    var body: some View {
        ForEach(breakdown.projects) { project in
            projectRow(project)
        }
        if breakdown.generalBytes > 0 {
            HStack {
                Text("VS Code (geral)").foregroundStyle(.secondary)
                Spacer()
                Text(MemoryFormat.bytes(breakdown.generalBytes)).monospacedDigit().foregroundStyle(.secondary)
            }
        }
    }

    private func projectRow(_ project: VSCodeProject) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 6) {
                Text(project.displayName).lineLimit(1)
                if let folder = project.folder, forgotten.contains(folder) { ForgottenBadge() }
                Spacer(minLength: 8)
                Text(MemoryFormat.bytes(project.ownBytes)).monospacedDigit()
                CloseRowButton { onClose(.vscodeWindow(project)) }
            }
            Text(details(project)).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func details(_ project: VSCodeProject) -> String {
        var parts = ["Aberto há \(MemoryFormat.duration(now.timeIntervalSince(project.openSince)))"]
        if !project.sessions.isEmpty {
            parts.append(project.sessions.count == 1 ? "1 sessão" : "\(project.sessions.count) sessões")
        }
        if let status = sessionStatusText(project.sessions, now: now) { parts.append(status) }
        if project.mcpBytes > 0 { parts.append("+ \(MemoryFormat.bytes(project.mcpBytes)) de MCPs") }
        return parts.joined(separator: " · ")
    }
}

struct TerminalSectionView: View {
    let sessions: [TerminalSessionInfo]
    let forgotten: Set<String>
    let now: Date
    let onClose: (CloseTarget) -> Void

    var body: some View {
        ForEach(sessions) { info in
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(folderName(info.session)).lineLimit(1)
                    if let cwd = info.session.cwd, forgotten.contains(cwd) { ForgottenBadge() }
                    Spacer(minLength: 8)
                    Text(MemoryFormat.bytes(info.bytes)).monospacedDigit()
                    CloseRowButton { onClose(.terminalSession(info.session, bytes: info.bytes)) }
                }
                if let status = sessionStatusText([info.session], now: now) {
                    Text(status).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func folderName(_ session: ClaudeSession) -> String {
        guard let cwd = session.cwd, cwd != "/" else { return "Sessão" }
        return URL(fileURLWithPath: cwd).lastPathComponent
    }
}

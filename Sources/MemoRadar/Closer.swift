import AppKit
import MemoRadarCore

@MainActor
final class Closer {
    private static let waitSeconds: TimeInterval = 5

    func perform(_ pending: PendingClose, current: Dashboard) async -> CloseOutcome {
        switch pending.target {
        case .app:
            return await closeApp(pending)
        case let .vscodeWindow(project):
            return await closeWindow(project, pending: pending, current: current)
        case .terminalSession, .mcpCopy, .mcpServer:
            return await ProcessTerminator.terminate(pending.identities)
        }
    }

    private func closeApp(_ pending: PendingClose) async -> CloseOutcome {
        let live = Set(ProcessTerminator.signalablePids(pending.identities, current: ProcessSampler.sample()))
        let candidates = pending.mainAppCandidates.filter(live.contains)
        guard let app = candidates.lazy.compactMap({ NSRunningApplication(processIdentifier: $0) }).first(where: { $0.bundleIdentifier != nil }) else {
            return .failed("Não encontrei este app em execução. Nada foi fechado.")
        }
        guard app.terminate() else {
            return .failed("O macOS não aceitou o pedido de fechar este app.")
        }
        let deadline = Date().addingTimeInterval(Self.waitSeconds)
        while !app.isTerminated, Date() < deadline {
            try? await Task.sleep(for: .milliseconds(200))
        }
        return closeOutcome(stillRunningAfterWait: !app.isTerminated, error: nil)
    }

    private func closeWindow(_ project: VSCodeProject, pending: PendingClose, current: Dashboard) async -> CloseOutcome {
        guard AccessibilityWindows.isTrusted else {
            return .failed("Fechar janelas precisa da permissão de Acessibilidade.")
        }
        guard let folder = project.folder else {
            return .failed("Sem uma sessão do Claude, não dá para saber com segurança qual é esta janela. Nada foi fechado.")
        }
        let siblings = current.vscode.projects.compactMap(\.folder)
        let titles = AccessibilityWindows.vscodeWindowTitles()
        switch WindowMatcher.match(
            folder: folder, siblingFolders: siblings, titles: titles, hostCount: current.vscode.projects.count
        ) {
        case .none:
            return .failed("Não encontrei a janela de \(project.displayName). Nada foi fechado.")
        case .ambiguous:
            return .failed("Há mais de uma janela que pode ser \(project.displayName). Nada foi fechado.")
        case let .unique(index):
            guard AccessibilityWindows.pressClose(windowAt: index) else {
                return .failed("O VS Code não aceitou o pedido de fechar a janela.")
            }
        }
        let stillRunning = await ProcessTerminator.waitUntilGone(pending.identities, timeout: Self.waitSeconds)
        return closeOutcome(stillRunningAfterWait: stillRunning, error: nil)
    }
}

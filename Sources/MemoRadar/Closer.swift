import AppKit
import MemoRadarCore

@MainActor
final class Closer {
    private static let waitSeconds: TimeInterval = 5

    func perform(_ target: CloseTarget, dashboard: Dashboard) async -> CloseOutcome {
        switch target {
        case let .app(_, pids, _):
            return await closeApp(pids: pids, dashboard: dashboard)
        case let .vscodeWindow(project):
            return await closeWindow(project, dashboard: dashboard)
        case let .terminalSession(session, _):
            return await ProcessTerminator.terminate(identities([session.pid], dashboard))
        case let .mcpCopy(copy):
            return await ProcessTerminator.terminate(identities(copy.pids, dashboard))
        case let .mcpServer(_, copies):
            return await ProcessTerminator.terminate(identities(copies.flatMap(\.pids), dashboard))
        }
    }

    private func closeApp(pids: [Int32], dashboard: Dashboard) async -> CloseOutcome {
        let targets = identities(pids, dashboard)
        let live = ProcessTerminator.signalablePids(targets, current: ProcessSampler.sample())
        guard let app = live.lazy.compactMap({ NSRunningApplication(processIdentifier: $0) }).first(where: { $0.bundleIdentifier != nil }) else {
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

    private func closeWindow(_ project: VSCodeProject, dashboard: Dashboard) async -> CloseOutcome {
        guard AccessibilityWindows.isTrusted else {
            return .failed("Fechar janelas precisa da permissão de Acessibilidade.")
        }
        guard let folder = project.folder else {
            return .failed("Sem uma sessão do Claude, não dá para saber com segurança qual é esta janela. Nada foi fechado.")
        }
        let siblings = dashboard.vscode.projects.compactMap(\.folder)
        let titles = AccessibilityWindows.vscodeWindowTitles()
        switch WindowMatcher.match(folder: folder, siblingFolders: siblings, titles: titles) {
        case .none:
            return .failed("Não encontrei a janela de \(project.displayName). Nada foi fechado.")
        case .ambiguous:
            return .failed("Há mais de uma janela que pode ser \(project.displayName). Nada foi fechado.")
        case let .unique(index):
            guard AccessibilityWindows.pressClose(windowAt: index) else {
                return .failed("O VS Code não aceitou o pedido de fechar a janela.")
            }
        }
        let stillRunning = await ProcessTerminator.waitUntilGone(identities([project.hostPid], dashboard), timeout: Self.waitSeconds)
        return closeOutcome(stillRunningAfterWait: stillRunning, error: nil)
    }

    private func identities(_ pids: [Int32], _ dashboard: Dashboard) -> [ProcessIdentity] {
        let wanted = Set(pids)
        return dashboard.processes.filter { wanted.contains($0.pid) }
            .map { ProcessIdentity(pid: $0.pid, startTime: $0.startTime) }
    }
}

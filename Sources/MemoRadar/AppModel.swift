import Foundation
import MemoRadarCore
import Observation

/// Estado da interface. Fica em um objeto, em vez de `@State`, porque `@State` é uma macro
/// cujo plugin só vem com o Xcode, e este projeto compila com as Command Line Tools.
@MainActor @Observable
final class PanelState {
    var showingSettings = false
    var expanded: Set<String> = []
    var pendingClose: PendingClose?
    var isClosing = false
    var closeResult: String?

    func toggle(_ key: String) {
        if expanded.contains(key) { expanded.remove(key) } else { expanded.insert(key) }
    }
}

@MainActor @Observable
final class AppModel {
    private(set) var dashboard: Dashboard?
    private(set) var iconState: IconState = .normal
    private(set) var panelIsOpen = false

    let settings: AppSettings
    let panel = PanelState()
    private let notifier = Notifier()
    private let closer = Closer()
    private var ledger = NotificationLedger()
    private var askedNotificationPermission = false
    private var loop: Task<Void, Never>?

    private static let closedInterval: Duration = .seconds(10)
    private static let openInterval: Duration = .seconds(3)
    private static let sessionsDirectory = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".claude/sessions")

    init(settings: AppSettings) {
        self.settings = settings
    }

    func start() {
        guard loop == nil else { return }
        requestNotificationPermissionOnce()
        loop = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                let interval = self?.panelIsOpen == true ? Self.openInterval : Self.closedInterval
                try? await Task.sleep(for: interval)
            }
        }
    }

    /// Fora do ciclo de leitura: o painel não pode ficar esperando a resposta do diálogo.
    private func requestNotificationPermissionOnce() {
        guard !askedNotificationPermission, settings.notificationsEnabled else { return }
        askedNotificationPermission = true
        Task { await notifier.requestPermission() }
    }

    func setPanelOpen(_ open: Bool) {
        guard open != panelIsOpen else { return }
        panelIsOpen = open
        if !open, !panel.isClosing {
            panel.pendingClose = nil
            panel.closeResult = nil
        }
        if open {
            // Reinicia o ciclo para atualizar agora e passar ao intervalo curto.
            loop?.cancel()
            loop = nil
            start()
        }
    }

    func requestClose(_ target: CloseTarget) {
        guard let dashboard else { return }
        panel.closeResult = nil
        panel.pendingClose = PendingClose(target: target, dashboard: dashboard)
    }

    func confirmClose() {
        guard let pending = panel.pendingClose, let dashboard, !panel.isClosing else { return }
        panel.isClosing = true
        Task {
            let outcome = await closer.perform(pending, current: dashboard)
            panel.isClosing = false
            panel.pendingClose = nil
            panel.closeResult = Self.message(for: outcome)
            await refresh()
        }
    }

    private static func message(for outcome: CloseOutcome) -> String {
        switch outcome {
        case .closed: "Fechado."
        case .stillOpen: "Continua aberto. Pode estar aguardando você salvar um arquivo."
        case .reopened: "Fechou, mas o app abriu de novo logo em seguida."
        case let .failed(reason): reason
        }
    }

    /// O registro é atualizado mesmo com avisos desligados, para não disparar tudo de uma vez ao religar.
    private func notifyNewlyForgotten(in dashboard: Dashboard) {
        let new = ledger.update(forgotten: dashboard.forgotten)
        guard settings.notificationsEnabled else { return }
        for folder in new.sorted() {
            let sessions = dashboard.sessions.filter { $0.cwd == folder }
            let idle = Dashboard.idleDuration(sessions: sessions, now: dashboard.now) ?? 0
            notifier.notifyForgotten(
                folderName: URL(fileURLWithPath: folder).lastPathComponent,
                idleFor: MemoryFormat.duration(idle))
        }
    }

    func refresh() async {
        let threshold = settings.threshold
        let directory = Self.sessionsDirectory
        let result = await Task.detached(priority: .utility) {
            let processes = ProcessSampler.sample()
            return Dashboard.build(
                processes: processes,
                sessions: SessionStore.load(directory: directory, processes: processes),
                system: SystemSampler.sample(),
                now: Date(),
                threshold: threshold
            )
        }.value
        dashboard = result
        iconState = IconState.compute(pressure: result.system.pressure, hasForgotten: !result.forgotten.isEmpty)
        notifyNewlyForgotten(in: result)
    }
}

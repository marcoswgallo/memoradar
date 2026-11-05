import Foundation
import MemoRadarCore
import Observation

/// Estado da interface. Fica em um objeto, em vez de `@State`, porque `@State` é uma macro
/// cujo plugin só vem com o Xcode, e este projeto compila com as Command Line Tools.
@MainActor @Observable
final class PanelState {
    var showingSettings = false
    var expanded: Set<String> = []

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
    private var ledger = NotificationLedger()
    private var loop: Task<Void, Never>?

    private static let closedInterval: Duration = .seconds(10)
    private static let openInterval: Duration = .seconds(3)
    private static let sessionsDirectory = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".claude/sessions")

    init(settings: AppSettings) {
        self.settings = settings
    }

    func start() {
        guard loop == nil else { return }
        loop = Task { [weak self] in
            if self?.settings.notificationsEnabled == true { await self?.notifier.requestPermission() }
            while !Task.isCancelled {
                await self?.refresh()
                let interval = self?.panelIsOpen == true ? Self.openInterval : Self.closedInterval
                try? await Task.sleep(for: interval)
            }
        }
    }

    func setPanelOpen(_ open: Bool) {
        panelIsOpen = open
        if open {
            // Reinicia o ciclo para atualizar agora e passar ao intervalo curto.
            loop?.cancel()
            loop = nil
            start()
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

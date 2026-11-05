import AppKit
import MemoRadarCore
import SwiftUI

struct PanelView: View {
    let model: AppModel

    private static let maximumHeight: CGFloat = 560

    var body: some View {
        Group {
            if let pending = model.panel.pendingClose, let dashboard = model.dashboard {
                CloseDialog(
                    target: pending.target,
                    confirmation: ClosePolicy.confirmation(
                        for: pending.target, allSessions: dashboard.sessions, tree: ProcessTree(dashboard.processes)),
                    isClosing: model.panel.isClosing,
                    onCancel: { model.panel.pendingClose = nil },
                    onConfirm: { model.confirmClose() }
                )
            } else if model.panel.showingSettings {
                SettingsView(settings: model.settings) { model.panel.showingSettings = false }
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    if let dashboard = model.dashboard {
                        // Uma ScrollView sozinha encolhe dentro do MenuBarExtra: a altura vem do conteúdo.
                        ScrollView {
                            PanelContent(dashboard: dashboard, panel: model.panel, onClose: { model.requestClose($0) })
                                .padding(14)
                                .onGeometryChange(for: CGFloat.self, of: { $0.size.height }) { height in
                                    model.panel.contentHeight = height
                                }
                        }
                        .frame(height: min(model.panel.contentHeight, Self.maximumHeight))
                    } else {
                        Text("Lendo a memória…").foregroundStyle(.secondary).padding(14)
                    }
                    Divider()
                    HStack {
                        Button("Configurações") { model.panel.showingSettings = true }
                        Spacer()
                        Button("Sair") { NSApplication.shared.terminate(nil) }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .padding(10)
                }
                .frame(width: 360)
            }
        }
        .onAppear { model.setPanelOpen(true) }
        .onDisappear { model.setPanelOpen(false) }
    }
}

struct PanelContent: View {
    let dashboard: Dashboard
    let panel: PanelState
    let onClose: (CloseTarget) -> Void

    private static let maximumProcessDetails = 8

    /// Linhas menores que isso só poluem a lista.
    private static let minimumRowBytes: UInt64 = 50 * 1_048_576

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            header
            if let result = panel.closeResult {
                Text(result).font(.caption.weight(.medium)).padding(.bottom, 4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(visibleRows, id: \.kind) { row in
                rowView(row)
            }
            Divider().padding(.vertical, 4)
            HStack {
                Text("Reservada pelo sistema").foregroundStyle(.secondary)
                Spacer()
                Text(MemoryFormat.bytes(dashboard.system.wiredBytes)).monospacedDigit().foregroundStyle(.secondary)
            }
            HStack {
                Text("Swap").foregroundStyle(.secondary)
                Spacer()
                Text(MemoryFormat.bytes(dashboard.system.swapUsedBytes)).monospacedDigit().foregroundStyle(.secondary)
            }
        }
    }

    private var visibleRows: [RankingRow] {
        dashboard.rows.filter { row in
            switch row.kind {
            case .vscode, .mcps, .claudeTerminal: true
            default: row.bytes >= Self.minimumRowBytes
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Memória \(dashboard.system.usedPercent)%").font(.headline)
                Spacer()
                Text(pressureText)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(pressureColor.opacity(0.22), in: Capsule())
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.25))
                    Capsule().fill(pressureColor)
                        .frame(width: geometry.size.width * CGFloat(min(dashboard.system.usedPercent, 100)) / 100)
                }
            }
            .frame(height: 6)
            if !dashboard.forgotten.isEmpty {
                Text(dashboard.forgotten.count == 1 ? "1 projeto parece esquecido" : "\(dashboard.forgotten.count) projetos parecem esquecidos")
                    .font(.caption.weight(.medium))
            }
        }
        .padding(.bottom, 6)
    }

    private var pressureText: String {
        switch dashboard.system.pressure {
        case .normal: "Pressão normal"
        case .warning: "Pressão em aviso"
        case .critical: "Pressão crítica"
        case .unknown: "Pressão desconhecida"
        }
    }

    private var pressureColor: Color {
        switch dashboard.system.pressure {
        case .normal: .green
        case .warning: .yellow
        case .critical: .red
        case .unknown: .gray
        }
    }

    @ViewBuilder
    private func rowView(_ row: RankingRow) -> some View {
        switch row.kind {
        case .vscode:
            ExpandableRow(title: row.title, panel: panel) {
                Text(MemoryFormat.bytes(row.bytes))
            } details: {
                VSCodeSectionView(breakdown: dashboard.vscode, forgotten: dashboard.forgotten, now: dashboard.now, onClose: onClose)
            }
        case .mcps:
            ExpandableRow(title: row.title, panel: panel) {
                Text("\(mcpCopyCount) · \(MemoryFormat.bytes(row.bytes))")
            } details: {
                McpSectionView(servers: dashboard.mcpServers, sessions: dashboard.sessions, onClose: onClose)
            }
        case .claudeTerminal:
            ExpandableRow(title: row.title, panel: panel) {
                Text(MemoryFormat.bytes(row.bytes))
            } details: {
                TerminalSectionView(sessions: dashboard.terminalSessions, forgotten: dashboard.forgotten, now: dashboard.now, onClose: onClose)
            }
        default:
            ExpandableRow(title: row.title, panel: panel, trailing: {
                HStack(spacing: 6) {
                    Text(MemoryFormat.bytes(row.bytes))
                    if row.closable {
                        CloseRowButton { onClose(.app(name: row.title, pids: row.pids, bytes: row.bytes)) }
                    }
                }
            }, details: {
                ProcessListView(
                    processes: dashboard.topProcesses(pids: row.pids, limit: Self.maximumProcessDetails),
                    total: row.pids.count)
            })
        }
    }

    private var mcpCopyCount: Int {
        dashboard.mcpServers.reduce(0) { $0 + $1.copies.count }
    }
}

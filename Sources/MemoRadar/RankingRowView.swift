import MemoRadarCore
import SwiftUI

/// Linha do painel: título à esquerda e valor à direita, com expansão opcional.
struct ExpandableRow<Trailing: View, Details: View>: View {
    let title: String
    let panel: PanelState
    @ViewBuilder let trailing: Trailing
    @ViewBuilder let details: Details
    var expandable = true

    private var expanded: Bool { panel.expanded.contains(title) }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if expandable {
                Button { panel.toggle(title) } label: { header }
                    .buttonStyle(.plain)
            } else {
                header
            }
            if expanded {
                VStack(alignment: .leading, spacing: 6) { details }
                    .padding(.leading, 16)
            }
        }
        .padding(.vertical, 3)
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: expanded ? "chevron.down" : "chevron.right")
                .font(.system(size: 9, weight: .semibold))
                .frame(width: 10)
                .opacity(expandable ? 0.6 : 0)
            Text(title).fontWeight(.medium).lineLimit(1)
            Spacer(minLength: 8)
            trailing.monospacedDigit().foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
    }
}

/// Estado de uma ou mais sessões do Claude, em texto.
func sessionStatusText(_ sessions: [ClaudeSession], now: Date) -> String? {
    guard !sessions.isEmpty else { return nil }
    if sessions.contains(where: { $0.status == .busy }) { return "Trabalhando" }
    if let idle = Dashboard.idleDuration(sessions: sessions, now: now) {
        return "Parado há \(MemoryFormat.duration(idle))"
    }
    return "Estado desconhecido"
}

/// Selo de destaque para o que parece esquecido.
struct ForgottenBadge: View {
    var body: some View {
        Text("Esquecido?")
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(Color.yellow.opacity(0.25), in: Capsule())
    }
}

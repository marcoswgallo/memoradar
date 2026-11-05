import AppKit
import MemoRadarCore
import SwiftUI

/// Skills sem uso, por plugin. Só mostra: desativar é sempre decisão da pessoa.
struct SkillsSectionView: View {
    let report: SkillReport
    let panel: PanelState

    var body: some View {
        ExpandableRow(title: "Skills", panel: panel, trailing: {
            Text(report.summary)
        }, details: {
            ForEach(report.groups) { group in
                groupRow(group)
            }
            Text("Skills não gastam RAM: ocupam contexto em cada sessão. A conta não inclui Skills de projeto nem de outras origens.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }, key: "secao-skills")
    }

    private func groupRow(_ group: SkillGroup) -> some View {
        ExpandableRow(title: group.title, panel: panel, trailing: {
            Text(group.summary(usageKnown: report.usageKnown))
        }, details: {
            hint(for: group)
            ForEach(group.skills) { skill in
                HStack {
                    Text(skill.shortName).font(.caption).lineLimit(1).truncationMode(.middle)
                    Spacer(minLength: 8)
                    Text(skill.text(usageKnown: report.usageKnown)).font(.caption).monospacedDigit().foregroundStyle(.secondary)
                }
            }
        }, key: "skills-\(group.title)")
    }

    @ViewBuilder
    private func hint(for group: SkillGroup) -> some View {
        if let command = group.disableCommand {
            HStack(spacing: 6) {
                Text(command).font(.caption2.monospaced()).lineLimit(1).truncationMode(.middle).foregroundStyle(.secondary)
                Spacer(minLength: 4)
                CloseRowButton(title: "Copiar") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(command, forType: .string)
                }
            }
        } else {
            Text("Ficam em ~/.claude/skills").font(.caption2).foregroundStyle(.secondary)
        }
    }
}

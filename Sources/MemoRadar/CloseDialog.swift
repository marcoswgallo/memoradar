import MemoRadarCore
import SwiftUI

/// Confirmação dentro do próprio painel: nada fecha sem passar por aqui.
struct CloseDialog: View {
    let target: CloseTarget
    let confirmation: Confirmation
    let isClosing: Bool
    let onCancel: () -> Void
    let onConfirm: () -> Void

    private var needsAccessibility: Bool {
        if case .vscodeWindow = target { return !AccessibilityWindows.isTrusted }
        return false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if needsAccessibility {
                accessibilityExplanation
            } else {
                HStack(alignment: .top, spacing: 8) {
                    if confirmation.severity == .strong {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
                    }
                    Text(confirmation.title).fontWeight(.semibold).fixedSize(horizontal: false, vertical: true)
                }
                Text(confirmation.message).font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    Spacer()
                    Button("Cancelar", action: onCancel).keyboardShortcut(.cancelAction)
                    Button(confirmation.severity == .strong ? "Fechar mesmo assim" : "Fechar", role: .destructive, action: onConfirm)
                        .disabled(isClosing)
                }
                if isClosing {
                    Text("Fechando…").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .padding(14)
        .frame(width: 360, alignment: .leading)
    }

    private var accessibilityExplanation: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Permissão necessária").fontWeight(.semibold)
            Text("Para fechar uma janela específica do VS Code, o MemoRadar precisa da permissão de Acessibilidade. Ela só é usada para ler os títulos das janelas do VS Code e acionar o botão de fechar. O resto do app funciona sem ela.")
                .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button("Agora não", action: onCancel)
                Button("Abrir Ajustes") { AccessibilityWindows.openSettings() }
            }
        }
    }
}

/// Botão pequeno de fechar usado nas linhas do painel.
struct CloseRowButton: View {
    var title = "Fechar"
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .controlSize(.mini)
    }
}

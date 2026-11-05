import SwiftUI

struct SettingsView: View {
    @Bindable var settings: AppSettings
    let onBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button(action: onBack) { Label("Voltar", systemImage: "chevron.left") }
                    .buttonStyle(.plain)
                Spacer()
                Text("Configurações").fontWeight(.semibold)
            }
            Divider()
            Stepper(value: $settings.forgottenThresholdHours, in: 1...72) {
                Text("Considerar esquecido após \(settings.forgottenThresholdHours) h parado")
            }
            Toggle("Avisar com notificação", isOn: $settings.notificationsEnabled)
            Toggle("Abrir ao iniciar sessão no Mac", isOn: $settings.launchAtLogin)
            if let error = settings.launchAtLoginError {
                Text(error).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(14)
    }
}

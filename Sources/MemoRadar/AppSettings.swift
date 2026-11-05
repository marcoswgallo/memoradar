import Foundation
import Observation
import ServiceManagement

@MainActor @Observable
final class AppSettings {
    private enum Key {
        static let threshold = "forgottenThresholdHours"
        static let notifications = "notificationsEnabled"
    }

    private let defaults = UserDefaults.standard

    var forgottenThresholdHours: Int {
        didSet { defaults.set(forgottenThresholdHours, forKey: Key.threshold) }
    }

    var notificationsEnabled: Bool {
        didSet { defaults.set(notificationsEnabled, forKey: Key.notifications) }
    }

    /// Mensagem do último erro ao ligar ou desligar a abertura automática.
    private(set) var launchAtLoginError: String?

    var launchAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do {
                if newValue {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
                launchAtLoginError = nil
            } catch {
                launchAtLoginError = "Não foi possível alterar. Mova o app para a pasta Aplicativos e tente de novo."
            }
        }
    }

    var threshold: TimeInterval { TimeInterval(forgottenThresholdHours) * 3600 }

    init() {
        forgottenThresholdHours = defaults.object(forKey: Key.threshold) as? Int ?? 4
        notificationsEnabled = defaults.object(forKey: Key.notifications) as? Bool ?? true
    }
}

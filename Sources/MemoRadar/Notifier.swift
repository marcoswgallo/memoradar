import Foundation
import UserNotifications

/// Sem permissão de notificação, o app segue normalmente: o destaque e a cor continuam.
@MainActor
final class Notifier {
    private var center: UNUserNotificationCenter? {
        // Fora de um .app, esta API encerra o processo.
        Bundle.main.bundleIdentifier == nil ? nil : .current()
    }

    func requestPermission() async {
        _ = try? await center?.requestAuthorization(options: [.alert, .sound])
    }

    func notifyForgotten(folderName: String, idleFor: String) {
        guard let center else { return }
        let content = UNMutableNotificationContent()
        content.title = "\(folderName) parece esquecido"
        content.body = "O Claude Code está parado há \(idleFor) neste projeto. Abra o MemoRadar para ver quanto dá para liberar."
        center.add(UNNotificationRequest(identifier: "esquecido-\(folderName)-\(UUID().uuidString)", content: content, trigger: nil))
    }
}

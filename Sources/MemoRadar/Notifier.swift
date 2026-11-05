import Foundation
import MemoRadarCore

/// Usa o AppleScript porque a API oficial recusa apps sem certificado pago da Apple.
/// Se o aviso falhar, o destaque no painel e a cor do ícone continuam.
@MainActor
final class Notifier {
    func notifyForgotten(folderName: String, idleFor: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: NotificationScript.executablePath)
        process.arguments = NotificationScript.arguments(folderName: folderName, idleFor: idleFor)
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
    }
}

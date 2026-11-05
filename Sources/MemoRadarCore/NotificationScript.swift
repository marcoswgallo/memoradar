/// Argumentos do `osascript` para o aviso de projeto esquecido. O nome da pasta pode conter
/// qualquer coisa, por isso só entra como argumento, nunca no texto do script.
public enum NotificationScript {
    public static let executablePath = "/usr/bin/osascript"

    public static func arguments(folderName: String, idleFor: String) -> [String] {
        [
            "-e", "on run argv",
            "-e", "display notification (item 2 of argv) with title (item 1 of argv)",
            "-e", "end run",
            "--",
            "MemoRadar: \(folderName) parece esquecido",
            "O Claude Code está parado há \(idleFor) neste projeto. Abra o MemoRadar para ver quanto dá para liberar.",
        ]
    }
}

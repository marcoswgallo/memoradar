import Foundation

public enum WindowMatch: Sendable, Equatable {
    case unique(Int), none, ambiguous
}

/// Liga uma pasta a uma janela pelo título. O VS Code mostra o nome da pasta, e não o
/// caminho, então duas pastas com o mesmo nome nunca são resolvidas por palpite.
public enum WindowMatcher {
    /// `hostCount` é o número de janelas conhecidas pelos processos. Com menos títulos do
    /// que isso, alguma janela está invisível e pode ser homônima: não dá para ter certeza.
    public static func match(
        folder: String, siblingFolders: [String], titles: [String], hostCount: Int = 0
    ) -> WindowMatch {
        if titles.count < hostCount { return .ambiguous }
        let name = URL(fileURLWithPath: folder).lastPathComponent
        let hasHomonym = siblingFolders.contains {
            $0 != folder && URL(fileURLWithPath: $0).lastPathComponent == name
        }
        if hasHomonym { return .ambiguous }

        let matches = titles.indices.filter { rootName(of: titles[$0]) == name }
        switch matches.count {
        case 0: return .none
        case 1: return .unique(matches[0])
        default: return .ambiguous
        }
    }

    /// O título padrão é "arquivo — pasta" ou "arquivo — pasta — Visual Studio Code". A pasta é
    /// o último componente, para um arquivo com o nome de uma pasta não ser confundido com ela.
    private static func rootName(of title: String) -> String? {
        let parts = title.replacingOccurrences(of: " - ", with: " — ")
            .components(separatedBy: " — ")
            .map { $0.replacingOccurrences(of: "●", with: "").trimmingCharacters(in: .whitespaces) }
        return parts.last { $0 != "Visual Studio Code" }
    }
}

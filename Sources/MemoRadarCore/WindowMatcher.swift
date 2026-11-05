import Foundation

public enum WindowMatch: Sendable, Equatable {
    case unique(Int), none, ambiguous
}

/// Liga uma pasta a uma janela pelo título. O VS Code mostra o nome da pasta, e não o
/// caminho, então duas pastas com o mesmo nome nunca são resolvidas por palpite.
public enum WindowMatcher {
    public static func match(folder: String, siblingFolders: [String], titles: [String]) -> WindowMatch {
        let name = URL(fileURLWithPath: folder).lastPathComponent
        let hasHomonym = siblingFolders.contains {
            $0 != folder && URL(fileURLWithPath: $0).lastPathComponent == name
        }
        if hasHomonym { return .ambiguous }

        let matches = titles.indices.filter { components(of: titles[$0]).contains(name) }
        switch matches.count {
        case 0: return .none
        case 1: return .unique(matches[0])
        default: return .ambiguous
        }
    }

    private static func components(of title: String) -> [String] {
        title.replacingOccurrences(of: " - ", with: " — ")
            .components(separatedBy: " — ")
            .map { $0.replacingOccurrences(of: "●", with: "").trimmingCharacters(in: .whitespaces) }
    }
}

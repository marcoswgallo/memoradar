import Foundation

public struct SkillUsage: Sendable, Equatable {
    public var count: Int
    public var lastUsedAt: Date?

    public init(count: Int, lastUsedAt: Date?) {
        self.count = count
        self.lastUsedAt = lastUsedAt
    }
}

public struct SkillStatus: Sendable, Equatable, Identifiable {
    public var id: String { name }
    public var name: String
    public var usage: SkillUsage?

    public init(name: String, usage: SkillUsage?) {
        self.name = name
        self.usage = usage
    }

    public var shortName: String { name.split(separator: ":").last.map(String.init) ?? name }

    public func text(usageKnown: Bool) -> String {
        usageKnown ? usageText : "uso indisponível"
    }

    /// O registro do Claude Code não é uma contagem exata, por isso "sem uso registrado".
    public var usageText: String {
        guard let usage else { return "sem uso registrado" }
        guard let date = usage.lastUsedAt else { return "\(usage.count)×" }
        let parts = Calendar(identifier: .gregorian).dateComponents([.day, .month, .year], from: date)
        let day = String(format: "%02d/%02d/%04d", parts.day ?? 0, parts.month ?? 0, parts.year ?? 0)
        return "\(usage.count)× · \(day)"
    }
}

public struct SkillGroup: Sendable, Equatable, Identifiable {
    public var id: String { title }
    public var title: String
    /// Comando para desativar. `nil` nas Skills pessoais, que não têm comando.
    public var disableCommand: String?
    public var skills: [SkillStatus]

    public init(title: String, disableCommand: String?, skills: [SkillStatus]) {
        self.title = title
        self.disableCommand = disableCommand
        self.skills = skills.sorted {
            ($0.usage == nil) != ($1.usage == nil) ? $0.usage == nil : $0.name < $1.name
        }
    }

    public var unusedCount: Int { skills.filter { $0.usage == nil }.count }

    public func summary(usageKnown: Bool) -> String {
        guard usageKnown else { return skills.count == 1 ? "1 Skill" : "\(skills.count) Skills" }
        return "\(unusedCount) de \(skills.count) sem uso"
    }
}

public struct SkillReport: Sendable, Equatable {
    public var groups: [SkillGroup]
    /// Sem o registro de uso não dá para dizer que algo está sem uso.
    public var usageKnown: Bool

    public init(groups: [SkillGroup], usageKnown: Bool) {
        self.groups = groups.sorted {
            $0.unusedCount != $1.unusedCount ? $0.unusedCount > $1.unusedCount : $0.title < $1.title
        }
        self.usageKnown = usageKnown
    }

    public var totalCount: Int { groups.reduce(0) { $0 + $1.skills.count } }
    public var unusedCount: Int { groups.reduce(0) { $0 + $1.unusedCount } }

    public var summary: String {
        guard usageKnown else { return "\(totalCount) Skills. Uso indisponível" }
        return "\(unusedCount) de \(totalCount) sem uso registrado"
    }
}

public enum SkillUsageReader {
    /// Lê só o campo `skillUsage`. O resto do arquivo é descartado aqui mesmo.
    /// `nil` significa que o uso é desconhecido; vazio significa que não há uso registrado.
    public static func parse(claudeJSON data: Data) -> [String: SkillUsage]? {
        guard let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let entries = object["skillUsage"] as? [String: Any]
        else { return nil }
        var result: [String: SkillUsage] = [:]
        for (name, value) in entries {
            guard let entry = value as? [String: Any] else { continue }
            result[name] = SkillUsage(
                count: entry["usageCount"] as? Int ?? 0,
                lastUsedAt: (entry["lastUsedAt"] as? Double).map { Date(timeIntervalSince1970: $0 / 1000) }
            )
        }
        return result
    }
}

/// Monta o relatório. Só lista pastas de Skills, sem abrir os arquivos delas, e dos arquivos de
/// configuração usa apenas `skillUsage` e `enabledPlugins`. Skills de projeto ficam de fora.
public enum SkillScanner {
    public static func load(home: URL) -> SkillReport {
        let claude = home.appendingPathComponent(".claude")
        let usage = (try? Data(contentsOf: home.appendingPathComponent(".claude.json")))
            .flatMap(SkillUsageReader.parse(claudeJSON:))

        var groups: [SkillGroup] = []
        for (pluginId, installPath) in enabledPlugins(claude: claude) {
            let plugin = pluginId.split(separator: "@").first.map(String.init) ?? pluginId
            let names = skillFolders(in: URL(fileURLWithPath: installPath).appendingPathComponent("skills"))
            guard !names.isEmpty else { continue }
            let skills = names.map { name -> SkillStatus in
                let full = "\(plugin):\(name)"
                return SkillStatus(name: full, usage: usage?[full])
            }
            groups.append(SkillGroup(title: plugin, disableCommand: "claude plugin disable \(pluginId)", skills: skills))
        }

        let personal = skillFolders(in: claude.appendingPathComponent("skills"))
            .map { SkillStatus(name: $0, usage: usage?[$0]) }
        if !personal.isEmpty {
            groups.append(SkillGroup(title: "Pessoais", disableCommand: nil, skills: personal))
        }
        return SkillReport(groups: groups, usageKnown: usage != nil)
    }

    private static func enabledPlugins(claude: URL) -> [(id: String, path: String)] {
        guard let settings = jsonObject(claude.appendingPathComponent("settings.json")),
              let enabled = settings["enabledPlugins"] as? [String: Any],
              let installed = jsonObject(claude.appendingPathComponent("plugins/installed_plugins.json")),
              let plugins = installed["plugins"] as? [String: Any]
        else { return [] }
        return enabled.compactMap { id, value -> (id: String, path: String)? in
            guard value as? Bool == true, let entries = plugins[id] as? [[String: Any]],
                  let entry = entries.first(where: { $0["scope"] as? String == "user" }),
                  let path = entry["installPath"] as? String
            else { return nil }
            return (id, path)
        }
    }

    private static func skillFolders(in directory: URL) -> [String] {
        let manager = FileManager.default
        guard let names = try? manager.contentsOfDirectory(atPath: directory.path) else { return [] }
        return names.filter {
            manager.fileExists(atPath: directory.appendingPathComponent($0).appendingPathComponent("SKILL.md").path)
        }
    }

    private static func jsonObject(_ url: URL) -> [String: Any]? {
        (try? Data(contentsOf: url)).flatMap { (try? JSONSerialization.jsonObject(with: $0)) as? [String: Any] }
    }
}

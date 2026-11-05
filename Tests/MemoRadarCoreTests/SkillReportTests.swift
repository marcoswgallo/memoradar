import Foundation
import Testing
@testable import MemoRadarCore

private func tempHome() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: url.appendingPathComponent(".claude/plugins"), withIntermediateDirectories: true)
    return url
}

private func write(_ text: String, _ path: String, in home: URL) throws {
    let url = home.appendingPathComponent(path)
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data(text.utf8).write(to: url)
}

private func addSkill(_ name: String, at folder: String, in home: URL) throws {
    try write("---\nname: \(name)\n---\n", "\(folder)/\(name)/SKILL.md", in: home)
}

/// Um plugin ativo (`alfa`, 2 skills), um inativo (`beta`), uma skill pessoal e uso de uma delas.
private func fullHome() throws -> URL {
    let home = try tempHome()
    let root = home.path
    try write(#"{"oauthAccount":{"email":"segredo@exemplo.com"},"skillUsage":{"alfa:um":{"usageCount":3,"lastUsedAt":1700000000000}}}"#, ".claude.json", in: home)
    try write(#"{"apiKeyHelper":"segredo-config","enabledPlugins":{"alfa@loja":true,"beta@loja":false}}"#, ".claude/settings.json", in: home)
    try write(#"{"version":2,"plugins":{"alfa@loja":[{"scope":"user","installPath":"\#(root)/p/alfa"}],"beta@loja":[{"scope":"user","installPath":"\#(root)/p/beta"}]}}"#, ".claude/plugins/installed_plugins.json", in: home)
    try addSkill("um", at: "p/alfa/skills", in: home)
    try addSkill("dois", at: "p/alfa/skills", in: home)
    try addSkill("tres", at: "p/beta/skills", in: home)
    try addSkill("minha", at: ".claude/skills", in: home)
    return home
}

@Suite struct SkillUsageReaderTests {
    @Test func readsCountAndDate() throws {
        let usage = try #require(SkillUsageReader.parse(claudeJSON: Data(#"{"skillUsage":{"a:b":{"usageCount":3,"lastUsedAt":1700000000000}}}"#.utf8)))
        #expect(usage["a:b"] == SkillUsage(count: 3, lastUsedAt: Date(timeIntervalSince1970: 1_700_000_000)))
    }

    @Test func missingKeyIsUnknownNotEmpty() {
        #expect(SkillUsageReader.parse(claudeJSON: Data(#"{"outro":1}"#.utf8)) == nil)
    }

    @Test func invalidJSONIsUnknown() {
        #expect(SkillUsageReader.parse(claudeJSON: Data("{oops".utf8)) == nil)
    }

    @Test func emptyKeyMeansKnownWithNoUse() {
        #expect(SkillUsageReader.parse(claudeJSON: Data(#"{"skillUsage":{}}"#.utf8))?.isEmpty == true)
    }

    @Test func oddEntryFieldsDoNotFail() throws {
        let usage = try #require(SkillUsageReader.parse(claudeJSON: Data(#"{"skillUsage":{"a":{"usageCount":"x"},"b":5}}"#.utf8)))
        #expect(usage["a"] == SkillUsage(count: 0, lastUsedAt: nil))
        #expect(usage["b"] == nil)
    }
}

@Suite struct SkillScannerTests {
    @Test func listsEnabledPluginsAndPersonalSkills() throws {
        let report = SkillScanner.load(home: try fullHome())
        #expect(Set(report.groups.map(\.title)) == ["alfa", "Pessoais"])
        #expect(report.totalCount == 3)
    }

    @Test func disabledPluginIsNotCounted() throws {
        let report = SkillScanner.load(home: try fullHome())
        #expect(!report.groups.flatMap(\.skills).map(\.name).contains("beta:tres"))
    }

    @Test func skillNamesUseThePluginPrefix() throws {
        let report = SkillScanner.load(home: try fullHome())
        let alfa = try #require(report.groups.first { $0.title == "alfa" })
        #expect(Set(alfa.skills.map(\.name)) == ["alfa:um", "alfa:dois"])
    }

    @Test func usageIsMatchedByFullName() throws {
        let report = SkillScanner.load(home: try fullHome())
        let alfa = try #require(report.groups.first { $0.title == "alfa" })
        #expect(alfa.skills.first { $0.name == "alfa:um" }?.usage?.count == 3)
        #expect(alfa.skills.first { $0.name == "alfa:dois" }?.usage == nil)
        #expect(alfa.unusedCount == 1)
    }

    @Test func pluginGroupTeachesTheExactCommand() throws {
        let report = SkillScanner.load(home: try fullHome())
        let alfa = try #require(report.groups.first { $0.title == "alfa" })
        #expect(alfa.disableCommand == "claude plugin disable alfa@loja")
        #expect(report.groups.first { $0.title == "Pessoais" }?.disableCommand == nil)
    }

    @Test func folderWithoutSkillFileIsIgnored() throws {
        let home = try fullHome()
        try FileManager.default.createDirectory(at: home.appendingPathComponent(".claude/skills/vazia"), withIntermediateDirectories: true)
        let report = SkillScanner.load(home: home)
        #expect(!report.groups.flatMap(\.skills).map(\.name).contains("vazia"))
    }

    @Test func projectScopedPluginIsNotCounted() throws {
        let home = try fullHome()
        try write(#"{"version":2,"plugins":{"alfa@loja":[{"scope":"project","installPath":"\#(home.path)/p/alfa"}]}}"#, ".claude/plugins/installed_plugins.json", in: home)
        #expect(SkillScanner.load(home: home).groups.map(\.title) == ["Pessoais"])
    }

    @Test func macWithoutClaudeCodeIsEmpty() {
        let report = SkillScanner.load(home: URL(fileURLWithPath: "/tmp/nao-existe-\(UUID().uuidString)"))
        #expect(report.groups.isEmpty)
        #expect(report.totalCount == 0)
    }

    @Test func unreadableUsageNeverClaimsUnused() throws {
        let home = try fullHome()
        try write("{oops", ".claude.json", in: home)
        let report = SkillScanner.load(home: home)
        #expect(!report.usageKnown)
        #expect(report.summary == "3 Skills. Uso indisponível")
        #expect(report.groups.first { $0.title == "alfa" }?.summary(usageKnown: false) == "2 Skills")
    }

    @Test func invalidSettingsStillListsPersonalSkills() throws {
        let home = try fullHome()
        try write("{oops", ".claude/settings.json", in: home)
        #expect(SkillScanner.load(home: home).groups.map(\.title) == ["Pessoais"])
    }

    @Test func otherConfigurationValuesNeverReachTheReport() throws {
        let description = String(describing: SkillScanner.load(home: try fullHome()))
        #expect(!description.contains("segredo"))
    }
}

@Suite struct SkillReportTests {
    private func skill(_ name: String, used: Bool = false) -> SkillStatus {
        SkillStatus(name: name, usage: used ? SkillUsage(count: 1, lastUsedAt: nil) : nil)
    }

    @Test func summaryUsesHonestWording() {
        let group = SkillGroup(title: "alfa", disableCommand: nil, skills: [skill("a"), skill("b", used: true)])
        let report = SkillReport(groups: [group], usageKnown: true)
        #expect(report.summary == "1 de 2 sem uso registrado")
        #expect(group.summary(usageKnown: true) == "1 de 2 sem uso")
    }

    @Test func groupsWithMostUnusedComeFirst() {
        let few = SkillGroup(title: "poucas", disableCommand: nil, skills: [skill("a")])
        let many = SkillGroup(title: "muitas", disableCommand: nil, skills: [skill("b"), skill("c")])
        #expect(SkillReport(groups: [few, many], usageKnown: true).groups.map(\.title) == ["muitas", "poucas"])
    }

    @Test func unusedSkillsAppearBeforeUsedOnes() {
        let group = SkillGroup(title: "alfa", disableCommand: nil, skills: [skill("z", used: true), skill("a")])
        #expect(group.skills.map(\.name) == ["a", "z"])
    }

    @Test func unknownUsageNeverSaysUnused() {
        #expect(SkillStatus(name: "a", usage: nil).text(usageKnown: false) == "uso indisponível")
        #expect(SkillStatus(name: "a", usage: nil).text(usageKnown: true) == "sem uso registrado")
    }

    @Test func shortNameDropsThePluginPrefix() {
        #expect(SkillStatus(name: "alfa:um", usage: nil).shortName == "um")
        #expect(SkillStatus(name: "minha", usage: nil).shortName == "minha")
    }

    @Test func usageTextShowsCountAndDate() {
        let date = DateComponents(calendar: Calendar(identifier: .gregorian), timeZone: .current, year: 2026, month: 10, day: 2, hour: 12).date!
        #expect(SkillStatus(name: "a", usage: SkillUsage(count: 12, lastUsedAt: date)).usageText == "12× · 02/10/2026")
        #expect(SkillStatus(name: "a", usage: SkillUsage(count: 1, lastUsedAt: nil)).usageText == "1×")
        #expect(SkillStatus(name: "a", usage: nil).usageText == "sem uso registrado")
    }
}

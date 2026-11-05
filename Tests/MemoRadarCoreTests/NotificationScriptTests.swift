import Testing
@testable import MemoRadarCore

@Suite struct NotificationScriptTests {
    private let malicious = #"x"; do shell script "touch /tmp/invadido"; ""#

    private func scriptPart(_ arguments: [String]) -> [String] {
        Array(arguments.prefix { $0 != "--" })
    }

    @Test func folderNameNeverEntersTheScriptText() {
        let arguments = NotificationScript.arguments(folderName: malicious, idleFor: "5 h")
        #expect(!scriptPart(arguments).joined().contains("invadido"))
        #expect(!scriptPart(arguments).joined().contains("do shell script"))
    }

    @Test func idleTextNeverEntersTheScriptText() {
        let arguments = NotificationScript.arguments(folderName: "projeto-a", idleFor: malicious)
        #expect(!scriptPart(arguments).joined().contains("invadido"))
    }

    @Test func textGoesAfterTheSeparatorAsArguments() {
        let arguments = NotificationScript.arguments(folderName: "projeto-a", idleFor: "5 h")
        let index = arguments.firstIndex(of: "--")
        #expect(index != nil)
        #expect(Array(arguments.suffix(2)) == [
            "MemoRadar: projeto-a parece esquecido",
            "O Claude Code está parado há 5 h neste projeto. Abra o MemoRadar para ver quanto dá para liberar.",
        ])
    }

    @Test func folderNameStartingWithDashStaysAfterTheSeparator() {
        let arguments = NotificationScript.arguments(folderName: "-e", idleFor: "5 h")
        #expect(scriptPart(arguments).filter { $0 == "-e" }.count == 3)
    }
}

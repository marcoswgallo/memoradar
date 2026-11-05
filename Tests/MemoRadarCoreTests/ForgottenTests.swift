import Foundation
import Testing
@testable import MemoRadarCore

private let now = Date(timeIntervalSince1970: 1_000_000)
private let fourHours: TimeInterval = 4 * 3600

private func session(_ pid: Int32 = 1, cwd: String? = "/x/projeto-a", status: SessionStatus = .idle,
                     idleFor: TimeInterval? = fourHours, entrypoint: String = "cli") -> ClaudeSession {
    ClaudeSession(pid: pid, cwd: cwd, entrypoint: entrypoint, status: status,
                  statusUpdatedAt: idleFor.map { now.addingTimeInterval(-$0) })
}

private func folders(_ sessions: [ClaudeSession]) -> Set<String> {
    Forgotten.folders(sessions: sessions, now: now, threshold: Forgotten.defaultThreshold)
}

@Suite struct ForgottenTests {
    @Test func defaultIsFourHours() { #expect(Forgotten.defaultThreshold == fourHours) }

    @Test func idleExactlyFourHoursIsForgotten() {
        #expect(folders([session()]) == ["/x/projeto-a"])
    }

    @Test func idleJustUnderFourHoursIsNot() {
        #expect(folders([session(idleFor: fourHours - 1)]).isEmpty)
    }

    @Test func oneBusySessionProtectsFolder() {
        #expect(folders([session(1), session(2, status: .busy)]).isEmpty)
    }

    @Test func oneRecentSessionProtectsFolder() {
        #expect(folders([session(1), session(2, idleFor: 60)]).isEmpty)
    }

    @Test func unknownStatusNeverForgotten() {
        #expect(folders([session(status: .unknown, idleFor: 36000)]).isEmpty)
        #expect(folders([session(1, idleFor: 36000), session(2, status: .unknown, idleFor: 36000)]).isEmpty)
    }

    @Test func missingTimestampNeverForgotten() {
        #expect(folders([session(idleFor: nil)]).isEmpty)
    }

    @Test func terminalAndVSCodeInSameFolderCombine() {
        let result = folders([session(1, entrypoint: "cli"), session(2, entrypoint: "claude-vscode")])
        #expect(result == ["/x/projeto-a"])
    }

    @Test func sessionWithoutCwdIgnored() {
        #expect(folders([session(cwd: nil), session(cwd: "/")]).isEmpty)
    }

    @Test func customThresholdIsRespected() {
        let result = Forgotten.folders(sessions: [session(idleFor: 3600)], now: now, threshold: 3600)
        #expect(result == ["/x/projeto-a"])
    }

    @Test func ledgerNotifiesOnce() {
        var ledger = NotificationLedger()
        #expect(ledger.update(forgotten: ["a"]) == ["a"])
        #expect(ledger.update(forgotten: ["a"]).isEmpty)
    }

    @Test func ledgerRenotifiesAfterActivity() {
        var ledger = NotificationLedger()
        #expect(ledger.update(forgotten: ["a"]) == ["a"])
        #expect(ledger.update(forgotten: []).isEmpty)
        #expect(ledger.update(forgotten: ["a"]) == ["a"])
    }
}

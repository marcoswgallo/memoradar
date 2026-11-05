import Foundation
import Testing
@testable import MemoRadarCore

private let clicked = Date(timeIntervalSince1970: 1000)
private let system = SystemMemory(totalBytes: 1, appBytes: 0, wiredBytes: 0, compressedBytes: 0, swapUsedBytes: 0, pressure: .normal)

private func proc(_ pid: Int32, parent: Int32 = 1, start: Date = clicked, exe: String = "/x/app", bytes: UInt64 = 1) -> ProcessSnapshot {
    ProcessSnapshot(pid: pid, ppid: parent, startTime: start, footprintBytes: bytes, executablePath: exe)
}

private func dashboard(_ processes: [ProcessSnapshot]) -> Dashboard {
    Dashboard.build(processes: processes, sessions: [], system: system, now: clicked, threshold: 14400)
}

@Suite struct PendingCloseTests {
    @Test func identitiesComeFromDashboardAtClick() {
        let pending = PendingClose(target: .app(name: "Foo", pids: [5], bytes: 1), dashboard: dashboard([proc(5)]))
        #expect(pending.identities == [ProcessIdentity(pid: 5, startTime: clicked)])
    }

    @Test func processSwappedAfterClickIsNotSignalable() {
        let pending = PendingClose(target: .app(name: "Foo", pids: [5], bytes: 1), dashboard: dashboard([proc(5)]))
        let swapped = proc(5, start: clicked.addingTimeInterval(2))
        #expect(ProcessTerminator.signalablePids(pending.identities, current: [swapped]).isEmpty)
    }

    @Test func windowIdentityIsTheHost() {
        let project = VSCodeProject(hostPid: 10, displayName: "projeto-a", openSince: clicked)
        let pending = PendingClose(target: .vscodeWindow(project), dashboard: dashboard([proc(10), proc(11)]))
        #expect(pending.identities.map(\.pid) == [10])
    }

    @Test func terminalSessionIdentityIsTheSession() {
        let target = CloseTarget.terminalSession(ClaudeSession(pid: 20), bytes: 1)
        #expect(PendingClose(target: target, dashboard: dashboard([proc(20), proc(21)])).identities.map(\.pid) == [20])
    }

    @Test func mcpIdentitiesIncludeWrapperAndChild() {
        let copy = McpCopy(serverName: "srv", sessionPid: 1, rootPid: 30, pids: [30, 31], bytes: 2)
        let pending = PendingClose(target: .mcpCopy(copy), dashboard: dashboard([proc(30), proc(31), proc(32)]))
        #expect(Set(pending.identities.map(\.pid)) == [30, 31])
    }

    @Test func mcpServerIdentitiesCoverAllCopies() {
        let copies = [
            McpCopy(serverName: "srv", sessionPid: 1, rootPid: 30, pids: [30], bytes: 1),
            McpCopy(serverName: "srv", sessionPid: 2, rootPid: 40, pids: [40], bytes: 1),
        ]
        let pending = PendingClose(target: .mcpServer(name: "srv", copies: copies), dashboard: dashboard([proc(30), proc(40)]))
        #expect(Set(pending.identities.map(\.pid)) == [30, 40])
    }

    @Test func mainAppCandidatesAreRootsOldestFirst() {
        let processes = [
            proc(70, parent: 60, start: clicked.addingTimeInterval(5)),
            proc(60, start: clicked.addingTimeInterval(1)),
            proc(50, start: clicked),
            proc(51, parent: 50, start: clicked.addingTimeInterval(9)),
        ]
        let pending = PendingClose(target: .app(name: "Foo", pids: [70, 60, 50, 51], bytes: 1), dashboard: dashboard(processes))
        #expect(pending.mainAppCandidates == [50, 60])
    }
}

@Suite struct TopProcessesTests {
    @Test func sortedByMemoryAndLimited() {
        let board = dashboard([
            proc(1, exe: "/A.app/Contents/MacOS/Pequeno", bytes: 5),
            proc(2, exe: "/A.app/Contents/MacOS/Grande", bytes: 50),
            proc(3, exe: "/A.app/Contents/MacOS/Medio", bytes: 20),
        ])
        let top = board.topProcesses(pids: [1, 2, 3], limit: 2)
        #expect(top.map(\.name) == ["Grande", "Medio"])
        #expect(top.map(\.bytes) == [50, 20])
    }

    @Test func ignoresPidsOutsideTheRow() {
        let board = dashboard([proc(1, exe: "/a"), proc(2, exe: "/b")])
        #expect(board.topProcesses(pids: [2], limit: 5).map(\.pid) == [2])
    }

    @Test func goneProcessIsSkipped() {
        #expect(dashboard([]).topProcesses(pids: [9], limit: 5).isEmpty)
    }
}

import Foundation
import Testing
@testable import MemoRadarCore

private func spawn(_ path: String, _ args: [String]) throws -> Process {
    let child = Process()
    child.executableURL = URL(fileURLWithPath: path)
    child.arguments = args
    try child.run()
    return child
}

private func identity(of child: Process) throws -> ProcessIdentity {
    let snapshot = try #require(ProcessSampler.sample().first { $0.pid == child.processIdentifier })
    return ProcessIdentity(pid: snapshot.pid, startTime: snapshot.startTime)
}

@Suite(.serialized) struct ProcessTerminatorTests {
    @Test func terminatesLiveProcess() async throws {
        let child = try spawn("/bin/sleep", ["30"])
        let target = try identity(of: child)
        let outcome = await ProcessTerminator.terminate([target], timeout: 3)
        #expect(outcome == .closed)
        child.waitUntilExit()
        #expect(child.terminationReason == .uncaughtSignal)
        #expect(child.terminationStatus == SIGTERM)
    }

    @Test func reusedPidIsNotSignaled() async throws {
        let child = try spawn("/bin/sleep", ["30"])
        defer { child.terminate() }
        let real = try identity(of: child)
        let stale = ProcessIdentity(pid: real.pid, startTime: real.startTime.addingTimeInterval(-100))
        let outcome = await ProcessTerminator.terminate([stale], timeout: 0.3)
        if case .failed = outcome {} else { Issue.record("esperava .failed, veio \(outcome)") }
        #expect(child.isRunning)
    }

    @Test func goneProcessIsReportedAsFailed() async {
        let gone = ProcessIdentity(pid: Int32.max - 1, startTime: Date())
        let outcome = await ProcessTerminator.terminate([gone], timeout: 0.2)
        if case .failed = outcome {} else { Issue.record("esperava .failed, veio \(outcome)") }
    }

    @Test func processIgnoringTermIsStillOpen() async throws {
        let child = try spawn("/bin/sh", ["-c", "trap '' TERM; while :; do sleep 1; done"])
        defer { kill(child.processIdentifier, SIGKILL) }
        try await Task.sleep(for: .milliseconds(200))
        let outcome = await ProcessTerminator.terminate([try identity(of: child)], timeout: 0.5)
        #expect(outcome == .stillOpen)
        #expect(child.isRunning)
    }

    @Test func emptyListIsFailedNotClosed() async {
        let outcome = await ProcessTerminator.terminate([], timeout: 0.1)
        if case .failed = outcome {} else { Issue.record("esperava .failed, veio \(outcome)") }
    }

    @Test func otherProcessesKeepRunning() async throws {
        let target = try spawn("/bin/sleep", ["30"])
        let bystander = try spawn("/bin/sleep", ["30"])
        defer { bystander.terminate() }
        _ = await ProcessTerminator.terminate([try identity(of: target)], timeout: 3)
        #expect(bystander.isRunning)
    }

    @Test func onlyLiveMatchingPidsAreSelected() {
        let start = Date(timeIntervalSince1970: 1000)
        let current = [ProcessSnapshot(pid: 5, ppid: 1, startTime: start, footprintBytes: 1, executablePath: "/x")]
        let selected = ProcessTerminator.signalablePids(
            [ProcessIdentity(pid: 5, startTime: start), ProcessIdentity(pid: 6, startTime: start)], current: current)
        #expect(selected == [5])
    }
}

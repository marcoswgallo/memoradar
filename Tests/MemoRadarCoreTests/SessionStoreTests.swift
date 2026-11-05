import Foundation
import Testing
@testable import MemoRadarCore

private func tempDir() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func process(pid: Int32, startedAt: Date) -> ProcessSnapshot {
    ProcessSnapshot(pid: pid, ppid: 1, startTime: startedAt, footprintBytes: 1, executablePath: "/bin/x")
}

private let sessionJSON = #"""
{"pid":123,"cwd":"/tmp/projeto-a","entrypoint":"cli","status":"busy",
 "startedAt":1700000000000,"statusUpdatedAt":1700000000000}
"""#

@Suite struct SessionStoreTests {
    @Test func parsesBusySession() throws {
        let s = try #require(SessionStore.parse(fileName: "123.json", data: Data(sessionJSON.utf8)))
        #expect(s.pid == 123)
        #expect(s.status == .busy)
        #expect(s.cwd == "/tmp/projeto-a")
        #expect(s.entrypoint == "cli")
        #expect(s.statusUpdatedAt == Date(timeIntervalSince1970: 1_700_000_000))
        #expect(s.startedAt == Date(timeIntervalSince1970: 1_700_000_000))
    }

    @Test func parsesIdleSession() throws {
        let s = try #require(SessionStore.parse(fileName: "7.json", data: Data(#"{"status":"idle"}"#.utf8)))
        #expect(s.status == .idle)
    }

    @Test func unknownStatusValueBecomesUnknown() throws {
        let s = try #require(SessionStore.parse(fileName: "123.json", data: Data(#"{"status":"waiting"}"#.utf8)))
        #expect(s.status == .unknown)
    }

    @Test func missingStatusBecomesUnknown() throws {
        let s = try #require(SessionStore.parse(fileName: "123.json", data: Data(#"{"cwd":"/tmp/a"}"#.utf8)))
        #expect(s.status == .unknown)
        #expect(s.cwd == "/tmp/a")
    }

    @Test func wrongFieldTypesDoNotFail() throws {
        let s = try #require(SessionStore.parse(fileName: "123.json", data: Data(#"{"status":5,"cwd":1,"statusUpdatedAt":"x"}"#.utf8)))
        #expect(s.status == .unknown)
        #expect(s.cwd == nil)
        #expect(s.statusUpdatedAt == nil)
    }

    @Test func invalidJSONStillYieldsUnknownSession() throws {
        let s = try #require(SessionStore.parse(fileName: "123.json", data: Data("{oops".utf8)))
        #expect(s.pid == 123)
        #expect(s.status == .unknown)
    }

    @Test func nonPidFileNameIsIgnored() {
        #expect(SessionStore.parse(fileName: "abc.json", data: Data("{}".utf8)) == nil)
        #expect(SessionStore.parse(fileName: "123.abc.key", data: Data("{}".utf8)) == nil)
        #expect(SessionStore.parse(fileName: "12.3.json", data: Data("{}".utf8)) == nil)
    }

    @Test func loadIgnoresKeyFiles() throws {
        let dir = try tempDir()
        try Data("{oops".utf8).write(to: dir.appendingPathComponent("123.abc.key"))
        let found = SessionStore.load(directory: dir, processes: [process(pid: 123, startedAt: .distantPast)])
        #expect(found.isEmpty)
    }

    @Test func loadDropsDeadPid() throws {
        let dir = try tempDir()
        try Data(sessionJSON.utf8).write(to: dir.appendingPathComponent("123.json"))
        #expect(SessionStore.load(directory: dir, processes: []).isEmpty)
    }

    @Test func loadDropsReusedPid() throws {
        let dir = try tempDir()
        try Data(sessionJSON.utf8).write(to: dir.appendingPathComponent("123.json"))
        let later = Date(timeIntervalSince1970: 1_700_000_060)
        #expect(SessionStore.load(directory: dir, processes: [process(pid: 123, startedAt: later)]).isEmpty)
    }

    @Test func loadKeepsMatchingProcess() throws {
        let dir = try tempDir()
        try Data(sessionJSON.utf8).write(to: dir.appendingPathComponent("123.json"))
        let earlier = Date(timeIntervalSince1970: 1_699_999_990)
        let found = SessionStore.load(directory: dir, processes: [process(pid: 123, startedAt: earlier)])
        #expect(found.map(\.pid) == [123])
    }

    @Test func loadKeepsSessionWithoutStartedAt() throws {
        let dir = try tempDir()
        try Data(#"{"status":"idle"}"#.utf8).write(to: dir.appendingPathComponent("123.json"))
        let found = SessionStore.load(directory: dir, processes: [process(pid: 123, startedAt: .now)])
        #expect(found.count == 1)
    }

    @Test func missingDirectoryReturnsEmpty() {
        let dir = URL(fileURLWithPath: "/tmp/nao-existe-\(UUID().uuidString)")
        #expect(SessionStore.load(directory: dir, processes: []).isEmpty)
    }
}

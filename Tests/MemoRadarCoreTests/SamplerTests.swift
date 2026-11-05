import Foundation
import Testing
@testable import MemoRadarCore

@Suite(.serialized) struct SamplerTests {
    @Test func samplerSeesCurrentProcess() throws {
        let me = try #require(ProcessSampler.sample().first { $0.pid == getpid() })
        #expect(me.footprintBytes > 0)
        #expect(me.startTime < Date())
        #expect(!me.executablePath.isEmpty)
        #expect(!me.arguments.isEmpty)
        #expect(me.cwd == FileManager.default.currentDirectoryPath)
    }

    @Test func samplerOnlyCurrentUser() {
        #expect(!ProcessSampler.sample().contains { $0.pid == 1 })
    }

    @Test func samplerReadsChildStdinKind() throws {
        let child = Process()
        child.executableURL = URL(fileURLWithPath: "/bin/sleep")
        child.arguments = ["30"]
        child.standardInput = Pipe()
        try child.run()
        defer { child.terminate() }
        let snapshot = try #require(ProcessSampler.sample().first { $0.pid == child.processIdentifier })
        #expect(snapshot.stdin == .pipeOrSocket)
        #expect(snapshot.ppid == getpid())
        #expect(snapshot.arguments == ["/bin/sleep", "30"])
    }

    @Test func samplerSurvivesProcessExit() async throws {
        let spawner = Task.detached {
            for _ in 0..<50 {
                let child = Process()
                child.executableURL = URL(fileURLWithPath: "/usr/bin/true")
                try? child.run()
            }
        }
        for _ in 0..<5 { _ = ProcessSampler.sample() }
        await spawner.value
    }

    @Test func systemMemoryIsPlausible() {
        let memory = SystemSampler.sample()
        #expect(memory.totalBytes > 0)
        #expect(memory.appBytes > 0)
        #expect(memory.wiredBytes > 0)
        #expect(memory.usedBytes <= memory.totalBytes)
        #expect(memory.pressure != .unknown)
    }
}

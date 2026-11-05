import Testing
@testable import MemoRadarCore

@Test func smoke() {
    #expect(SessionStatus.idle != .busy)
}

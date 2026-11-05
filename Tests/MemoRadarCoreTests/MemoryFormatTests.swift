import Testing
@testable import MemoRadarCore

@Suite struct MemoryFormatTests {
    @Test func formatsGbWithComma() { #expect(MemoryFormat.bytes(3_758_096_384) == "3,5 GB") }
    @Test func formatsWholeGb() { #expect(MemoryFormat.bytes(2_147_483_648) == "2,0 GB") }
    @Test func formatsMbUnderOneGb() { #expect(MemoryFormat.bytes(340 * 1024 * 1024) == "340 MB") }
    @Test func formatsZero() { #expect(MemoryFormat.bytes(0) == "0 MB") }

    @Test func formatsDurations() {
        #expect(MemoryFormat.duration(30) == "menos de 1 min")
        #expect(MemoryFormat.duration(360) == "6 min")
        #expect(MemoryFormat.duration(18000) == "5 h")
        #expect(MemoryFormat.duration(129_600) == "36 h")
        #expect(MemoryFormat.duration(172_800) == "2 dias")
        #expect(MemoryFormat.duration(302_400) == "3,5 dias")
    }

    @Test func negativeDurationDoesNotBreak() {
        #expect(MemoryFormat.duration(-5) == "menos de 1 min")
    }
}

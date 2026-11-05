import Testing
@testable import MemoRadarCore

private let gb: Double = 1_073_741_824

@Suite struct SystemMemoryTests {
    @Test func pressureMapping() {
        #expect(MemoryPressure(sysctlLevel: 1) == .normal)
        #expect(MemoryPressure(sysctlLevel: 2) == .warning)
        #expect(MemoryPressure(sysctlLevel: 4) == .critical)
        #expect(MemoryPressure(sysctlLevel: 7) == .unknown)
    }

    @Test func usedPercentMatchesMeasuredCase() {
        let memory = SystemMemory(
            totalBytes: UInt64(18 * gb), appBytes: UInt64(7.6 * gb), wiredBytes: UInt64(3.4 * gb),
            compressedBytes: UInt64(2.5 * gb), swapUsedBytes: 0, pressure: .normal)
        #expect(memory.usedPercent == 75)
        #expect(memory.usedBytes == UInt64(7.6 * gb) + UInt64(3.4 * gb) + UInt64(2.5 * gb))
    }

    @Test func zeroTotalDoesNotCrash() {
        let memory = SystemMemory(totalBytes: 0, appBytes: 1, wiredBytes: 0, compressedBytes: 0,
                                  swapUsedBytes: 0, pressure: .unknown)
        #expect(memory.usedPercent == 0)
    }
}

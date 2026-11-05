import Foundation

public enum MemoryPressure: Sendable, Equatable {
    case normal, warning, critical, unknown

    /// Valores de `kern.memorystatus_vm_pressure_level`.
    public init(sysctlLevel: Int) {
        switch sysctlLevel {
        case 1: self = .normal
        case 2: self = .warning
        case 4: self = .critical
        default: self = .unknown
        }
    }
}

public struct SystemMemory: Sendable, Equatable {
    public var totalBytes: UInt64
    public var appBytes: UInt64
    public var wiredBytes: UInt64
    public var compressedBytes: UInt64
    public var swapUsedBytes: UInt64
    public var pressure: MemoryPressure

    public init(
        totalBytes: UInt64, appBytes: UInt64, wiredBytes: UInt64, compressedBytes: UInt64,
        swapUsedBytes: UInt64, pressure: MemoryPressure
    ) {
        self.totalBytes = totalBytes
        self.appBytes = appBytes
        self.wiredBytes = wiredBytes
        self.compressedBytes = compressedBytes
        self.swapUsedBytes = swapUsedBytes
        self.pressure = pressure
    }

    public var usedBytes: UInt64 { appBytes + wiredBytes + compressedBytes }

    public var usedPercent: Int {
        guard totalBytes > 0 else { return 0 }
        return Int((Double(usedBytes) / Double(totalBytes) * 100).rounded())
    }
}

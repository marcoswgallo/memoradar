import Darwin
import Foundation

public enum SystemSampler {
    public static func sample() -> SystemMemory {
        let pageSize = UInt64(max(sysconf(_SC_PAGESIZE), 0))
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &stats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        let ok = result == KERN_SUCCESS
        let internalPages = UInt64(ok ? stats.internal_page_count : 0)
        let purgeable = UInt64(ok ? stats.purgeable_count : 0)
        return SystemMemory(
            totalBytes: sysctlValue("hw.memsize", as: UInt64.self) ?? 0,
            appBytes: (internalPages - min(internalPages, purgeable)) * pageSize,
            wiredBytes: UInt64(ok ? stats.wire_count : 0) * pageSize,
            compressedBytes: UInt64(ok ? stats.compressor_page_count : 0) * pageSize,
            swapUsedBytes: sysctlValue("vm.swapusage", as: xsw_usage.self).map { UInt64($0.xsu_used) } ?? 0,
            pressure: MemoryPressure(sysctlLevel: Int(sysctlValue("kern.memorystatus_vm_pressure_level", as: Int32.self) ?? 0))
        )
    }

    private static func sysctlValue<T>(_ name: String, as type: T.Type) -> T? {
        var size = MemoryLayout<T>.size
        let pointer = UnsafeMutablePointer<T>.allocate(capacity: 1)
        defer { pointer.deallocate() }
        guard sysctlbyname(name, pointer, &size, nil, 0) == 0, size == MemoryLayout<T>.size else { return nil }
        return pointer.move()
    }
}

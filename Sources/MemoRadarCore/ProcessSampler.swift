import Darwin
import Foundation

/// Lê os processos do usuário atual com `libproc`, sem executar comandos. Processo que
/// termina no meio da leitura é apenas pulado.
public enum ProcessSampler {
    public static func sample() -> [ProcessSnapshot] {
        let uid = getuid()
        return allPids().compactMap { snapshot(pid: $0, uid: uid) }
    }

    private static func allPids() -> [Int32] {
        let capacity = proc_listallpids(nil, 0)
        guard capacity > 0 else { return [] }
        // Espaço extra para processos criados entre as duas chamadas.
        var pids = [Int32](repeating: 0, count: Int(capacity) + 64)
        let size = Int32(pids.count * MemoryLayout<Int32>.size)
        let count = proc_listallpids(&pids, size)
        guard count > 0 else { return [] }
        return pids.prefix(Int(count)).filter { $0 > 0 }
    }

    private static func snapshot(pid: Int32, uid: uid_t) -> ProcessSnapshot? {
        var info = proc_bsdinfo()
        let infoSize = Int32(MemoryLayout<proc_bsdinfo>.size)
        guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, infoSize) == infoSize,
              info.pbi_uid == uid,
              let footprint = footprint(pid: pid),
              let path = executablePath(pid: pid)
        else { return nil }

        let start = TimeInterval(info.pbi_start_tvsec) + TimeInterval(info.pbi_start_tvusec) / 1_000_000
        return ProcessSnapshot(
            pid: pid,
            ppid: Int32(info.pbi_ppid),
            startTime: Date(timeIntervalSince1970: start),
            footprintBytes: footprint,
            executablePath: path,
            arguments: arguments(pid: pid),
            cwd: workingDirectory(pid: pid),
            stdin: stdinKind(pid: pid)
        )
    }

    private static func footprint(pid: Int32) -> UInt64? {
        var usage = rusage_info_v4()
        let result = withUnsafeMutablePointer(to: &usage) { pointer in
            pointer.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
                proc_pid_rusage(pid, RUSAGE_INFO_V4, $0)
            }
        }
        return result == 0 ? usage.ri_phys_footprint : nil
    }

    private static func executablePath(pid: Int32) -> String? {
        var buffer = [CChar](repeating: 0, count: 4 * Int(MAXPATHLEN))
        let length = proc_pidpath(pid, &buffer, UInt32(buffer.count))
        guard length > 0 else { return nil }
        return String(decoding: buffer.prefix(Int(length)).map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }

    private static func workingDirectory(pid: Int32) -> String? {
        var info = proc_vnodepathinfo()
        let size = Int32(MemoryLayout<proc_vnodepathinfo>.size)
        guard proc_pidinfo(pid, PROC_PIDVNODEPATHINFO, 0, &info, size) == size else { return nil }
        let path = withUnsafeBytes(of: &info.pvi_cdir.vip_path) { raw in
            String(cString: raw.bindMemory(to: CChar.self).baseAddress!)
        }
        return path.isEmpty ? nil : path
    }

    private static func stdinKind(pid: Int32) -> StdinKind {
        let needed = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, nil, 0)
        guard needed > 0 else { return .unknown }
        let capacity = Int(needed) / MemoryLayout<proc_fdinfo>.stride
        var descriptors = [proc_fdinfo](repeating: proc_fdinfo(), count: capacity)
        let written = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, &descriptors, needed)
        guard written > 0 else { return .unknown }
        let count = Int(written) / MemoryLayout<proc_fdinfo>.stride
        guard let stdin = descriptors.prefix(count).first(where: { $0.proc_fd == 0 }) else { return .other }
        switch Int32(stdin.proc_fdtype) {
        case PROX_FDTYPE_PIPE, PROX_FDTYPE_SOCKET: return .pipeOrSocket
        default: return .other
        }
    }

    private static func arguments(pid: Int32) -> [String] {
        var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
        var size = 0
        guard sysctl(&mib, 3, nil, &size, nil, 0) == 0, size > MemoryLayout<Int32>.size else { return [] }
        var buffer = [UInt8](repeating: 0, count: size)
        guard sysctl(&mib, 3, &buffer, &size, nil, 0) == 0, size > MemoryLayout<Int32>.size else { return [] }

        let argc = buffer.withUnsafeBytes { Int($0.loadUnaligned(as: Int32.self)) }
        var index = MemoryLayout<Int32>.size
        // Pula o caminho do executável e os zeros de alinhamento.
        while index < size, buffer[index] != 0 { index += 1 }
        while index < size, buffer[index] == 0 { index += 1 }

        var result: [String] = []
        while index < size, result.count < argc {
            let start = index
            while index < size, buffer[index] != 0 { index += 1 }
            result.append(String(decoding: buffer[start..<index], as: UTF8.self))
            index += 1
        }
        return result
    }
}

import Foundation

public struct ProcessTree: Sendable {
    private let byPid: [Int32: ProcessSnapshot]
    private let childrenByPid: [Int32: [ProcessSnapshot]]

    public init(_ processes: [ProcessSnapshot]) {
        byPid = Dictionary(processes.map { ($0.pid, $0) }, uniquingKeysWith: { first, _ in first })
        childrenByPid = Dictionary(grouping: processes.filter { $0.pid != $0.ppid }, by: \.ppid)
    }

    public func process(_ pid: Int32) -> ProcessSnapshot? { byPid[pid] }

    public func children(of pid: Int32) -> [ProcessSnapshot] { childrenByPid[pid] ?? [] }

    public func descendants(of pid: Int32) -> [ProcessSnapshot] {
        var visited: Set<Int32> = [pid]
        var result: [ProcessSnapshot] = []
        var pending = children(of: pid)
        while let next = pending.popLast() {
            guard visited.insert(next.pid).inserted else { continue }
            result.append(next)
            pending.append(contentsOf: children(of: next.pid))
        }
        return result
    }

    public func ancestors(of pid: Int32) -> [ProcessSnapshot] {
        var visited: Set<Int32> = [pid]
        var result: [ProcessSnapshot] = []
        var current = byPid[pid]?.ppid
        while let parent = current, visited.insert(parent).inserted, let process = byPid[parent] {
            result.append(process)
            current = process.ppid
        }
        return result
    }

    public func isDescendant(_ pid: Int32, of ancestor: Int32) -> Bool {
        var visited: Set<Int32> = [pid]
        var current = byPid[pid]?.ppid
        while let parent = current, visited.insert(parent).inserted {
            if parent == ancestor { return true }
            current = byPid[parent]?.ppid
        }
        return false
    }
}

import Foundation

public enum StdinKind: Sendable, Equatable {
    case pipeOrSocket, other, unknown
}

public struct ProcessSnapshot: Sendable, Equatable {
    public var pid: Int32
    public var ppid: Int32
    public var startTime: Date
    public var footprintBytes: UInt64
    public var executablePath: String
    public var arguments: [String]
    public var cwd: String?
    public var stdin: StdinKind

    public init(
        pid: Int32, ppid: Int32, startTime: Date, footprintBytes: UInt64,
        executablePath: String, arguments: [String] = [], cwd: String? = nil,
        stdin: StdinKind = .unknown
    ) {
        self.pid = pid
        self.ppid = ppid
        self.startTime = startTime
        self.footprintBytes = footprintBytes
        self.executablePath = executablePath
        self.arguments = arguments
        self.cwd = cwd
        self.stdin = stdin
    }
}

public struct ProcessIdentity: Sendable, Hashable {
    public var pid: Int32
    public var startTime: Date

    public init(pid: Int32, startTime: Date) {
        self.pid = pid
        self.startTime = startTime
    }
}

public enum SessionStatus: Sendable, Equatable {
    case idle, busy, unknown
}

public struct ClaudeSession: Sendable, Equatable {
    public var pid: Int32
    public var cwd: String?
    public var entrypoint: String?
    public var status: SessionStatus
    public var statusUpdatedAt: Date?
    public var startedAt: Date?

    public init(
        pid: Int32, cwd: String? = nil, entrypoint: String? = nil,
        status: SessionStatus = .unknown, statusUpdatedAt: Date? = nil, startedAt: Date? = nil
    ) {
        self.pid = pid
        self.cwd = cwd
        self.entrypoint = entrypoint
        self.status = status
        self.statusUpdatedAt = statusUpdatedAt
        self.startedAt = startedAt
    }
}

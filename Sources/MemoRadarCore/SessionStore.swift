import Foundation

/// Lê `~/.claude/sessions/<pid>.json`. É um formato interno do Claude Code: tudo o que
/// não for reconhecido vira "desconhecido", nunca erro. Só abre arquivos `<pid>.json`.
public enum SessionStore {
    /// Tolerância para diferença entre o início do processo e o `startedAt` da sessão.
    private static let startTolerance: TimeInterval = 5

    public static func parse(fileName: String, data: Data) -> ClaudeSession? {
        guard let pid = pid(fromFileName: fileName) else { return nil }
        guard let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return ClaudeSession(pid: pid)
        }
        return ClaudeSession(
            pid: pid,
            cwd: object["cwd"] as? String,
            entrypoint: object["entrypoint"] as? String,
            status: status(from: object["status"]),
            statusUpdatedAt: date(from: object["statusUpdatedAt"]),
            startedAt: date(from: object["startedAt"])
        )
    }

    public static func load(directory: URL, processes: [ProcessSnapshot]) -> [ClaudeSession] {
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: directory.path) else {
            return []
        }
        let processByPid = Dictionary(processes.map { ($0.pid, $0) }, uniquingKeysWith: { first, _ in first })

        return names.compactMap { name -> ClaudeSession? in
            guard let pid = pid(fromFileName: name), let process = processByPid[pid] else { return nil }
            let url = directory.appendingPathComponent(name)
            guard let data = try? Data(contentsOf: url),
                  let session = parse(fileName: name, data: data) else { return nil }
            if let startedAt = session.startedAt,
               process.startTime.timeIntervalSince(startedAt) > startTolerance {
                return nil
            }
            return session
        }
        .sorted { $0.pid < $1.pid }
    }

    private static func pid(fromFileName name: String) -> Int32? {
        guard name.hasSuffix(".json") else { return nil }
        let stem = name.dropLast(".json".count)
        guard !stem.isEmpty, stem.allSatisfy(\.isASCII), stem.allSatisfy(\.isNumber) else { return nil }
        return Int32(stem)
    }

    private static func status(from value: Any?) -> SessionStatus {
        switch value as? String {
        case "idle": .idle
        case "busy": .busy
        default: .unknown
        }
    }

    private static func date(from value: Any?) -> Date? {
        guard let milliseconds = value as? Double else { return nil }
        return Date(timeIntervalSince1970: milliseconds / 1000)
    }
}

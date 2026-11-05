import Foundation

/// Uma pasta está esquecida quando todas as suas sessões estão paradas há pelo menos
/// o limite. Sessão em estado desconhecido nunca conta como parada e protege a pasta.
public enum Forgotten {
    public static let defaultThreshold: TimeInterval = 4 * 3600

    public static func folders(sessions: [ClaudeSession], now: Date, threshold: TimeInterval) -> Set<String> {
        let byFolder = Dictionary(grouping: sessions.filter { $0.cwd != nil && $0.cwd != "/" }, by: { $0.cwd! })
        let forgotten = byFolder.filter { _, group in
            group.allSatisfy { session in
                guard session.status == .idle, let updatedAt = session.statusUpdatedAt else { return false }
                return now.timeIntervalSince(updatedAt) >= threshold
            }
        }
        return Set(forgotten.keys)
    }
}

/// Garante uma notificação por pasta a cada vez que ela vira esquecida.
public struct NotificationLedger: Sendable {
    private var notified: Set<String> = []

    public init() {}

    public mutating func update(forgotten: Set<String>) -> Set<String> {
        let new = forgotten.subtracting(notified)
        notified = forgotten
        return new
    }
}

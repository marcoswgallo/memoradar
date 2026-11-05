import Darwin
import Foundation

/// Envia `SIGTERM`, nunca `SIGKILL`, e só a processos que continuam sendo os mesmos
/// (PID e horário de início), para não atingir quem reaproveitou o PID.
public enum ProcessTerminator {
    public static func signalablePids(_ targets: [ProcessIdentity], current: [ProcessSnapshot]) -> [Int32] {
        let byPid = Dictionary(current.map { ($0.pid, $0) }, uniquingKeysWith: { first, _ in first })
        return targets.filter { ClosePolicy.isSameProcess($0, current: byPid[$0.pid]) }.map(\.pid)
    }

    public static func terminate(_ targets: [ProcessIdentity], timeout: TimeInterval = 5) async -> CloseOutcome {
        let pids = signalablePids(targets, current: ProcessSampler.sample())
        guard !pids.isEmpty else {
            return .failed("O processo já não é o mesmo. Nada foi fechado.")
        }
        for pid in pids { kill(pid, SIGTERM) }
        let stillRunning = await waitUntilGone(targets, timeout: timeout)
        return closeOutcome(stillRunningAfterWait: stillRunning, error: nil)
    }

    /// Retorna `true` se algum dos processos continuar vivo depois do tempo limite.
    public static func waitUntilGone(_ targets: [ProcessIdentity], timeout: TimeInterval) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while true {
            let alive = !signalablePids(targets, current: ProcessSampler.sample()).isEmpty
            if !alive { return false }
            if Date() >= deadline { return true }
            try? await Task.sleep(for: .milliseconds(200))
        }
    }
}

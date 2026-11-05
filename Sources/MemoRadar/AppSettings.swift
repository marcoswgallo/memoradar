import Foundation
import Observation

@MainActor @Observable
final class AppSettings {
    private enum Key {
        static let threshold = "forgottenThresholdHours"
        static let notifications = "notificationsEnabled"
    }

    private let defaults = UserDefaults.standard

    var forgottenThresholdHours: Int {
        didSet { defaults.set(forgottenThresholdHours, forKey: Key.threshold) }
    }

    var notificationsEnabled: Bool {
        didSet { defaults.set(notificationsEnabled, forKey: Key.notifications) }
    }

    var threshold: TimeInterval { TimeInterval(forgottenThresholdHours) * 3600 }

    init() {
        forgottenThresholdHours = defaults.object(forKey: Key.threshold) as? Int ?? 4
        notificationsEnabled = defaults.object(forKey: Key.notifications) as? Bool ?? true
    }
}

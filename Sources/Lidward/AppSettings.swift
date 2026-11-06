import Foundation

final class AppSettings {
    private enum Keys {
        static let displaySleepAllowed = "displaySleepAllowed"
        static let allowDisplaySleepWhenLocked = "allowDisplaySleepWhenLocked"
        static let lockScreenAfterInactivity = "lockScreenAfterInactivity"
        static let lockScreenOnLidClose = "lockScreenOnLidClose"
    }

    private let defaults: UserDefaults

    /// When true, the session does not hold a display-sleep assertion.
    var displaySleepAllowed: Bool {
        didSet {
            persist(displaySleepAllowed, oldValue: oldValue, key: Keys.displaySleepAllowed)
        }
    }

    /// When true, the display assertion is released while the screen is locked.
    var allowDisplaySleepWhenLocked: Bool {
        didSet {
            persist(allowDisplaySleepWhenLocked, oldValue: oldValue, key: Keys.allowDisplaySleepWhenLocked)
        }
    }

    /// Minutes of inactivity before Lidward locks the screen. Zero means off.
    var lockScreenAfterInactivity: Int {
        didSet {
            persist(lockScreenAfterInactivity, oldValue: oldValue, key: Keys.lockScreenAfterInactivity)
        }
    }

    /// Lock the screen immediately when the lid closes.
    var lockScreenOnLidClose: Bool {
        didSet {
            persist(lockScreenOnLidClose, oldValue: oldValue, key: Keys.lockScreenOnLidClose)
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.displaySleepAllowed = defaults.bool(forKey: Keys.displaySleepAllowed)
        self.allowDisplaySleepWhenLocked = defaults.bool(forKey: Keys.allowDisplaySleepWhenLocked)
        self.lockScreenAfterInactivity = max(0, defaults.integer(forKey: Keys.lockScreenAfterInactivity))
        self.lockScreenOnLidClose = defaults.bool(forKey: Keys.lockScreenOnLidClose)
    }

    private func persist<T: Equatable>(_ value: T, oldValue: T, key: String) {
        guard value != oldValue else { return }

        defaults.set(value, forKey: key)
        NotificationCenter.default.post(name: .lidwardSettingsDidChange, object: self)
    }
}

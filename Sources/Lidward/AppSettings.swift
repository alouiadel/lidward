import Combine
import Foundation

final class AppSettings: ObservableObject {
    private enum Keys {
        static let displaySleepAllowed = "displaySleepAllowed"
        static let allowDisplaySleepWhenLocked = "allowDisplaySleepWhenLocked"
        static let lockScreenAfterInactivity = "lockScreenAfterInactivity"
        static let lockScreenOnLidClose = "lockScreenOnLidClose"
        static let closedDisplayModeEnabled = "closedDisplayModeEnabled"
        static let showSessionTimeInMenuBar = "showSessionTimeInMenuBar"
        static let hideInDock = "hideInDock"
        static let automaticallyCheckForUpdates = "automaticallyCheckForUpdates"
        static let lastUpdateCheck = "lastUpdateCheck"
    }

    private let defaults: UserDefaults

    /// When true, the session does not hold a display-sleep assertion.
    @Published var displaySleepAllowed: Bool {
        didSet {
            persist(displaySleepAllowed, oldValue: oldValue, key: Keys.displaySleepAllowed)
        }
    }

    /// When true, the display assertion is released while the screen is locked.
    @Published var allowDisplaySleepWhenLocked: Bool {
        didSet {
            persist(allowDisplaySleepWhenLocked, oldValue: oldValue, key: Keys.allowDisplaySleepWhenLocked)
        }
    }

    /// Minutes of inactivity before Lidward locks the screen. Zero means off.
    @Published var lockScreenAfterInactivity: Int {
        didSet {
            persist(lockScreenAfterInactivity, oldValue: oldValue, key: Keys.lockScreenAfterInactivity)
        }
    }

    /// Lock the screen immediately when the lid closes.
    @Published var lockScreenOnLidClose: Bool {
        didSet {
            persist(lockScreenOnLidClose, oldValue: oldValue, key: Keys.lockScreenOnLidClose)
        }
    }

    /// Keep the system awake when the MacBook lid is closed.
    @Published var closedDisplayModeEnabled: Bool {
        didSet {
            persist(closedDisplayModeEnabled, oldValue: oldValue, key: Keys.closedDisplayModeEnabled)
        }
    }

    /// Show elapsed session time next to the menu-bar icon.
    @Published var showSessionTimeInMenuBar: Bool {
        didSet {
            persist(showSessionTimeInMenuBar, oldValue: oldValue, key: Keys.showSessionTimeInMenuBar)
        }
    }

    /// Hide the app from the Dock and Cmd-Tab.
    @Published var hideInDock: Bool {
        didSet {
            persist(hideInDock, oldValue: oldValue, key: Keys.hideInDock)
        }
    }

    /// Check GitHub Releases at most once a day.
    @Published var automaticallyCheckForUpdates: Bool {
        didSet {
            persist(automaticallyCheckForUpdates, oldValue: oldValue, key: Keys.automaticallyCheckForUpdates)
        }
    }

    /// Timestamp of the last update check.
    @Published var lastUpdateCheck: Date? {
        didSet {
            if let lastUpdateCheck {
                defaults.set(lastUpdateCheck, forKey: Keys.lastUpdateCheck)
            } else {
                defaults.removeObject(forKey: Keys.lastUpdateCheck)
            }
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.displaySleepAllowed = defaults.bool(forKey: Keys.displaySleepAllowed)
        self.allowDisplaySleepWhenLocked = defaults.bool(forKey: Keys.allowDisplaySleepWhenLocked)
        self.lockScreenAfterInactivity = max(0, defaults.integer(forKey: Keys.lockScreenAfterInactivity))
        self.lockScreenOnLidClose = defaults.bool(forKey: Keys.lockScreenOnLidClose)
        self.closedDisplayModeEnabled = defaults.bool(forKey: Keys.closedDisplayModeEnabled)
        self.showSessionTimeInMenuBar = defaults.object(forKey: Keys.showSessionTimeInMenuBar) as? Bool ?? true
        self.hideInDock = defaults.object(forKey: Keys.hideInDock) as? Bool ?? true
        self.automaticallyCheckForUpdates = defaults.object(forKey: Keys.automaticallyCheckForUpdates) as? Bool ?? true
        self.lastUpdateCheck = defaults.object(forKey: Keys.lastUpdateCheck) as? Date
    }

    private func persist<T: Equatable>(_ value: T, oldValue: T, key: String) {
        guard value != oldValue else { return }

        defaults.set(value, forKey: key)
        NotificationCenter.default.post(name: .lidwardSettingsDidChange, object: self)
    }
}

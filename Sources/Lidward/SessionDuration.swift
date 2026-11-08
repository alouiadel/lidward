import Foundation

/// A session length chosen before starting a keep-awake session.
///
/// `rawValue` is the number of minutes, so the selection can be persisted
/// directly in `AppSettings`. Zero means “until I stop it”.
enum SessionDuration: Int, CaseIterable, Identifiable {
    case indefinite = 0
    case fifteenMinutes = 15
    case thirtyMinutes = 30
    case oneHour = 60
    case twoHours = 120
    case fourHours = 240
    case eightHours = 480

    var id: Int { rawValue }

    var minutes: Int { rawValue }

    init?(minutes: Int) {
        self.init(rawValue: minutes)
    }

    var isIndefinite: Bool { self == .indefinite }

    /// Seconds for timed sessions, or `nil` for an indefinite session.
    var seconds: TimeInterval? {
        isIndefinite ? nil : TimeInterval(rawValue * 60)
    }

    var label: String {
        switch self {
        case .indefinite:
            return "Indefinitely"
        case .fifteenMinutes:
            return "15 minutes"
        case .thirtyMinutes:
            return "30 minutes"
        case .oneHour:
            return "1 hour"
        case .twoHours:
            return "2 hours"
        case .fourHours:
            return "4 hours"
        case .eightHours:
            return "8 hours"
        }
    }

    /// Compact form used in the menu-bar menu.
    var shortLabel: String {
        switch self {
        case .indefinite:
            return "Indefinitely"
        case .fifteenMinutes:
            return "15m"
        case .thirtyMinutes:
            return "30m"
        case .oneHour:
            return "1h"
        case .twoHours:
            return "2h"
        case .fourHours:
            return "4h"
        case .eightHours:
            return "8h"
        }
    }
}

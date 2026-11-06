import Foundation
import IOKit.pwr_mgt

enum SessionError: LocalizedError {
    case assertionFailed(String, IOReturn)

    var errorDescription: String? {
        switch self {
        case let .assertionFailed(name, code):
            return "Could not create the \(name) assertion (error \(code))."
        }
    }
}

/// Owns the lifetime of a keep-awake session.
///
/// The session holds two IOPMAssertions: one prevents idle system sleep and
/// one prevents idle display sleep. Both are released when the session ends,
/// and macOS releases them automatically if the process exits unexpectedly.
final class SessionController {
    private(set) var isActive = false

    private var systemAssertionID: IOPMAssertionID = 0
    private var displayAssertionID: IOPMAssertionID = 0

    /// Called whenever the session state changes.
    var onChange: (() -> Void)?

    func start() throws {
        guard !isActive else { return }

        var systemID: IOPMAssertionID = 0
        var displayID: IOPMAssertionID = 0

        let systemResult = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "Lidward is keeping your Mac awake" as CFString,
            &systemID
        )

        guard systemResult == kIOReturnSuccess else {
            throw SessionError.assertionFailed("system sleep", systemResult)
        }

        let displayResult = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "Lidward is keeping your display awake" as CFString,
            &displayID
        )

        guard displayResult == kIOReturnSuccess else {
            IOPMAssertionRelease(systemID)
            throw SessionError.assertionFailed("display sleep", displayResult)
        }

        systemAssertionID = systemID
        displayAssertionID = displayID
        isActive = true
        onChange?()
    }

    func stop() {
        guard isActive else { return }

        releaseAssertions()
        isActive = false
        onChange?()
    }

    private func releaseAssertions() {
        if systemAssertionID != 0 {
            IOPMAssertionRelease(systemAssertionID)
            systemAssertionID = 0
        }

        if displayAssertionID != 0 {
            IOPMAssertionRelease(displayAssertionID)
            displayAssertionID = 0
        }
    }

    deinit {
        releaseAssertions()
    }
}

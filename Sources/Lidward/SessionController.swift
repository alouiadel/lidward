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
/// The session holds a system-sleep assertion and, depending on the current
/// settings, a display-sleep assertion. macOS releases both automatically if
/// the process exits unexpectedly.
final class SessionController {
    private let settings: AppSettings

    private(set) var isActive = false
    private(set) var isScreenLocked = false
    private(set) var startedAt: ContinuousClock.Instant?
    private(set) var scheduledDuration: TimeInterval?

    /// Monotonic elapsed time for the current session.
    var elapsedTime: TimeInterval? {
        guard let startedAt else { return nil }

        let duration = ContinuousClock.now - startedAt
        let components = duration.components

        return TimeInterval(components.seconds)
            + TimeInterval(components.attoseconds) / 1_000_000_000_000_000_000
    }

    /// Remaining time for a timed session, or `nil` for an indefinite one.
    var remainingTime: TimeInterval? {
        guard let scheduledDuration, let elapsedTime else { return nil }
        return max(0, scheduledDuration - elapsedTime)
    }

    private var systemAssertionID: IOPMAssertionID = 0
    private var displayAssertionID: IOPMAssertionID = 0
    private var autoStopTimer: Timer?
    private var settingsObserver: NSObjectProtocol?

    var onError: ((Error) -> Void)?

    init(settings: AppSettings) {
        self.settings = settings

        settingsObserver = NotificationCenter.default.addObserver(
            forName: .lidwardSettingsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateDisplayAssertionReportingErrors()
        }
    }

    func start(duration: SessionDuration = .indefinite) throws {
        guard !isActive else { return }

        var systemID: IOPMAssertionID = 0

        let systemResult = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "Lidward is keeping your Mac awake" as CFString,
            &systemID
        )

        guard systemResult == kIOReturnSuccess else {
            throw SessionError.assertionFailed("system sleep", systemResult)
        }

        systemAssertionID = systemID
        isActive = true

        do {
            try updateDisplayAssertion()
        } catch {
            IOPMAssertionRelease(systemAssertionID)
            systemAssertionID = 0
            isActive = false
            throw error
        }

        startedAt = ContinuousClock.now
        scheduledDuration = duration.seconds
        scheduleAutoStop(after: scheduledDuration)
        notifySessionChanged()
    }

    func stop() {
        guard isActive else { return }

        autoStopTimer?.invalidate()
        autoStopTimer = nil
        scheduledDuration = nil
        releaseAssertions()
        isActive = false
        startedAt = nil
        notifySessionChanged()
    }

    func setScreenLocked(_ locked: Bool) {
        guard isScreenLocked != locked else { return }

        isScreenLocked = locked
        updateDisplayAssertionReportingErrors()
    }

    private func updateDisplayAssertion() throws {
        let shouldPreventDisplaySleep = isActive
            && !settings.displaySleepAllowed
            && !(settings.allowDisplaySleepWhenLocked && isScreenLocked)

        if shouldPreventDisplaySleep {
            guard displayAssertionID == 0 else { return }

            var displayID: IOPMAssertionID = 0

            let result = IOPMAssertionCreateWithName(
                kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                "Lidward is keeping your display awake" as CFString,
                &displayID
            )

            guard result == kIOReturnSuccess else {
                throw SessionError.assertionFailed("display sleep", result)
            }

            displayAssertionID = displayID
        } else if displayAssertionID != 0 {
            IOPMAssertionRelease(displayAssertionID)
            displayAssertionID = 0
        }
    }

    private func updateDisplayAssertionReportingErrors() {
        do {
            try updateDisplayAssertion()
        } catch {
            onError?(error)
        }
    }

    private func scheduleAutoStop(after duration: TimeInterval?) {
        autoStopTimer?.invalidate()
        autoStopTimer = nil

        guard let duration, duration > 0 else { return }

        let timer = Timer(timeInterval: duration, repeats: false) { [weak self] _ in
            self?.stop()
        }
        RunLoop.main.add(timer, forMode: .common)
        autoStopTimer = timer
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

    private func notifySessionChanged() {
        NotificationCenter.default.post(name: .lidwardSessionDidChange, object: self)
    }

    deinit {
        autoStopTimer?.invalidate()

        if let settingsObserver {
            NotificationCenter.default.removeObserver(settingsObserver)
        }

        releaseAssertions()
    }
}

import AppKit
import CoreGraphics

/// Locks the screen after a configurable period of user inactivity while a
/// session is active.
final class IdleLockController {
    private let session: SessionController
    private let settings: AppSettings
    private let screenLockMonitor: ScreenLockMonitor

    private var timer: Timer?
    private var hasLockedForInactivity = false
    private var observers: [NSObjectProtocol] = []

    init(
        session: SessionController,
        settings: AppSettings,
        screenLockMonitor: ScreenLockMonitor
    ) {
        self.session = session
        self.settings = settings
        self.screenLockMonitor = screenLockMonitor

        observers.append(NotificationCenter.default.addObserver(
            forName: .lidwardSessionDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateTimer()
        })

        observers.append(NotificationCenter.default.addObserver(
            forName: .lidwardSettingsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateTimer()
        })

        updateTimer()
    }

    func screenLockStateDidChange(_ locked: Bool) {
        if !locked {
            hasLockedForInactivity = false
        }
    }

    private func updateTimer() {
        let shouldRun = session.isActive && settings.lockScreenAfterInactivity > 0

        if shouldRun {
            guard timer == nil else { return }

            let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
                self?.tick()
            }
            RunLoop.main.add(timer, forMode: .common)
            self.timer = timer
        } else {
            timer?.invalidate()
            timer = nil
            hasLockedForInactivity = false
        }
    }

    private func tick() {
        guard session.isActive, settings.lockScreenAfterInactivity > 0 else { return }
        guard !screenLockMonitor.isLocked, !hasLockedForInactivity else { return }

        let threshold = Double(settings.lockScreenAfterInactivity * 60)
        let idle = CGEventSource.secondsSinceLastEventType(
            .combinedSessionState,
            eventType: CGEventType(rawValue: ~0)!
        )

        if idle < threshold {
            hasLockedForInactivity = false
            return
        }

        hasLockedForInactivity = true
        ScreenLocker.lock()
    }

    deinit {
        timer?.invalidate()

        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}

import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = AppSettings()
    private let helperInstaller = HelperInstaller()
    private lazy var session = SessionController(settings: settings)
    private lazy var closedDisplayController = ClosedDisplayController(
        session: session,
        settings: settings,
        installer: helperInstaller
    )
    private let screenLockMonitor = ScreenLockMonitor()

    private var statusItemController: StatusItemController?
    private var idleLockController: IdleLockController?
    private var lidMonitor: LidMonitor?

    func applicationDidFinishLaunching(_ notification: Notification) {
        helperInstaller.restoreIfNeeded()

        statusItemController = StatusItemController(
            session: session,
            settings: settings,
            closedDisplayController: closedDisplayController
        )
        closedDisplayController.onError = { [weak self] error in
            self?.statusItemController?.presentError(error)
        }

        idleLockController = IdleLockController(
            session: session,
            settings: settings,
            screenLockMonitor: screenLockMonitor
        )
        lidMonitor = LidMonitor(
            session: session,
            settings: settings,
            screenLockMonitor: screenLockMonitor
        )

        session.setScreenLocked(screenLockMonitor.isLocked)

        screenLockMonitor.onChange = { [weak self] locked in
            self?.session.setScreenLocked(locked)
            self?.idleLockController?.screenLockStateDidChange(locked)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        closedDisplayController.shutdown()
        session.stop()
    }

    #if DEBUG
    func applyDebugArguments() {
        if CommandLine.arguments.contains("--allow-display-sleep") {
            settings.displaySleepAllowed = true
        }

        if CommandLine.arguments.contains("--start-session") {
            startSessionForTesting()
        }
    }

    private func startSessionForTesting() {
        do {
            try session.start()
        } catch {
            NSLog("Lidward: failed to start test session: \(error.localizedDescription)")
        }
    }
    #endif
}

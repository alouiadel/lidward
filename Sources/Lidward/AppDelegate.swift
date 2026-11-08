import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = AppSettings()
    private let helperInstaller = HelperInstaller()
    private let loginItemController = LoginItemController()
    private lazy var session = SessionController(settings: settings)
    private lazy var closedDisplayController = ClosedDisplayController(
        session: session,
        settings: settings,
        installer: helperInstaller
    )
    private let screenLockMonitor = ScreenLockMonitor()
    private lazy var updateChecker = UpdateChecker(settings: settings)
    private lazy var uninstaller = UninstallController(
        helperInstaller: helperInstaller,
        onWillUninstall: { [weak self] in
            self?.closedDisplayController.shutdown()
            self?.session.stop()
        }
    )

    private var statusItemController: StatusItemController?
    private var idleLockController: IdleLockController?
    private var lidMonitor: LidMonitor?
    private var preferencesWindowController: PreferencesWindowController?
    private var settingsObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        helperInstaller.restoreIfNeeded()
        applyDockVisibility()

        statusItemController = StatusItemController(
            session: session,
            settings: settings,
            closedDisplayController: closedDisplayController,
            updateChecker: updateChecker,
            showPreferences: { [weak self] in self?.showPreferences() }
        )
        closedDisplayController.onError = { [weak self] error in
            self?.statusItemController?.presentError(error)
        }

        updateChecker.start()

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

        settingsObserver = NotificationCenter.default.addObserver(
            forName: .lidwardSettingsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.applyDockVisibility()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        closedDisplayController.shutdown()
        session.stop()

        if let settingsObserver {
            NotificationCenter.default.removeObserver(settingsObserver)
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            showPreferences()
        }

        return true
    }

    private func showPreferences() {
        if preferencesWindowController == nil {
            preferencesWindowController = PreferencesWindowController(
                settings: settings,
                loginItem: loginItemController,
                updateChecker: updateChecker,
                uninstaller: uninstaller
            )
        }

        preferencesWindowController?.show()
    }

    private func applyDockVisibility() {
        let policy: NSApplication.ActivationPolicy = settings.hideInDock ? .accessory : .regular

        if NSApp.activationPolicy() != policy {
            NSApp.setActivationPolicy(policy)
        }
    }

    #if DEBUG
    func applyDebugArguments() {
        if CommandLine.arguments.contains("--allow-display-sleep") {
            settings.displaySleepAllowed = true
        }

        if CommandLine.arguments.contains("--start-session") {
            startSessionForTesting()
        }

        if CommandLine.arguments.contains("--show-preferences") {
            DispatchQueue.main.async { [weak self] in
                self?.showPreferences()
            }
        }

        if CommandLine.arguments.contains("--show-menu") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.statusItemController?.showMenuForTesting()
            }
        }
    }

    private func startSessionForTesting() {
        let duration = SessionDuration(minutes: settings.sessionDurationMinutes) ?? .indefinite

        do {
            try session.start(duration: duration)
        } catch {
            NSLog("Lidward: failed to start test session: \(error.localizedDescription)")
        }
    }
    #endif

    deinit {
        if let settingsObserver {
            NotificationCenter.default.removeObserver(settingsObserver)
        }
    }
}

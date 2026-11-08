import AppKit

final class StatusItemController: NSObject {
    private let session: SessionController
    private let settings: AppSettings
    private let closedDisplayController: ClosedDisplayController?
    private let updateChecker: UpdateChecker?
    private let showPreferences: (() -> Void)?
    private let statusItem: NSStatusItem
    private let menu = NSMenu()

    private let sessionMenuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let startForItem = NSMenuItem(title: "Start For", action: nil, keyEquivalent: "")
    private let durationSubmenu = NSMenu(title: "Start For")
    private let stateMenuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let preventDisplaySleepItem = NSMenuItem(title: "Prevent Display Sleep", action: nil, keyEquivalent: "")
    private let allowDisplaySleepWhenLockedItem = NSMenuItem(title: "Allow Display Sleep When Locked", action: nil, keyEquivalent: "")
    private let lockScreenOnLidCloseItem = NSMenuItem(title: "Lock Screen When Lid Closes", action: nil, keyEquivalent: "")
    private let closedDisplayModeItem = NSMenuItem(title: "Keep Awake With Lid Closed", action: nil, keyEquivalent: "")
    private let helperSeparatorItem = NSMenuItem.separator()
    private let uninstallHelperItem = NSMenuItem(title: "Remove Closed-Display Helper…", action: nil, keyEquivalent: "")
    private let updateMenuItem = NSMenuItem(title: "Check for Updates…", action: nil, keyEquivalent: "")
    private let preferencesItem = NSMenuItem(title: "Preferences…", action: nil, keyEquivalent: ",")
    private let inactivitySubmenu = NSMenu(title: "Lock Screen After Inactivity")

    private var observers: [NSObjectProtocol] = []
    private var spaceObserver: NSObjectProtocol?
    private var sessionTimer: Timer?

    init(
        session: SessionController,
        settings: AppSettings,
        closedDisplayController: ClosedDisplayController? = nil,
        updateChecker: UpdateChecker? = nil,
        showPreferences: (() -> Void)? = nil
    ) {
        self.session = session
        self.settings = settings
        self.closedDisplayController = closedDisplayController
        self.updateChecker = updateChecker
        self.showPreferences = showPreferences
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        super.init()

        configureStatusItem()
        configureMenu()
        observeChanges()
        refreshMenu()

        session.onError = { [weak self] error in
            self?.presentError(error)
        }
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }

        button.toolTip = "Lidward"
        button.imagePosition = .imageLeading
        button.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
    }

    private func configureMenu() {
        menu.removeAllItems()

        sessionMenuItem.target = self
        sessionMenuItem.action = #selector(toggleSession)
        menu.addItem(sessionMenuItem)

        startForItem.image = symbol("timer")
        startForItem.toolTip = "Start a session with a specific length."
        startForItem.submenu = durationSubmenu

        for duration in SessionDuration.allCases {
            let item = NSMenuItem(
                title: duration.label,
                action: #selector(startForDuration(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.tag = duration.minutes
            durationSubmenu.addItem(item)
        }

        menu.addItem(startForItem)

        menu.addItem(.separator())

        stateMenuItem.isEnabled = false
        menu.addItem(stateMenuItem)

        menu.addItem(.separator())

        preventDisplaySleepItem.target = self
        preventDisplaySleepItem.action = #selector(togglePreventDisplaySleep)
        preventDisplaySleepItem.image = symbol("display")
        preventDisplaySleepItem.toolTip = "Keep the display awake while a session is active."
        menu.addItem(preventDisplaySleepItem)

        allowDisplaySleepWhenLockedItem.target = self
        allowDisplaySleepWhenLockedItem.action = #selector(toggleAllowDisplaySleepWhenLocked)
        allowDisplaySleepWhenLockedItem.image = symbol("lock")
        allowDisplaySleepWhenLockedItem.toolTip = "Let the display sleep when the screen is locked."
        menu.addItem(allowDisplaySleepWhenLockedItem)

        let inactivityItem = NSMenuItem(title: "Lock Screen After Inactivity", action: nil, keyEquivalent: "")
        inactivityItem.image = symbol("clock")
        inactivityItem.submenu = inactivitySubmenu

        for minutes in [0, 1, 2, 5, 10, 15, 30] {
            let item = NSMenuItem(
                title: inactivityTitle(minutes),
                action: #selector(setInactivityLock),
                keyEquivalent: ""
            )
            item.target = self
            item.tag = minutes
            inactivitySubmenu.addItem(item)
        }

        menu.addItem(inactivityItem)

        lockScreenOnLidCloseItem.target = self
        lockScreenOnLidCloseItem.action = #selector(toggleLockOnLidClose)
        lockScreenOnLidCloseItem.image = symbol("lock.fill")
        lockScreenOnLidCloseItem.toolTip = "Lock the screen as soon as the lid closes."
        menu.addItem(lockScreenOnLidCloseItem)

        menu.addItem(.separator())

        closedDisplayModeItem.target = self
        closedDisplayModeItem.action = #selector(toggleClosedDisplayMode)
        closedDisplayModeItem.image = symbol("laptopcomputer")
        closedDisplayModeItem.toolTip = "Keep your Mac awake with the lid closed. Requires a one-time administrator setup."
        menu.addItem(closedDisplayModeItem)

        menu.addItem(helperSeparatorItem)

        uninstallHelperItem.target = self
        uninstallHelperItem.action = #selector(uninstallHelper)
        uninstallHelperItem.image = symbol("trash")
        menu.addItem(uninstallHelperItem)

        menu.addItem(.separator())

        updateMenuItem.target = self
        updateMenuItem.action = #selector(handleUpdateMenu)
        updateMenuItem.image = symbol("arrow.triangle.2.circlepath")
        menu.addItem(updateMenuItem)

        preferencesItem.target = self
        preferencesItem.action = #selector(openPreferences)
        preferencesItem.image = symbol("gearshape")
        menu.addItem(preferencesItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit Lidward",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        quitItem.image = symbol("power")
        menu.addItem(quitItem)

        updateMenuMode()
    }

    private func symbol(_ name: String) -> NSImage? {
        let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)
        image?.isTemplate = true
        return image
    }

    /// In a normal space, let AppKit position the status menu natively. In a
    /// full-screen space, use a direct pop-up because activating the accessory
    /// app can make macOS hide the menu bar (FB13544993).
    private func updateMenuMode() {
        if isFullscreenSpace() {
            statusItem.menu = nil

            if let button = statusItem.button {
                button.target = self
                button.action = #selector(showStatusMenu)
                button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            }
        } else {
            statusItem.menu = menu
            statusItem.button?.target = nil
            statusItem.button?.action = nil
        }
    }

    private func isFullscreenSpace() -> Bool {
        let screen = NSScreen.main ?? NSScreen.screens.first
        let displayID = screen?.deviceDescription[
            NSDeviceDescriptionKey("NSScreenNumber")
        ] as? CGDirectDisplayID ?? CGMainDisplayID()
        let displayBounds = CGDisplayBounds(displayID)

        guard let windows = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return false
        }

        let ownPID = getpid()

        for window in windows {
            let layer = window[kCGWindowLayer as String] as? Int ?? 0
            guard layer == 0 else { continue }

            let ownerPID = window[kCGWindowOwnerPID as String] as? pid_t ?? 0
            guard ownerPID != ownPID else { continue }

            guard let bounds = window[kCGWindowBounds as String] as? [String: Any],
                  let x = (bounds["X"] as? NSNumber)?.doubleValue,
                  let y = (bounds["Y"] as? NSNumber)?.doubleValue,
                  let width = (bounds["Width"] as? NSNumber)?.doubleValue,
                  let height = (bounds["Height"] as? NSNumber)?.doubleValue else {
                continue
            }

            let rect = CGRect(x: x, y: y, width: width, height: height)

            if rect.width >= displayBounds.width - 1,
               rect.height >= displayBounds.height - 1 {
                return true
            }
        }

        return false
    }

    @objc private func showStatusMenu() {
        guard let button = statusItem.button,
              let window = button.window else { return }

        let buttonRectInWindow = button.convert(button.bounds, to: nil)
        let buttonRectOnScreen = window.convertToScreen(buttonRectInWindow)

        menu.popUp(
            positioning: sessionMenuItem,
            at: NSPoint(
                x: buttonRectOnScreen.minX,
                y: buttonRectOnScreen.minY - 4
            ),
            in: nil
        )
    }

    #if DEBUG
    func showMenuForTesting() {
        showStatusMenu()
    }
    #endif

    private func observeChanges() {
        let center = NotificationCenter.default

        observers.append(center.addObserver(
            forName: .lidwardSessionDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshMenu()
        })

        observers.append(center.addObserver(
            forName: .lidwardSettingsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshMenu()
        })

        observers.append(center.addObserver(
            forName: .lidwardHelperStatusDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshMenu()
        })

        observers.append(center.addObserver(
            forName: .lidwardUpdateStatusDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshMenu()
        })

        spaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateMenuMode()
        }
    }

    private func refreshMenu() {
        let isActive = session.isActive
        let description = isActive ? "Session active" : "Session inactive"

        statusItem.button?.image = MenuBarGlyph.image(active: isActive)
        statusItem.button?.toolTip = description
        statusItem.button?.setAccessibilityLabel("Lidward, \(description)")

        sessionMenuItem.title = isActive ? "Stop Session" : "Start Session"
        sessionMenuItem.image = symbol(isActive ? "stop.fill" : "play.fill")
        sessionMenuItem.toolTip = isActive
            ? "Stop the current keep-awake session."
            : "Start a session using the selected length."
        startForItem.isHidden = isActive

        let selectedDuration = SessionDuration(minutes: settings.sessionDurationMinutes) ?? .indefinite
        if !isActive, !selectedDuration.isIndefinite {
            sessionMenuItem.title = "Start Session · \(selectedDuration.shortLabel)"
        }

        for item in durationSubmenu.items {
            item.state = item.tag == settings.sessionDurationMinutes ? .on : .off
        }

        updateStateItemTitle()

        preventDisplaySleepItem.state = settings.displaySleepAllowed ? .off : .on
        allowDisplaySleepWhenLockedItem.state = settings.allowDisplaySleepWhenLocked ? .on : .off
        allowDisplaySleepWhenLockedItem.isEnabled = !settings.displaySleepAllowed
        lockScreenOnLidCloseItem.state = settings.lockScreenOnLidClose ? .on : .off
        closedDisplayModeItem.state = settings.closedDisplayModeEnabled ? .on : .off
        closedDisplayModeItem.isEnabled = LidMonitor.supportsClamshell

        let showHelperRemoval = closedDisplayController?.isHelperInstalled ?? false
        helperSeparatorItem.isHidden = !showHelperRemoval
        uninstallHelperItem.isHidden = !showHelperRemoval

        if let updateChecker {
            updateMenuItem.isHidden = false

            if updateChecker.isChecking {
                updateMenuItem.title = "Checking for Updates…"
                updateMenuItem.image = nil
                updateMenuItem.isEnabled = false
            } else if let update = updateChecker.availableUpdate {
                updateMenuItem.title = "Download Lidward \(update.version)…"
                updateMenuItem.image = NSImage(
                    systemSymbolName: "arrow.down.circle",
                    accessibilityDescription: "Update available"
                )
                updateMenuItem.image?.isTemplate = true
                updateMenuItem.isEnabled = true
            } else {
                updateMenuItem.title = "Check for Updates…"
                updateMenuItem.image = nil
                updateMenuItem.isEnabled = true
            }
        } else {
            updateMenuItem.isHidden = true
        }

        for item in inactivitySubmenu.items {
            item.state = item.tag == settings.lockScreenAfterInactivity ? .on : .off
        }

        updateSessionTimer()
    }

    private func updateSessionTimer() {
        // Keep running while a session is active even if the menu-bar timer is
        // hidden, so the menu's status line always shows a current elapsed time.
        let shouldRun = session.isActive

        if shouldRun {
            updateSessionTitle()

            guard sessionTimer == nil else { return }

            let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
                self?.updateSessionTitle()
            }
            RunLoop.main.add(timer, forMode: .common)
            sessionTimer = timer
        } else {
            sessionTimer?.invalidate()
            sessionTimer = nil
            statusItem.button?.title = ""
        }
    }

    private func updateSessionTitle() {
        guard session.isActive,
              settings.showSessionTimeInMenuBar,
              let time = currentSessionTime() else {
            statusItem.button?.title = ""
            updateStateItemTitle()
            return
        }

        statusItem.button?.title = " " + time.text
        statusItem.button?.toolTip = time.isRemaining
            ? "Lidward — session active · \(time.text) remaining"
            : "Lidward — session active · \(time.text) elapsed"
        updateStateItemTitle()
    }

    private func currentSessionTime() -> (text: String, isRemaining: Bool)? {
        if let remaining = session.remainingTime {
            return (formattedElapsed(remaining), true)
        }

        if let elapsed = session.elapsedTime {
            return (formattedElapsed(elapsed), false)
        }

        return nil
    }

    private func updateStateItemTitle() {
        let isActive = session.isActive
        let status: String

        if isActive, let time = currentSessionTime() {
            let suffix = time.isRemaining ? " left" : ""
            status = "Session active  ·  \(time.text)\(suffix)"
        } else {
            status = isActive ? "Session active" : "Session inactive"
        }

        let title = NSMutableAttributedString(
            string: "● ",
            attributes: [
                .foregroundColor: isActive ? NSColor.systemGreen : NSColor.tertiaryLabelColor,
                .font: NSFont.systemFont(ofSize: 9)
            ]
        )

        title.append(NSAttributedString(
            string: status,
            attributes: [
                .foregroundColor: NSColor.secondaryLabelColor,
                .font: NSFont.systemFont(ofSize: 12, weight: .medium)
            ]
        ))

        stateMenuItem.attributedTitle = title
    }

    private func formattedElapsed(_ elapsedTime: TimeInterval) -> String {
        let elapsed = max(0, Int(elapsedTime))
        let hours = elapsed / 3600
        let minutes = (elapsed % 3600) / 60
        let seconds = elapsed % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }

        return String(format: "%d:%02d", minutes, seconds)
    }

    private func inactivityTitle(_ minutes: Int) -> String {
        switch minutes {
        case 0:
            return "Off"
        case 1:
            return "1 minute"
        default:
            return "\(minutes) minutes"
        }
    }

    @objc private func toggleSession() {
        if session.isActive {
            session.stop()
        } else {
            let duration = SessionDuration(minutes: settings.sessionDurationMinutes) ?? .indefinite

            do {
                try session.start(duration: duration)
            } catch {
                presentError(error)
            }
        }
    }

    @objc private func startForDuration(_ sender: NSMenuItem) {
        guard !session.isActive else { return }

        let duration = SessionDuration(minutes: sender.tag) ?? .indefinite
        settings.sessionDurationMinutes = duration.minutes

        do {
            try session.start(duration: duration)
        } catch {
            presentError(error)
        }
    }

    @objc private func togglePreventDisplaySleep() {
        settings.displaySleepAllowed.toggle()
    }

    @objc private func toggleAllowDisplaySleepWhenLocked() {
        settings.allowDisplaySleepWhenLocked.toggle()
    }

    @objc private func toggleLockOnLidClose() {
        settings.lockScreenOnLidClose.toggle()
    }

    @objc private func toggleClosedDisplayMode() {
        settings.closedDisplayModeEnabled.toggle()
    }

    @objc private func uninstallHelper() {
        do {
            try closedDisplayController?.uninstallHelper()
        } catch {
            presentError(error)
        }
    }

    @objc private func setInactivityLock(_ sender: NSMenuItem) {
        settings.lockScreenAfterInactivity = sender.tag
    }

    func presentError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "Lidward could not complete that action"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.icon = NSApp.applicationIconImage
        alert.addButton(withTitle: "OK")

        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    @objc private func handleUpdateMenu() {
        if let update = updateChecker?.availableUpdate {
            NSWorkspace.shared.open(update.releaseURL)
            return
        }

        checkForUpdates()
    }

    private func checkForUpdates() {
        guard let updateChecker else { return }

        updateChecker.check(force: true) { [weak self] error in
            guard let self else { return }

            if let error {
                self.presentError(error)
                return
            }

            if let update = self.updateChecker?.availableUpdate {
                let alert = NSAlert()
                alert.messageText = "Lidward \(update.version) is available"
                alert.informativeText = "Open the GitHub release page to download it."
                alert.icon = NSApp.applicationIconImage
                alert.addButton(withTitle: "Download")
                alert.addButton(withTitle: "Later")

                NSApp.activate(ignoringOtherApps: true)
                if alert.runModal() == .alertFirstButtonReturn {
                    NSWorkspace.shared.open(update.releaseURL)
                }
            } else {
                let alert = NSAlert()
                alert.messageText = "Lidward is up to date"
                alert.informativeText = "You are running the latest version."
                alert.icon = NSApp.applicationIconImage
                alert.addButton(withTitle: "OK")

                NSApp.activate(ignoringOtherApps: true)
                alert.runModal()
            }
        }
    }

    @objc private func openPreferences() {
        showPreferences?()
    }

    @objc private func quit() {
        session.stop()
        NSApp.terminate(nil)
    }

    deinit {
        sessionTimer?.invalidate()

        if let spaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(spaceObserver)
        }

        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}

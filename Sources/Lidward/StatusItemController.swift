import AppKit

final class StatusItemController: NSObject {
    private let session: SessionController
    private let settings: AppSettings
    private let statusItem: NSStatusItem

    private let sessionMenuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let stateMenuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let preventDisplaySleepItem = NSMenuItem(title: "Prevent Display Sleep", action: nil, keyEquivalent: "")
    private let allowDisplaySleepWhenLockedItem = NSMenuItem(title: "Allow Display Sleep When Locked", action: nil, keyEquivalent: "")
    private let lockScreenOnLidCloseItem = NSMenuItem(title: "Lock Screen When Lid Closes", action: nil, keyEquivalent: "")
    private let inactivitySubmenu = NSMenu(title: "Lock Screen After Inactivity")

    private var observers: [NSObjectProtocol] = []

    init(session: SessionController, settings: AppSettings) {
        self.session = session
        self.settings = settings
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
        button.imagePosition = .imageOnly
    }

    private func configureMenu() {
        let menu = NSMenu()

        sessionMenuItem.target = self
        sessionMenuItem.action = #selector(toggleSession)
        menu.addItem(sessionMenuItem)

        menu.addItem(.separator())

        stateMenuItem.isEnabled = false
        menu.addItem(stateMenuItem)

        menu.addItem(.separator())

        let controlsItem = NSMenuItem(title: "Session Controls", action: nil, keyEquivalent: "")
        let controlsMenu = NSMenu(title: "Session Controls")

        preventDisplaySleepItem.target = self
        preventDisplaySleepItem.action = #selector(togglePreventDisplaySleep)
        controlsMenu.addItem(preventDisplaySleepItem)

        allowDisplaySleepWhenLockedItem.target = self
        allowDisplaySleepWhenLockedItem.action = #selector(toggleAllowDisplaySleepWhenLocked)
        controlsMenu.addItem(allowDisplaySleepWhenLockedItem)

        controlsMenu.addItem(.separator())

        let inactivityItem = NSMenuItem(title: "Lock Screen After Inactivity", action: nil, keyEquivalent: "")
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

        controlsMenu.addItem(inactivityItem)

        lockScreenOnLidCloseItem.target = self
        lockScreenOnLidCloseItem.action = #selector(toggleLockOnLidClose)
        controlsMenu.addItem(lockScreenOnLidCloseItem)

        controlsItem.submenu = controlsMenu
        menu.addItem(controlsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit Lidward",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

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
    }

    private func refreshMenu() {
        let isActive = session.isActive
        let symbolName = isActive ? "eye.fill" : "eye.slash"
        let description = isActive ? "Session active" : "Session inactive"

        let image = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: description
        )
        image?.isTemplate = true

        statusItem.button?.image = image
        statusItem.button?.toolTip = description

        sessionMenuItem.title = isActive ? "Stop Session" : "Start Session"
        stateMenuItem.title = isActive ? "Session: Active" : "Session: Inactive"

        preventDisplaySleepItem.state = settings.displaySleepAllowed ? .off : .on
        allowDisplaySleepWhenLockedItem.state = settings.allowDisplaySleepWhenLocked ? .on : .off
        allowDisplaySleepWhenLockedItem.isEnabled = !settings.displaySleepAllowed
        lockScreenOnLidCloseItem.state = settings.lockScreenOnLidClose ? .on : .off

        for item in inactivitySubmenu.items {
            item.state = item.tag == settings.lockScreenAfterInactivity ? .on : .off
        }
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
            do {
                try session.start()
            } catch {
                presentError(error)
            }
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

    @objc private func setInactivityLock(_ sender: NSMenuItem) {
        settings.lockScreenAfterInactivity = sender.tag
    }

    private func presentError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "Lidward could not update the session"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")

        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    @objc private func quit() {
        session.stop()
        NSApp.terminate(nil)
    }

    deinit {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}

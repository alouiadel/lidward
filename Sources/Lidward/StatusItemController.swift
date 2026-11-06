import AppKit

final class StatusItemController: NSObject {
    private let session: SessionController
    private let statusItem: NSStatusItem
    private let sessionMenuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let stateMenuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")

    init(session: SessionController) {
        self.session = session
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        super.init()

        configureStatusItem()
        configureMenu()
        updateInterface()

        session.onChange = { [weak self] in
            self?.updateInterface()
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

        let quitItem = NSMenuItem(
            title: "Quit Lidward",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func updateInterface() {
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
    }

    @objc private func toggleSession() {
        if session.isActive {
            session.stop()
        } else {
            session.start()
        }
    }

    @objc private func quit() {
        session.stop()
        NSApp.terminate(nil)
    }
}

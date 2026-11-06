import AppKit
import SwiftUI

final class PreferencesWindowController: NSWindowController {
    init(
        settings: AppSettings,
        loginItem: LoginItemController,
        updateChecker: UpdateChecker,
        uninstaller: UninstallController
    ) {
        let rootView = PreferencesView(
            settings: settings,
            loginItem: loginItem,
            updateChecker: updateChecker,
            uninstaller: uninstaller
        )
        let hostingController = NSHostingController(rootView: rootView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "Lidward Preferences"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setContentSize(NSSize(width: 460, height: 520))
        window.center()
        window.isReleasedWhenClosed = false

        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }
}

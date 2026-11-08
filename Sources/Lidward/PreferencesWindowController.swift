import AppKit
import SwiftUI

final class PreferencesWindowController: NSWindowController {
    private let feedback: UpdateCheckFeedback

    init(
        settings: AppSettings,
        loginItem: LoginItemController,
        updateChecker: UpdateChecker,
        uninstaller: UninstallController
    ) {
        let feedback = UpdateCheckFeedback()
        self.feedback = feedback

        let rootView = PreferencesView(
            settings: settings,
            loginItem: loginItem,
            updateChecker: updateChecker,
            feedback: feedback,
            uninstaller: uninstaller
        )
        let hostingController = NSHostingController(rootView: rootView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "Lidward"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.backgroundColor = .windowBackgroundColor
        window.setContentSize(NSSize(width: 520, height: 680))
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

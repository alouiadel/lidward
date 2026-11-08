import AppKit
import Foundation
import ServiceManagement

final class UninstallController {
    private let helperInstaller: HelperInstaller
    private let onWillUninstall: () -> Void

    init(helperInstaller: HelperInstaller, onWillUninstall: @escaping () -> Void) {
        self.helperInstaller = helperInstaller
        self.onWillUninstall = onWillUninstall
    }

    func requestUninstall() {
        let alert = NSAlert()
        alert.messageText = "Uninstall Lidward?"
        alert.informativeText = """
        This removes Lidward, its preferences, its login item, and the closed-display helper. Normal sleep will be restored.

        This cannot be undone.
        """
        alert.alertStyle = .warning
        alert.icon = NSApp.applicationIconImage
        alert.addButton(withTitle: "Uninstall")
        alert.addButton(withTitle: "Cancel")

        NSApp.activate(ignoringOtherApps: true)

        guard alert.runModal() == .alertFirstButtonReturn else { return }

        performPurge()
    }

    private func performPurge() {
        onWillUninstall()

        if helperInstaller.isInstalled {
            do {
                try helperInstaller.uninstall()
            } catch {
                presentError(error)
                return
            }
        }

        try? SMAppService.mainApp.unregister()

        let domains = Set([
            Bundle.main.bundleIdentifier,
            "app.lidward",
            "dev.alouiadel.lidward"
        ].compactMap { $0 })

        for domain in domains {
            UserDefaults.standard.removePersistentDomain(forName: domain)
        }

        let fileManager = FileManager.default
        let savedStatePaths = [
            NSHomeDirectory() + "/Library/Saved Application State/app.lidward.savedState",
            NSHomeDirectory() + "/Library/Saved Application State/dev.alouiadel.lidward.savedState"
        ]

        for path in savedStatePaths {
            try? fileManager.removeItem(atPath: path)
        }

        let appPath = Bundle.main.bundlePath

        if appPath.hasPrefix("/Volumes/") {
            let alert = NSAlert()
            alert.messageText = "Eject the Lidward disk image"
            alert.informativeText = "Lidward removed its preferences and helper. Eject the disk image and move Lidward to the Trash."
            alert.icon = NSApp.applicationIconImage
            alert.addButton(withTitle: "Quit Lidward")
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
            NSApp.terminate(nil)
            return
        }

        scheduleBundleRemoval(at: appPath)
        NSApp.terminate(nil)
    }

    private func scheduleBundleRemoval(at path: String) {
        let parent = (path as NSString).deletingLastPathComponent
        let cleanup = """
        sleep 1
        /usr/bin/defaults delete app.lidward 2>/dev/null || true
        /usr/bin/defaults delete dev.alouiadel.lidward 2>/dev/null || true
        /bin/rm -rf \(shellQuoted(path))
        """

        if FileManager.default.isWritableFile(atPath: parent) {
            runDetached(executable: "/bin/sh", arguments: ["-c", cleanup])
        } else {
            let command = cleanup
                .split(separator: "\n")
                .map(String.init)
                .joined(separator: "; ")
            let escaped = command
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
            let appleScript = "do shell script \"\(escaped)\" with administrator privileges"

            runDetached(executable: "/usr/bin/osascript", arguments: ["-e", appleScript])
        }
    }

    private func runDetached(executable: String, arguments: [String]) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            NSLog("Lidward: uninstall cleanup failed: \(error.localizedDescription)")
        }
    }

    private func presentError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "Lidward could not uninstall completely"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.icon = NSApp.applicationIconImage
        alert.addButton(withTitle: "OK")

        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    private func shellQuoted(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}

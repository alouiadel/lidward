import AppKit
import Foundation

enum ClosedDisplayError: LocalizedError {
    case helperExited(Int32)

    var errorDescription: String? {
        switch self {
        case let .helperExited(status):
            return "The closed-display helper stopped unexpectedly (exit status \(status)). Sleep has been restored."
        }
    }
}

/// Owns the root helper that toggles `pmset -a disablesleep` while a session
/// is active. The helper watches Lidward through a pipe: if Lidward quits or
/// crashes, the pipe closes and the helper restores the previous sleep state.
final class ClosedDisplayController {
    private let session: SessionController
    private let settings: AppSettings
    private let installer: HelperInstaller

    private var process: Process?
    private var inputPipe: Pipe?
    private var errorPipe: Pipe?
    private var isStopping = false
    private var isInstalling = false
    private var isUninstalling = false
    private var isShuttingDown = false
    private var observers: [NSObjectProtocol] = []

    var onError: ((Error) -> Void)?

    var isHelperInstalled: Bool {
        installer.isInstalled
    }

    init(
        session: SessionController,
        settings: AppSettings,
        installer: HelperInstaller = HelperInstaller()
    ) {
        self.session = session
        self.settings = settings
        self.installer = installer

        observers.append(NotificationCenter.default.addObserver(
            forName: .lidwardSessionDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.update()
        })

        observers.append(NotificationCenter.default.addObserver(
            forName: .lidwardSettingsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.update()
        })

        update()
    }

    func shutdown() {
        isShuttingDown = true
        stop()
    }

    func uninstallHelper() throws {
        isUninstalling = true
        defer { isUninstalling = false }

        stop()
        try installer.uninstall()
        settings.closedDisplayModeEnabled = false
        NotificationCenter.default.post(name: .lidwardHelperStatusDidChange, object: self)
    }

    private func update() {
        guard !isShuttingDown, !isUninstalling else { return }

        guard session.isActive, settings.closedDisplayModeEnabled else {
            stop()
            return
        }

        guard process == nil, !isInstalling else { return }

        isInstalling = true
        defer { isInstalling = false }

        if !installer.isInstalled || installer.installedVersion != HelperInstaller.helperVersion {
            guard confirmInstallation() else {
                settings.closedDisplayModeEnabled = false
                return
            }
        }

        do {
            try installer.installIfNeeded()
        } catch {
            settings.closedDisplayModeEnabled = false
            onError?(error)
            return
        }

        NotificationCenter.default.post(name: .lidwardHelperStatusDidChange, object: self)
        startHelper()
    }

    private func confirmInstallation() -> Bool {
        let alert = NSAlert()
        alert.messageText = "Set up closed-display mode?"
        alert.informativeText = """
        Lidward needs a one-time administrator setup to keep your Mac awake with the lid closed.

        It installs a small root-owned helper and a sudoers rule that allows only two commands: enabling and disabling lid-close sleep. macOS will ask for your administrator password once. After that, toggling closed-display mode does not ask for a password.
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Continue")
        alert.addButton(withTitle: "Cancel")

        NSApp.activate(ignoringOtherApps: true)
        return alert.runModal() == .alertFirstButtonReturn
    }

    private func startHelper() {
        guard process == nil else { return }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        process.arguments = [
            "-n",
            HelperInstaller.helperPath,
            "--parent-pid",
            "\(getpid())"
        ]

        let input = Pipe()
        let output = Pipe()
        let error = Pipe()

        process.standardInput = input
        process.standardOutput = output
        process.standardError = error

        process.terminationHandler = { [weak self] process in
            DispatchQueue.main.async {
                self?.helperTerminated(process)
            }
        }

        do {
            try process.run()
        } catch {
            onError?(error)
            settings.closedDisplayModeEnabled = false
            return
        }

        self.process = process
        self.inputPipe = input
        self.errorPipe = error
        self.isStopping = false
    }

    private func stop() {
        guard let process, process.isRunning else {
            cleanup()
            return
        }

        isStopping = true
        try? inputPipe?.fileHandleForWriting.write(contentsOf: Data("stop\n".utf8))
        try? inputPipe?.fileHandleForWriting.close()

        // If the helper does not exit promptly, do not leave the app waiting
        // forever. The helper's state file still lets the next launch restore
        // sleep if it has to be terminated.
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            guard let self,
                  self.isStopping,
                  let process = self.process,
                  process.isRunning else {
                return
            }

            process.terminate()
        }
    }

    private func helperTerminated(_ process: Process) {
        let wasStopping = isStopping
        let status = process.terminationStatus

        cleanup()

        if wasStopping {
            update()
            return
        }

        settings.closedDisplayModeEnabled = false
        onError?(ClosedDisplayError.helperExited(status))
    }

    private func cleanup() {
        process = nil
        inputPipe = nil
        errorPipe = nil
        isStopping = false
    }

    deinit {
        stop()

        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}

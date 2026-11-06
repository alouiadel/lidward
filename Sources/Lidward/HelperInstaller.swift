import Foundation

enum HelperInstallerError: LocalizedError {
    case bundledHelperMissing
    case installFailed(String)
    case userCancelled

    var errorDescription: String? {
        switch self {
        case .bundledHelperMissing:
            return "The bundled closed-display helper could not be found."
        case let .installFailed(message):
            return message
        case .userCancelled:
            return "The administrator authorization was cancelled."
        }
    }
}

final class HelperInstaller {
    static let helperPath = "/usr/local/libexec/lidward-helper"
    static let sudoersPath = "/etc/sudoers.d/lidward"
    static let statePath = "/var/run/lidward-disablesleep.previous"
    static let helperVersion = "1.0.0"

    var isInstalled: Bool {
        FileManager.default.isExecutableFile(atPath: Self.helperPath)
            && FileManager.default.fileExists(atPath: Self.sudoersPath)
    }

    var installedVersion: String? {
        guard FileManager.default.isExecutableFile(atPath: Self.helperPath) else {
            return nil
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: Self.helperPath)
        process.arguments = ["--version"]

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }

    func installIfNeeded() throws {
        if isInstalled, installedVersion == Self.helperVersion {
            return
        }

        try install()
    }

    func install() throws {
        guard let bundledHelper = bundledHelperURL() else {
            throw HelperInstallerError.bundledHelperMissing
        }

        let user = NSUserName()
        let helperSource = shellQuoted(bundledHelper.path)
        let helperDestination = shellQuoted(Self.helperPath)
        let sudoersDestination = shellQuoted(Self.sudoersPath)

        let sudoersTemporary = Self.sudoersPath + ".tmp"
        let sudoersTemporaryQuoted = shellQuoted(sudoersTemporary)

        let script = """
        #!/bin/bash
        set -euo pipefail
        trap '/bin/rm -f \(sudoersTemporary)' EXIT
        /usr/bin/install -d -m 0755 /usr/local/libexec
        /usr/bin/install -m 0755 -o root -g wheel \(helperSource) \(helperDestination)
        cat > \(sudoersTemporaryQuoted) <<'EOF'
        \(user) ALL=(root) NOPASSWD: \(Self.helperPath) --parent-pid *, \(Self.helperPath) --restore
        EOF
        /bin/chmod 0440 \(sudoersTemporaryQuoted)
        /usr/sbin/chown root:wheel \(sudoersTemporaryQuoted)
        /usr/sbin/visudo -cf \(sudoersTemporaryQuoted)
        /bin/mv \(sudoersTemporaryQuoted) \(sudoersDestination)
        """

        try runAdminScript(script)
    }

    func uninstall() throws {
        let script = """
        #!/bin/bash
        set -euo pipefail
        /usr/bin/pmset -a disablesleep 0 || true
        /bin/rm -f \(shellQuoted(Self.sudoersPath))
        /bin/rm -f \(shellQuoted(Self.helperPath))
        /bin/rm -f \(shellQuoted(Self.statePath))
        """

        try runAdminScript(script)
    }

    /// If a previous Lidward instance crashed after enabling closed-display
    /// mode, the state file survives. Restore sleep before doing anything else.
    func restoreIfNeeded() {
        guard isInstalled,
              FileManager.default.fileExists(atPath: Self.statePath) else {
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        process.arguments = ["-n", Self.helperPath, "--restore"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        try? process.run()
        process.waitUntilExit()
    }

    private func bundledHelperURL() -> URL? {
        if let url = Bundle.main.url(forAuxiliaryExecutable: "LidwardHelper") {
            return url
        }

        let executableDirectory = URL(fileURLWithPath: CommandLine.arguments[0])
            .deletingLastPathComponent()
        let candidate = executableDirectory.appendingPathComponent("LidwardHelper")

        return FileManager.default.isExecutableFile(atPath: candidate.path) ? candidate : nil
    }

    private func runAdminScript(_ script: String) throws {
        let scriptURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("lidward-install-\(UUID().uuidString).sh")

        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: scriptURL.path
        )
        defer { try? FileManager.default.removeItem(at: scriptURL) }

        let appleScript = "do shell script \"/bin/bash '\(scriptURL.path)'\" with administrator privileges"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", appleScript]

        let errorPipe = Pipe()
        process.standardError = errorPipe
        process.standardOutput = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            throw HelperInstallerError.installFailed(error.localizedDescription)
        }

        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let data = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let message = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if message?.localizedCaseInsensitiveContains("cancel") == true {
                throw HelperInstallerError.userCancelled
            }

            throw HelperInstallerError.installFailed(
                message ?? "The installer exited with status \(process.terminationStatus)."
            )
        }
    }

    private func shellQuoted(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}

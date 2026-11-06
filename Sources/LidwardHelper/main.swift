import Darwin
import Foundation

private let helperVersion = "1.0.0"
private let previousStatePath = "/var/run/lidward-disablesleep.previous"
private let pmsetPath = "/usr/bin/pmset"

private func run(_ executable: String, arguments: [String]) -> (status: Int32, output: String) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments

    let outputPipe = Pipe()
    process.standardOutput = outputPipe
    process.standardError = outputPipe

    do {
        try process.run()
        process.waitUntilExit()
        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        return (process.terminationStatus, String(data: data, encoding: .utf8) ?? "")
    } catch {
        return (-1, error.localizedDescription)
    }
}

private func currentSleepDisabled() -> Bool {
    let result = run(pmsetPath, arguments: ["-g"])

    for line in result.output.split(separator: "\n") {
        let parts = line.split(whereSeparator: { $0 == " " || $0 == "\t" })
        if parts.count >= 2, parts[0] == "SleepDisabled" {
            return parts[1] == "1"
        }
    }

    return false
}

private func setSleepDisabled(_ disabled: Bool) -> Bool {
    let result = run(
        pmsetPath,
        arguments: ["-a", "disablesleep", disabled ? "1" : "0"]
    )

    if result.status != 0 || result.output.localizedCaseInsensitiveContains("must be run as root") {
        FileHandle.standardError.write(
            Data("LidwardHelper: pmset failed: \(result.output)\n".utf8)
        )
        return false
    }

    // pmset can report a permission error while still exiting 0, so verify the
    // setting actually changed.
    let actual = currentSleepDisabled()
    guard actual == disabled else {
        FileHandle.standardError.write(
            Data("LidwardHelper: pmset did not change SleepDisabled to \(disabled ? 1 : 0)\n".utf8)
        )
        return false
    }

    return true
}

private func readPreviousState() -> Bool? {
    guard let contents = try? String(contentsOfFile: previousStatePath, encoding: .utf8) else {
        return nil
    }

    switch contents.trimmingCharacters(in: .whitespacesAndNewlines) {
    case "1":
        return true
    case "0":
        return false
    default:
        return nil
    }
}

private func writePreviousState(_ disabled: Bool) {
    try? "\(disabled ? 1 : 0)\n".write(
        toFile: previousStatePath,
        atomically: true,
        encoding: .utf8
    )
    chmod(previousStatePath, 0o600)
}

private func restorePreviousState() {
    let previous = readPreviousState() ?? false

    if setSleepDisabled(previous) {
        try? FileManager.default.removeItem(atPath: previousStatePath)
    }
}

private func ensureEnabled() {
    if !currentSleepDisabled() {
        _ = setSleepDisabled(true)
    }
}

let arguments = CommandLine.arguments

if arguments.contains("--version") {
    print(helperVersion)
    exit(0)
}

if arguments.contains("--restore") {
    restorePreviousState()
    exit(0)
}

guard let parentIndex = arguments.firstIndex(of: "--parent-pid"),
      arguments.indices.contains(parentIndex + 1),
      let parentPID = Int32(arguments[parentIndex + 1]),
      parentPID > 1,
      kill(parentPID, 0) == 0 else {
    FileHandle.standardError.write(
        Data("Usage: LidwardHelper --parent-pid <pid> | --restore | --version\n".utf8)
    )
    exit(64)
}

let stateFileExisted = readPreviousState() != nil
if !stateFileExisted {
    writePreviousState(currentSleepDisabled())
}

guard setSleepDisabled(true) else {
    if !stateFileExisted {
        try? FileManager.default.removeItem(atPath: previousStatePath)
    }
    exit(1)
}

var descriptor = pollfd(fd: STDIN_FILENO, events: Int16(POLLIN), revents: 0)

while true {
    let result = poll(&descriptor, 1, 2000)

    if result > 0 {
        let data = FileHandle.standardInput.availableData
        if data.isEmpty {
            break
        }

        if let command = String(data: data, encoding: .utf8),
           command.contains("stop") {
            break
        }
    } else if result == 0 {
        ensureEnabled()

        if kill(parentPID, 0) != 0 {
            break
        }
    } else if errno != EINTR {
        break
    }
}

restorePreviousState()
exit(0)

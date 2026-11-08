import AppKit
import ServiceManagement

if CommandLine.arguments.contains("--unregister-login-item") {
    let status = SMAppService.mainApp.status

    if status == .notRegistered || status == .notFound {
        print("Lidward is not registered as a login item.")
        exit(0)
    }

    do {
        try SMAppService.mainApp.unregister()
        print("Removed Lidward from Login Items.")
        exit(0)
    } catch {
        FileHandle.standardError.write(
            Data("Could not remove login item: \(error.localizedDescription)\n".utf8)
        )
        exit(1)
    }
}

#if DEBUG
if CommandLine.arguments.contains("--check-updates") {
    let settings = AppSettings()
    let checker = UpdateChecker(settings: settings)
    let semaphore = DispatchSemaphore(value: 0)
    var output = "unknown"

    checker.check(force: true) { error in
        if let error {
            output = "error: \(error.localizedDescription)"
        } else if let update = checker.availableUpdate {
            output = "update available: \(update.version) — \(update.releaseURL.absoluteString)"
        } else {
            output = "up to date"
        }

        semaphore.signal()
    }

    while semaphore.wait(timeout: .now() + 0.1) == .timedOut {
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
    }

    print(output)
    exit(0)
}
#endif

let app = NSApplication.shared
let delegate = AppDelegate()

app.delegate = delegate
app.setActivationPolicy(.accessory)

#if DEBUG
if let index = CommandLine.arguments.firstIndex(of: "--render-demo"),
   CommandLine.arguments.indices.contains(index + 1) {
    DemoRenderer.render(to: CommandLine.arguments[index + 1])
    exit(0)
}

delegate.applyDebugArguments()
#endif

app.run()

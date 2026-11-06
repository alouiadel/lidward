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

let app = NSApplication.shared
let delegate = AppDelegate()

app.delegate = delegate
app.setActivationPolicy(.accessory)

#if DEBUG
delegate.applyDebugArguments()
#endif

app.run()

import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()

app.delegate = delegate
app.setActivationPolicy(.accessory)

#if DEBUG
if CommandLine.arguments.contains("--start-session") {
    delegate.startSessionForTesting()
}
#endif

app.run()

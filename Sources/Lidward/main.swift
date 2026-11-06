import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()

app.delegate = delegate
app.setActivationPolicy(.accessory)

#if DEBUG
delegate.applyDebugArguments()
#endif

app.run()

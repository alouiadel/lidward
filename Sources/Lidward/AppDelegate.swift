import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let session = SessionController()
    private var statusItemController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItemController = StatusItemController(session: session)
    }

    func applicationWillTerminate(_ notification: Notification) {
        session.stop()
    }

    #if DEBUG
    func startSessionForTesting() {
        do {
            try session.start()
        } catch {
            NSLog("Lidward: failed to start test session: \(error.localizedDescription)")
        }
    }
    #endif
}

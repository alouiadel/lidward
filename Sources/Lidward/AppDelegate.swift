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
}

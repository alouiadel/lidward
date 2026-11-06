import Darwin
import Foundation

enum ScreenLocker {
    private typealias LockScreenFunction = @convention(c) () -> Void

    static func lock() {
        guard !lockWithLoginFramework() else { return }

        lockWithCGSession()
    }

    /// `SACLockScreenImmediate` is the same private login-framework call that
    /// many menu-bar utilities use. This app is distributed outside the App
    /// Store, so the private API is acceptable here.
    private static func lockWithLoginFramework() -> Bool {
        let paths = [
            "/System/Library/PrivateFrameworks/login.framework/login",
            "/System/Library/PrivateFrameworks/login.framework/Versions/A/login",
            "/System/Library/PrivateFrameworks/login.framework/Versions/Current/login"
        ]

        for path in paths {
            guard let handle = dlopen(path, RTLD_LAZY) else { continue }
            defer { dlclose(handle) }

            guard let symbol = dlsym(handle, "SACLockScreenImmediate") else { continue }

            let lockScreen = unsafeBitCast(symbol, to: LockScreenFunction.self)
            lockScreen()
            return true
        }

        return false
    }

    private static func lockWithCGSession() {
        let path = "/System/Library/CoreServices/Menu Extras/User.menu/Contents/Resources/CGSession"

        guard FileManager.default.isExecutableFile(atPath: path) else {
            NSLog("Lidward: no screen-lock mechanism is available")
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = ["-suspend"]

        do {
            try process.run()
        } catch {
            NSLog("Lidward: CGSession failed: \(error.localizedDescription)")
        }
    }
}

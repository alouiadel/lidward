import AppKit
import CoreGraphics

/// Tracks whether the login session's screen is currently locked.
final class ScreenLockMonitor {
    private(set) var isLocked: Bool
    var onChange: ((Bool) -> Void)?

    private var observers: [NSObjectProtocol] = []
    private var timer: Timer?

    init() {
        self.isLocked = Self.currentScreenLockState()

        // Distributed notifications are the fast path, but a cheap poll keeps
        // the state correct on macOS versions where they are unreliable.
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer

        let center = DistributedNotificationCenter.default()

        observers.append(center.addObserver(
            forName: NSNotification.Name("com.apple.screenIsLocked"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.setLocked(true)
        })

        observers.append(center.addObserver(
            forName: NSNotification.Name("com.apple.screenIsUnlocked"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.setLocked(false)
        })
    }

    private func refresh() {
        setLocked(Self.currentScreenLockState())
    }

    private func setLocked(_ locked: Bool) {
        guard isLocked != locked else { return }

        isLocked = locked
        onChange?(locked)
    }

    private static func currentScreenLockState() -> Bool {
        guard let session = CGSessionCopyCurrentDictionary() as NSDictionary? else {
            return false
        }

        return session["CGSSessionScreenIsLocked"] as? Bool ?? false
    }

    deinit {
        timer?.invalidate()

        let center = DistributedNotificationCenter.default()
        for observer in observers {
            center.removeObserver(observer)
        }
    }
}

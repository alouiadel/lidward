import Foundation
import IOKit

/// Polls the root power-management domain for the clamshell state. macOS has
/// no public lid-close notification, so a one-second poll is the pragmatic
/// option.
final class LidMonitor {
    private let session: SessionController
    private let settings: AppSettings
    private let screenLockMonitor: ScreenLockMonitor

    private var timer: Timer?
    private(set) var isLidClosed: Bool

    init(
        session: SessionController,
        settings: AppSettings,
        screenLockMonitor: ScreenLockMonitor
    ) {
        self.session = session
        self.settings = settings
        self.screenLockMonitor = screenLockMonitor
        self.isLidClosed = Self.readClamshellState()

        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func tick() {
        let closed = Self.readClamshellState()
        let wasClosed = isLidClosed
        isLidClosed = closed

        guard !wasClosed, closed else { return }
        guard session.isActive, settings.lockScreenOnLidClose, !screenLockMonitor.isLocked else { return }

        ScreenLocker.lock()
    }

    private static func readClamshellState() -> Bool {
        let service = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("IOPMrootDomain")
        )
        guard service != 0 else { return false }
        defer { IOObjectRelease(service) }

        guard let value = IORegistryEntryCreateCFProperty(
            service,
            "AppleClamshellState" as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() else {
            return false
        }

        if let boolValue = value as? Bool {
            return boolValue
        }

        if let number = value as? NSNumber {
            return number.boolValue
        }

        return false
    }

    deinit {
        timer?.invalidate()
    }
}

import Foundation

/// Owns the lifetime of a keep-awake session.
///
/// Block 1 only tracks state. The IOPMAssertion calls that actually prevent
/// sleep land in the next implementation block.
final class SessionController {
    private(set) var isActive = false

    /// Called whenever the session state changes.
    var onChange: (() -> Void)?

    func start() {
        guard !isActive else { return }

        isActive = true
        onChange?()
    }

    func stop() {
        guard isActive else { return }

        isActive = false
        onChange?()
    }
}

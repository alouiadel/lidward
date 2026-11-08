import AppKit
import SwiftUI

/// The small set of visual constants that keep Lidward's UI consistent.
///
/// The app icon is warm and retro; the interface stays native but borrows the
/// same terracotta accent so the two feel related.
enum LidwardTheme {
    static let accent = Color(nsColor: NSColor(name: nil) { appearance in
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua

        return isDark
            ? NSColor(srgbRed: 0.96, green: 0.54, blue: 0.38, alpha: 1)
            : NSColor(srgbRed: 0.80, green: 0.30, blue: 0.17, alpha: 1)
    })

    static let success = Color(nsColor: .systemGreen)
    static let warning = Color(nsColor: .systemOrange)
    static let danger = Color(nsColor: .systemRed)

    /// Slightly lighter than the window in dark mode, and near-white in light
    /// mode, so cards read as raised surfaces without hard-coded greys.
    static let panel = Color(nsColor: NSColor(name: nil) { appearance in
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua

        return isDark
            ? NSColor(white: 1.0, alpha: 0.07)
            : NSColor(white: 1.0, alpha: 0.72)
    })
}

extension Color {
    /// Lidward's warm terracotta accent, tuned for light and dark mode.
    static var lidwardAccent: Color { LidwardTheme.accent }
}

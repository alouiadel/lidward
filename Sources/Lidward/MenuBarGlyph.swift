import AppKit

/// The menu-bar mark: a tiny pixel eye taken from Lidward's app icon.
///
/// It is drawn as a template image so macOS tints it correctly in light and
/// dark menu bars. The pupil is present only while a session is active.
enum MenuBarGlyph {
    static func image(active: Bool) -> NSImage {
        let size = NSSize(width: 18, height: 18)

        let image = NSImage(size: size, flipped: false) { _ in
            NSColor.black.setFill()

            // Five 2-point rows form the almond-shaped eye.
            let rows: [(x: CGFloat, width: CGFloat)] = [
                (5, 8),
                (3, 12),
                (1, 16),
                (3, 12),
                (5, 8)
            ]

            for (index, row) in rows.enumerated() {
                let y = 4 + CGFloat(4 - index) * 2

                if index == 0 || index == 4 {
                    NSRect(x: row.x, y: y, width: row.width, height: 2).fill()
                } else {
                    NSRect(x: row.x, y: y, width: 2, height: 2).fill()
                    NSRect(x: row.x + row.width - 2, y: y, width: 2, height: 2).fill()
                }
            }

            if active {
                NSRect(x: 7, y: 7, width: 4, height: 4).fill()
            }

            return true
        }

        image.isTemplate = true
        return image
    }
}

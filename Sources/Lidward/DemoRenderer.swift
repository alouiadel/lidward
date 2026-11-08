#if DEBUG
import AppKit

/// Development-only renderer for the README demo animation.
///
/// Usage: `Lidward --render-demo /tmp/lidward-frames`
///
/// It draws the menu-bar menu against a branded background and writes numbered
/// PNG frames. `scripts/render-demo.sh` assembles them into a GIF.
enum DemoRenderer {
    private static let canvasSize = NSSize(width: 600, height: 620)
    private static let canvasScale: CGFloat = 2

    private static let paper = NSColor(srgbRed: 0.949, green: 0.906, blue: 0.816, alpha: 1)
    private static let ink = NSColor(srgbRed: 0.141, green: 0.110, blue: 0.090, alpha: 1)
    private static let terracotta = NSColor(srgbRed: 0.851, green: 0.365, blue: 0.224, alpha: 1)
    private static let amber = NSColor(srgbRed: 0.890, green: 0.655, blue: 0.184, alpha: 1)

    private static let menuBarHeight: CGFloat = 28
    private static let statusItemCenter = NSPoint(x: 445, y: 606)
    private static let menuX: CGFloat = 170
    private static let menuWidth: CGFloat = 310
    private static let menuTop: CGFloat = 588
    private static let menuRowHeight: CGFloat = 27
    private static let menuSeparatorHeight: CGFloat = 9
    private static let menuStatusHeight: CGFloat = 24
    private static let menuPadding: CGFloat = 6
    private static let topRowCenter = NSPoint(x: 325, y: 568.5)
    private static let cursorRest = NSPoint(x: 535, y: 120)

    static func render(to directoryPath: String) {
        let directory = URL(fileURLWithPath: directoryPath, isDirectory: true)
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        let suite = "lidward.demo"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)

        let settings = AppSettings(defaults: defaults)
        settings.sessionDurationMinutes = SessionDuration.thirtyMinutes.minutes
        settings.showSessionTimeInMenuBar = true

        let session = SessionController(settings: settings)
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""

        let frameCount = 66
        let frameDuration = 1.0 / 10.0

        for index in 0..<frameCount {
            let startedAt = Date()

            if index == 9 {
                do {
                    try session.start(duration: .thirtyMinutes)
                } catch {
                    NSLog("Lidward demo: failed to start session: \(error.localizedDescription)")
                }
            }

            if index == 41 {
                session.stop()
            }

            let frame = renderFrame(
                index: index,
                session: session,
                settings: settings,
                version: version
            )

            if let png = frame.representation(using: .png, properties: [:]) {
                let name = String(format: "frame_%03d.png", index)
                try? png.write(to: directory.appendingPathComponent(name))
            }

            let elapsed = Date().timeIntervalSince(startedAt)
            let remaining = max(0.02, frameDuration - elapsed)
            RunLoop.main.run(until: Date().addingTimeInterval(remaining))
        }

        session.stop()
    }

    private static func renderFrame(
        index: Int,
        session: SessionController,
        settings: AppSettings,
        version: String
    ) -> NSBitmapImageRep {
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(canvasSize.width * canvasScale),
            pixelsHigh: Int(canvasSize.height * canvasScale),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )!

        let context = NSGraphicsContext(bitmapImageRep: rep)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.cgContext.scaleBy(x: canvasScale, y: canvasScale)

        let cursor = cursorPosition(for: index)
        let menuOpen = (0...8).contains(index)
            || (32...40).contains(index)
            || (58...65).contains(index)
        let topRow = NSRect(
            x: menuX,
            y: menuTop - menuPadding - menuRowHeight,
            width: menuWidth,
            height: menuRowHeight
        )
        let hoverTop = menuOpen && topRow.contains(cursor)

        drawBackground()
        drawMenuBar(session: session, menuOpen: menuOpen)
        if menuOpen {
            drawMenu(
                session: session,
                settings: settings,
                hoverTop: hoverTop
            )
        }
        drawCaption(version: version)
        drawInteractions(index: index, cursor: cursor)

        NSGraphicsContext.restoreGraphicsState()
        return rep
    }

    // MARK: - Background

    private static func drawBackground() {
        paper.setFill()
        NSRect(origin: .zero, size: canvasSize).fill()

        let glow = NSGradient(colors: [
            terracotta.withAlphaComponent(0.17),
            terracotta.withAlphaComponent(0)
        ])!
        glow.draw(
            in: NSBezierPath(ovalIn: NSRect(x: 70, y: 180, width: 480, height: 420)),
            relativeCenterPosition: NSPoint(x: -0.05, y: 0.15)
        )

        let amberGlow = NSGradient(colors: [
            amber.withAlphaComponent(0.18),
            amber.withAlphaComponent(0)
        ])!
        amberGlow.draw(
            in: NSBezierPath(ovalIn: NSRect(x: 340, y: 380, width: 300, height: 300)),
            relativeCenterPosition: NSPoint(x: 0.4, y: 0.4)
        )

        ink.withAlphaComponent(0.07).setFill()
        var y: CGFloat = 12
        while y < canvasSize.height {
            var x: CGFloat = 12
            while x < canvasSize.width {
                NSBezierPath(
                    ovalIn: NSRect(x: x, y: y, width: 2.6, height: 2.6)
                ).fill()
                x += 26
            }
            y += 26
        }
    }

    // MARK: - Menu bar

    private static func drawMenuBar(session: SessionController, menuOpen: Bool) {
        let bar = NSRect(
            x: 0,
            y: canvasSize.height - menuBarHeight,
            width: canvasSize.width,
            height: menuBarHeight
        )
        NSColor.white.withAlphaComponent(0.68).setFill()
        bar.fill()

        NSColor.black.withAlphaComponent(0.08).setStroke()
        let divider = NSBezierPath()
        divider.move(to: NSPoint(x: 0, y: bar.minY + 0.5))
        divider.line(to: NSPoint(x: canvasSize.width, y: bar.minY + 0.5))
        divider.lineWidth = 1
        divider.stroke()

        if menuOpen {
            let highlight = NSBezierPath(
                roundedRect: NSRect(x: 402, y: bar.minY + 4, width: 84, height: 20),
                xRadius: 5,
                yRadius: 5
            )
            ink.withAlphaComponent(0.07).setFill()
            highlight.fill()
        }

        drawText(
            "Lidward",
            at: NSPoint(x: 16, y: bar.minY + 7),
            font: NSFont.systemFont(ofSize: 13, weight: .semibold),
            color: ink,
            alignment: .left
        )

        MenuBarGlyph.image(active: session.isActive).draw(
            in: NSRect(x: 408, y: bar.minY + 5, width: 18, height: 18)
        )

        if session.isActive, let time = sessionTimeText(session) {
            drawText(
                time,
                at: NSPoint(x: 432, y: bar.minY + 7),
                font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium),
                color: ink.withAlphaComponent(0.82),
                alignment: .left
            )
        }

        drawSymbol("switch.2", at: NSPoint(x: 492, y: bar.minY + 6))
        drawSymbol("wifi", at: NSPoint(x: 516, y: bar.minY + 6))
        drawSymbol("battery.100", at: NSPoint(x: 540, y: bar.minY + 6))

        drawText(
            "9:41",
            at: NSPoint(x: 584, y: bar.minY + 7),
            font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular),
            color: ink,
            alignment: .right
        )
    }

    // MARK: - Menu

    private static func drawMenu(
        session: SessionController,
        settings: AppSettings,
        hoverTop: Bool
    ) {
        let itemCount = session.isActive ? 9 : 10
        let height = menuPadding * 2
            + CGFloat(itemCount) * menuRowHeight
            + menuStatusHeight
            + 5 * menuSeparatorHeight
        let panelRect = NSRect(
            x: menuX,
            y: menuTop - height,
            width: menuWidth,
            height: height
        )
        let panel = NSBezierPath(
            roundedRect: panelRect,
            xRadius: 10,
            yRadius: 10
        )

        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.24)
        shadow.shadowBlurRadius = 28
        shadow.shadowOffset = NSSize(width: 0, height: -10)
        shadow.set()
        NSColor(srgbRed: 0.985, green: 0.976, blue: 0.957, alpha: 0.98).setFill()
        panel.fill()
        NSGraphicsContext.restoreGraphicsState()

        ink.withAlphaComponent(0.13).setStroke()
        panel.lineWidth = 1
        panel.stroke()

        var y = menuTop - menuPadding

        func row(
            icon: String?,
            title: String,
            checked: Bool = false,
            shortcut: String? = nil,
            chevron: Bool = false,
            hovered: Bool = false
        ) {
            let rowRect = NSRect(
                x: menuX,
                y: y - menuRowHeight,
                width: menuWidth,
                height: menuRowHeight
            )
            let centerY = rowRect.midY

            if hovered {
                let hover = NSBezierPath(
                    roundedRect: rowRect.insetBy(dx: 4, dy: 2),
                    xRadius: 5,
                    yRadius: 5
                )
                terracotta.withAlphaComponent(0.14).setFill()
                hover.fill()
            }

            if checked {
                drawSymbol(
                    "checkmark",
                    in: NSRect(x: menuX + 13, y: centerY - 6, width: 12, height: 12),
                    fraction: 0.9
                )
            } else if let icon {
                drawSymbol(
                    icon,
                    in: NSRect(x: menuX + 13, y: centerY - 7, width: 14, height: 14),
                    fraction: 0.82
                )
            }

            drawTextVerticallyCentered(
                title,
                x: menuX + 38,
                centerY: centerY,
                font: NSFont.systemFont(ofSize: 13),
                color: ink,
                alignment: .left
            )

            if let shortcut {
                drawTextVerticallyCentered(
                    shortcut,
                    x: menuX + menuWidth - 14,
                    centerY: centerY,
                    font: NSFont.systemFont(ofSize: 12),
                    color: ink.withAlphaComponent(0.45),
                    alignment: .right
                )
            }

            if chevron {
                drawSymbol(
                    "chevron.right",
                    in: NSRect(x: menuX + menuWidth - 21, y: centerY - 5, width: 7, height: 10),
                    fraction: 0.55
                )
            }

            y -= menuRowHeight
        }

        func separator() {
            let lineY = y - menuSeparatorHeight / 2
            let line = NSBezierPath()
            line.move(to: NSPoint(x: menuX + 12, y: lineY))
            line.line(to: NSPoint(x: menuX + menuWidth - 12, y: lineY))
            line.lineWidth = 1
            ink.withAlphaComponent(0.10).setStroke()
            line.stroke()
            y -= menuSeparatorHeight
        }

        func statusRow() {
            let centerY = y - menuStatusHeight / 2
            let dot = NSBezierPath(
                ovalIn: NSRect(x: menuX + 15, y: centerY - 3, width: 6, height: 6)
            )
            (session.isActive ? NSColor.systemGreen : NSColor.tertiaryLabelColor).setFill()
            dot.fill()

            let time = sessionTimeText(session) ?? "0:00"
            let text: String

            if session.isActive {
                text = session.remainingTime != nil
                    ? "Session active  ·  \(time) left"
                    : "Session active  ·  \(time)"
            } else {
                text = "Session inactive"
            }

            drawTextVerticallyCentered(
                text,
                x: menuX + 38,
                centerY: centerY,
                font: NSFont.systemFont(ofSize: 12),
                color: ink.withAlphaComponent(0.55),
                alignment: .left
            )
            y -= menuStatusHeight
        }

        let duration = SessionDuration(minutes: settings.sessionDurationMinutes) ?? .indefinite

        row(
            icon: session.isActive ? "stop.fill" : "play.fill",
            title: session.isActive
                ? "Stop Session"
                : (duration.isIndefinite
                    ? "Start Session"
                    : "Start Session · \(duration.shortLabel)"),
            hovered: hoverTop
        )

        if !session.isActive {
            row(icon: "timer", title: "Start For", chevron: true)
        }

        separator()
        statusRow()
        separator()

        row(
            icon: "display",
            title: "Prevent Display Sleep",
            checked: !settings.displaySleepAllowed
        )
        row(icon: "lock", title: "Allow Display Sleep When Locked")
        row(icon: "clock", title: "Lock Screen After Inactivity", chevron: true)
        row(icon: "lock.fill", title: "Lock Screen When Lid Closes")

        separator()
        row(icon: "laptopcomputer", title: "Keep Awake With Lid Closed")

        separator()
        row(icon: "arrow.triangle.2.circlepath", title: "Check for Updates…")
        row(icon: "gearshape", title: "Preferences…", shortcut: "⌘,")

        separator()
        row(icon: "power", title: "Quit Lidward", shortcut: "⌘Q")
    }

    // MARK: - Caption

    private static func drawCaption(version: String) {
        let font = roundedFont(size: 15, weight: .medium)
        let text = NSMutableAttributedString(
            string: "Start a session. ",
            attributes: [.font: font, .foregroundColor: ink]
        )
        text.append(NSAttributedString(
            string: "Close the lid.",
            attributes: [.font: font, .foregroundColor: terracotta]
        ))
        text.append(NSAttributedString(
            string: " Keep working.",
            attributes: [.font: font, .foregroundColor: ink.withAlphaComponent(0.62)]
        ))

        let size = text.size()
        text.draw(at: NSPoint(x: (canvasSize.width - size.width) / 2, y: 70))

        drawText(
            "Indefinite or timed sessions — 15 minutes to 8 hours.",
            at: NSPoint(x: canvasSize.width / 2, y: 48),
            font: NSFont.systemFont(ofSize: 11),
            color: ink.withAlphaComponent(0.52),
            alignment: .center
        )

        terracotta.withAlphaComponent(0.55).setFill()
        NSRect(
            x: (canvasSize.width - 26) / 2,
            y: 94,
            width: 26,
            height: 2
        ).fill()

        guard !version.isEmpty else { return }

        let pillText = "v\(version)"
        let pillFont = NSFont.systemFont(ofSize: 10, weight: .medium)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: pillFont,
            .foregroundColor: ink.withAlphaComponent(0.55)
        ]
        let pillSize = (pillText as NSString).size(withAttributes: attributes)
        let pillRect = NSRect(
            x: (canvasSize.width - pillSize.width - 18) / 2,
            y: 16,
            width: pillSize.width + 18,
            height: 20
        )
        ink.withAlphaComponent(0.06).setFill()
        NSBezierPath(
            roundedRect: pillRect,
            xRadius: 10,
            yRadius: 10
        ).fill()
        (pillText as NSString).draw(
            at: NSPoint(
                x: pillRect.minX + 9,
                y: pillRect.minY + (pillRect.height - pillSize.height) / 2
            ),
            withAttributes: attributes
        )
    }

    // MARK: - Interaction

    private static func cursorPosition(for index: Int) -> NSPoint {
        switch index {
        case 0...7:
            return lerp(cursorRest, topRowCenter, easeOut(Double(index) / 7))
        case 8:
            return topRowCenter
        case 9...16:
            return lerp(topRowCenter, cursorRest, easeOut(Double(index - 9) / 7))
        case 17...23:
            return cursorRest
        case 24...31:
            return lerp(cursorRest, statusItemCenter, easeOut(Double(index - 24) / 7))
        case 32:
            return statusItemCenter
        case 33...39:
            return lerp(statusItemCenter, topRowCenter, easeOut(Double(index - 33) / 6))
        case 40:
            return topRowCenter
        case 41...48:
            return lerp(topRowCenter, cursorRest, easeOut(Double(index - 41) / 7))
        case 49...57:
            return lerp(cursorRest, statusItemCenter, easeOut(Double(index - 49) / 8))
        case 58:
            return statusItemCenter
        case 59...65:
            return lerp(statusItemCenter, cursorRest, easeOut(Double(index - 59) / 6))
        default:
            return cursorRest
        }
    }

    private static func drawInteractions(index: Int, cursor: NSPoint) {
        if let ripple = ripple(for: index) {
            let rect = NSRect(
                x: ripple.center.x - ripple.radius,
                y: ripple.center.y - ripple.radius,
                width: ripple.radius * 2,
                height: ripple.radius * 2
            )
            let ring = NSBezierPath(ovalIn: rect)
            ring.lineWidth = 2
            NSColor.white.withAlphaComponent(ripple.alpha).setStroke()
            ring.stroke()

            let inner = NSBezierPath(ovalIn: rect.insetBy(dx: 1, dy: 1))
            inner.lineWidth = 1
            terracotta.withAlphaComponent(ripple.alpha * 0.7).setStroke()
            inner.stroke()
        }

        drawCursor(at: cursor)
    }

    private static func ripple(
        for index: Int
    ) -> (center: NSPoint, radius: CGFloat, alpha: CGFloat)? {
        let statusRipples = [32, 58]
        for start in statusRipples where index >= start && index <= start + 2 {
            let step = index - start
            let radii: [CGFloat] = [5, 11, 17]
            let alphas: [CGFloat] = [0.9, 0.5, 0.2]
            return (statusItemCenter, radii[step], alphas[step])
        }

        if index == 8 || index == 40 {
            return (topRowCenter, 5, 0.8)
        }

        return nil
    }

    private static func drawCursor(at point: NSPoint) {
        let path = NSBezierPath()
        path.move(to: point)
        path.line(to: NSPoint(x: point.x, y: point.y - 16))
        path.line(to: NSPoint(x: point.x + 4.1, y: point.y - 12.2))
        path.line(to: NSPoint(x: point.x + 6.4, y: point.y - 17.2))
        path.line(to: NSPoint(x: point.x + 9.0, y: point.y - 16.0))
        path.line(to: NSPoint(x: point.x + 6.7, y: point.y - 11.2))
        path.line(to: NSPoint(x: point.x + 11.4, y: point.y - 11.2))
        path.close()

        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.20)
        shadow.shadowBlurRadius = 3
        shadow.shadowOffset = NSSize(width: 0, height: -1.5)
        shadow.set()

        NSColor.white.setFill()
        path.fill()
        NSGraphicsContext.restoreGraphicsState()

        NSColor.black.withAlphaComponent(0.78).setStroke()
        path.lineWidth = 1.1
        path.stroke()
    }

    // MARK: - Helpers

    private static func sessionTimeText(_ session: SessionController) -> String? {
        if let remaining = session.remainingTime {
            return formatTime(remaining)
        }

        if let elapsed = session.elapsedTime {
            return formatTime(elapsed)
        }

        return nil
    }

    private static func formatTime(_ time: TimeInterval) -> String {
        let total = max(0, Int(time))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }

        return String(format: "%d:%02d", minutes, seconds)
    }

    private static func drawSymbol(
        _ name: String,
        at point: NSPoint,
        size: CGFloat = 16,
        fraction: CGFloat = 0.78
    ) {
        guard let image = NSImage(
            systemSymbolName: name,
            accessibilityDescription: nil
        ) else {
            return
        }

        image.draw(
            in: NSRect(x: point.x, y: point.y, width: size, height: size),
            from: .zero,
            operation: .sourceOver,
            fraction: fraction
        )
    }

    private static func drawSymbol(
        _ name: String,
        in rect: NSRect,
        fraction: CGFloat
    ) {
        guard let image = NSImage(
            systemSymbolName: name,
            accessibilityDescription: nil
        ) else {
            return
        }

        image.draw(
            in: rect,
            from: .zero,
            operation: .sourceOver,
            fraction: fraction
        )
    }

    private static func drawText(
        _ text: String,
        at point: NSPoint,
        font: NSFont,
        color: NSColor,
        alignment: NSTextAlignment
    ) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color
        ]
        let size = (text as NSString).size(withAttributes: attributes)
        let x: CGFloat

        switch alignment {
        case .center:
            x = point.x - size.width / 2
        case .right:
            x = point.x - size.width
        default:
            x = point.x
        }

        (text as NSString).draw(
            at: NSPoint(x: x, y: point.y),
            withAttributes: attributes
        )
    }

    private static func drawTextVerticallyCentered(
        _ text: String,
        x: CGFloat,
        centerY: CGFloat,
        font: NSFont,
        color: NSColor,
        alignment: NSTextAlignment
    ) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color
        ]
        let size = (text as NSString).size(withAttributes: attributes)
        let originX = alignment == .right ? x - size.width : x
        let originY = centerY - size.height / 2

        (text as NSString).draw(
            at: NSPoint(x: originX, y: originY),
            withAttributes: attributes
        )
    }

    private static func roundedFont(size: CGFloat, weight: NSFont.Weight) -> NSFont {
        let base = NSFont.systemFont(ofSize: size, weight: weight)

        if let descriptor = base.fontDescriptor.withDesign(.rounded) {
            return NSFont(descriptor: descriptor, size: size) ?? base
        }

        return base
    }

    private static func lerp(_ from: NSPoint, _ to: NSPoint, _ progress: Double) -> NSPoint {
        NSPoint(
            x: from.x + (to.x - from.x) * progress,
            y: from.y + (to.y - from.y) * progress
        )
    }

    private static func easeOut(_ value: Double) -> Double {
        let clamped = min(1, max(0, value))
        return 1 - pow(1 - clamped, 3)
    }
}
#endif

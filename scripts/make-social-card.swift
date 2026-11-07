import AppKit

let width = 1200
let height = 630

let cream = NSColor(calibratedRed: 0.949, green: 0.906, blue: 0.816, alpha: 1)
let dark = NSColor(calibratedRed: 0.141, green: 0.110, blue: 0.090, alpha: 1)
let orange = NSColor(calibratedRed: 0.851, green: 0.365, blue: 0.224, alpha: 1)
let green = NSColor(calibratedRed: 0.549, green: 1.000, blue: 0.620, alpha: 1)

guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: width,
    pixelsHigh: height,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    fatalError("Could not create bitmap")
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

cream.setFill()
NSRect(x: 0, y: 0, width: width, height: height).fill()

dark.withAlphaComponent(0.08).setFill()
for x in stride(from: 24, to: width, by: 26) {
    for y in stride(from: 24, to: height, by: 26) {
        NSBezierPath(ovalIn: NSRect(x: x, y: y, width: 5, height: 5)).fill()
    }
}

let border = NSBezierPath(
    roundedRect: NSRect(x: 12, y: 12, width: width - 24, height: height - 24),
    xRadius: 38,
    yRadius: 38
)
border.lineWidth = 14
dark.setStroke()
border.stroke()

if let icon = NSImage(contentsOfFile: "assets/logo.svg") {
    icon.draw(
        in: NSRect(x: 70, y: 85, width: 460, height: 460),
        from: NSRect(origin: .zero, size: icon.size),
        operation: .sourceOver,
        fraction: 1
    )
}

func drawText(
    _ text: String,
    font: NSFont,
    color: NSColor,
    x: CGFloat,
    top: CGFloat,
    width: CGFloat,
    kern: CGFloat = 0,
    lineSpacing: CGFloat = 8
) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.lineBreakMode = .byWordWrapping
    paragraph.lineSpacing = lineSpacing

    var attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color,
        .paragraphStyle: paragraph
    ]
    if kern != 0 {
        attributes[.kern] = kern
    }

    let string = NSAttributedString(string: text, attributes: attributes)
    let bounds = string.boundingRect(
        with: NSSize(width: width, height: 1000),
        options: [.usesLineFragmentOrigin, .usesFontLeading]
    )

    string.draw(
        in: NSRect(
            x: x,
            y: CGFloat(height) - top - bounds.height,
            width: width,
            height: bounds.height
        )
    )
}

let menloBold = NSFont(name: "Menlo-Bold", size: 72) ?? NSFont.boldSystemFont(ofSize: 72)
let headlineFont = NSFont(name: "Menlo-Bold", size: 40) ?? NSFont.boldSystemFont(ofSize: 40)
let bodyFont = NSFont(name: "Menlo", size: 20) ?? NSFont.systemFont(ofSize: 20)
let smallBold = NSFont(name: "Menlo-Bold", size: 18) ?? NSFont.boldSystemFont(ofSize: 18)
let smallFont = NSFont(name: "Menlo", size: 18) ?? NSFont.systemFont(ofSize: 18)
let footerFont = NSFont(name: "Menlo-Bold", size: 20) ?? NSFont.boldSystemFont(ofSize: 20)

drawText(
    "MACOS MENU-BAR UTILITY",
    font: smallBold,
    color: orange,
    x: 580,
    top: 92,
    width: 520,
    kern: 2
)

drawText(
    "LIDWARD",
    font: menloBold,
    color: dark,
    x: 576,
    top: 126,
    width: 540,
    kern: 2,
    lineSpacing: 0
)

orange.setFill()
NSBezierPath(
    roundedRect: NSRect(x: 580, y: CGFloat(height) - 238, width: 124, height: 8),
    xRadius: 4,
    yRadius: 4
).fill()

drawText(
    "Keep your Mac awake.",
    font: headlineFont,
    color: dark,
    x: 580,
    top: 262,
    width: 560,
    lineSpacing: 4
)

drawText(
    "Even with the lid shut.",
    font: headlineFont,
    color: dark,
    x: 580,
    top: 314,
    width: 560,
    lineSpacing: 4
)

drawText(
    "A tiny menu-bar app for long builds,\ndownloads, renders, and agent sessions.",
    font: bodyFont,
    color: dark.withAlphaComponent(0.78),
    x: 580,
    top: 402,
    width: 550,
    lineSpacing: 6
)

green.setFill()
NSBezierPath(ovalIn: NSRect(x: 580, y: CGFloat(height) - 535, width: 10, height: 10)).fill()

drawText(
    "github.com/alouiadel/lidward",
    font: footerFont,
    color: dark,
    x: 600,
    top: 530,
    width: 520,
    lineSpacing: 0
)

drawText(
    "MIT · macOS 13+",
    font: smallFont,
    color: orange,
    x: 600,
    top: 566,
    width: 520,
    lineSpacing: 0
)

let pillRect = NSRect(x: 1022, y: CGFloat(height) - 108, width: 148, height: 36)
let pill = NSBezierPath(roundedRect: pillRect, xRadius: 18, yRadius: 18)
orange.setFill()
pill.fill()

let pillText = NSAttributedString(
    string: "OPEN SOURCE",
    attributes: [
        .font: NSFont(name: "Menlo-Bold", size: 14) ?? NSFont.boldSystemFont(ofSize: 14),
        .foregroundColor: cream,
        .kern: 1
    ]
)
let pillTextSize = pillText.size()
pillText.draw(
    at: NSPoint(
        x: pillRect.midX - pillTextSize.width / 2,
        y: pillRect.midY - pillTextSize.height / 2
    )
)

NSGraphicsContext.restoreGraphicsState()

guard let png = rep.representation(using: .png, properties: [:]) else {
    fatalError("Could not encode PNG")
}

try png.write(to: URL(fileURLWithPath: "assets/social-card.png"))
print("Wrote assets/social-card.png")

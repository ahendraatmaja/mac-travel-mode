// Draws the disk image window background (640 x 400 points) at 1x and 2x.
// Usage: swift make_dmg_background.swift out.png out@2x.png
// The app icon sits at (160, 190) and the Applications folder at (480, 190), measured from the
// top-left, as set in dmg-settings.py.
import AppKit

func render(scale: CGFloat, to path: String) {
    let w: CGFloat = 640, h: CGFloat = 400
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(w * scale), pixelsHigh: Int(h * scale),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: w, height: h)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    // Soft background
    NSGradient(starting: NSColor(srgbRed: 0.985, green: 0.988, blue: 1.0, alpha: 1),
               ending: NSColor(srgbRed: 0.93, green: 0.945, blue: 0.985, alpha: 1))!
        .draw(in: NSRect(x: 0, y: 0, width: w, height: h), angle: -90)

    // Arrow from the app icon to Applications (icons centred at y = 190 from the top)
    let y = h - 190
    let blue = NSColor(srgbRed: 0.27, green: 0.45, blue: 0.98, alpha: 0.85)
    blue.setStroke()
    let shaft = NSBezierPath()
    shaft.move(to: NSPoint(x: 250, y: y))
    shaft.line(to: NSPoint(x: 384, y: y))
    shaft.lineWidth = 5
    shaft.lineCapStyle = .round
    shaft.stroke()
    let head = NSBezierPath()
    head.move(to: NSPoint(x: 372, y: y + 13))
    head.line(to: NSPoint(x: 390, y: y))
    head.line(to: NSPoint(x: 372, y: y - 13))
    head.lineWidth = 5
    head.lineCapStyle = .round
    head.lineJoinStyle = .round
    head.stroke()

    // Captions
    let center = NSMutableParagraphStyle()
    center.alignment = .center
    let title: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 17, weight: .semibold),
        .foregroundColor: NSColor(srgbRed: 0.11, green: 0.12, blue: 0.16, alpha: 1),
        .paragraphStyle: center,
    ]
    let note: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 12, weight: .regular),
        .foregroundColor: NSColor(srgbRed: 0.36, green: 0.38, blue: 0.44, alpha: 1),
        .paragraphStyle: center,
    ]
    NSAttributedString(string: "Drag Travel Mode to Applications", attributes: title)
        .draw(in: NSRect(x: 0, y: 72, width: w, height: 24))
    NSAttributedString(string: "If macOS blocks the first launch: System Settings > Privacy & Security > Open Anyway",
                       attributes: note)
        .draw(in: NSRect(x: 20, y: 44, width: w - 40, height: 18))

    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
}

let args = CommandLine.arguments
render(scale: 1, to: args[1])
render(scale: 2, to: args[2])

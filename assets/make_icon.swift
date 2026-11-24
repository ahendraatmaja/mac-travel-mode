import AppKit
let size: CGFloat = 1024
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let body = NSRect(x: 100, y: 100, width: 824, height: 824)
let path = NSBezierPath(roundedRect: body, xRadius: 185, yRadius: 185)
NSGradient(starting: NSColor(srgbRed: 0.24, green: 0.56, blue: 1.0, alpha: 1), ending: NSColor(srgbRed: 0.33, green: 0.24, blue: 0.85, alpha: 1))!.draw(in: path, angle: -90)
var sym: NSImage? = nil
for name in ["suitcase.rolling.fill", "suitcase.fill", "briefcase.fill"] {
  if let s = NSImage(systemSymbolName: name, accessibilityDescription: nil) { sym = s; break }
}
let cfg = NSImage.SymbolConfiguration(pointSize: 440, weight: .semibold).applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
let img = sym!.withSymbolConfiguration(cfg)!
let s = img.size
img.draw(in: NSRect(x: (size - s.width) / 2, y: (size - s.height) / 2, width: s.width, height: s.height))
NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))

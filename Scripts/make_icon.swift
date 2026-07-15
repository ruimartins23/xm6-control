// Generates AppIcon.icns for XM6 Control.
// Run: swift Scripts/make_icon.swift
// Draws a macOS-style rounded-square icon with an indigo gradient and a headphones
// glyph, renders it at 1024pt, then emits the full .iconset and compiles it to .icns.
import AppKit

let canvas: CGFloat = 1024

func drawIcon() -> NSImage {
    let image = NSImage(size: NSSize(width: canvas, height: canvas))
    image.lockFocus()

    // macOS icons float inside the canvas with a margin (~10% each side).
    let squircleRect = NSRect(x: canvas * 0.10, y: canvas * 0.10, width: canvas * 0.80, height: canvas * 0.80)
    let radius = squircleRect.width * 0.225
    let squircle = NSBezierPath(roundedRect: squircleRect, xRadius: radius, yRadius: radius)

    // Soft drop shadow behind the squircle
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
    shadow.shadowBlurRadius = canvas * 0.02
    shadow.shadowOffset = NSSize(width: 0, height: -canvas * 0.01)
    NSGraphicsContext.saveGraphicsState()
    shadow.set()
    NSColor.black.withAlphaComponent(0.001).setFill()
    squircle.fill()
    NSGraphicsContext.restoreGraphicsState()

    // Indigo gradient fill
    let top = NSColor(calibratedRed: 0.42, green: 0.40, blue: 0.94, alpha: 1.0)
    let bottom = NSColor(calibratedRed: 0.22, green: 0.19, blue: 0.60, alpha: 1.0)
    NSGradient(colors: [top, bottom])?.draw(in: squircle, angle: -90)

    // Subtle top-edge highlight
    let highlight = NSBezierPath(roundedRect: squircleRect.insetBy(dx: canvas * 0.004, dy: canvas * 0.004), xRadius: radius, yRadius: radius)
    NSColor.white.withAlphaComponent(0.12).setStroke()
    highlight.lineWidth = canvas * 0.008
    highlight.stroke()

    // Headphones glyph, tinted white
    let config = NSImage.SymbolConfiguration(pointSize: canvas * 0.42, weight: .medium)
    if let symbol = NSImage(systemSymbolName: "headphones", accessibilityDescription: nil)?
        .withSymbolConfiguration(config) {
        let tinted = NSImage(size: symbol.size, flipped: false) { rect in
            symbol.draw(in: rect)
            NSColor.white.set()
            rect.fill(using: .sourceAtop)
            return true
        }
        let glyphSize = NSSize(width: squircleRect.width * 0.52 * (tinted.size.width / tinted.size.height),
                               height: squircleRect.width * 0.52)
        let glyphRect = NSRect(
            x: squircleRect.midX - glyphSize.width / 2,
            y: squircleRect.midY - glyphSize.height / 2,
            width: glyphSize.width,
            height: glyphSize.height
        )
        tinted.draw(in: glyphRect, from: .zero, operation: .sourceOver, fraction: 1.0)
    }

    image.unlockFocus()
    return image
}

func writePNG(_ image: NSImage, to url: URL, pixels: Int) throws {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    rep.size = NSSize(width: pixels, height: pixels)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels),
               from: NSRect(origin: .zero, size: image.size),
               operation: .copy, fraction: 1.0)
    NSGraphicsContext.restoreGraphicsState()
    try rep.representation(using: .png, properties: [:])!.write(to: url)
}

let scriptDir = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
let projectDir = scriptDir.deletingLastPathComponent()
let iconsetDir = projectDir.appendingPathComponent(".build/AppIcon.iconset")
let icnsPath = projectDir.appendingPathComponent("Sources/XM6Control/Resources/AppIcon.icns")

try? FileManager.default.removeItem(at: iconsetDir)
try FileManager.default.createDirectory(at: iconsetDir, withIntermediateDirectories: true)

let icon = drawIcon()
let sizes: [(name: String, pixels: Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]
for (name, pixels) in sizes {
    try writePNG(icon, to: iconsetDir.appendingPathComponent("\(name).png"), pixels: pixels)
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconsetDir.path, "-o", icnsPath.path]
try iconutil.run()
iconutil.waitUntilExit()
guard iconutil.terminationStatus == 0 else {
    fatalError("iconutil failed with status \(iconutil.terminationStatus)")
}
print("Wrote \(icnsPath.path)")

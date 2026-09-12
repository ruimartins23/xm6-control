import SwiftUI
import AppKit

/// Over-ear headphones drawn as a single fillable path, for the menu bar item.
///
/// Deliberately a vector shape rather than a bitmap or an SF Symbol: the menu bar
/// renders at whatever size and colour the system decides (and inverts on click and
/// under dark menu bars), so a monochrome path that fills with the ambient
/// foreground colour is the only thing that stays correct everywhere. Being one
/// combined path, including the headband, means it behaves like a template image.
///
/// Proportioned after the XM6 itself: a slim headband over tall, softly rounded
/// earcups, rather than the wide circular cups of the generic headphone symbol.
struct XM6HeadphonesGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height)

        // Headband: upper half of a circle, stroked then flattened into the fill path
        // so the whole glyph is a single shape.
        let bandRadius = s * 0.32
        let bandCenter = CGPoint(x: rect.midX, y: rect.minY + s * 0.55)
        var combined = Path { p in
            p.addArc(
                center: bandCenter,
                radius: bandRadius,
                startAngle: .degrees(180),
                endAngle: .degrees(360),
                clockwise: false
            )
        }
        .strokedPath(StrokeStyle(lineWidth: s * 0.12, lineCap: .round))

        // Earcups, hanging from the ends of the band.
        let cupWidth = s * 0.22
        let cupHeight = s * 0.40
        let cupTop = rect.minY + s * 0.46
        let corner = CGSize(width: s * 0.10, height: s * 0.10)

        for direction in [-1.0, 1.0] {
            let centerX = bandCenter.x + CGFloat(direction) * bandRadius
            combined.addRoundedRect(
                in: CGRect(
                    x: centerX - cupWidth / 2,
                    y: cupTop,
                    width: cupWidth,
                    height: cupHeight
                ),
                cornerSize: corner
            )
        }

        return combined
    }
}

extension NSImage {
    /// The glyph rasterised as a *template* image for the menu bar.
    ///
    /// A SwiftUI `Shape` used directly as a `MenuBarExtra` label renders nothing:
    /// the status item gives the label no foreground style to fill with. A template
    /// NSImage is what AppKit expects there, and it gets the system's light/dark and
    /// click-highlight inversion handled for free.
    static func xm6MenuBarIcon(size: CGFloat = 16) -> NSImage {
        let box = CGRect(x: 0, y: 0, width: size, height: size)
        // `flipped: true` matches the top-left origin the Shape is drawn against,
        // so the headband stays above the earcups.
        let image = NSImage(size: box.size, flipped: true) { rect in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            context.addPath(XM6HeadphonesGlyph().path(in: rect).cgPath)
            // Colour is irrelevant for a template image; only coverage matters.
            context.setFillColor(NSColor.black.cgColor)
            context.fillPath()
            return true
        }
        image.isTemplate = true
        return image
    }
}

/// The menu bar item's label.
struct MenuBarIcon: View {
    var body: some View {
        Image(nsImage: .xm6MenuBarIcon())
            .accessibilityLabel("XM6 Control")
    }
}

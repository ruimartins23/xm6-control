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
/// Proportioned after the XM6 itself. Three traits carry the likeness at this size,
/// and a plain semicircle-over-small-pads drawing reads as generic headphones
/// instead:
///   - the headband is slim and arches with near-vertical sides, not a semicircle
///   - the earcups are tall ovals that sit *wider* than the band, so the band looks
///     inset between them
///   - the cups hang well below the band rather than capping its ends
struct XM6HeadphonesGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height)
        let centerX = rect.midX

        // Headband: straight sides into one broad cubic across the top. A circular
        // arc gives the dome of the generic headphone symbol; the XM6's band is
        // flatter over the crown and drops almost vertically at the sides.
        let bandHalfWidth = s * 0.26
        let archTopY = rect.minY + s * 0.02
        let archShoulderY = rect.minY + s * 0.32
        // Ends deep inside the earcup so the joint is buried rather than showing a
        // visible cap where band meets cup.
        let shoulderY = rect.minY + s * 0.56
        let bandStroke = s * 0.07

        let band = Path { p in
            p.move(to: CGPoint(x: centerX - bandHalfWidth, y: shoulderY))
            p.addLine(to: CGPoint(x: centerX - bandHalfWidth, y: archShoulderY))
            p.addCurve(
                to: CGPoint(x: centerX + bandHalfWidth, y: archShoulderY),
                control1: CGPoint(x: centerX - bandHalfWidth, y: archTopY),
                control2: CGPoint(x: centerX + bandHalfWidth, y: archTopY)
            )
            p.addLine(to: CGPoint(x: centerX + bandHalfWidth, y: shoulderY))
        }
        .strokedPath(StrokeStyle(lineWidth: bandStroke, lineCap: .butt))

        // Earcups: tall ovals, set outboard of the band so the band reads as inset
        // between them, and deep enough to swallow the shoulder ends.
        let cupWidth = s * 0.32
        let cupHeight = s * 0.48
        let cupTop = rect.minY + s * 0.40
        let cupOffset = s * 0.32

        // Unioned rather than just accumulated into one path: the stroked band and the
        // cup rectangles wind in opposite directions, so overlapping them in a single
        // path punches holes where they cross instead of merging.
        var merged = band.cgPath
        for direction in [-1.0, 1.0] {
            let cupCenterX = centerX + CGFloat(direction) * cupOffset
            let cup = Path(
                roundedRect: CGRect(
                    x: cupCenterX - cupWidth / 2,
                    y: cupTop,
                    width: cupWidth,
                    height: cupHeight
                ),
                // Half the width, so the cup is a true oval-ended capsule.
                cornerRadius: cupWidth / 2
            )
            merged = merged.union(cup.cgPath)
        }

        return Path(merged)
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

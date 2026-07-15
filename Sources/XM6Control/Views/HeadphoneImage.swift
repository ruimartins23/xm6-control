import SwiftUI
import AppKit

/// The hero image at the top of the dashboard.
///
/// Prefers a user-supplied photo when one exists (so you can use your own picture of
/// your actual headphones); otherwise falls back to an original vector illustration of
/// black over-ear headphones drawn below. Photo locations checked, in order:
///   1. `headphones.png` bundled in the app's Resources (drop it into
///      `Sources/XM6Control/Resources/` and rebuild)
///   2. `~/Library/Application Support/XM6 Control/headphones.png` (no rebuild needed)
struct HeadphoneImage: View {
    var body: some View {
        if let custom = Self.customImage() {
            Image(nsImage: custom)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
        } else {
            HeadphoneIllustration()
        }
    }

    static func customImage() -> NSImage? {
        if let url = Bundle.main.url(forResource: "headphones", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            return image
        }
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        if let url = appSupport?.appendingPathComponent("XM6 Control/headphones.png"),
           let image = NSImage(contentsOf: url) {
            return image
        }
        return nil
    }
}

/// Original vector artwork: front view of black over-ear headphones.
struct HeadphoneIllustration: View {
    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            let cx = geo.size.width / 2

            ZStack {
                // Headband (outer)
                HeadbandArc(inset: 0)
                    .stroke(
                        LinearGradient(
                            colors: [Color(red: 0.24, green: 0.24, blue: 0.26), Color(red: 0.10, green: 0.10, blue: 0.12)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        style: StrokeStyle(lineWidth: s * 0.085, lineCap: .round)
                    )

                // Headband cushion (inner, slightly lighter)
                HeadbandArc(inset: s * 0.012)
                    .stroke(
                        Color(red: 0.30, green: 0.30, blue: 0.33).opacity(0.9),
                        style: StrokeStyle(lineWidth: s * 0.03, lineCap: .round)
                    )

                // Yokes connecting band ends to the cups
                Capsule()
                    .fill(Color(red: 0.16, green: 0.16, blue: 0.18))
                    .frame(width: s * 0.035, height: s * 0.10)
                    .rotationEffect(.degrees(-14))
                    .offset(x: -s * 0.315, y: s * 0.02)

                Capsule()
                    .fill(Color(red: 0.16, green: 0.16, blue: 0.18))
                    .frame(width: s * 0.035, height: s * 0.10)
                    .rotationEffect(.degrees(14))
                    .offset(x: s * 0.315, y: s * 0.02)

                earCup(size: s)
                    .rotationEffect(.degrees(-7))
                    .offset(x: -s * 0.33, y: s * 0.175)

                earCup(size: s)
                    .scaleEffect(x: -1)
                    .rotationEffect(.degrees(7))
                    .offset(x: s * 0.33, y: s * 0.175)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .aspectRatio(1.05, contentMode: .fit)
    }

    private func earCup(size s: CGFloat) -> some View {
        ZStack {
            // Cup body
            RoundedRectangle(cornerRadius: s * 0.115)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.17, green: 0.17, blue: 0.19), Color(red: 0.05, green: 0.05, blue: 0.06)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: s * 0.235, height: s * 0.335)
                .shadow(color: .black.opacity(0.35), radius: s * 0.02, y: s * 0.012)

            // Soft top-edge sheen
            RoundedRectangle(cornerRadius: s * 0.115)
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.16), .clear],
                        startPoint: .top,
                        endPoint: .center
                    ),
                    lineWidth: s * 0.008
                )
                .frame(width: s * 0.235, height: s * 0.335)

            // Diagonal highlight
            Ellipse()
                .fill(.white.opacity(0.05))
                .frame(width: s * 0.10, height: s * 0.22)
                .rotationEffect(.degrees(18))
                .offset(x: -s * 0.045, y: -s * 0.05)
        }
    }
}

/// Top arc of the headband.
private struct HeadbandArc: Shape {
    var inset: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = min(rect.width, rect.height)
        path.addArc(
            center: CGPoint(x: rect.midX, y: rect.midY + s * 0.16),
            radius: s * 0.335 - inset,
            startAngle: .degrees(197),
            endAngle: .degrees(343),
            clockwise: false
        )
        return path
    }
}

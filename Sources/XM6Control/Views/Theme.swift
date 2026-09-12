import SwiftUI
import AppKit

/// Surface tones that adapt to the system appearance.
///
/// These were hardcoded as black and white overlays, which worked in dark mode and
/// broke in light: a well filled with 16% black sat on a light card as a heavy grey
/// blob, so unselected controls looked as prominent as the selected one. Every value
/// here resolves per appearance instead.
enum Surface {
    /// Recessed fill for an unselected control.
    static let well = dynamic(dark: .init(white: 0, alpha: 0.20), light: .init(white: 0, alpha: 0.055))
    /// Upper edge of a recess. Darker than the fill is what makes it read as sunken.
    static let wellEdgeTop = dynamic(dark: .init(white: 0, alpha: 0.34), light: .init(white: 0, alpha: 0.13))
    /// Lower edge of a recess, catching light from above.
    static let wellEdgeBottom = dynamic(dark: .init(white: 1, alpha: 0.10), light: .init(white: 1, alpha: 0.85))

    /// Lit upper edge of a raised control.
    static let raisedEdgeTop = dynamic(dark: .init(white: 1, alpha: 0.42), light: .init(white: 1, alpha: 0.50))
    /// Shaded lower edge of a raised control.
    static let raisedEdgeBottom = dynamic(dark: .init(white: 1, alpha: 0.05), light: .init(white: 0, alpha: 0.10))

    /// Specular hairline along the top of a card.
    static let cardEdgeTop = dynamic(dark: .init(white: 1, alpha: 0.20), light: .init(white: 1, alpha: 0.90))
    /// The same hairline where it falls away down the sides.
    static let cardEdgeBottom = dynamic(dark: .init(white: 0, alpha: 0.12), light: .init(white: 0, alpha: 0.07))

    /// Hairline between rows.
    static let separator = Color(nsColor: .separatorColor)

    /// Card elevation. Light appearance needs far less: the same shadow that reads as
    /// depth on a dark panel looks like grime on a white one.
    static var cardShadowContact: Color {
        dynamic(dark: .init(white: 0, alpha: 0.24), light: .init(white: 0, alpha: 0.10))
    }
    static var cardShadowAmbient: Color {
        dynamic(dark: .init(white: 0, alpha: 0.18), light: .init(white: 0, alpha: 0.07))
    }
    static var pressShadow: Color {
        dynamic(dark: .init(white: 0, alpha: 0.34), light: .init(white: 0, alpha: 0.18))
    }

    private static func dynamic(dark: NSColor, light: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
        })
    }
}

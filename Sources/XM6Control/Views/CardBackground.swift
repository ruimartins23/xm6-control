import SwiftUI

extension Color {
    /// Single accent for selection and emphasis, deliberately the *system* accent
    /// rather than a fixed hue: macOS users expect selection to follow their
    /// System Settings choice, and a hardcoded indigo reads as a generic app
    /// default instead of a Mac app.
    static let brand = Color.accentColor
}

/// One corner-radius scale for the whole app. Two shapes sit outside it on purpose:
/// status badges are capsules (battery, "Play here"), and the three-way mode
/// selectors are circles to match the iconography of Sony's own app. Everything
/// else uses these two values.
enum Radius {
    /// Elevated surfaces. 12 rather than a phone-sized 20: macOS windows are
    /// denser and large radii make panels look like iOS sheets.
    static let card: CGFloat = 12
    /// Chips, wells, and inline controls.
    static let control: CGFloat = 8
}

/// Liquid Glass surface where the OS supports it (macOS 26+), with a hand-tuned
/// glassy material fallback on older systems.
struct GlassSurface: ViewModifier {
    var cornerRadius: CGFloat = Radius.card

    func body(content: Content) -> some View {
        base(content: content)
            // Specular edge: a hairline that is bright along the top and fades down the
            // sides, which is how every macOS material catches light. Without it the
            // card is a flat rectangle of slightly different grey.
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Surface.cardEdgeTop, Surface.cardEdgeBottom],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            )
            // Elevation. Two shadows rather than one: a tight contact shadow that
            // separates the card from the panel, and a wider soft one for depth.
            .shadow(color: Surface.cardShadowContact, radius: 2, y: 1)
            .shadow(color: Surface.cardShadowAmbient, radius: 14, y: 6)
    }

    @ViewBuilder
    private func base(content: Content) -> some View {
        // `#available` is a runtime check, so it still requires `glassEffect` to exist at
        // compile time -- which it doesn't on SDKs older than macOS 26. The compiler guard
        // keeps the project buildable on earlier Xcode versions.
        #if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            content
                .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            fallbackSurface(content: content)
        }
        #else
        fallbackSurface(content: content)
        #endif
    }

    private func fallbackSurface(content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
    }
}

extension View {
    func glassSurface(cornerRadius: CGFloat = Radius.card) -> some View {
        modifier(GlassSurface(cornerRadius: cornerRadius))
    }
}

/// The selection treatment shared by every pick-one control in the app: mode
/// selectors, equalizer chips, and the menu bar panel's buttons.
///
/// Selected reads as a raised, top-lit button; unselected as a well pressed into
/// the surface. Keeping it in one place is what stops the panel and the window
/// drifting into different visual languages, and it means state is a physical
/// difference rather than only a change of colour.
struct ControlSurface<S: InsettableShape>: ViewModifier {
    let shape: S
    let isSelected: Bool

    func body(content: Content) -> some View {
        content
            .background(
                shape.fill(
                    isSelected
                        ? AnyShapeStyle(
                            LinearGradient(
                                colors: [Color.brand, Color.brand.opacity(0.80)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        : AnyShapeStyle(Surface.well)
                )
                .shadow(color: isSelected ? Surface.pressShadow : .clear, radius: 4, y: 2)
            )
            .overlay(
                shape.strokeBorder(
                    LinearGradient(
                        colors: isSelected
                            // Lit along the top edge, like a key-lit control.
                            ? [Surface.raisedEdgeTop, Surface.raisedEdgeBottom]
                            // Dark along the top is what makes a recess read as sunken.
                            : [Surface.wellEdgeTop, Surface.wellEdgeBottom],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
            )
    }
}

extension View {
    func controlSurface<S: InsettableShape>(_ shape: S, isSelected: Bool) -> some View {
        modifier(ControlSurface(shape: shape, isSelected: isSelected))
    }
}

/// A rounded glass card container. Reserved for groups that genuinely deserve their
/// own elevated surface: related controls that are grouped inside a card use
/// `CardSection` instead, so secondary settings don't each spawn a panel and flatten
/// the hierarchy.
struct Card<Content: View>: View {
    let title: String?
    let icon: String?
    @ViewBuilder let content: Content

    init(_ title: String? = nil, icon: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                SectionLabel(title: title, icon: icon, font: .headline, prominent: true)
            }
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSurface(cornerRadius: Radius.card)
        .hoverLift()
    }
}

/// Heading for a card or a section. The glyph is not decoration: with several
/// groups on one surface it is what lets you find the one you want without
/// reading every label.
struct SectionLabel: View {
    let title: String
    let icon: String?
    var font: Font = .subheadline.weight(.semibold)
    /// Card headings are the top of the hierarchy and take the primary colour;
    /// sections nested inside a card step down to secondary.
    var prominent: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            if let icon {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(Color.brand)
                    .frame(width: 14)
            }
            Text(title)
                .font(font)
                .foregroundStyle(prominent ? .primary : .secondary)
        }
    }
}

/// A labeled group of controls *inside* a card. Lets several related settings share
/// one surface, which is what keeps the dashboard from being a stack of identical
/// panels with no visual ranking.
struct CardSection<Content: View>: View {
    let title: String
    let icon: String?
    @ViewBuilder let content: Content

    init(_ title: String, icon: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(title: title, icon: icon)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Shown inside a card when the headphones didn't answer the initial state query for
/// this feature. Controls below it still work (writes are independent of reads).
struct StateNotReportedBanner: View {
    var body: some View {
        Label("Current state not reported. Controls below still work.", systemImage: "info.circle")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct LoadingRow: View {
    var body: some View {
        HStack {
            Spacer()
            ProgressView()
                .controlSize(.small)
            Spacer()
        }
        .padding(.vertical, 10)
    }
}


/// A settings row: label left, control right, the way System Settings lays one out.
/// Controls previously sat immediately after their label with the rest of the row
/// empty, which read as unfinished rather than deliberate.
struct SettingsRow<Control: View>: View {
    let label: String
    @ViewBuilder let control: Control

    init(_ label: String, @ViewBuilder control: () -> Control) {
        self.label = label
        self.control = control()
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
            Spacer(minLength: 12)
            control
        }
        .frame(minHeight: 22)
    }
}

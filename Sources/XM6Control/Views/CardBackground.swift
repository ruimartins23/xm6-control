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
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            )
            // Shadow tinted toward the window background rather than pure black,
            // so the card doesn't look pasted onto the panel.
            .shadow(color: Color.black.opacity(0.08), radius: 10, y: 3)
    }
}

extension View {
    func glassSurface(cornerRadius: CGFloat = Radius.card) -> some View {
        modifier(GlassSurface(cornerRadius: cornerRadius))
    }
}

/// A rounded glass card container. Reserved for groups that genuinely deserve their
/// own elevated surface: related controls that are grouped inside a card use
/// `CardSection` instead, so secondary settings don't each spawn a panel and flatten
/// the hierarchy.
struct Card<Content: View>: View {
    let title: String?
    @ViewBuilder let content: Content

    init(_ title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSurface(cornerRadius: Radius.card)
    }
}

/// A labeled group of controls *inside* a card. Lets several related settings share
/// one surface, which is what keeps the dashboard from being a stack of identical
/// panels with no visual ranking.
struct CardSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(nil)
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

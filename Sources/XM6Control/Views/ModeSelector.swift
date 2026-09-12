import SwiftUI

/// The three-way circular selector used for both ambient sound modes and listening
/// modes. Those two controls were previously separate near-identical copies, which
/// meant every visual or accessibility fix had to be made twice.
///
/// Circles rather than the app's usual corner radius is a deliberate exception to the
/// shape scale: it matches the iconography of Sony's own app, which is what makes the
/// control recognisable to someone coming from there.
struct ModeSelector<Value: Hashable>: View {
    struct Option: Identifiable {
        let value: Value
        /// May contain a newline for a two-line caption; the accessibility label
        /// flattens it back to one line.
        let title: String
        let icon: String

        var id: Value { value }

        init(value: Value, title: String, icon: String) {
            self.value = value
            self.title = title
            self.icon = icon
        }
    }

    let options: [Option]
    let selection: Value
    let select: (Value) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options) { option in
                ModeSelectorButton(
                    option: option,
                    isSelected: option.value == selection,
                    select: select
                )
                // Equal shares of the card width rather than a cluster in the middle:
                // the window is resizable, and a centred huddle leaves the card looking
                // half-empty as soon as it's widened.
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ModeSelectorButton<Value: Hashable>: View {
    let option: ModeSelector<Value>.Option
    let isSelected: Bool
    let select: (Value) -> Void

    /// Flattened caption, so VoiceOver reads "Noise Canceling" rather than pausing
    /// mid-label, and so icon-only options (a bare xmark for "Off") are announced.
    private var accessibilityName: String {
        option.title.replacingOccurrences(of: "\n", with: " ")
    }

    var body: some View {
        Button {
            select(option.value)
        } label: {
            VStack(spacing: 7) {
                Image(systemName: option.icon)
                    .font(.system(size: 19, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.white : Color.primary.opacity(0.75))
                    .frame(width: 54, height: 54)
                    .controlSurface(Circle(), isSelected: isSelected)

                Text(option.title)
                    .font(.caption2.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(accessibilityName)
        .accessibilityLabel(accessibilityName)
        // Selection is communicated to assistive tech as a trait, not inferred from
        // the fill color, and the caption weight carries it visually for anyone who
        // can't distinguish the accent fill.
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

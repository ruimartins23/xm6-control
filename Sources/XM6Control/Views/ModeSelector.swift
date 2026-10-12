import SwiftUI

/// The three-way circular selector used for both ambient sound modes and listening
/// modes.
///
/// Circles match the iconography of Sony's own app, which is what makes the control
/// recognisable to someone coming from there. Each circle is interactive Liquid Glass;
/// the selected one is tinted with the system accent, and the tint morphs between
/// circles because they share one glass container.
struct ModeSelector<Value: Hashable>: View {
    struct Option: Identifiable {
        let value: Value
        let title: String
        let icon: String

        var id: Value { value }
    }

    let options: [Option]
    let selection: Value
    let select: (Value) -> Void
    var diameter: CGFloat = 52

    var body: some View {
        GlassEffectContainer(spacing: 16) {
            HStack(spacing: 0) {
                ForEach(options) { option in
                    button(for: option)
                        // Equal shares of the row rather than a cluster in the middle,
                        // so the control fills the section at any window width.
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func button(for option: Option) -> some View {
        let isSelected = option.value == selection
        return Button {
            withAnimation(Motion.transition) { select(option.value) }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: option.icon)
                    .font(.system(size: diameter * 0.36, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.white : Color.primary)
                    .frame(width: diameter, height: diameter)
                    .glassEffect(
                        isSelected ? .regular.tint(.accentColor).interactive() : .regular.interactive(),
                        in: .circle
                    )

                Text(option.title)
                    .font(.caption.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .help(option.title)
        .accessibilityLabel(option.title)
        // Selection is a trait for assistive tech, not inferred from the tint, and the
        // caption weight carries it for anyone who can't distinguish the accent.
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

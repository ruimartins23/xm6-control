import SwiftUI

/// The pick-one control used for ambient sound modes and listening modes.
///
/// This was three 54pt circles with two-line captions spread across the card, which
/// is the idiom of Sony's phone app. On a desktop it cost roughly 130pt of height for
/// a three-way choice and left the card looking mostly empty, and a Mac app expresses
/// an exclusive choice as a segmented control. The Sony glyphs are kept inside the
/// segments, so the control is still recognisable to someone arriving from that app.
struct ModeSelector<Value: Hashable>: View {
    struct Option: Identifiable {
        let value: Value
        let title: String
        let icon: String

        var id: Value { value }

        init(value: Value, title: String, icon: String) {
            self.value = value
            // Two-line captions were needed when each option was a circle. In a
            // segment the label sits beside the glyph on one line.
            self.title = title.replacingOccurrences(of: "\n", with: " ")
            self.icon = icon
        }
    }

    let options: [Option]
    let selection: Value
    let select: (Value) -> Void

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options) { option in
                segment(option)
            }
        }
        .padding(2)
        // The track is the recess; the selected segment is what sits raised inside it.
        .background(
            RoundedRectangle(cornerRadius: Radius.control + 2)
                .fill(Surface.well)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.control + 2).strokeBorder(
                LinearGradient(
                    colors: [Surface.wellEdgeTop, Surface.wellEdgeBottom],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: 1
            )
        )
        .animation(Motion.transition, value: selection)
    }

    private func segment(_ option: Option) -> some View {
        let isSelected = option.value == selection

        return Button {
            select(option.value)
        } label: {
            HStack(spacing: 5) {
                Image(systemName: option.icon)
                    .font(.system(size: 12, weight: .medium))
                Text(option.title)
                    .font(.callout.weight(isSelected ? .semibold : .regular))
                    .lineLimit(1)
                    // "Background Music" is the longest label; let it shrink rather
                    // than truncate in a narrow window.
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .foregroundStyle(isSelected ? Color.white : Color.primary.opacity(0.85))
            .background(selectedFill(isSelected))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle(scale: 0.97))
        .help(option.title)
        .accessibilityLabel(option.title)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    @ViewBuilder
    private func selectedFill(_ isSelected: Bool) -> some View {
        if isSelected {
            RoundedRectangle(cornerRadius: Radius.control)
                .fill(
                    LinearGradient(
                        colors: [Color.brand, Color.brand.opacity(0.84)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.control).strokeBorder(
                        LinearGradient(
                            colors: [Surface.raisedEdgeTop, Surface.raisedEdgeBottom],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
                )
                .shadow(color: Surface.pressShadow, radius: 3, y: 1)
        }
    }
}

import SwiftUI
import SonyHeadphonesKit

/// Equalizer preset chips. A section rather than its own card, sharing `SoundCard`
/// with the listening mode.
struct EqualizerSection: View {
    @EnvironmentObject private var controller: HeadphonesController

    private let columns = [GridItem(.adaptive(minimum: 92), spacing: 6)]

    private var effectivePresetCode: UInt8? {
        controller.equalizer?.presetCode ?? (controller.initialStateTimedOut ? EqualizerPreset.off.rawValue : nil)
    }

    var body: some View {
        CardSection("Equalizer") {
            if let presetCode = effectivePresetCode {
                VStack(alignment: .leading, spacing: 8) {
                    if controller.equalizer == nil {
                        StateNotReportedBanner()
                    }

                    LazyVGrid(columns: columns, spacing: 6) {
                        ForEach(EqualizerPreset.allCases) { option in
                            presetChip(option, isSelected: option.rawValue == presetCode)
                        }
                    }

                    if EqualizerPreset(rawValue: presetCode) == nil {
                        Text("A personalized preset is active, set in the official app. Picking one above replaces it.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            } else {
                LoadingRow()
            }
        }
    }

    private func presetChip(_ preset: EqualizerPreset, isSelected: Bool) -> some View {
        Button {
            controller.setEqualizerPreset(preset)
        } label: {
            Text(preset.label)
                .font(.caption.weight(isSelected ? .semibold : .regular))
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: Radius.control)
                        .fill(isSelected ? AnyShapeStyle(Color.brand) : AnyShapeStyle(Color.primary.opacity(0.06)))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.control).strokeBorder(
                        isSelected ? Color.clear : Color.primary.opacity(0.10),
                        lineWidth: 1
                    )
                )
                .foregroundStyle(isSelected ? Color.white : Color.primary.opacity(0.85))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(preset.label) equalizer preset")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

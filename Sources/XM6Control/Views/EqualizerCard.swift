import SwiftUI
import SonyHeadphonesKit

struct EqualizerCard: View {
    @EnvironmentObject private var controller: HeadphonesController

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: 8)]

    private var effectivePresetCode: UInt8? {
        controller.equalizer?.presetCode ?? (controller.initialStateTimedOut ? EqualizerPreset.off.rawValue : nil)
    }

    var body: some View {
        Card("Equalizer") {
            if let presetCode = effectivePresetCode {
                VStack(alignment: .leading, spacing: 12) {
                    if controller.equalizer == nil {
                        StateNotReportedBanner()
                    }

                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(EqualizerPreset.allCases) { option in
                            presetChip(option, isSelected: option.rawValue == presetCode)
                        }
                    }

                    if EqualizerPreset(rawValue: presetCode) == nil {
                        Text("A personalized preset is active (set in the official app). Picking one above replaces it.")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
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
                .padding(.vertical, 7)
                .background(
                    Capsule().fill(
                        isSelected
                            ? AnyShapeStyle(
                                LinearGradient(
                                    colors: [.brand, .brand.opacity(0.72)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            : AnyShapeStyle(Color.primary.opacity(0.06))
                    )
                )
                .overlay(
                    Capsule().strokeBorder(
                        isSelected ? Color.clear : Color.primary.opacity(0.10),
                        lineWidth: 1
                    )
                )
                .foregroundStyle(isSelected ? Color.white : Color.primary.opacity(0.8))
        }
        .buttonStyle(.plain)
    }
}

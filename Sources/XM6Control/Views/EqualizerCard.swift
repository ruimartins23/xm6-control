import SwiftUI
import SonyHeadphonesKit

/// Equalizer preset chips, plus the band faders when the custom preset is active.
/// A section rather than its own card, sharing `SoundCard` with the listening mode.
struct EqualizerSection: View {
    @EnvironmentObject private var controller: HeadphonesController

    private let columns = [GridItem(.adaptive(minimum: 92), spacing: 6)]

    private var effectivePresetCode: UInt8? {
        controller.equalizer?.presetCode ?? (controller.initialStateTimedOut ? EqualizerPreset.off.rawValue : nil)
    }

    /// The curve the faders edit. The headphones report ten bands; if a reply hasn't
    /// arrived yet, start from flat so the faders are still usable.
    private var bands: [Int] {
        let reported = controller.equalizer?.bands ?? []
        guard reported.count == SonyCommands.defaultBandCount else {
            return Array(repeating: 0, count: SonyCommands.defaultBandCount)
        }
        return reported
    }

    private var isCustomActive: Bool {
        effectivePresetCode == EqualizerPreset.custom.rawValue
    }

    var body: some View {
        CardSection("Equalizer") {
            if let presetCode = effectivePresetCode {
                VStack(alignment: .leading, spacing: 10) {
                    if controller.equalizer == nil {
                        StateNotReportedBanner()
                    }

                    LazyVGrid(columns: columns, spacing: 6) {
                        ForEach(EqualizerPreset.allCases) { option in
                            presetChip(option, isSelected: option.rawValue == presetCode)
                        }
                    }

                    if isCustomActive {
                        customBands
                            .transition(.opacity)
                    } else if EqualizerPreset(rawValue: presetCode) == nil {
                        Text("A personalized preset is active, set in the official app. Picking one above replaces it.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .animation(.easeInOut(duration: 0.18), value: isCustomActive)
            } else {
                LoadingRow()
            }
        }
    }

    // MARK: - Custom band faders

    private var customBands: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()

            HStack(alignment: .bottom, spacing: 2) {
                ForEach(Array(bands.enumerated()), id: \.offset) { index, gain in
                    bandFader(index: index, gain: gain)
                }
            }
            .frame(maxWidth: .infinity)

            HStack {
                Text("Low")
                Spacer()
                Text("High")
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)

            Button("Reset to flat") {
                controller.setEqualizerBands(
                    Array(repeating: 0, count: SonyCommands.defaultBandCount)
                )
            }
            .controlSize(.small)
            .disabled(bands.allSatisfy { $0 == 0 })
        }
    }

    private func bandFader(index: Int, gain: Int) -> some View {
        VStack(spacing: 3) {
            Text(gain > 0 ? "+\(gain)" : "\(gain)")
                .font(.system(size: 9).monospacedDigit())
                .foregroundStyle(gain == 0 ? .tertiary : .secondary)

            VerticalFader(
                value: gain,
                range: SonyCommands.bandGainRange
            ) { newGain in
                var updated = bands
                updated[index] = newGain
                controller.setEqualizerBands(updated)
            }
            .frame(width: 24, height: 86)
            .accessibilityLabel("Band \(index + 1) of \(bands.count)")
            .accessibilityValue("\(gain)")

            Text("\(index + 1)")
                .font(.system(size: 9).monospacedDigit())
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Presets

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

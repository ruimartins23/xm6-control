import SwiftUI
import SonyHeadphonesKit

/// Listening mode and equalizer. Both answer "how should this sound", so they share
/// one section.
struct SoundSection: View {
    @EnvironmentObject private var controller: HeadphonesController

    private var effectiveMode: ListeningMode? {
        controller.listeningMode ?? (controller.initialStateTimedOut ? .standard : nil)
    }

    private var effectivePresetCode: UInt8? {
        controller.equalizer?.presetCode ?? (controller.initialStateTimedOut ? EqualizerPreset.off.rawValue : nil)
    }

    /// The curve the faders edit. The headphones report ten bands; until a reply
    /// arrives, start from flat so the faders are still usable.
    private var bands: [Int] {
        let reported = controller.equalizer?.bands ?? []
        guard reported.count == SonyCommands.defaultBandCount else {
            return Array(repeating: 0, count: SonyCommands.defaultBandCount)
        }
        return reported
    }

    var body: some View {
        Section("Sound") {
            if let mode = effectiveMode {
                if controller.listeningMode == nil {
                    StateNotReportedNote()
                }

                ModeSelector(
                    options: [
                        .init(value: .standard, title: "Standard", icon: "music.note"),
                        .init(value: .backgroundMusic, title: "Background Music", icon: "sofa"),
                        .init(value: .cinema, title: "Cinema", icon: "film"),
                    ],
                    selection: mode,
                    select: { controller.setListeningMode($0) },
                    diameter: 44
                )
                .padding(.vertical, 4)

                if mode == .backgroundMusic {
                    Picker("Speaker distance", selection: Binding(
                        get: { controller.bgmRoomSize ?? .middle },
                        set: { controller.setBGMRoomSize($0) }
                    )) {
                        ForEach(BGMRoomSize.allCases) { size in
                            Text(size.label).tag(size)
                        }
                    }
                }
            } else {
                LoadingRow()
            }

            if let presetCode = effectivePresetCode {
                equalizer(presetCode: presetCode)
            }
        }
    }

    @ViewBuilder
    private func equalizer(presetCode: UInt8) -> some View {
        // A Menu-backed picker can't show a value outside the enum, and the device can
        // report a personalized preset id set in Sony's app. Show that as its own
        // label instead of pretending the equalizer is off.
        let known = EqualizerPreset(rawValue: presetCode)

        Picker("Equalizer", selection: Binding(
            get: { known },
            set: { if let preset = $0 { controller.setEqualizerPreset(preset) } }
        )) {
            if known == nil {
                Text("Personalized").tag(EqualizerPreset?.none)
            }
            ForEach(EqualizerPreset.allCases) { preset in
                Text(preset.label).tag(Optional(preset))
            }
        }

        if known == .custom {
            customBands
        }
    }

    private var customBands: some View {
        VStack(spacing: 8) {
            HStack(alignment: .bottom, spacing: 0) {
                ForEach(Array(bands.enumerated()), id: \.offset) { index, gain in
                    VStack(spacing: 4) {
                        Text(gain > 0 ? "+\(gain)" : "\(gain)")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(gain == 0 ? .tertiary : .secondary)

                        VerticalFader(value: gain, range: SonyCommands.bandGainRange) { newGain in
                            var updated = bands
                            updated[index] = newGain
                            controller.setEqualizerBands(updated)
                        }
                        .frame(width: 24, height: 96)
                        .accessibilityLabel("Band \(index + 1) of \(bands.count)")
                        .accessibilityValue("\(gain)")
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            HStack {
                Text("Low")
                Spacer()
                Button("Reset to Flat") {
                    controller.setEqualizerBands(Array(repeating: 0, count: SonyCommands.defaultBandCount))
                }
                .buttonStyle(.glass)
                .controlSize(.small)
                .disabled(bands.allSatisfy { $0 == 0 })
                Spacer()
                Text("High")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

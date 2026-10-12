import SwiftUI
import SonyHeadphonesKit

struct NoiseControlSection: View {
    @EnvironmentObject private var controller: HeadphonesController

    private var effectiveState: AmbientSoundState? {
        controller.ambientSound ?? (controller.initialStateTimedOut ? AmbientSoundState() : nil)
    }

    var body: some View {
        Section("Noise Control") {
            if let state = effectiveState {
                if controller.ambientSound == nil {
                    StateNotReportedNote()
                }

                ModeSelector(
                    options: [
                        .init(value: .noiseCancelling, title: "Noise Canceling", icon: "person.wave.2.fill"),
                        .init(value: .ambientSound, title: "Ambient Sound", icon: "waveform.and.person.filled"),
                        .init(value: .off, title: "Off", icon: "xmark"),
                    ],
                    selection: state.mode,
                    select: { mode in
                        var updated = state
                        updated.mode = mode
                        controller.setAmbientSound(updated)
                    }
                )
                .padding(.vertical, 6)

                if state.mode == .ambientSound {
                    LabeledContent("Ambient level") {
                        HStack(spacing: 8) {
                            Slider(
                                value: Binding(
                                    get: { Double(state.level) },
                                    set: { newValue in
                                        var updated = state
                                        updated.level = Int(newValue.rounded())
                                        controller.setAmbientSound(updated)
                                    }
                                ),
                                in: 0...20,
                                step: 1
                            )
                            .frame(maxWidth: 200)
                            .accessibilityLabel("Ambient sound level")

                            Text("\(state.level)")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                                .frame(width: 20, alignment: .trailing)
                        }
                    }

                    Toggle("Focus on Voice", isOn: Binding(
                        get: { state.focusOnVoice },
                        set: { newValue in
                            var updated = state
                            updated.focusOnVoice = newValue
                            controller.setAmbientSound(updated)
                        }
                    ))
                }
            } else {
                LoadingRow()
            }
        }
    }
}

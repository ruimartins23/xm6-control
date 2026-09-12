import SwiftUI
import SonyHeadphonesKit

struct NoiseControlCard: View {
    @EnvironmentObject private var controller: HeadphonesController

    private var effectiveState: AmbientSoundState? {
        controller.ambientSound ?? (controller.initialStateTimedOut ? AmbientSoundState() : nil)
    }

    var body: some View {
        Card("Ambient Sound Control", icon: "waveform") {
            if let state = effectiveState {
                VStack(spacing: 14) {
                    if controller.ambientSound == nil {
                        StateNotReportedBanner()
                    }

                    ModeSelector(
                        options: [
                            .init(value: .noiseCancelling, title: "Noise\nCanceling", icon: "person.wave.2.fill"),
                            .init(value: .ambientSound, title: "Ambient\nSound", icon: "waveform.and.person.filled"),
                            .init(value: .off, title: "Off", icon: "xmark"),
                        ],
                        selection: state.mode,
                        select: { mode in
                            var updated = state
                            updated.mode = mode
                            controller.setAmbientSound(updated)
                        }
                    )

                    if state.mode == .ambientSound {
                        ambientDetail(state: state)
                            .transition(.opacity)
                    }
                }
                .animation(Motion.transition, value: state.mode)
            } else {
                LoadingRow()
            }
        }
    }

    private func ambientDetail(state: AmbientSoundState) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()

            HStack(spacing: 10) {
                Text("Level")
                    .font(.caption)
                    .foregroundStyle(.secondary)

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
                .accessibilityLabel("Ambient sound level")

                Text("\(state.level)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 18, alignment: .trailing)
            }

            Toggle("Focus on Voice", isOn: Binding(
                get: { state.focusOnVoice },
                set: { newValue in
                    var updated = state
                    updated.focusOnVoice = newValue
                    controller.setAmbientSound(updated)
                }
            ))
            .toggleStyle(.switch)
            .controlSize(.small)
        }
    }
}

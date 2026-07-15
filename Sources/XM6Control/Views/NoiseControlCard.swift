import SwiftUI
import SonyHeadphonesKit

struct NoiseControlCard: View {
    @EnvironmentObject private var controller: HeadphonesController

    private var effectiveState: AmbientSoundState? {
        controller.ambientSound ?? (controller.initialStateTimedOut ? AmbientSoundState() : nil)
    }

    var body: some View {
        Card("Ambient Sound Control") {
            if let state = effectiveState {
                VStack(spacing: 18) {
                    if controller.ambientSound == nil {
                        StateNotReportedBanner()
                    }

                    // Three circular mode buttons, arranged like the official app.
                    HStack(spacing: 24) {
                        modeButton(.noiseCancelling, label: "Noise\nCanceling", icon: "person.wave.2.fill", current: state)
                        modeButton(.ambientSound, label: "Ambient\nSound", icon: "waveform.and.person.filled", current: state)
                        modeButton(.off, label: "Off", icon: "xmark", current: state)
                    }
                    .frame(maxWidth: .infinity)

                    if state.mode == .ambientSound {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Ambient Sound Level")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            HStack(spacing: 10) {
                                Image(systemName: "speaker.wave.1")
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
                                Image(systemName: "speaker.wave.3")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("\(state.level)")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                                    .frame(width: 20, alignment: .trailing)
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
                            .padding(.top, 2)
                        }
                        .transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: state.mode)
            } else {
                LoadingRow()
            }
        }
    }

    private func modeButton(_ mode: AmbientSoundMode, label: String, icon: String, current: AmbientSoundState) -> some View {
        let isSelected = current.mode == mode
        return Button {
            var updated = current
            updated.mode = mode
            controller.setAmbientSound(updated)
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    if isSelected {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.brand, .brand.opacity(0.72)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .shadow(color: Color.brand.opacity(0.45), radius: 8, y: 3)
                    } else {
                        Circle()
                            .fill(Color.primary.opacity(0.06))
                            .overlay(Circle().strokeBorder(Color.primary.opacity(0.10), lineWidth: 1))
                    }
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? Color.white : Color.primary.opacity(0.75))
                }
                .frame(width: 58, height: 58)

                Text(label)
                    .font(.caption2.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.brand : Color.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .buttonStyle(.plain)
    }
}

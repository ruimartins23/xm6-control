import SwiftUI
import SonyHeadphonesKit

/// The menu bar panel: every frequently used control, laid out like a Control
/// Center module.
struct CompactControlsView: View {
    @EnvironmentObject private var controller: HeadphonesController
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if controller.connectionState == .connected {
                noiseControl
                Divider()
                soundControls
                if let devices = controller.devices, devices.count > 1 {
                    Divider()
                    devicesList(devices)
                }
            } else {
                connectPrompt
            }

            Divider()
            appRow
        }
        .padding(16)
        .frame(width: 320)
    }

    // MARK: - Sections

    private var header: some View {
        HStack(spacing: 8) {
            // The same drawn glyph as the menu bar item, so the panel is visibly the
            // same app as the icon it dropped out of.
            Image(nsImage: .xm6MenuBarIcon(size: 16))
                .foregroundStyle(Color.accentColor)
            Text(controller.deviceName ?? "WH-1000XM6")
                .font(.headline)
                .lineLimit(1)
            Spacer()
            if let battery = controller.battery {
                BatteryLabel(level: battery.level, isCharging: battery.isCharging)
                    .font(.callout)
            }
        }
    }

    @ViewBuilder
    private var noiseControl: some View {
        let state = controller.ambientSound ?? AmbientSoundState()

        ModeSelector(
            options: [
                .init(value: .noiseCancelling, title: "Noise Canceling", icon: "person.wave.2.fill"),
                .init(value: .ambientSound, title: "Ambient", icon: "waveform.and.person.filled"),
                .init(value: .off, title: "Off", icon: "xmark"),
            ],
            selection: controller.ambientSound?.mode ?? .noiseCancelling,
            select: { mode in
                var updated = state
                updated.mode = mode
                controller.setAmbientSound(updated)
            },
            diameter: 44
        )

        if state.mode == .ambientSound {
            HStack(spacing: 8) {
                Image(systemName: "speaker.wave.1").foregroundStyle(.secondary)
                Slider(
                    value: Binding(
                        get: { Double(state.level) },
                        set: { newValue in
                            var updated = state
                            updated.level = Int(newValue.rounded())
                            controller.setAmbientSound(updated)
                        }
                    ),
                    in: 0...20, step: 1
                )
                .accessibilityLabel("Ambient sound level")
                Image(systemName: "speaker.wave.3").foregroundStyle(.secondary)
            }
            .font(.caption)
        }
    }

    private var soundControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Listening mode", selection: Binding(
                get: { controller.listeningMode ?? .standard },
                set: { controller.setListeningMode($0) }
            )) {
                Text("Standard").tag(ListeningMode.standard)
                Text("BGM").tag(ListeningMode.backgroundMusic)
                Text("Cinema").tag(ListeningMode.cinema)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            // A segmented picker keeps its intrinsic width on macOS and sits at the
            // leading edge; centre it under the noise buttons.
            .frame(maxWidth: .infinity)

            HStack {
                Text("Equalizer")
                    .foregroundStyle(.secondary)
                Spacer()
                // A Menu rather than a Picker so the current value can be a label the
                // enum doesn't contain: the device can report a personalized preset.
                Menu(currentEqualizerLabel) {
                    ForEach(EqualizerPreset.allCases) { preset in
                        Button(preset.label) { controller.setEqualizerPreset(preset) }
                    }
                }
                .fixedSize()
                .accessibilityLabel("Equalizer preset, \(currentEqualizerLabel)")
            }
        }
    }

    private var currentEqualizerLabel: String {
        guard let equalizer = controller.equalizer else { return EqualizerPreset.off.label }
        return equalizer.preset?.label ?? "Personalized"
    }

    private func devicesList(_ devices: [MultipointDevice]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(devices) { device in
                HStack(spacing: 8) {
                    Image(systemName: symbolForDevice(named: device.name))
                        .frame(width: 18)
                        .foregroundStyle(device.isPlayback ? Color.accentColor : Color.secondary)
                    Text(device.name)
                        .lineLimit(1)
                        .foregroundStyle(device.isConnected ? .primary : .secondary)
                    Spacer()
                    if device.isPlayback {
                        Image(systemName: "speaker.wave.2.fill")
                            .foregroundStyle(Color.accentColor)
                    } else if device.isConnected {
                        Button("Play Here") { controller.switchPlayback(to: device) }
                            .buttonStyle(.glass)
                            .controlSize(.small)
                    }
                }
                .font(.callout)
            }
        }
    }

    private var connectPrompt: some View {
        VStack(spacing: 10) {
            Text(promptText)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            if controller.connectionState != .connecting && controller.connectionState != .initializing {
                Button("Connect") { controller.autoConnect() }
                    .buttonStyle(.glassProminent)
            }
        }
        .padding(.vertical, 6)
    }

    private var promptText: String {
        switch controller.connectionState {
        case .connecting, .initializing: return "Connecting\u{2026}"
        case .failed: return "Couldn't reach the headphones.\nMake sure they're on and paired."
        default: return "Not connected."
        }
    }

    /// With the Dock icon hidden, this row is the only way to reopen the main
    /// window, reach Settings, or quit. Do not remove it.
    private var appRow: some View {
        HStack(spacing: 8) {
            Button("Open XM6 Control") {
                openWindow(id: "main")
                NSApp.activate()
            }
            Spacer()
            // Not `SettingsLink`: opened from a menu bar panel it never activates the
            // app, so the Settings window lands behind whatever app is in front.
            Button {
                openSettings()
                NSApp.activate()
            } label: {
                Image(systemName: "gearshape")
            }
            .help("Settings")
            Button {
                NSApp.terminate(nil)
            } label: {
                Image(systemName: "power")
            }
            .help("Quit XM6 Control")
        }
        .buttonStyle(.glass)
        .controlSize(.small)
    }
}

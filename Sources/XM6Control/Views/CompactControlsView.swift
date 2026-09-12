import SwiftUI
import SonyHeadphonesKit

/// Compact control panel used by both the menu bar extra and the floating desktop
/// widget: every frequently-used control in a small footprint.
struct CompactControlsView: View {
    @EnvironmentObject private var controller: HeadphonesController
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.openWindow) private var openWindow
    /// Extra chrome (drag hint + close) shown only in the desktop-widget window.
    var isDesktopWidget = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if controller.connectionState == .connected {
                ancRow

                if (controller.ambientSound?.mode ?? .noiseCancelling) == .ambientSound {
                    ambientSlider
                }

                Divider()
                listeningModeRow
                equalizerRow

                if let devices = controller.devices, devices.count > 1 {
                    Divider()
                    devicesRow(devices)
                }
            } else {
                connectPrompt
            }

            if !isDesktopWidget {
                Divider()
                appRow
            }
        }
        .padding(14)
        .frame(width: 300)
    }

    /// With the Dock icon hidden, this row is the only way to reopen the main
    /// window or quit -- do not remove it from the menu bar panel.
    private var appRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button("Open App") {
                    openWindow(id: "main")
                    NSApp.activate(ignoringOtherApps: true)
                }
                Button("Widget") {
                    openWindow(id: "desktop-widget")
                }
                Spacer()
                Button("Quit") {
                    NSApp.terminate(nil)
                }
            }
            .controlSize(.small)

            // Reachable from here on purpose: in menu-bar-only mode this panel is the
            // only interface, so the way back to a normal window has to live in it.
            Toggle("Show only in the menu bar", isOn: $settings.menuBarOnly)
                .toggleStyle(.checkbox)
                .font(.caption)
                .foregroundStyle(.secondary)
                .help("Hides the Dock icon. Uncheck to get the Dock icon and window back.")
        }
    }

    // MARK: - Sections

    private var header: some View {
        HStack(spacing: 8) {
            // The same drawn glyph as the menu bar item, so the panel is visibly the
            // same app as the icon it dropped out of.
            Image(nsImage: .xm6MenuBarIcon(size: 15))
                .foregroundStyle(Color.brand)
            Text(controller.deviceName ?? "WH-1000XM6")
                .font(.callout.weight(.semibold))
                .lineLimit(1)
            Spacer()
            if let battery = controller.battery {
                BatteryGauge(level: battery.level, isCharging: battery.isCharging)
            }
        }
    }

    private var ancRow: some View {
        HStack(spacing: 6) {
            compactModeButton("NC", spoken: "Noise Canceling", icon: "person.wave.2.fill", mode: .noiseCancelling)
            compactModeButton("Ambient", spoken: "Ambient Sound", icon: "waveform.and.person.filled", mode: .ambientSound)
            compactModeButton("Off", spoken: "Off", icon: "xmark", mode: .off)
        }
    }

    private var ambientSlider: some View {
        HStack(spacing: 8) {
            Image(systemName: "speaker.wave.1").font(.caption2).foregroundStyle(.secondary)
            Slider(
                value: Binding(
                    get: { Double(controller.ambientSound?.level ?? 15) },
                    // Falls back to a default state rather than bailing out: when the
                    // headphones never reported ambient sound, the old `guard` left a
                    // slider that moved under the cursor and silently did nothing.
                    set: { newValue in
                        var state = controller.ambientSound ?? AmbientSoundState(mode: .ambientSound)
                        state.level = Int(newValue.rounded())
                        controller.setAmbientSound(state)
                    }
                ),
                in: 0...20, step: 1
            )
            .controlSize(.mini)
            .accessibilityLabel("Ambient sound level")
            Image(systemName: "speaker.wave.3").font(.caption2).foregroundStyle(.secondary)
        }
    }

    private var listeningModeRow: some View {
        Picker("Mode", selection: Binding(
            get: { controller.listeningMode ?? .standard },
            set: { controller.setListeningMode($0) }
        )) {
            Text("Standard").tag(ListeningMode.standard)
            Text("BGM").tag(ListeningMode.backgroundMusic)
            Text("Cinema").tag(ListeningMode.cinema)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }

    private var equalizerRow: some View {
        HStack {
            Text("Equalizer")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            // A Menu rather than a Picker so the current value can be a label the
            // enum doesn't contain. The device can report a personalized preset id,
            // and a Picker forced that through `?? .off`, showing "Off" while the
            // headphones were using something else entirely.
            Menu(currentEqualizerLabel) {
                ForEach(EqualizerPreset.allCases) { preset in
                    Button(preset.label) { controller.setEqualizerPreset(preset) }
                }
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .accessibilityLabel("Equalizer preset, \(currentEqualizerLabel)")
        }
    }

    private var currentEqualizerLabel: String {
        guard let equalizer = controller.equalizer else { return EqualizerPreset.off.label }
        return equalizer.preset?.label ?? "Personalized"
    }

    private func devicesRow(_ devices: [MultipointDevice]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(devices) { device in
                Button {
                    if device.isConnected && !device.isPlayback {
                        controller.switchPlayback(to: device)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: symbolForDevice(named: device.name))
                            .font(.caption)
                            .frame(width: 16)
                            .foregroundStyle(device.isPlayback ? Color.brand : Color.secondary)
                        Text(device.name)
                            .font(.caption)
                            .lineLimit(1)
                            .foregroundStyle(device.isConnected ? Color.primary : Color.secondary)
                        Spacer()
                        if !device.isPlayback && device.isConnected {
                            Text("Play here")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(Color.brand)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!device.isConnected || device.isPlayback)
            }
        }
    }

    private var connectPrompt: some View {
        VStack(spacing: 8) {
            Text(promptText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
            Button("Connect") {
                controller.autoConnect()
            }
            .controlSize(.small)
            .frame(maxWidth: .infinity)
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

    /// `spoken` carries the full name for VoiceOver and the tooltip, since the visible
    /// captions are abbreviated to fit ("NC") or are icon-only in meaning ("Off").
    private func compactModeButton(
        _ label: String,
        spoken accessibilityName: String,
        icon: String,
        mode: AmbientSoundMode
    ) -> some View {
        let current = controller.ambientSound?.mode
        let isSelected = current == mode
        return Button {
            var state = controller.ambientSound ?? AmbientSoundState()
            state.mode = mode
            controller.setAmbientSound(state)
        } label: {
            VStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 13, weight: .medium))
                Text(label).font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .foregroundStyle(isSelected ? Color.white : Color.primary.opacity(0.8))
            .controlSurface(
                RoundedRectangle(cornerRadius: Radius.control),
                isSelected: isSelected
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityName)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

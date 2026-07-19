import SwiftUI
import SonyHeadphonesKit

/// Compact control panel used by both the menu bar extra and the floating desktop
/// widget: every frequently-used control in a small footprint.
struct CompactControlsView: View {
    @EnvironmentObject private var controller: HeadphonesController
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
        HStack {
            Button("Open App") {
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            }
            .controlSize(.small)
            Button("Open Widget") {
                openWindow(id: "desktop-widget")
                NSApp.activate(ignoringOtherApps: true)
            }
            .controlSize(.small)
            Spacer()
            Button("Quit") {
                NSApp.terminate(nil)
            }
            .controlSize(.small)
        }
    }

    // MARK: - Sections

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "headphones")
                .foregroundStyle(Color.brand)
            Text(controller.deviceName ?? "WH-1000XM6")
                .font(.callout.weight(.semibold))
                .lineLimit(1)
            Spacer()
            if let battery = controller.battery {
                HStack(spacing: 3) {
                    Image(systemName: battery.isCharging ? "battery.100.bolt" : "battery.75")
                    Text("\(battery.level)%")
                        .font(.caption.monospacedDigit())
                }
                .font(.caption)
                .foregroundStyle(battery.level < 20 && !battery.isCharging ? Color.red : Color.secondary)
            }
        }
    }

    private var ancRow: some View {
        HStack(spacing: 6) {
            compactModeButton("NC", icon: "person.wave.2.fill", mode: .noiseCancelling)
            compactModeButton("Ambient", icon: "waveform.and.person.filled", mode: .ambientSound)
            compactModeButton("Off", icon: "xmark", mode: .off)
        }
    }

    private var ambientSlider: some View {
        HStack(spacing: 8) {
            Image(systemName: "speaker.wave.1").font(.caption2).foregroundStyle(.secondary)
            Slider(
                value: Binding(
                    get: { Double(controller.ambientSound?.level ?? 15) },
                    set: { newValue in
                        guard var state = controller.ambientSound else { return }
                        state.level = Int(newValue.rounded())
                        controller.setAmbientSound(state)
                    }
                ),
                in: 0...20, step: 1
            )
            .controlSize(.mini)
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
            Picker("Equalizer", selection: Binding(
                get: { controller.equalizer?.preset ?? .off },
                set: { controller.setEqualizerPreset($0) }
            )) {
                ForEach(EqualizerPreset.allCases) { preset in
                    Text(preset.label).tag(preset)
                }
            }
            .labelsHidden()
            .fixedSize()
        }
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
                        Image(systemName: device.isPlayback ? "speaker.wave.2.fill" : "circle")
                            .font(.caption2)
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

    private func compactModeButton(_ label: String, icon: String, mode: AmbientSoundMode) -> some View {
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
            .background(
                RoundedRectangle(cornerRadius: 9)
                    .fill(isSelected ? AnyShapeStyle(Color.brand) : AnyShapeStyle(Color.primary.opacity(0.06)))
            )
            .foregroundStyle(isSelected ? Color.white : Color.primary.opacity(0.8))
        }
        .buttonStyle(.plain)
    }
}

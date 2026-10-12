import SwiftUI
import SonyHeadphonesKit

struct DevicesSection: View {
    @EnvironmentObject private var controller: HeadphonesController

    var body: some View {
        Section("Connected Devices") {
            if let devices = controller.devices, !devices.isEmpty {
                ForEach(devices) { device in
                    row(device)
                }
            } else if controller.deviceListTimedOut || controller.initialStateTimedOut {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Device list unavailable")
                        Text("The headphones didn't report their connected devices. This can happen when connecting to two devices is turned off.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Retry") { controller.refreshDeviceList() }
                        .buttonStyle(.glass)
                        .controlSize(.small)
                }
            } else {
                LoadingRow()
            }
        }
    }

    private func row(_ device: MultipointDevice) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbolForDevice(named: device.name))
                .font(.title3)
                .foregroundStyle(device.isConnected ? Color.accentColor : Color.secondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 1) {
                Text(device.name)
                    .foregroundStyle(device.isConnected ? .primary : .secondary)
                Text(status(of: device))
                    .font(.caption)
                    .foregroundStyle(device.isPlayback ? Color.accentColor : Color.secondary)
            }

            Spacer()

            if device.isPlayback {
                Image(systemName: "speaker.wave.2.fill")
                    .foregroundStyle(Color.accentColor)
                    .symbolEffect(.variableColor.iterative, options: .nonRepeating)
            } else if device.isConnected {
                Button("Play Here") {
                    controller.switchPlayback(to: device)
                }
                .buttonStyle(.glass)
                .controlSize(.small)
                .help("Switch playback to this device")
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func status(of device: MultipointDevice) -> String {
        if device.isPlayback { return "Playing" }
        return device.isConnected ? "Connected" : "Paired, not connected"
    }
}

/// Guesses a glyph from the device's advertised name. Shared with the menu bar panel
/// so a device doesn't appear as a laptop in one place and a generic box in another.
func symbolForDevice(named name: String) -> String {
    let lowered = name.lowercased()
    if lowered.contains("iphone") || lowered.contains("phone") { return "iphone" }
    if lowered.contains("ipad") || lowered.contains("tab") { return "ipad" }
    if lowered.contains("watch") { return "applewatch" }
    if lowered.contains("book") || lowered.contains("mac") || lowered.contains("pc") { return "laptopcomputer" }
    return "desktopcomputer"
}

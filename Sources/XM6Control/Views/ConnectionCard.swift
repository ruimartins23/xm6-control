import SwiftUI
import SonyHeadphonesKit

struct ConnectionCard: View {
    @EnvironmentObject private var controller: HeadphonesController

    var body: some View {
        Card("Connected Devices") {
            if let devices = controller.devices, !devices.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(devices) { device in
                        deviceRow(device)
                        if device.id != devices.last?.id {
                            Divider()
                        }
                    }

                    Text("Click a connected device to make it the playback source.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 8)
                }
            } else if controller.initialStateTimedOut {
                Text("The headphones didn't report their device list.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                LoadingRow()
            }
        }
    }

    private func deviceRow(_ device: MultipointDevice) -> some View {
        Button {
            if device.isConnected && !device.isPlayback {
                controller.switchPlayback(to: device)
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: deviceIcon(for: device.name))
                    .font(.system(size: 16))
                    .foregroundStyle(device.isConnected ? Color.brand : Color.secondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(device.name)
                        .font(.callout.weight(device.isPlayback ? .semibold : .regular))
                        .foregroundStyle(device.isConnected ? Color.primary : Color.secondary)
                    Text(device.isPlayback
                         ? "Playing"
                         : (device.isConnected ? "Connected" : "Paired, not connected"))
                        .font(.caption2)
                        .foregroundStyle(device.isPlayback ? Color.brand : Color.secondary)
                }

                Spacer()

                if device.isPlayback {
                    Image(systemName: "speaker.wave.2.fill")
                        .foregroundStyle(Color.brand)
                } else if device.isConnected {
                    Text("Play here")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.brand)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.brand.opacity(0.12), in: Capsule())
                }
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!device.isConnected || device.isPlayback)
    }

    private func deviceIcon(for name: String) -> String {
        let lowered = name.lowercased()
        if lowered.contains("iphone") || lowered.contains("phone") { return "iphone" }
        if lowered.contains("ipad") || lowered.contains("tab") { return "ipad" }
        if lowered.contains("book") || lowered.contains("mac") || lowered.contains("pc") { return "laptopcomputer" }
        return "desktopcomputer"
    }
}

import SwiftUI
import SonyHeadphonesKit

/// The product, its name and battery at the top of the form, the way System Settings
/// opens a Bluetooth device's page.
struct HeaderView: View {
    @EnvironmentObject private var controller: HeadphonesController

    var body: some View {
        Section {
            VStack(spacing: 8) {
                HeadphoneImage()
                    .frame(height: 120)
                    .shadow(color: .black.opacity(0.3), radius: 12, y: 8)
                    .padding(.bottom, 4)

                Text(controller.deviceName ?? "WH-1000XM6")
                    .font(.title2.weight(.semibold))

                HStack(spacing: 12) {
                    battery
                    if let playing = controller.devices?.first(where: \.isPlayback)?.name {
                        Label(playing, systemImage: "speaker.wave.2.fill")
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .font(.callout)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .listRowBackground(Color.clear)
    }

    @ViewBuilder
    private var battery: some View {
        if let battery = controller.battery {
            BatteryLabel(level: battery.level, isCharging: battery.isCharging)
        } else {
            Text(controller.initialStateTimedOut ? "Battery level not reported" : "Loading battery\u{2026}")
                .foregroundStyle(.tertiary)
        }
    }
}

/// Battery as the system shows it for Bluetooth accessories: the SF battery glyph
/// and a percentage, tinted only when it needs attention.
struct BatteryLabel: View {
    let level: Int
    let isCharging: Bool

    var body: some View {
        Label {
            Text("\(level)%").monospacedDigit()
        } icon: {
            Image(systemName: symbol)
                .symbolRenderingMode(isCharging ? .multicolor : .hierarchical)
                .foregroundStyle(level < 20 && !isCharging ? Color.red : Color.secondary)
        }
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Battery \(level) percent\(isCharging ? ", charging" : "")")
    }

    private var symbol: String {
        if isCharging { return "battery.100percent.bolt" }
        switch level {
        case ..<13: return "battery.0percent"
        case ..<38: return "battery.25percent"
        case ..<63: return "battery.50percent"
        case ..<88: return "battery.75percent"
        default: return "battery.100percent"
        }
    }
}

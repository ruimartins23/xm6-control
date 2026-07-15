import SwiftUI
import SonyHeadphonesKit

struct HeaderView: View {
    @EnvironmentObject private var controller: HeadphonesController

    var body: some View {
        VStack(spacing: 12) {
            HeadphoneImage()
                .frame(height: 150)
                .padding(.top, 4)

            VStack(spacing: 8) {
                Text(controller.deviceName ?? "WH-1000XM6")
                    .font(.title3.weight(.semibold))

                if let battery = controller.battery {
                    HStack(spacing: 5) {
                        Image(systemName: batteryIcon(for: battery))
                        Text("\(battery.level)%\(battery.isCharging ? " \u{2022} Charging" : "")")
                            .font(.footnote.weight(.medium).monospacedDigit())
                    }
                    .foregroundStyle(batteryColor(for: battery))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .glassSurface(cornerRadius: 999)
                } else if controller.initialStateTimedOut {
                    Text("Battery level not reported")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                } else {
                    Text("Loading battery\u{2026}")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func batteryColor(for battery: BatteryStatus) -> Color {
        if battery.isCharging { return .green }
        switch battery.level {
        case ..<20: return .red
        case ..<40: return .orange
        default: return .green
        }
    }

    private func batteryIcon(for battery: BatteryStatus) -> String {
        if battery.isCharging { return "battery.100.bolt" }
        switch battery.level {
        case ..<15: return "battery.0"
        case ..<40: return "battery.25"
        case ..<65: return "battery.50"
        case ..<90: return "battery.75"
        default: return "battery.100"
        }
    }
}

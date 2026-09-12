import SwiftUI
import SonyHeadphonesKit

struct HeaderView: View {
    @EnvironmentObject private var controller: HeadphonesController

    var body: some View {
        VStack(spacing: 10) {
            // Trimmed from 150pt: the hero image was pushing the primary control
            // below the fold in the default window size.
            HeadphoneImage()
                .frame(height: 112)
                // Contact shadow. The photo has a transparent background, so this
                // follows the headphones' own outline and grounds them on the panel
                // instead of leaving them floating flat against it.
                .shadow(color: Color.black.opacity(0.45), radius: 10, y: 7)

            VStack(spacing: 6) {
                Text(controller.deviceName ?? "WH-1000XM6")
                    .font(.headline)

                batteryStatus
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var batteryStatus: some View {
        if let battery = controller.battery {
            HStack(spacing: 5) {
                Image(systemName: batteryIcon(for: battery))
                Text("\(battery.level)%\(battery.isCharging ? " \u{2022} Charging" : "")")
                    .font(.footnote.weight(.medium).monospacedDigit())
            }
            .foregroundStyle(batteryColor(for: battery))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            // Capsule is the documented exception to the radius scale for status
            // badges (see `Radius`). Recessed, matching the unselected controls.
            .background(Color.black.opacity(0.18), in: Capsule())
            .overlay(
                Capsule().strokeBorder(
                    LinearGradient(
                        colors: [Color.black.opacity(0.30), Color.white.opacity(0.09)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
            )
            .accessibilityLabel(
                "Battery \(battery.level) percent\(battery.isCharging ? ", charging" : "")"
            )
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

    private func batteryColor(for battery: BatteryStatus) -> Color {
        if battery.isCharging { return .green }
        switch battery.level {
        case ..<20: return .red
        case ..<40: return .orange
        // Above 40% the level isn't noteworthy, so it stays in the neutral text
        // color instead of spending the one accent on a non-actionable status.
        default: return .secondary
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

import SwiftUI
import SonyHeadphonesKit

/// The connected dashboard: one grouped form, laid out the way System Settings lays
/// out a device, with the frequently changed controls at the top.
struct DashboardView: View {
    @EnvironmentObject private var controller: HeadphonesController

    var body: some View {
        Form {
            HeaderView()

            NoiseControlSection()
            SoundSection()
            DevicesSection()
            SpeakToChatSection()
            WearDetectionSection()
        }
        .formStyle(.grouped)
        .scrollEdgeEffectStyle(.soft, for: .top)
        .fitsWindowToContent()
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button("Refresh", systemImage: "arrow.clockwise") {
                    controller.refreshState()
                }
                .help("Re-read every setting from the headphones")

                Button("Disconnect", systemImage: "eject") {
                    controller.disconnect()
                }
                .help("Disconnect from the headphones")
            }
        }
    }
}

/// Shown inside a section when the headphones didn't answer the initial state query
/// for it. Controls still work, since writes are independent of reads.
struct StateNotReportedNote: View {
    var body: some View {
        Label("Current state not reported. Controls still work.", systemImage: "info.circle")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}

struct LoadingRow: View {
    var body: some View {
        ProgressView()
            .controlSize(.small)
            .frame(maxWidth: .infinity)
    }
}

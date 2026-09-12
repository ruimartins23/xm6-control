import SwiftUI
import SonyHeadphonesKit

struct DashboardView: View {
    @EnvironmentObject private var controller: HeadphonesController
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        ScrollView {
            // Ranked top to bottom: the control most likely to be the reason the
            // window was opened first, set-once preferences last.
            VStack(spacing: 12) {
                HeaderView()
                NoiseControlCard()
                SoundCard()
                ConnectionCard()
                BehaviorCard()
                footer
            }
            .padding(16)
        }
    }

    private var footer: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Button {
                    openWindow(id: "desktop-widget")
                } label: {
                    Label("Widget", systemImage: "macwindow.on.rectangle")
                        .frame(maxWidth: .infinity)
                }
                .help("Open the floating desktop widget")

                Button {
                    controller.refreshState()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .help("Re-read every setting from the headphones")

                Button(role: .destructive) {
                    controller.disconnect()
                } label: {
                    Text("Disconnect")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            VStack(alignment: .leading, spacing: 6) {
                Toggle("Show only in the menu bar", isOn: $settings.menuBarOnly)
                    .toggleStyle(.checkbox)
                    .help("Hides the Dock icon. The menu bar panel stays available, and you can reopen this window from there.")

                Toggle("Debug log", isOn: $controller.protocolLoggingEnabled)
                    .toggleStyle(.checkbox)
                    .help("Write a hex transcript of every frame to protocol.log")

                Text(footerText)
                    .foregroundStyle(.tertiary)
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.top, 2)
    }

    private var footerText: String {
        switch controller.protocolVersion {
        case .v2: return "Sony protocol v2"
        case .v1: return "Sony protocol v1 (some features may be limited)"
        case .unknown: return "Protocol version not identified"
        }
    }
}

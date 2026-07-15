import SwiftUI
import SonyHeadphonesKit

struct DashboardView: View {
    @EnvironmentObject private var controller: HeadphonesController
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HeaderView()
                NoiseControlCard()
                ListeningModeCard()
                EqualizerCard()
                SpeakToChatCard()
                WearDetectionCard()
                ConnectionCard()

                HStack(spacing: 10) {
                    Button {
                        openWindow(id: "desktop-widget")
                    } label: {
                        Label("Widget", systemImage: "macwindow.on.rectangle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        controller.refreshState()
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button(role: .destructive) {
                        controller.disconnect()
                    } label: {
                        Text("Disconnect")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.top, 4)

                Text(footerText)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                Toggle("Debug logging (protocol.log)", isOn: $controller.protocolLoggingEnabled)
                    .toggleStyle(.checkbox)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(20)
        }
    }

    private var footerText: String {
        switch controller.protocolVersion {
        case .v2: return "Connected \u{2022} Sony protocol v2"
        case .v1: return "Connected \u{2022} Sony protocol v1 (some features may be limited)"
        case .unknown: return "Connected \u{2022} protocol version not identified"
        }
    }
}

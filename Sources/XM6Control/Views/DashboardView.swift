import SwiftUI
import SonyHeadphonesKit

struct DashboardView: View {
    @EnvironmentObject private var controller: HeadphonesController
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.openWindow) private var openWindow

    /// Above this width the cards sit in two columns. Below it they stack. A single
    /// column stretched to a wide window turns every card into a mostly-empty slab,
    /// which is what made the interface look barren when resized.
    private static let twoColumnWidth: CGFloat = 720
    /// Content stops growing past this, so a maximised window centres the layout
    /// instead of stretching controls apart.
    private static let maxContentWidth: CGFloat = 1000

    var body: some View {
        GeometryReader { geometry in
            let isWide = geometry.size.width >= Self.twoColumnWidth

            ScrollView {
                VStack(spacing: 14) {
                    HeaderView(horizontal: isWide)

                    if isWide {
                        HStack(alignment: .top, spacing: 14) {
                            VStack(spacing: 14) {
                                NoiseControlCard()
                                SoundCard()
                            }
                            VStack(spacing: 14) {
                                ConnectionCard()
                                BehaviorCard()
                            }
                        }
                    } else {
                        NoiseControlCard()
                        SoundCard()
                        ConnectionCard()
                        BehaviorCard()
                    }

                    footer
                }
                .frame(maxWidth: Self.maxContentWidth)
                .frame(maxWidth: .infinity)
                .padding(16)
            }
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

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Toggle("Show only in the menu bar", isOn: $settings.menuBarOnly)
                        .toggleStyle(.checkbox)
                        .help("Hides the Dock icon. The menu bar panel stays available, and you can reopen this window from there.")

                    Toggle("Debug log", isOn: $controller.protocolLoggingEnabled)
                        .toggleStyle(.checkbox)
                        .help("Write a hex transcript of every frame to protocol.log")
                }
                Spacer()
                Text(footerText)
                    .foregroundStyle(.tertiary)
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
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

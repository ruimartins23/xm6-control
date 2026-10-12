import SwiftUI
import ServiceManagement
import SonyHeadphonesKit

/// App preferences, in the standard ⌘, window rather than as checkboxes under the
/// headphone controls they have nothing to do with.
struct SettingsView: View {
    @EnvironmentObject private var controller: HeadphonesController
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        Form {
            Section {
                Toggle("Open at login", isOn: Binding(
                    get: { settings.launchAtLogin },
                    set: { settings.setLaunchAtLogin($0) }
                ))
            } footer: {
                if settings.launchAtLoginStatus == .requiresApproval {
                    HStack {
                        Text("Allow XM6 Control in Login Items to finish turning this on.")
                        Button("Open Login Items") {
                            SMAppService.openSystemSettingsLoginItems()
                        }
                        .buttonStyle(.link)
                    }
                } else if let error = settings.launchAtLoginError {
                    Text(error).foregroundStyle(.red)
                } else {
                    Text("Starts XM6 Control when you log in, so the menu bar panel and the widget are ready.")
                }
            }

            Section {
                Toggle("Show only in the menu bar", isOn: $settings.menuBarOnly)
            } footer: {
                Text("Hides the Dock icon. The menu bar panel stays available and can reopen the main window.")
            }

            Section {
                LabeledContent("Desktop & Notification Center") {
                    Text("Edit Widgets\u{2026}, then XM6 Control")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Widget")
            } footer: {
                Text("Right-click the desktop or open Notification Center and choose Edit Widgets to add the XM6 widget.")
            }

            Section {
                Toggle("Write protocol log", isOn: $controller.protocolLoggingEnabled)
                LabeledContent("Protocol", value: protocolText)
            } header: {
                Text("Diagnostics")
            } footer: {
                Text("Writes a hex transcript of every frame to protocol.log in Application Support.")
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var protocolText: String {
        switch controller.protocolVersion {
        case .v2: return "Sony v2"
        case .v1: return "Sony v1"
        case .unknown: return "Not identified"
        }
    }
}

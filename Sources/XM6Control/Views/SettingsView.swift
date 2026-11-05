import SwiftUI
import AppKit
import ServiceManagement
import SonyHeadphonesKit

/// The Settings window (⌘,).
///
/// App-level preferences used to be checkboxes along the bottom of the dashboard,
/// sharing space with headphone controls. A Settings window is where a Mac app keeps
/// them, and it is what people reach for with ⌘, before they look anywhere else.
struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var controller: HeadphonesController

    var body: some View {
        Form {
            Section("General") {
                Toggle("Open at login", isOn: Binding(
                    get: { settings.opensAtLogin },
                    set: { settings.setOpensAtLogin($0) }
                ))
                .help("Start XM6 Control when you log in, so the menu bar controls are always there")

                if settings.loginItemStatus == .requiresApproval {
                    HStack {
                        Text("macOS needs you to allow this in Login Items.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Open Login Items\u{2026}") {
                            SMAppService.openSystemSettingsLoginItems()
                        }
                        .controlSize(.small)
                    }
                }

                if let error = settings.loginItemError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Toggle("Show only in the menu bar", isOn: $settings.menuBarOnly)
                Text("Hides the Dock icon. The menu bar panel stays available, and the same option there brings the window back.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section("Troubleshooting") {
                Toggle("Write a protocol debug log", isOn: $controller.protocolLoggingEnabled)
                HStack {
                    Text("A hex transcript of every message, for diagnosing connection problems or adding support for new firmware.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                    Button("Show in Finder") {
                        revealLog()
                    }
                    .controlSize(.small)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
        // The login item can be changed in System Settings while the app runs.
        .onAppear { settings.refreshLoginItem() }
    }

    private func revealLog() {
        let folder = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("XM6 Control", isDirectory: true)
        let log = folder.appendingPathComponent("protocol.log")
        if FileManager.default.fileExists(atPath: log.path) {
            NSWorkspace.shared.activateFileViewerSelecting([log])
        } else {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            NSWorkspace.shared.open(folder)
        }
    }
}

/// Opens the Settings window from anywhere in the app.
///
/// `SettingsLink` is the supported way on macOS 14 and later; macOS 13 only has the
/// responder-chain action. The app is activated as well, because from the menu bar
/// panel in menu-bar-only mode the window otherwise opens behind whatever is in front.
struct OpenSettingsButton: View {
    var title = "Settings\u{2026}"

    var body: some View {
        if #available(macOS 14.0, *) {
            SettingsLink {
                Label(title, systemImage: "gearshape")
            }
            .simultaneousGesture(TapGesture().onEnded {
                DispatchQueue.main.async { NSApp.activate(ignoringOtherApps: true) }
            })
        } else {
            Button {
                NSApp.activate(ignoringOtherApps: true)
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            } label: {
                Label(title, systemImage: "gearshape")
            }
        }
    }
}

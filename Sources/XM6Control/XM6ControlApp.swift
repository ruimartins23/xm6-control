import SwiftUI
import AppKit
import SonyHeadphonesKit

@main
struct XM6ControlApp: App {
    @StateObject private var controller: HeadphonesController
    @StateObject private var settings = AppSettings()
    private let widgetBridge: WidgetBridge

    init() {
        let controller = HeadphonesController()
        _controller = StateObject(wrappedValue: controller)
        widgetBridge = WidgetBridge(controller: controller)

        // `--demo` fills in a connected state without Bluetooth, for working on the
        // interface away from the headphones.
        if CommandLine.arguments.contains("--demo") {
            controller.loadDemoState()
        }
        ProbeMode.runIfRequested()
    }

    var body: some Scene {
        WindowGroup("XM6 Control", id: "main") {
            ContentView()
                .environmentObject(controller)
                .environmentObject(settings)
                .frame(minWidth: 420, idealWidth: 460, maxWidth: 640, minHeight: 520, idealHeight: 760)
                .onAppear {
                    // The stored preference has to be pushed onto NSApp once the app is
                    // actually up; the bundle always launches as a regular app so that
                    // this window can exist at all.
                    if ProbeMode.active {
                        // Keep the protocol probe out of the Dock and the app switcher.
                        NSApp.setActivationPolicy(.accessory)
                    } else {
                        settings.apply()
                    }
                    if CommandLine.arguments.contains("--dark") {
                        NSApp.appearance = NSAppearance(named: .darkAqua)
                    }
                }
        }
        .windowResizability(.contentSize)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }

        // Menu bar controls: always one click away, even with the main window closed.
        // Icon-only label: the title+systemImage form reserves layout space for the
        // (invisible) title text, leaving an odd gap next to the icon.
        MenuBarExtra {
            CompactControlsView()
                .environmentObject(controller)
                .environmentObject(settings)
        } label: {
            MenuBarIcon()
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(controller)
                .environmentObject(settings)
        }
    }
}

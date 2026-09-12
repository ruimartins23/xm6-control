import SwiftUI
import AppKit
import SonyHeadphonesKit

@main
struct XM6ControlApp: App {
    @StateObject private var controller = HeadphonesController()
    @StateObject private var settings = AppSettings()

    init() {
        ProbeMode.runIfRequested()
    }

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView()
                .environmentObject(controller)
                .environmentObject(settings)
                .frame(minWidth: 380, idealWidth: 420, minHeight: 560, idealHeight: 680)
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
                }
        }
        .windowResizability(.contentSize)
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
            Image(systemName: "headphones.circle.fill")
        }
        .menuBarExtraStyle(.window)

        // Floating desktop widget, opened from the main window or the menu bar panel.
        Window("XM6 Widget", id: "desktop-widget") {
            DesktopWidgetView()
                .environmentObject(controller)
                .environmentObject(settings)
        }
        .windowResizability(.contentSize)
        .defaultPosition(.topTrailing)
    }
}

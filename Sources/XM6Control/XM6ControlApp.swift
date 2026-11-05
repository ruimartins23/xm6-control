import SwiftUI
import AppKit
import SonyHeadphonesKit

/// Handles reopening and closing the dashboard while the app keeps running.
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Closing the dashboard must leave the app running in the menu bar. That is
    /// SwiftUI's default for a WindowGroup app, but only until an app delegate is
    /// installed: with one present, closing the last window quits the app. So the
    /// answer is given explicitly here.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    /// A minimized dashboard counts as "no visible windows", and the default answer
    /// to that is a brand-new window: a second dashboard. Bring the existing one back
    /// instead, and only let SwiftUI create a window when there genuinely isn't one.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        !MainWindowTracker.shared.bringForward()
    }
}

@main
struct XM6ControlApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var controller = HeadphonesController()
    @StateObject private var settings = AppSettings()
    @StateObject private var profiles = EqualizerProfileStore()

    init() {
        // A single-window app: with the system's "Prefer tabs" set to Always, macOS
        // would otherwise offer tab-bar controls that try to open another copy.
        NSWindow.allowsAutomaticWindowTabbing = false
        ProbeMode.runIfRequested()
    }

    var body: some Scene {
        // A WindowGroup is a multi-window scene: every openWindow(id: "main") creates a
        // new window, so "Open App" used to stack up copies of the dashboard (as tabs,
        // with "Prefer tabs" set to Always). Opening goes through MainWindowTracker,
        // which brings the existing window forward instead.
        //
        // Not a single-instance `Window` scene: on this setup a Window either quits the
        // app when it is closed or, once told not to, stops opening at launch. A
        // WindowGroup opens at launch and keeps the app running in the menu bar.
        WindowGroup(id: "main") {
            ContentView()
                .environmentObject(controller)
                .environmentObject(settings)
                .environmentObject(profiles)
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
                .environmentObject(profiles)
        } label: {
            MenuBarIcon()
        }
        .menuBarExtraStyle(.window)

        // Floating desktop widget, opened from the main window or the menu bar panel.
        Window("XM6 Widget", id: "desktop-widget") {
            DesktopWidgetView()
                .environmentObject(controller)
                .environmentObject(settings)
                .environmentObject(profiles)
        }
        .windowResizability(.contentSize)
        .defaultPosition(.topTrailing)

        // Standard Settings window: gives the app menu its "Settings\u{2026}" item and ⌘,.
        Settings {
            SettingsView()
                .environmentObject(controller)
                .environmentObject(settings)
        }
    }
}

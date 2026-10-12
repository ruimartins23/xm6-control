import SwiftUI
import AppKit
import ServiceManagement

/// App-level preferences, as opposed to headphone settings.
///
/// The menu-bar-only mode is applied at runtime rather than through `LSUIElement`
/// in the bundle: an `LSUIElement` app can never show a Dock icon or open a window
/// on launch, so the choice has to be a switchable activation policy instead of a
/// build-time fact.
@MainActor
final class AppSettings: ObservableObject {
    private static let menuBarOnlyKey = "menuBarOnly"

    /// `true` runs as a menu bar accessory: no Dock icon, no app-switcher entry, the
    /// menu bar panel is the whole interface. `false` is a normal Mac app.
    @Published var menuBarOnly: Bool {
        didSet {
            guard oldValue != menuBarOnly else { return }
            UserDefaults.standard.set(menuBarOnly, forKey: Self.menuBarOnlyKey)
            apply(openWindowIfNeeded: true)
        }
    }

    /// Whether macOS starts the app at login. The system owns this (the person can
    /// also change it in System Settings → General → Login Items), so it is read
    /// back from `SMAppService` rather than stored here.
    @Published private(set) var launchAtLoginStatus: SMAppService.Status = .notRegistered
    @Published private(set) var launchAtLoginError: String?

    var launchAtLogin: Bool {
        launchAtLoginStatus == .enabled || launchAtLoginStatus == .requiresApproval
    }

    private var activeObserver: NSObjectProtocol?

    init() {
        menuBarOnly = UserDefaults.standard.bool(forKey: Self.menuBarOnlyKey)
        refreshLaunchAtLogin()
        // Pick up a change made in System Settings while the app was in the background.
        activeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshLaunchAtLogin() }
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLoginError = nil
        } catch {
            launchAtLoginError = error.localizedDescription
        }
        refreshLaunchAtLogin()
    }

    func refreshLaunchAtLogin() {
        launchAtLoginStatus = SMAppService.mainApp.status
    }

    /// Pushes the current preference onto `NSApp`. Call once at launch, and it runs
    /// again automatically whenever the preference changes.
    ///
    /// - Parameter openWindowIfNeeded: when leaving menu-bar-only mode, bring the app
    ///   forward so the change is visible; there is otherwise no feedback that the
    ///   Dock icon came back.
    func apply(openWindowIfNeeded: Bool = false) {
        NSApp.setActivationPolicy(menuBarOnly ? .accessory : .regular)

        if !menuBarOnly && openWindowIfNeeded {
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}

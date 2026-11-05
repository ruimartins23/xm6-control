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

    init() {
        menuBarOnly = UserDefaults.standard.bool(forKey: Self.menuBarOnlyKey)
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

    // MARK: - Open at login

    /// Read back from the system rather than stored here: the user can remove the
    /// login item in System Settings at any time, and a stored flag would then lie.
    @Published private(set) var loginItemStatus: SMAppService.Status = SMAppService.mainApp.status
    @Published private(set) var loginItemError: String?

    var opensAtLogin: Bool { loginItemStatus == .enabled }

    func refreshLoginItem() {
        loginItemStatus = SMAppService.mainApp.status
    }

    func setOpensAtLogin(_ enabled: Bool) {
        loginItemError = nil
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            loginItemError = error.localizedDescription
        }
        refreshLoginItem()
    }
}

import SwiftUI
import AppKit
import Combine
import SonyHeadphonesKit

/// App-level preferences, as opposed to headphone settings.
///
/// The menu-bar-only mode is applied at runtime rather than through `LSUIElement`
/// in the bundle: an `LSUIElement` app can never show a Dock icon or open a window
/// on launch, so the choice has to be a switchable activation policy instead of a
/// build-time fact.
@MainActor
final class AppSettings: ObservableObject {
    private static let menuBarOnlyKey = "menuBarOnly"
    private static let releaseWhenIdleKey = "releaseHeadphonesWhenIdle"
    private let controller: HeadphonesController
    private var configuredInitialWindow = false
    private var terminationObserver: AnyCancellable?

    @Published var releaseWhenIdle: Bool {
        didSet {
            guard oldValue != releaseWhenIdle else { return }
            UserDefaults.standard.set(releaseWhenIdle, forKey: Self.releaseWhenIdleKey)
            controller.releaseWhenIdle = releaseWhenIdle
        }
    }

    /// `true` runs as a menu bar accessory: no Dock icon, no app-switcher entry, the
    /// menu bar panel is the whole interface. `false` is a normal Mac app.
    @Published var menuBarOnly: Bool {
        didSet {
            guard oldValue != menuBarOnly else { return }
            UserDefaults.standard.set(menuBarOnly, forKey: Self.menuBarOnlyKey)
            apply(openWindowIfNeeded: true)
        }
    }

    init(controller: HeadphonesController) {
        self.controller = controller
        releaseWhenIdle = UserDefaults.standard.object(forKey: Self.releaseWhenIdleKey) as? Bool ?? true
        menuBarOnly = UserDefaults.standard.bool(forKey: Self.menuBarOnlyKey)
        controller.releaseWhenIdle = releaseWhenIdle
        terminationObserver = NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)
            .sink { [weak controller] _ in controller?.disconnect() }
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

    func shouldHideInitialWindow() -> Bool {
        guard !configuredInitialWindow else { return false }
        configuredInitialWindow = true
        return releaseWhenIdle && menuBarOnly
    }
}

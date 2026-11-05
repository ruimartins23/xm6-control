import SwiftUI
import AppKit

/// Remembers the dashboard's window so "open the app" can mean "show the window that
/// is already there" rather than "make another one".
///
/// The dashboard is a `WindowGroup`, which creates a fresh window on every
/// `openWindow(id: "main")`. Every path that opens the dashboard goes through
/// `show(using:)`, so there is only ever one.
@MainActor
final class MainWindowTracker {
    static let shared = MainWindowTracker()

    /// Weak, so a window SwiftUI has released doesn't keep being offered back.
    weak var window: NSWindow?

    /// Brings the existing dashboard to the front, restoring it from the Dock if it
    /// was minimized. Returns false when there is no live dashboard window, so the
    /// caller can create one.
    @discardableResult
    func bringForward() -> Bool {
        guard let window, window.isVisible || window.isMiniaturized else { return false }
        if window.isMiniaturized {
            window.deminiaturize(nil)
        }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        return true
    }

    /// Shows the dashboard: the existing window if there is one, a new one if not.
    func show(using openWindow: OpenWindowAction) {
        guard !bringForward() else { return }
        openWindow(id: "main")
        NSApp.activate(ignoringOtherApps: true)
    }
}

/// Reports the window a view ends up in. A SwiftUI view has no direct handle on its
/// `NSWindow`; this zero-size AppKit view picks it up once it is attached.
struct WindowReader: NSViewRepresentable {
    let onWindow: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        report(from: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        report(from: nsView)
    }

    private func report(from view: NSView) {
        // The view isn't in a window yet when it is created; look on the next pass.
        DispatchQueue.main.async {
            if let window = view.window {
                onWindow(window)
            }
        }
    }
}

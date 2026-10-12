import SwiftUI
import AppKit

extension View {
    /// Sizes the window to show the whole scrollable content, up to the screen height,
    /// until the person resizes the window themselves.
    func fitsWindowToContent() -> some View {
        modifier(FitWindowToContent())
    }
}

/// macOS restores the last window size, and the dashboard's height only settles once
/// the headphones have answered, so a fixed default size either leaves it scrolling
/// or leaves empty space. This follows the content instead. A manual resize wins.
private struct FitWindowToContent: ViewModifier {
    @State private var window: NSWindow?
    @State private var resizedByUser = false

    func body(content: Content) -> some View {
        content
            .background(WindowReader(window: $window))
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                // How much taller the content is than the space it has.
                geometry.contentSize.height + geometry.contentInsets.top
                    + geometry.contentInsets.bottom - geometry.containerSize.height
            } action: { _, overflow in
                fit(by: overflow)
            }
            .onReceive(NotificationCenter.default.publisher(for: NSWindow.willStartLiveResizeNotification)) { note in
                if let window, note.object as? NSWindow === window {
                    resizedByUser = true
                }
            }
    }

    private func fit(by overflow: CGFloat) {
        guard !resizedByUser, abs(overflow) > 1, let window,
              let visible = (window.screen ?? NSScreen.main)?.visibleFrame else { return }

        var frame = window.frame
        let height = min(max(frame.height + overflow, window.minSize.height), visible.height)
        // Keep the top edge where it is, then nudge the window back onto the screen.
        frame.origin.y += frame.height - height
        frame.size.height = height
        frame.origin.y = max(frame.origin.y, visible.minY)
        frame.origin.y = min(frame.origin.y, visible.maxY - height)
        window.setFrame(frame, display: true, animate: false)
    }
}

private struct WindowReader: NSViewRepresentable {
    @Binding var window: NSWindow?

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { window = view.window }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if window == nil {
            DispatchQueue.main.async { window = nsView.window }
        }
    }
}

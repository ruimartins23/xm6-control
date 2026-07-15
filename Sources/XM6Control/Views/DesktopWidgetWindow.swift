import SwiftUI
import AppKit
import SonyHeadphonesKit

/// Content for the floating desktop widget: the compact controls on a glass panel,
/// draggable anywhere, always visible above normal windows, on every Space.
struct DesktopWidgetView: View {
    @EnvironmentObject private var controller: HeadphonesController
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        CompactControlsView(isDesktopWidget: true)
            .overlay(alignment: .topTrailing) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .padding(6)
                .help("Close widget")
            }
            .glassSurface(cornerRadius: 22)
            .padding(8)
            .background(WidgetWindowConfigurator())
    }
}

/// Applies desktop-widget behavior to the hosting NSWindow: no title bar chrome,
/// transparent background, floats above normal windows, appears on all Spaces,
/// draggable by grabbing anywhere, and remembers its position.
private struct WidgetWindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.styleMask = [.borderless, .fullSizeContentView]
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = true
            window.level = .floating
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            window.isMovableByWindowBackground = true
            window.setFrameAutosaveName("XM6DesktopWidget")
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

import SwiftUI
import Combine
import SonyHeadphonesKit

/// SwiftUI can keep a menu panel's content alive while the panel is closed. Watch
/// the hosting window instead of treating the content's lifetime as user activity.
struct ControlSurfaceObserver: NSViewRepresentable {
    let controller: HeadphonesController
    var hideInitialWindow: (() -> Bool)?

    func makeNSView(context: Context) -> SurfaceView {
        SurfaceView(controller: controller, hideFirstAppearance: hideInitialWindow?() ?? false)
    }

    func updateNSView(_ nsView: SurfaceView, context: Context) {}

    static func dismantleNSView(_ nsView: SurfaceView, coordinator: ()) {
        nsView.observations.removeAll()
        nsView.controller.setControlSurface(nsView.id, visible: false)
    }

    final class SurfaceView: NSView {
        let id = UUID()
        let controller: HeadphonesController
        var hideFirstAppearance: Bool
        var observations: Set<AnyCancellable> = []

        init(controller: HeadphonesController, hideFirstAppearance: Bool) {
            self.controller = controller
            self.hideFirstAppearance = hideFirstAppearance
            super.init(frame: .zero)
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            observations.removeAll()
            controller.setControlSurface(id, visible: false)
            guard let window, !ProbeMode.active else { return }

            Publishers.Merge3(
                window.publisher(for: \.isVisible),
                window.publisher(for: \.isMiniaturized),
                NSApp.publisher(for: \.isHidden)
            )
            .receive(on: RunLoop.main)
            .sink { [weak self, weak window] _ in
                guard let self, let window else { return }
                if window.isVisible && self.hideFirstAppearance {
                    self.hideFirstAppearance = false
                    window.orderOut(nil)
                    return
                }
                self.controller.setControlSurface(self.id, visible: window.isVisible && !window.isMiniaturized && !NSApp.isHidden)
            }
            .store(in: &observations)
        }
    }
}

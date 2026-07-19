import AppKit
import Combine
import SonyHeadphonesKit
import SwiftUI
import XM6SystemIntegration

/// Keeps system actions on the app's one long-lived headphones controller. This
/// view is attached to the persistent MenuBarExtra label, so it remains alive when
/// the main and widget windows are closed.
struct XM6SystemActionBridge: View {
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var controller: HeadphonesController
    @State private var pendingSoundAction: XM6SystemAction?

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onAppear {
                performPendingAction()
            }
            .onReceive(NotificationCenter.default.publisher(for: XM6SystemActionMailbox.didSubmit)) { _ in
                performPendingAction()
            }
            .onReceive(controller.$connectionState) { state in
                guard state == .connected, let action = pendingSoundAction else { return }
                pendingSoundAction = nil
                applySoundAction(action)
            }
    }

    private func performPendingAction() {
        guard let action = XM6SystemActionMailbox.consume() else { return }

        switch action {
        case .openControls:
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        case .openWidget:
            openWindow(id: "desktop-widget")
            NSApp.activate(ignoringOtherApps: true)
        case .noiseCancelling, .ambientSound, .soundControlOff:
            performSoundActionWhenConnected(action)
        }
    }

    private func performSoundActionWhenConnected(_ action: XM6SystemAction) {
        if controller.connectionState == .connected {
            applySoundAction(action)
            return
        }

        pendingSoundAction = action
        switch controller.connectionState {
        case .disconnected, .failed:
            controller.autoConnect()
        case .searching, .connecting, .initializing, .connected:
            break
        }
    }

    private func applySoundAction(_ action: XM6SystemAction) {
        guard let mode = action.ambientSoundMode else { return }
        var state = controller.ambientSound ?? AmbientSoundState()
        state.mode = mode
        controller.setAmbientSound(state)
    }
}

private extension XM6SystemAction {
    var ambientSoundMode: AmbientSoundMode? {
        switch self {
        case .noiseCancelling: .noiseCancelling
        case .ambientSound: .ambientSound
        case .soundControlOff: .off
        case .openControls, .openWidget: nil
        }
    }
}

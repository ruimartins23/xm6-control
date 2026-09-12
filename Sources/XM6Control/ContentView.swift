import SwiftUI
import AppKit
import SonyHeadphonesKit

struct ContentView: View {
    @EnvironmentObject private var controller: HeadphonesController

    var body: some View {
        ZStack {
            // Plain window background. This used to carry two large blurred color
            // circles; they read as generic app decoration rather than as part of a
            // Mac app, and they fought the translucency of the cards on top.
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()

            switch controller.connectionState {
            case .disconnected, .failed, .searching:
                DisconnectedView()
            case .connecting, .initializing:
                ConnectingView()
            case .connected:
                DashboardView()
            }
        }
        // No explicit tint: selection follows the user's System Settings accent,
        // which is what every other Mac app does.
        .onAppear {
            // Only connect on a genuinely fresh start. This view re-appears every time
            // the main window is reopened from the menu bar; reconnecting over a live
            // connection tears the session down (and can trip a fresh TCC Bluetooth
            // check mid-flight, which killed the app once).
            if controller.connectionState == .disconnected && !ProbeMode.active {
                controller.autoConnect()
            }
        }
    }
}

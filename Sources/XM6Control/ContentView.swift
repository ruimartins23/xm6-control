import SwiftUI
import AppKit
import SonyHeadphonesKit

struct ContentView: View {
    @EnvironmentObject private var controller: HeadphonesController

    var body: some View {
        ZStack {
            // A shallow vertical gradient rather than a flat fill: it gives the cards
            // something to sit against, so they read as layers instead of rectangles
            // on the same plane. Deliberately only a few percent, and nothing like
            // the large blurred colour circles this replaced, which read as generic
            // app decoration rather than as part of a Mac app.
            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor),
                    Color(nsColor: .underPageBackgroundColor),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
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

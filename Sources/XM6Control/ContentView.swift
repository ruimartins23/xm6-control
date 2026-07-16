import SwiftUI
import SonyHeadphonesKit

struct ContentView: View {
    @EnvironmentObject private var controller: HeadphonesController

    var body: some View {
        ZStack {
            backgroundGradient

            switch controller.connectionState {
            case .disconnected, .failed, .searching:
                DisconnectedView()
            case .connecting, .initializing:
                ConnectingView()
            case .connected:
                DashboardView()
            }
        }
        .tint(.indigo)
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

    private var backgroundGradient: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)

            // Soft out-of-focus color washes behind the glass surfaces.
            Circle()
                .fill(Color.indigo.opacity(0.18))
                .frame(width: 420, height: 420)
                .blur(radius: 110)
                .offset(x: -140, y: -220)

            Circle()
                .fill(Color.purple.opacity(0.10))
                .frame(width: 380, height: 380)
                .blur(radius: 120)
                .offset(x: 170, y: 240)
        }
        .ignoresSafeArea()
    }
}

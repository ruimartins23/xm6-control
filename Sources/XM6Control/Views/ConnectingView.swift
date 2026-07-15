import SwiftUI
import SonyHeadphonesKit

struct ConnectingView: View {
    @EnvironmentObject private var controller: HeadphonesController

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text(statusText)
                .font(.headline)
                .foregroundStyle(.secondary)
            if let name = controller.deviceName {
                Text(name)
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var statusText: String {
        switch controller.connectionState {
        case .connecting: return "Connecting\u{2026}"
        case .initializing: return "Talking to headphones\u{2026}"
        default: return "Connecting\u{2026}"
        }
    }
}

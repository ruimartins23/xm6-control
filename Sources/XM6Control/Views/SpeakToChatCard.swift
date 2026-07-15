import SwiftUI
import SonyHeadphonesKit

struct SpeakToChatCard: View {
    @EnvironmentObject private var controller: HeadphonesController

    private var effectiveEnabled: Bool? {
        controller.speakToChatEnabled ?? (controller.initialStateTimedOut ? false : nil)
    }

    private var effectiveConfig: SpeakToChatConfigState {
        controller.speakToChatConfig ?? SpeakToChatConfigState(sensitivity: .auto, timeout: .standard)
    }

    var body: some View {
        Card("Speak-to-Chat") {
            if let enabled = effectiveEnabled {
                if controller.speakToChatEnabled == nil {
                    StateNotReportedBanner()
                }

                Toggle("Automatically pause playback when you talk", isOn: Binding(
                    get: { enabled },
                    set: { controller.setSpeakToChatEnabled($0) }
                ))
                .toggleStyle(.switch)

                if enabled {
                    Divider()

                    let config = effectiveConfig

                    Picker("Sensitivity", selection: Binding(
                        get: { config.sensitivity },
                        set: { controller.setSpeakToChatConfig(SpeakToChatConfigState(sensitivity: $0, timeout: config.timeout)) }
                    )) {
                        ForEach(SpeakToChatSensitivity.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    }

                    Picker("Resume After", selection: Binding(
                        get: { config.timeout },
                        set: { controller.setSpeakToChatConfig(SpeakToChatConfigState(sensitivity: config.sensitivity, timeout: $0)) }
                    )) {
                        ForEach(SpeakToChatTimeout.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    }
                }
            } else {
                LoadingRow()
            }
        }
    }
}

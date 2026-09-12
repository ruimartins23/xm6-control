import SwiftUI
import SonyHeadphonesKit

/// Speak-to-Chat settings. A section inside `BehaviorCard`: these are set-once
/// preferences, so they don't warrant the same visual weight as the controls the
/// user actually came to change.
struct SpeakToChatSection: View {
    @EnvironmentObject private var controller: HeadphonesController

    private var effectiveEnabled: Bool? {
        controller.speakToChatEnabled ?? (controller.initialStateTimedOut ? false : nil)
    }

    private var effectiveConfig: SpeakToChatConfigState {
        controller.speakToChatConfig ?? SpeakToChatConfigState(sensitivity: .auto, timeout: .standard)
    }

    var body: some View {
        CardSection("Speak-to-Chat", icon: "mic") {
            if let enabled = effectiveEnabled {
                VStack(alignment: .leading, spacing: 10) {
                    if controller.speakToChatEnabled == nil {
                        StateNotReportedBanner()
                    }

                    Toggle("Pause playback when you talk", isOn: Binding(
                        get: { enabled },
                        set: { controller.setSpeakToChatEnabled($0) }
                    ))
                    .toggleStyle(.switch)
                    .controlSize(.small)

                    if enabled {
                        let config = effectiveConfig

                        Picker("Sensitivity", selection: Binding(
                            get: { config.sensitivity },
                            set: { controller.setSpeakToChatConfig(SpeakToChatConfigState(sensitivity: $0, timeout: config.timeout)) }
                        )) {
                            ForEach(SpeakToChatSensitivity.allCases) { option in
                                Text(option.label).tag(option)
                            }
                        }
                        .controlSize(.small)

                        Picker("Resume After", selection: Binding(
                            get: { config.timeout },
                            set: { controller.setSpeakToChatConfig(SpeakToChatConfigState(sensitivity: config.sensitivity, timeout: $0)) }
                        )) {
                            ForEach(SpeakToChatTimeout.allCases) { option in
                                Text(option.label).tag(option)
                            }
                        }
                        .controlSize(.small)
                    }
                }
                .animation(Motion.transition, value: enabled)
            } else {
                LoadingRow()
            }
        }
    }
}

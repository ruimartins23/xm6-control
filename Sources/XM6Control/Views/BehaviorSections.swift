import SwiftUI
import SonyHeadphonesKit

/// Set-once preferences, below the controls people open the window to change.
struct SpeakToChatSection: View {
    @EnvironmentObject private var controller: HeadphonesController

    private var effectiveEnabled: Bool? {
        controller.speakToChatEnabled ?? (controller.initialStateTimedOut ? false : nil)
    }

    private var config: SpeakToChatConfigState {
        controller.speakToChatConfig ?? SpeakToChatConfigState(sensitivity: .auto, timeout: .standard)
    }

    var body: some View {
        Section("Speak-to-Chat") {
            if let enabled = effectiveEnabled {
                if controller.speakToChatEnabled == nil {
                    StateNotReportedNote()
                }

                Toggle("Pause playback when you talk", isOn: Binding(
                    get: { enabled },
                    set: { controller.setSpeakToChatEnabled($0) }
                ))

                if enabled {
                    Picker("Sensitivity", selection: Binding(
                        get: { config.sensitivity },
                        set: { controller.setSpeakToChatConfig(SpeakToChatConfigState(sensitivity: $0, timeout: config.timeout)) }
                    )) {
                        ForEach(SpeakToChatSensitivity.allCases) { Text($0.label).tag($0) }
                    }

                    Picker("Resume after", selection: Binding(
                        get: { config.timeout },
                        set: { controller.setSpeakToChatConfig(SpeakToChatConfigState(sensitivity: config.sensitivity, timeout: $0)) }
                    )) {
                        ForEach(SpeakToChatTimeout.allCases) { Text($0.label).tag($0) }
                    }
                }
            } else {
                LoadingRow()
            }
        }
    }
}

struct WearDetectionSection: View {
    @EnvironmentObject private var controller: HeadphonesController

    private var effectivePause: Bool? {
        controller.pauseWhenTakenOff ?? (controller.initialStateTimedOut ? true : nil)
    }

    private var effectiveAutoPowerOff: AutomaticPowerOffMode? {
        controller.automaticPowerOff ?? (controller.initialStateTimedOut ? .whenTakenOff : nil)
    }

    var body: some View {
        Section("Wearing Detection") {
            if controller.initialStateTimedOut
                && (controller.pauseWhenTakenOff == nil || controller.automaticPowerOff == nil) {
                StateNotReportedNote()
            }

            if let pause = effectivePause {
                Toggle("Pause playback when taken off", isOn: Binding(
                    get: { pause },
                    set: { controller.setPauseWhenTakenOff($0) }
                ))
            } else {
                LabeledContent("Pause playback when taken off") { ProgressView().controlSize(.small) }
            }

            if let autoPowerOff = effectiveAutoPowerOff {
                Picker("Automatic power off", selection: Binding(
                    get: { autoPowerOff },
                    set: { controller.setAutomaticPowerOff($0) }
                )) {
                    ForEach(AutomaticPowerOffMode.allCases) { Text($0.label).tag($0) }
                }
            } else {
                LabeledContent("Automatic power off") { ProgressView().controlSize(.small) }
            }
        }
    }
}

import SwiftUI
import SonyHeadphonesKit

/// Wearing-detection and power settings. A section inside `BehaviorCard`.
struct WearDetectionSection: View {
    @EnvironmentObject private var controller: HeadphonesController

    private var effectivePause: Bool? {
        controller.pauseWhenTakenOff ?? (controller.initialStateTimedOut ? true : nil)
    }

    private var effectiveAutoPowerOff: AutomaticPowerOffMode? {
        controller.automaticPowerOff ?? (controller.initialStateTimedOut ? .whenTakenOff : nil)
    }

    var body: some View {
        CardSection("Wearing Detection", icon: "sensor.tag.radiowaves.forward") {
            VStack(alignment: .leading, spacing: 10) {
                if controller.initialStateTimedOut
                    && (controller.pauseWhenTakenOff == nil || controller.automaticPowerOff == nil) {
                    StateNotReportedBanner()
                }

                if let pauseWhenTakenOff = effectivePause {
                    SettingsRow("Pause playback when taken off") {
                        Toggle("", isOn: Binding(
                            get: { pauseWhenTakenOff },
                            set: { controller.setPauseWhenTakenOff($0) }
                        ))
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                    }
                } else {
                    pendingRow("Pause playback when taken off")
                }

                Divider()

                if let autoPowerOff = effectiveAutoPowerOff {
                    SettingsRow("Automatic power off") {
                        Picker("", selection: Binding(
                            get: { autoPowerOff },
                            set: { controller.setAutomaticPowerOff($0) }
                        )) {
                            ForEach(AutomaticPowerOffMode.allCases) { option in
                                Text(option.label).tag(option)
                            }
                        }
                        .labelsHidden()
                        .controlSize(.small)
                        .fixedSize()
                    }
                } else {
                    pendingRow("Automatic Power Off")
                }
            }
        }
    }

    private func pendingRow(_ label: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            ProgressView().controlSize(.small)
        }
        .foregroundStyle(.secondary)
    }
}

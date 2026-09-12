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
        CardSection("Wearing Detection") {
            VStack(alignment: .leading, spacing: 10) {
                if controller.initialStateTimedOut
                    && (controller.pauseWhenTakenOff == nil || controller.automaticPowerOff == nil) {
                    StateNotReportedBanner()
                }

                if let pauseWhenTakenOff = effectivePause {
                    Toggle("Pause playback when taken off", isOn: Binding(
                        get: { pauseWhenTakenOff },
                        set: { controller.setPauseWhenTakenOff($0) }
                    ))
                    .toggleStyle(.switch)
                    .controlSize(.small)
                } else {
                    pendingRow("Pause playback when taken off")
                }

                if let autoPowerOff = effectiveAutoPowerOff {
                    Picker("Automatic Power Off", selection: Binding(
                        get: { autoPowerOff },
                        set: { controller.setAutomaticPowerOff($0) }
                    )) {
                        ForEach(AutomaticPowerOffMode.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    }
                    .controlSize(.small)
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

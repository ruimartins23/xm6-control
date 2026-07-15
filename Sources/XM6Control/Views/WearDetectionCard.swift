import SwiftUI
import SonyHeadphonesKit

struct WearDetectionCard: View {
    @EnvironmentObject private var controller: HeadphonesController

    private var effectivePause: Bool? {
        controller.pauseWhenTakenOff ?? (controller.initialStateTimedOut ? true : nil)
    }

    private var effectiveAutoPowerOff: AutomaticPowerOffMode? {
        controller.automaticPowerOff ?? (controller.initialStateTimedOut ? .whenTakenOff : nil)
    }

    var body: some View {
        Card("Wearing Detection") {
            VStack(alignment: .leading, spacing: 14) {
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
                } else {
                    HStack {
                        Text("Pause playback when taken off")
                        Spacer()
                        ProgressView().controlSize(.small)
                    }
                }

                Divider()

                if let autoPowerOff = effectiveAutoPowerOff {
                    Picker("Automatic Power Off", selection: Binding(
                        get: { autoPowerOff },
                        set: { controller.setAutomaticPowerOff($0) }
                    )) {
                        ForEach(AutomaticPowerOffMode.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    }
                } else {
                    HStack {
                        Text("Automatic Power Off")
                        Spacer()
                        ProgressView().controlSize(.small)
                    }
                }
            }
        }
    }
}

import SwiftUI
import SonyHeadphonesKit

/// Listening mode picker. A section rather than its own card: it shapes the sound,
/// so it shares a surface with the equalizer inside `SoundCard`.
struct ListeningModeSection: View {
    @EnvironmentObject private var controller: HeadphonesController

    private var effectiveMode: ListeningMode? {
        controller.listeningMode ?? (controller.initialStateTimedOut ? .standard : nil)
    }

    var body: some View {
        CardSection("Listening Mode", icon: "music.note") {
            if let mode = effectiveMode {
                VStack(alignment: .leading, spacing: 12) {
                    if controller.listeningMode == nil {
                        StateNotReportedBanner()
                    }

                    ModeSelector(
                        options: [
                            .init(value: .standard, title: "Standard", icon: "music.note"),
                            .init(value: .backgroundMusic, title: "Background\nMusic", icon: "sofa"),
                            .init(value: .cinema, title: "Cinema", icon: "film"),
                        ],
                        selection: mode,
                        select: { controller.setListeningMode($0) }
                    )

                    if mode == .backgroundMusic {
                        Picker("Speaker Distance", selection: Binding(
                            get: { controller.bgmRoomSize ?? .middle },
                            set: { controller.setBGMRoomSize($0) }
                        )) {
                            ForEach(BGMRoomSize.allCases) { size in
                                Text(size.label).tag(size)
                            }
                        }
                        .pickerStyle(.segmented)
                        .controlSize(.small)
                        .transition(.opacity)
                    }
                }
                .animation(Motion.transition, value: mode)
            } else {
                LoadingRow()
            }
        }
    }
}

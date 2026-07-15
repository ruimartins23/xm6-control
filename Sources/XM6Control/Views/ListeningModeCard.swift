import SwiftUI
import SonyHeadphonesKit

struct ListeningModeCard: View {
    @EnvironmentObject private var controller: HeadphonesController

    private var effectiveMode: ListeningMode? {
        controller.listeningMode ?? (controller.initialStateTimedOut ? .standard : nil)
    }

    var body: some View {
        Card("Listening Mode") {
            if let mode = effectiveMode {
                VStack(alignment: .leading, spacing: 14) {
                    if controller.listeningMode == nil {
                        StateNotReportedBanner()
                    }

                    HStack(spacing: 24) {
                        modeButton(.standard, label: "Standard", icon: "music.note", current: mode)
                        modeButton(.backgroundMusic, label: "Background\nMusic", icon: "sofa", current: mode)
                        modeButton(.cinema, label: "Cinema", icon: "film", current: mode)
                    }
                    .frame(maxWidth: .infinity)

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
                        .transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: mode)
            } else {
                LoadingRow()
            }
        }
    }

    private func modeButton(_ mode: ListeningMode, label: String, icon: String, current: ListeningMode) -> some View {
        let isSelected = current == mode
        return Button {
            controller.setListeningMode(mode)
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    if isSelected {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.brand, .brand.opacity(0.72)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .shadow(color: Color.brand.opacity(0.45), radius: 8, y: 3)
                    } else {
                        Circle()
                            .fill(Color.primary.opacity(0.06))
                            .overlay(Circle().strokeBorder(Color.primary.opacity(0.10), lineWidth: 1))
                    }
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? Color.white : Color.primary.opacity(0.75))
                }
                .frame(width: 58, height: 58)

                Text(label)
                    .font(.caption2.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.brand : Color.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .buttonStyle(.plain)
    }
}

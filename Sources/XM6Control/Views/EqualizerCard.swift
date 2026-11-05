import SwiftUI
import SonyHeadphonesKit

/// Equalizer preset chips, plus the band faders when the custom preset is active.
/// A section rather than its own card, sharing `SoundCard` with the listening mode.
struct EqualizerSection: View {
    @EnvironmentObject private var controller: HeadphonesController
    @EnvironmentObject private var profileStore: EqualizerProfileStore

    private let columns = [GridItem(.adaptive(minimum: 92), spacing: 6)]

    private var effectivePresetCode: UInt8? {
        controller.equalizer?.presetCode ?? (controller.initialStateTimedOut ? EqualizerPreset.off.rawValue : nil)
    }

    /// The curve the faders edit. The headphones report ten bands; if a reply hasn't
    /// arrived yet, start from flat so the faders are still usable.
    private var bands: [Int] {
        let reported = controller.equalizer?.bands ?? []
        guard reported.count == SonyCommands.defaultBandCount else {
            return Array(repeating: 0, count: SonyCommands.defaultBandCount)
        }
        return reported
    }

    private var isCustomActive: Bool {
        effectivePresetCode == EqualizerPreset.custom.rawValue
    }

    /// The curve the headphones actually reported, with no flat fallback. Saving a
    /// profile from a fallback would store ten zeros that never came from the device.
    private var reportedBands: [Int]? {
        guard let bands = controller.equalizer?.bands,
              bands.count == SonyCommands.defaultBandCount else { return nil }
        return bands
    }

    var body: some View {
        CardSection("Equalizer", icon: "slider.vertical.3") {
            if let presetCode = effectivePresetCode {
                VStack(alignment: .leading, spacing: 10) {
                    if controller.equalizer == nil {
                        StateNotReportedBanner()
                    }

                    LazyVGrid(columns: columns, spacing: 6) {
                        ForEach(EqualizerPreset.allCases) { option in
                            presetChip(option, isSelected: option.rawValue == presetCode)
                        }
                    }

                    if isCustomActive {
                        customBands
                            .transition(.opacity)
                    } else if EqualizerPreset(rawValue: presetCode) == nil {
                        Text("A personalized preset is active, set in the official app. Picking one above replaces it.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    profilesSection
                }
                .animation(Motion.transition, value: isCustomActive)
            } else {
                LoadingRow()
            }
        }
    }

    // MARK: - Custom band faders

    private var customBands: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()

            HStack(alignment: .bottom, spacing: 2) {
                ForEach(Array(bands.enumerated()), id: \.offset) { index, gain in
                    bandFader(index: index, gain: gain)
                }
            }
            .frame(maxWidth: .infinity)

            HStack {
                Text("Low")
                Spacer()
                Text("High")
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)

            Button("Reset to flat") {
                controller.setEqualizerBands(
                    Array(repeating: 0, count: SonyCommands.defaultBandCount)
                )
            }
            .controlSize(.small)
            .disabled(bands.allSatisfy { $0 == 0 })
        }
    }

    private func bandFader(index: Int, gain: Int) -> some View {
        VStack(spacing: 3) {
            Text(gain > 0 ? "+\(gain)" : "\(gain)")
                .font(.system(size: 9).monospacedDigit())
                .foregroundStyle(gain == 0 ? .tertiary : .secondary)

            VerticalFader(
                value: gain,
                range: SonyCommands.bandGainRange
            ) { newGain in
                var updated = bands
                updated[index] = newGain
                controller.setEqualizerBands(updated)
            }
            .frame(width: 24, height: 86)
            .accessibilityLabel("Band \(index + 1) of \(bands.count)")
            .accessibilityValue("\(gain)")

            Text("\(index + 1)")
                .font(.system(size: 9).monospacedDigit())
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Saved profiles

    /// Profiles are shown whatever preset is active, since applying one is itself
    /// what switches the headphones to the custom slot.
    private var profilesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()

            HStack {
                Text("Profiles")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    saveCurrentCurve()
                } label: {
                    Label("Save Current\u{2026}", systemImage: "plus")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .disabled(reportedBands == nil)
                .help("Save the curve the headphones are using now as a named profile")
            }

            if profileStore.profiles.isEmpty {
                Text("Pick a preset or shape the custom curve, then save it here to come back to it later.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(profileStore.profiles) { profile in
                        profileChip(profile)
                    }
                }

                Text("Right-click a profile to rename, update or delete it.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func profileChip(_ profile: EqualizerProfile) -> some View {
        let isActive = isCustomActive && reportedBands == profile.bands

        return Button {
            controller.setEqualizerBands(profile.bands)
        } label: {
            Text(profile.name)
                .font(.caption.weight(isActive ? .semibold : .regular))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .padding(.horizontal, 6)
                .foregroundStyle(isActive ? Color.white : Color.primary.opacity(0.85))
                .controlSurface(
                    RoundedRectangle(cornerRadius: Radius.control),
                    isSelected: isActive
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle(scale: 0.96))
        .help(profile.name)
        .accessibilityLabel("\(profile.name) equalizer profile")
        .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
        .contextMenu {
            Button("Apply") {
                controller.setEqualizerBands(profile.bands)
            }
            Button("Update with Current Curve") {
                if let bands = reportedBands {
                    profileStore.overwrite(profile.id, with: bands)
                }
            }
            .disabled(reportedBands == nil || reportedBands == profile.bands)
            Button("Rename\u{2026}") {
                rename(profile)
            }
            Divider()
            Button("Delete\u{2026}", role: .destructive) {
                if ProfilePrompt.confirmDelete(profile.name) {
                    profileStore.delete(profile.id)
                }
            }
        }
    }

    private func saveCurrentCurve() {
        guard let bands = reportedBands else { return }
        let source = isCustomActive ? "the custom curve" : "the \u{201c}\(controller.equalizer?.preset?.label ?? "current")\u{201d} preset"
        guard let name = ProfilePrompt.askForName(
            title: "Save Equalizer Profile",
            message: "Saves \(source) as a profile you can apply again later.",
            suggested: "My Profile",
            confirm: "Save"
        ) else { return }
        profileStore.add(name: name, bands: bands)
    }

    private func rename(_ profile: EqualizerProfile) {
        guard let name = ProfilePrompt.askForName(
            title: "Rename Profile",
            message: "Choose a new name for \u{201c}\(profile.name)\u{201d}.",
            suggested: profile.name,
            confirm: "Rename"
        ) else { return }
        profileStore.rename(profile.id, to: name)
    }

    // MARK: - Presets

    private func presetChip(_ preset: EqualizerPreset, isSelected: Bool) -> some View {
        Button {
            controller.setEqualizerPreset(preset)
        } label: {
            Text(preset.label)
                .font(.caption.weight(isSelected ? .semibold : .regular))
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .foregroundStyle(isSelected ? Color.white : Color.primary.opacity(0.85))
                .controlSurface(
                    RoundedRectangle(cornerRadius: Radius.control),
                    isSelected: isSelected
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle(scale: 0.96))
        .accessibilityLabel("\(preset.label) equalizer preset")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

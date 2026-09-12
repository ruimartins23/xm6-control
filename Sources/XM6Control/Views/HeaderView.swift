import SwiftUI
import SonyHeadphonesKit

struct HeaderView: View {
    @EnvironmentObject private var controller: HeadphonesController

    /// Side-by-side in a wide window, stacked in a narrow one. Stacked artwork in a
    /// wide window leaves a broad empty band either side of it.
    var horizontal = false

    var body: some View {
        Group {
            if horizontal {
                // A defined banner rather than artwork floating on the window: at wide
                // sizes the space to the right of the name would otherwise read as a
                // gap in the layout instead of deliberate breathing room.
                HStack(spacing: 18) {
                    artwork
                        .frame(width: 112, height: 96)
                    identity(alignment: .leading)
                    Spacer(minLength: 16)
                    glanceSummary
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassSurface(cornerRadius: Radius.card)
            } else {
                VStack(spacing: 10) {
                    artwork
                        .frame(height: 112)
                    identity(alignment: .center)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 2)
            }
        }
    }

    /// The product shot on a soft stage. The wash is a photographic pedestal behind
    /// the subject, not a decorative blob.
    ///
    /// Stage and artwork are stacked rather than the stage being a `.background` of
    /// the image: a background participates in the shadow, so the shadow was being
    /// cast by the gradient's rectangle and showed up as a grey box behind the
    /// headphones. Stacked, the shadow is cast only by the photo's own alpha.
    private var artwork: some View {
        ZStack {
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(0.10), Color.clear],
                        center: .center,
                        startRadius: 2,
                        endRadius: 62
                    )
                )
                .blur(radius: 8)

            HeadphoneImage()
                .shadow(color: Color.black.opacity(0.45), radius: 10, y: 7)
        }
    }

    /// State summary for the wide layout. The banner is otherwise mostly empty at
    /// that width, and the things worth knowing without scanning four cards are
    /// exactly what is on the headphones right now.
    private var glanceSummary: some View {
        VStack(alignment: .leading, spacing: 5) {
            if let mode = controller.ambientSound?.mode {
                glanceRow("Noise control", ambientLabel(mode))
            }
            if let listening = controller.listeningMode {
                glanceRow("Listening", listening.label)
            }
            if let preset = controller.equalizer {
                glanceRow("Equalizer", preset.preset?.label ?? "Personalized")
            }
            if let playing = controller.devices?.first(where: { $0.isPlayback })?.name {
                glanceRow("Playing on", playing)
            }
        }
        .frame(width: 240, alignment: .leading)
    }

    private func glanceRow(_ key: String, _ value: String) -> some View {
        HStack(spacing: 10) {
            Text(key)
                .foregroundStyle(.tertiary)
            Spacer(minLength: 8)
            Text(value)
                .foregroundStyle(.secondary)
                .fontWeight(.medium)
                .lineLimit(1)
        }
        .font(.caption)
    }

    private func ambientLabel(_ mode: AmbientSoundMode) -> String {
        switch mode {
        case .noiseCancelling: return "Noise Canceling"
        case .ambientSound: return "Ambient Sound"
        case .off: return "Off"
        }
    }

    private func identity(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 7) {
            Text(controller.deviceName ?? "WH-1000XM6")
                .font(.title3.weight(.semibold))

            batteryStatus
        }
    }

    @ViewBuilder
    private var batteryStatus: some View {
        if let battery = controller.battery {
            BatteryGauge(level: battery.level, isCharging: battery.isCharging)
        } else if controller.initialStateTimedOut {
            Text("Battery level not reported")
                .font(.footnote)
                .foregroundStyle(.tertiary)
        } else {
            Text("Loading battery\u{2026}")
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
    }
}

/// A drawn battery gauge rather than an SF Symbol plus a number: the fill level is
/// readable at a glance, and it gives the header a piece of real instrumentation
/// instead of another line of text.
struct BatteryGauge: View {
    let level: Int
    let isCharging: Bool

    private static let bodyWidth: CGFloat = 30
    private static let bodyHeight: CGFloat = 14
    private static let inset: CGFloat = 2
    /// Squared-off with a terminal nub, not a capsule: a rounded pill with a partial
    /// fill reads as a switch sitting in the off position rather than as a battery.
    private static let corner: CGFloat = 3.5

    private var tint: Color {
        if isCharging { return .green }
        switch level {
        case ..<20: return .red
        case ..<40: return .orange
        default: return .green
        }
    }

    private var fillWidth: CGFloat {
        let usable = Self.bodyWidth - Self.inset * 2
        let clamped = CGFloat(min(max(level, 0), 100)) / 100
        // Never fully empty, so the gauge still reads as a gauge at 1%.
        return max(3, usable * clamped)
    }

    var body: some View {
        HStack(spacing: 7) {
            HStack(spacing: 1.5) {
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: Self.corner)
                        .fill(Color.black.opacity(0.28))

                    RoundedRectangle(cornerRadius: Self.corner - Self.inset)
                        .fill(
                            LinearGradient(
                                colors: [tint, tint.opacity(0.72)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: fillWidth, height: Self.bodyHeight - Self.inset * 2)
                        .padding(.leading, Self.inset)

                    if isCharging {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.45), radius: 1)
                            .frame(width: Self.bodyWidth, alignment: .center)
                    }
                }
                .frame(width: Self.bodyWidth, height: Self.bodyHeight)
                .overlay(
                    RoundedRectangle(cornerRadius: Self.corner).strokeBorder(
                        LinearGradient(
                            colors: [Color.black.opacity(0.30), Color.white.opacity(0.14)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
                )

                // Terminal cap.
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.primary.opacity(0.35))
                    .frame(width: 2, height: 5)
            }

            Text("\(level)%")
                .font(.footnote.weight(.medium).monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Battery \(level) percent\(isCharging ? ", charging" : "")")
    }
}

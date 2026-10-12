import SwiftUI
import WidgetKit
import AppIntents
import XM6Shared

struct HeadphonesWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let snapshot: HeadphonesSnapshot

    var body: some View {
        if !snapshot.isConnected {
            disconnected
        } else {
            switch family {
            case .systemLarge: large
            case .systemMedium: medium
            default: small
            }
        }
    }

    // MARK: - Layouts

    private var small: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                Image(systemName: "headphones")
                    .font(.title3.weight(.semibold))
                    .widgetAccentable()
                Spacer()
                battery
            }
            Spacer(minLength: 4)
            Text(snapshot.noiseMode?.title ?? "Unknown")
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(snapshot.listeningMode?.title ?? snapshot.deviceName)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: 8)
            HStack(spacing: 6) {
                ForEach(NoiseMode.allCases, id: \.self) { mode in
                    noiseButton(mode, labeled: false)
                }
            }
        }
    }

    private var medium: some View {
        HStack(spacing: 14) {
            deviceColumn
            VStack(alignment: .leading, spacing: 8) {
                noiseRow
                listeningSegments
                Spacer(minLength: 0)
                detailRow("slider.vertical.3", mediumDetail)
                detailRow("speaker.wave.2.fill", snapshot.playingOn)
            }
        }
    }

    private var mediumDetail: String? {
        let parts = [snapshot.equalizerLabel.map { "EQ \($0)" }, snapshot.listeningMode?.title].compactMap(\.self)
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private var large: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                deviceColumn
                VStack(alignment: .leading, spacing: 8) {
                    noiseRow
                    HStack(spacing: 6) {
                        ForEach(ListeningModeOption.allCases, id: \.self) { mode in
                            listeningDot(mode)
                        }
                        if let title = snapshot.listeningMode?.title {
                            Text(title)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .padding(.leading, 2)
                        }
                    }
                    Spacer(minLength: 0)
                    detailRow("speaker.wave.2.fill", snapshot.playingOn)
                }
            }
            .frame(height: 150)

            Divider()

            section("Equalizer", trailing: snapshot.equalizer == nil ? snapshot.equalizerLabel : nil) {
                Grid(horizontalSpacing: 6, verticalSpacing: 6) {
                    GridRow {
                        equalizerButton(.off)
                        equalizerButton(.heavy)
                        equalizerButton(.clear)
                    }
                    GridRow {
                        equalizerButton(.hard)
                        equalizerButton(.soft)
                        equalizerButton(.custom)
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Shared rows

    private var deviceColumn: some View {
        VStack(alignment: .leading, spacing: 4) {
            artwork
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Text(snapshot.deviceName)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            battery
        }
        .frame(width: 112)
    }

    private var noiseRow: some View {
        HStack(spacing: 6) {
            ForEach(NoiseMode.allCases, id: \.self) { mode in
                noiseButton(mode, labeled: true)
            }
        }
    }

    /// The listening modes as one slim segmented capsule, quieter than the noise tiles.
    /// The selection is a single glass pill that slides between segments: WidgetKit
    /// animates the change from the old timeline entry to the new one.
    ///
    /// With Reduce Transparency on the pill turns solid, as the system's own controls
    /// do. When the widget is drawn tinted or clear rather than in full color, any
    /// pill would read as a blob, so the selection is marked by color and a dot.
    private var listeningSegments: some View {
        let isDark = colorScheme == .dark
        let showsPill = renderingMode == .fullColor
        let showsGlass = showsPill && !reduceTransparency
        let modes = ListeningModeOption.allCases
        let selectedIndex = snapshot.listeningMode.flatMap { modes.firstIndex(of: $0) }
        return GeometryReader { proxy in
            let segment = (proxy.size.width - 4) / CGFloat(modes.count)
            ZStack(alignment: .leading) {
                if let selectedIndex, showsPill {
                    // `glassEffect` renders empty inside a widget, so the clear glass is
                    // drawn by hand: a translucent white fill with a specular rim.
                    Capsule()
                        .fill(
                            showsGlass ? Color.white.opacity(isDark ? 0.16 : 0.7)
                                : (isDark ? Color(white: 0.36) : Color.white)
                        )
                        .overlay {
                            if showsGlass {
                                Capsule().strokeBorder(
                                    LinearGradient(
                                        colors: [
                                            .white.opacity(isDark ? 0.55 : 1),
                                            .white.opacity(isDark ? 0.05 : 0.3),
                                            .white.opacity(isDark ? 0.25 : 0.8),
                                        ],
                                        startPoint: .topLeading, endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                            }
                        }
                        .shadow(color: .black.opacity(isDark ? 0.4 : 0.12), radius: 4, y: 2)
                        .frame(width: segment, height: 24)
                        .offset(x: 2 + segment * CGFloat(selectedIndex))
                }
                HStack(spacing: 0) {
                    ForEach(modes, id: \.self) { mode in
                        let isSelected = mode == snapshot.listeningMode
                        listeningButton(mode) {
                            Image(systemName: mode.symbol)
                                .font(.system(size: 11, weight: .semibold))
                                .scaleEffect(isSelected ? 1.12 : 1)
                                .frame(width: segment, height: 24)
                                .foregroundStyle(
                                    isSelected ? Color.accentColor
                                        : (showsPill ? Color.primary : Color.secondary)
                                )
                                .overlay(alignment: .bottom) {
                                    if isSelected && !showsPill {
                                        Circle()
                                            .fill(Color.accentColor)
                                            .frame(width: 3, height: 3)
                                            .offset(y: 1)
                                    }
                                }
                                .widgetAccentable(isSelected)
                                .contentShape(Capsule())
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
            .frame(width: proxy.size.width, height: 28)
            .background(Capsule().fill(.fill.secondary))
            .animation(.spring(duration: 0.5, bounce: 0.35), value: selectedIndex)
        }
        .frame(height: 28)
    }

    private var disconnected: some View {
        VStack(spacing: 6) {
            Image(systemName: "headphones")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.secondary)
            Text("Not Connected")
                .font(.headline)
            Text("Open XM6 Control to connect")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Pieces

    @ViewBuilder
    private func detailRow(_ symbol: String, _ value: String?) -> some View {
        if let value {
            Label {
                Text(value).lineLimit(1)
            } icon: {
                Image(systemName: symbol).frame(width: 14)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private func section(
        _ title: String,
        trailing: String? = nil,
        @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title)
                Spacer()
                if let trailing {
                    Text(trailing)
                }
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            content()
        }
    }

    @ViewBuilder
    private var artwork: some View {
        if let image = NSImage(named: "headphones") {
            Image(nsImage: image)
                .resizable()
                .widgetAccentedRenderingMode(.desaturated)
                .scaledToFit()
        } else {
            Image(systemName: "headphones")
                .font(.system(size: 36, weight: .light))
        }
    }

    @ViewBuilder
    private var battery: some View {
        if let level = snapshot.batteryLevel {
            HStack(spacing: 3) {
                Image(systemName: batterySymbol(level))
                    .symbolRenderingMode(.hierarchical)
                Text("\(level)%")
                    .monospacedDigit()
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(level < 20 && !snapshot.isCharging ? Color.red : Color.secondary)
        }
    }

    private func batterySymbol(_ level: Int) -> String {
        if snapshot.isCharging { return "battery.100percent.bolt" }
        switch level {
        case ..<13: return "battery.0percent"
        case ..<38: return "battery.25percent"
        case ..<63: return "battery.50percent"
        case ..<88: return "battery.75percent"
        default: return "battery.100percent"
        }
    }

    // MARK: - Buttons

    // `Button(intent:)` needs a concrete intent type, so each option picks its own
    // intent here rather than going through `any AppIntent`.

    @ViewBuilder
    private func noiseButton(_ mode: NoiseMode, labeled: Bool) -> some View {
        let tile = ChoiceTile(
            symbol: mode.symbol,
            title: labeled ? mode.shortTitle : nil,
            isSelected: mode == snapshot.noiseMode,
            height: labeled ? 44 : 30
        )
        switch mode {
        case .noiseCancelling: choice(SetNoiseCancellingIntent(), tile, mode.title)
        case .ambientSound: choice(SetAmbientSoundIntent(), tile, mode.title)
        case .off: choice(SetNoiseControlOffIntent(), tile, mode.title)
        }
    }

    /// A small round listening-mode button, deliberately quieter than the noise tiles.
    private func listeningDot(_ mode: ListeningModeOption) -> some View {
        let isSelected = mode == snapshot.listeningMode
        return listeningButton(mode) {
            Image(systemName: mode.symbol)
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 26, height: 26)
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .background(Circle().fill(isSelected ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.fill.secondary)))
                .widgetAccentable(isSelected)
        }
    }

    private func listeningButton(_ mode: ListeningModeOption, @ViewBuilder label: () -> some View) -> some View {
        let label = label()
        return Group {
            switch mode {
            case .standard: Button(intent: SetStandardListeningIntent()) { label }
            case .backgroundMusic: Button(intent: SetBackgroundMusicIntent()) { label }
            case .cinema: Button(intent: SetCinemaIntent()) { label }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(mode.title)
        .accessibilityAddTraits(mode == snapshot.listeningMode ? .isSelected : [])
    }

    @ViewBuilder
    private func equalizerButton(_ preset: EqualizerOption) -> some View {
        let tile = ChoiceTile(
            symbol: nil,
            title: preset.title,
            isSelected: preset == snapshot.equalizer,
            height: 28
        )
        let label = "\(preset.title) equalizer"
        switch preset {
        case .off: choice(SetEqualizerOffIntent(), tile, label)
        case .heavy: choice(SetEqualizerHeavyIntent(), tile, label)
        case .clear: choice(SetEqualizerClearIntent(), tile, label)
        case .hard: choice(SetEqualizerHardIntent(), tile, label)
        case .soft: choice(SetEqualizerSoftIntent(), tile, label)
        case .custom: choice(SetEqualizerCustomIntent(), tile, label)
        }
    }

    private func choice(_ intent: some AppIntent, _ tile: ChoiceTile, _ accessibilityName: String) -> some View {
        Button(intent: intent) { tile }
            .buttonStyle(.plain)
            .accessibilityLabel(accessibilityName)
            .accessibilityAddTraits(tile.isSelected ? .isSelected : [])
    }
}

/// One selectable tile: accent-filled when selected, a quiet fill otherwise.
private struct ChoiceTile: View {
    let symbol: String?
    let title: String?
    let isSelected: Bool
    let height: CGFloat

    var body: some View {
        VStack(spacing: 3) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .semibold))
            }
            if let title {
                Text(title)
                    .font(.system(size: symbol == nil ? 11 : 9, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .foregroundStyle(isSelected ? Color.white : Color.primary)
        .background(
            RoundedRectangle(cornerRadius: height > 32 ? 12 : 9, style: .continuous)
                .fill(isSelected ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.fill.secondary))
        )
        .widgetAccentable(isSelected)
    }
}

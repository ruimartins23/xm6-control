import Foundation

/// What the WidgetKit widget shows. The widget runs in its own sandboxed process and
/// cannot hold the Bluetooth session, so the app publishes this after every state
/// change and the widget only ever renders the last copy.
public struct HeadphonesSnapshot: Codable, Equatable, Sendable {
    public var isConnected: Bool
    public var deviceName: String
    public var batteryLevel: Int?
    public var isCharging: Bool
    public var noiseMode: NoiseMode?
    public var listeningMode: ListeningModeOption?
    /// `nil` with `equalizerLabel` set means a personalized preset from Sony's app,
    /// which the widget can show but not select.
    public var equalizer: EqualizerOption?
    public var equalizerLabel: String?
    public var playingOn: String?
    public var updatedAt: Date

    public init(
        isConnected: Bool,
        deviceName: String,
        batteryLevel: Int? = nil,
        isCharging: Bool = false,
        noiseMode: NoiseMode? = nil,
        listeningMode: ListeningModeOption? = nil,
        equalizer: EqualizerOption? = nil,
        equalizerLabel: String? = nil,
        playingOn: String? = nil,
        updatedAt: Date = .now
    ) {
        self.isConnected = isConnected
        self.deviceName = deviceName
        self.batteryLevel = batteryLevel
        self.isCharging = isCharging
        self.noiseMode = noiseMode
        self.listeningMode = listeningMode
        self.equalizer = equalizer
        self.equalizerLabel = equalizerLabel
        self.playingOn = playingOn
        self.updatedAt = updatedAt
    }

    /// The widget's optimistic view of a command, shown until the app confirms.
    public mutating func apply(_ command: WidgetCommand) {
        switch command {
        case .setNoiseMode(let mode): noiseMode = mode
        case .setListeningMode(let mode): listeningMode = mode
        case .setEqualizer(let preset):
            equalizer = preset
            equalizerLabel = preset.title
        }
    }

    public static let disconnected = HeadphonesSnapshot(isConnected: false, deviceName: "WH-1000XM6")

    public static let placeholder = HeadphonesSnapshot(
        isConnected: true,
        deviceName: "WH-1000XM6",
        batteryLevel: 80,
        noiseMode: .noiseCancelling,
        listeningMode: .standard,
        equalizer: .off,
        equalizerLabel: "Off",
        playingOn: "MacBook Pro"
    )
}

/// The widget-side mirrors of the kit's enums, so the widget doesn't link the
/// Bluetooth kit.
public enum NoiseMode: String, Codable, CaseIterable, Sendable {
    case noiseCancelling
    case ambientSound
    case off

    public var title: String {
        switch self {
        case .noiseCancelling: return "Noise Canceling"
        case .ambientSound: return "Ambient Sound"
        case .off: return "Off"
        }
    }

    public var shortTitle: String {
        switch self {
        case .noiseCancelling: return "NC"
        case .ambientSound: return "Ambient"
        case .off: return "Off"
        }
    }

    public var symbol: String {
        switch self {
        case .noiseCancelling: return "person.wave.2.fill"
        case .ambientSound: return "waveform.and.person.filled"
        case .off: return "xmark"
        }
    }
}

public enum ListeningModeOption: String, Codable, CaseIterable, Sendable {
    case standard
    case backgroundMusic
    case cinema

    public var title: String {
        switch self {
        case .standard: return "Standard"
        case .backgroundMusic: return "Background Music"
        case .cinema: return "Cinema"
        }
    }

    public var shortTitle: String {
        switch self {
        case .standard: return "Standard"
        case .backgroundMusic: return "BGM"
        case .cinema: return "Cinema"
        }
    }

    public var symbol: String {
        switch self {
        case .standard: return "music.note"
        case .backgroundMusic: return "sofa.fill"
        case .cinema: return "film.fill"
        }
    }
}

public enum EqualizerOption: String, Codable, CaseIterable, Sendable {
    case off, heavy, clear, hard, soft, custom

    public var title: String {
        switch self {
        case .off: return "Off"
        case .heavy: return "Heavy"
        case .clear: return "Clear"
        case .hard: return "Hard"
        case .soft: return "Soft"
        case .custom: return "Custom"
        }
    }
}

/// A request from the widget for the app to act on.
public enum WidgetCommand: Codable, Equatable, Sendable {
    case setNoiseMode(NoiseMode)
    case setListeningMode(ListeningModeOption)
    case setEqualizer(EqualizerOption)
}

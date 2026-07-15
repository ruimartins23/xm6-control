import Foundation

/// The XM6 "Listening Mode": Standard, Background Music (BGM), or Cinema.
///
/// On the wire these are two independent on/off parameters in the AUDIO family
/// (BGM mode and Upmix Cinema); the app derives one tri-state mode from them,
/// mirroring how the official app presents it.
public enum ListeningMode: String, CaseIterable, Sendable, Identifiable {
    case standard
    case backgroundMusic
    case cinema

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .standard: return "Standard"
        case .backgroundMusic: return "Background Music"
        case .cinema: return "Cinema"
        }
    }
}

/// Perceived speaker distance for Background Music mode.
public enum BGMRoomSize: UInt8, CaseIterable, Sendable, Identifiable {
    case small = 0x00
    case middle = 0x01
    case large = 0x02

    public var id: UInt8 { rawValue }

    public var label: String {
        switch self {
        case .small: return "My Room"
        case .middle: return "Living Room"
        case .large: return "Cafe"
        }
    }
}

/// A source device paired/connected to the headphones (multipoint).
public struct MultipointDevice: Equatable, Sendable, Identifiable {
    public var macAddress: String
    public var name: String
    /// Non-zero when the device currently holds a connection.
    public var connectedStatus: UInt8
    /// True when this device is the active playback source.
    public var isPlayback: Bool

    public var id: String { macAddress }
    public var isConnected: Bool { connectedStatus != 0 }

    public init(macAddress: String, name: String, connectedStatus: UInt8, isPlayback: Bool) {
        self.macAddress = macAddress
        self.name = name
        self.connectedStatus = connectedStatus
        self.isPlayback = isPlayback
    }
}

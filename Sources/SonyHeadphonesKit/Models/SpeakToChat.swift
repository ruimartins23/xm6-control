import Foundation

public enum SpeakToChatSensitivity: UInt8, CaseIterable, Sendable, Identifiable {
    case auto = 0x00
    case high = 0x01
    case low = 0x02

    public var id: UInt8 { rawValue }

    public var label: String {
        switch self {
        case .auto: return "Auto"
        case .high: return "High"
        case .low: return "Low"
        }
    }
}

public enum SpeakToChatTimeout: UInt8, CaseIterable, Sendable, Identifiable {
    case short = 0x00
    case standard = 0x01
    case long = 0x02
    case off = 0x03

    public var id: UInt8 { rawValue }

    public var label: String {
        switch self {
        case .short: return "Short"
        case .standard: return "Standard"
        case .long: return "Long"
        case .off: return "Off"
        }
    }
}

public struct SpeakToChatConfigState: Equatable, Sendable {
    public var sensitivity: SpeakToChatSensitivity
    public var timeout: SpeakToChatTimeout

    public init(sensitivity: SpeakToChatSensitivity, timeout: SpeakToChatTimeout) {
        self.sensitivity = sensitivity
        self.timeout = timeout
    }
}

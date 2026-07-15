import Foundation

/// Verified byte-for-byte against Gadgetbridge's `AutomaticPowerOff.java` enum.
public enum AutomaticPowerOffMode: CaseIterable, Sendable, Identifiable {
    case off
    case after5Min
    case after30Min
    case after1Hour
    case after3Hour
    case whenTakenOff

    public var id: Self { self }

    var code: (UInt8, UInt8) {
        switch self {
        case .off: return (0x11, 0x00)
        case .after5Min: return (0x00, 0x00)
        case .after30Min: return (0x01, 0x01)
        case .after1Hour: return (0x02, 0x02)
        case .after3Hour: return (0x03, 0x03)
        case .whenTakenOff: return (0x10, 0x00)
        }
    }

    static func from(_ b1: UInt8, _ b2: UInt8) -> AutomaticPowerOffMode? {
        allCases.first { $0.code == (b1, b2) }
    }

    public var label: String {
        switch self {
        case .off: return "Off"
        case .after5Min: return "After 5 Minutes"
        case .after30Min: return "After 30 Minutes"
        case .after1Hour: return "After 1 Hour"
        case .after3Hour: return "After 3 Hours"
        case .whenTakenOff: return "When Taken Off"
        }
    }
}

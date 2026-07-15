import Foundation

/// Element codes for automatic power off, per the XM6-generation protocol
/// ("auto power off with wearing detection", inquired type 0x05).
public enum AutomaticPowerOffMode: UInt8, CaseIterable, Sendable, Identifiable {
    case after5Min = 0x00
    case after30Min = 0x01
    case after1Hour = 0x02
    case after3Hour = 0x03
    case whenTakenOff = 0x10
    case off = 0x11

    public var id: Self { self }

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

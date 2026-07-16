import Foundation

/// Automatic power off ("auto power off with wearing detection", POWER family
/// inquired type 0x05). XM6 firmware accepts exactly two values -- the timed
/// options of older 1000X models are rejected on-device (verified by probe:
/// writes of 0x00-0x03 are answered with a notify re-announcing the old value).
public enum AutomaticPowerOffMode: UInt8, CaseIterable, Sendable, Identifiable {
    case whenTakenOff = 0x10
    case off = 0x11

    public var id: Self { self }

    public var label: String {
        switch self {
        case .whenTakenOff: return "When Taken Off"
        case .off: return "Never"
        }
    }
}

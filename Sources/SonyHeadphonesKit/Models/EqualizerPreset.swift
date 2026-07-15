import Foundation

/// Equalizer presets accepted by WH-1000XM6 firmware (3.0.0+).
///
/// The XM6 generation dropped the classic preset table: firmware only accepts the new
/// codes 0x30-0x33 plus Custom (0xA0) and Off. These names match the Sound Connect app.
public enum EqualizerPreset: UInt8, CaseIterable, Sendable, Identifiable {
    case off = 0x00
    case heavy = 0x30
    case clear = 0x31
    case hard = 0x32
    case soft = 0x33
    case custom = 0xa0

    public var id: UInt8 { rawValue }

    public var label: String {
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

/// Decoded equalizer state.
public struct EqualizerState: Equatable, Sendable {
    /// Raw preset code as reported by the device. May be a value outside
    /// `EqualizerPreset` (e.g. a personalized/user preset id).
    public var presetCode: UInt8
    /// Raw band values as reported (10 bands on XM6, offset already removed).
    public var bands: [Int]
    /// The EQEBB inquired-type byte the device used (XM6: 0x04). Echoed on writes.
    public var subtype: UInt8

    public var preset: EqualizerPreset? { EqualizerPreset(rawValue: presetCode) }

    public init(presetCode: UInt8, bands: [Int] = [], subtype: UInt8 = 0x04) {
        self.presetCode = presetCode
        self.bands = bands
        self.subtype = subtype
    }
}

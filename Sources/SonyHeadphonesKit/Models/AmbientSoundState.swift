import Foundation

public enum AmbientSoundMode: String, CaseIterable, Sendable {
    case off
    case noiseCancelling
    case ambientSound
}

public struct AmbientSoundState: Equatable, Sendable {
    public var mode: AmbientSoundMode
    public var focusOnVoice: Bool
    /// 0...20, only meaningful while `mode == .ambientSound`.
    public var level: Int

    /// The subtype byte the device itself reported (0x15, 0x17, or 0x22). Writes echo
    /// this back so we always speak whichever dialect the firmware speaks, instead of
    /// assuming one.
    public var subtype: UInt8
    /// Whether the device's reply included the extra wind-noise-mode byte
    /// (only seen with subtype 0x17 and an 8-byte payload).
    public var hasWindNoiseByte: Bool

    public init(
        mode: AmbientSoundMode = .noiseCancelling,
        focusOnVoice: Bool = false,
        level: Int = 15,
        subtype: UInt8 = 0x15,
        hasWindNoiseByte: Bool = false
    ) {
        self.mode = mode
        self.focusOnVoice = focusOnVoice
        self.level = max(0, min(20, level))
        self.subtype = subtype
        self.hasWindNoiseByte = hasWindNoiseByte
    }
}

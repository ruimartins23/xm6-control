import Foundation

public enum AmbientSoundMode: String, CaseIterable, Sendable {
    case off
    case noiseCancelling
    case ambientSound
}

public struct AmbientSoundState: Equatable, Sendable {
    public var mode: AmbientSoundMode
    public var focusOnVoice: Bool
    /// Raw reported level (0...20); controls and writes use 1...20. Retain zero
    /// here so the legacy startup override can still replace it with 15.
    public var level: Int

    /// The reported subtype. XM6's 0x19 reports use 0x17 for writes; older
    /// subtypes (0x15, 0x17, 0x22) retain their existing write dialect.
    public var subtype: UInt8
    /// A zero-update 0x17 report is a placeholder on XM6 firmware 3.0.0.
    public var isUpdate: Bool
    /// Whether the device's reply included the extra wind-noise-mode byte
    /// (only seen with subtype 0x17 and an 8-byte payload).
    public var hasWindNoiseByte: Bool
    /// The two trailing bytes of a 0x19 report; their meaning is unknown.
    public var trailingBytes: [UInt8]

    public init(
        mode: AmbientSoundMode = .noiseCancelling,
        focusOnVoice: Bool = false,
        level: Int = 15,
        subtype: UInt8 = 0x15,
        hasWindNoiseByte: Bool = false,
        isUpdate: Bool = true,
        trailingBytes: [UInt8] = []
    ) {
        self.mode = mode
        self.focusOnVoice = focusOnVoice
        self.level = max(0, min(20, level))
        self.subtype = subtype
        self.hasWindNoiseByte = hasWindNoiseByte
        self.isUpdate = isUpdate
        self.trailingBytes = trailingBytes
    }
}

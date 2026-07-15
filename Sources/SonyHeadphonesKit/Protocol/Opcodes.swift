import Foundation

/// Payload opcode constants (`payload[0]`), verified byte-for-byte against Gadgetbridge's
/// `PayloadTypeV1.java` / `PayloadTypeV2.java`.
///
/// Sony's "v2" transport (the family the WH-1000XM5/XM6 use) reuses several numeric
/// opcodes across *different* logical features, disambiguated only by a "subtype" byte
/// at `payload[1]`. That's not a modeling choice here -- it's how the real protocol
/// works, confirmed directly in Gadgetbridge's `SonyProtocolImplV2.java`:
///
///   - `0xf6/f7/f8/f9` carries: pause-when-taken-off (subtype 0x01), button modes
///     (0x03), voice assistant (0x04), adaptive volume (0x0a), speak-to-chat enabled
///     (0x0c), quick access (0x0d).
///   - `0xfa/fb/fc/fd` carries: ambient-sound-control-button-mode (subtype 0x03) AND
///     speak-to-chat config (subtype 0x0c).
///   - `0x26/27/28/29` carries: pause-when-taken-off GET (subtype 0x01) and automatic
///     power off duration (subtype 0x05).
enum Opcode {
    static let initRequest: UInt8 = 0x00
    static let initReply: UInt8 = 0x01

    static let ambientSoundControlGet: UInt8 = 0x66
    static let ambientSoundControlRet: UInt8 = 0x67
    static let ambientSoundControlSet: UInt8 = 0x68
    static let ambientSoundControlNotify: UInt8 = 0x69

    static let batteryLevelRequest: UInt8 = 0x22
    static let batteryLevelReply: UInt8 = 0x23
    static let batteryLevelNotify: UInt8 = 0x25

    static let equalizerGet: UInt8 = 0x56
    static let equalizerRet: UInt8 = 0x57
    static let equalizerSet: UInt8 = 0x58
    static let equalizerNotify: UInt8 = 0x59

    /// AUDIO parameter family (XM6 generation): BGM mode, upmix cinema, etc.
    static let audioGetParam: UInt8 = 0xe6
    static let audioRetParam: UInt8 = 0xe7
    static let audioSetParam: UInt8 = 0xe8
    static let audioNotifyParam: UInt8 = 0xe9

    /// PERIPHERAL family — rides frame type 0x0e ("table 2"), not 0x0c.
    static let periGetParam: UInt8 = 0x36
    static let periRetParam: UInt8 = 0x37
    static let periSetParam: UInt8 = 0x38
    static let periNotifyParam: UInt8 = 0x39
    static let periSetExtendedParam: UInt8 = 0x3c
    static let periNotifyExtendedParam: UInt8 = 0x3d

    /// Shared family: wide-area-tap / connect-two-devices (subtype 0xd1), touch sensor
    /// panel (0xd2), capture-voice-during-call (0xd3).
    static let touchSensorGet: UInt8 = 0xd6
    static let touchSensorRet: UInt8 = 0xd7
    static let touchSensorSet: UInt8 = 0xd8
    static let touchSensorNotify: UInt8 = 0xd9

    static let systemControlSet: UInt8 = 0x98

    /// Shared family for: pause-when-taken-off GET (subtype 0x01) and automatic
    /// power off duration (subtype 0x05).
    static let autoPowerFamilyGet: UInt8 = 0x26
    static let autoPowerFamilyRet: UInt8 = 0x27
    static let autoPowerFamilySet: UInt8 = 0x28
    static let autoPowerFamilyNotify: UInt8 = 0x29

    /// Shared family for: pause-when-taken-off SET (subtype 0x01) and speak-to-chat
    /// enabled (subtype 0x0c), among others we don't implement.
    static let buttonModeFamilyGet: UInt8 = 0xf6
    static let buttonModeFamilyRet: UInt8 = 0xf7
    static let buttonModeFamilySet: UInt8 = 0xf8
    static let buttonModeFamilyNotify: UInt8 = 0xf9

    /// Shared family for: speak-to-chat config (subtype 0x0c), among others we don't implement.
    static let chatConfigFamilyGet: UInt8 = 0xfa
    static let chatConfigFamilyRet: UInt8 = 0xfb
    static let chatConfigFamilySet: UInt8 = 0xfc
    static let chatConfigFamilyNotify: UInt8 = 0xfd
}

enum Subtype {
    /// Ambient Sound Control subtype for devices without wind-noise-reduction / ANC-2
    /// hardware support. XM6's coordinator does not declare those capabilities, so this
    /// is the correct subtype for this device.
    static let ambientSoundStandard: UInt8 = 0x15
    static let pauseWhenTakenOff: UInt8 = 0x01
    static let speakToChatEnabled: UInt8 = 0x0c
    static let speakToChatConfig: UInt8 = 0x0c
    static let automaticPowerOffDuration: UInt8 = 0x05
}

func boolFromByte(_ b: UInt8) -> Bool? {
    switch b {
    case 0x00: return false
    case 0x01: return true
    default: return nil
    }
}

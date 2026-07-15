import Foundation

/// A decoded, high-level event produced from an incoming COMMAND_1/COMMAND_2 payload.
public enum HeadphonesEvent: Sendable {
    case protocolInfo(ProtocolVersion)
    case ambientSound(AmbientSoundState)
    case battery(BatteryStatus)
    case speakToChatEnabled(Bool)
    case speakToChatConfig(SpeakToChatConfigState)
    case automaticPowerOff(AutomaticPowerOffMode)
    case pauseWhenTakenOff(Bool)
    case equalizer(EqualizerState)
    case bgmMode(enabled: Bool, roomSize: BGMRoomSize)
    case upmixCinema(Bool)
    case deviceList([MultipointDevice])
}

/// Dispatches an incoming payload to the right decoder.
///
/// Several opcodes are shared across multiple logical features in Sony's real protocol
/// (see the doc comment on `Opcode`), so for opcodes that are ambiguous we try each
/// candidate decoder in turn -- every decoder validates its own subtype byte and
/// returns `nil` on mismatch, so this is a safe (not a guess-and-hope) disambiguation.
///
/// The `messageType` matters: opcode tables differ between frame type 0x0c (table 1)
/// and 0x0e (table 2), so table-2 payloads are only ever given to table-2 decoders.
public enum SonyEventDecoder {
    public static func decode(payload: [UInt8], messageType: SonyMessageType) -> HeadphonesEvent? {
        guard let opcode = payload.first else { return nil }

        if messageType == .command2 {
            // Table 2: only the peripheral family is handled.
            if SonyCommands.isDeviceListReply(opcode: opcode),
               let devices = SonyCommands.decodeDeviceList(payload) {
                return .deviceList(devices)
            }
            return nil
        }

        if opcode == Opcode.initReply {
            return .protocolInfo(SonyCommands.protocolVersion(fromInitReplyPayload: payload))
        }
        if SonyCommands.isAmbientSoundReply(opcode: opcode),
           let state = SonyCommands.decodeAmbientSound(payload) {
            return .ambientSound(state)
        }
        if SonyCommands.isBatteryReply(opcode: opcode),
           let status = SonyCommands.decodeBattery(payload) {
            return .battery(status)
        }
        if SonyCommands.isAutomaticPowerOffReply(opcode: opcode),
           let mode = SonyCommands.decodeAutomaticPowerOff(payload) {
            return .automaticPowerOff(mode)
        }
        if SonyCommands.isPauseWhenTakenOffReply(opcode: opcode),
           let enabled = SonyCommands.decodePauseWhenTakenOff(payload) {
            return .pauseWhenTakenOff(enabled)
        }
        if SonyCommands.isSpeakToChatEnabledReply(opcode: opcode),
           let enabled = SonyCommands.decodeSpeakToChatEnabled(payload) {
            return .speakToChatEnabled(enabled)
        }
        if SonyCommands.isSpeakToChatConfigReply(opcode: opcode),
           let config = SonyCommands.decodeSpeakToChatConfig(payload) {
            return .speakToChatConfig(config)
        }
        if SonyCommands.isEqualizerReply(opcode: opcode),
           let state = SonyCommands.decodeEqualizer(payload) {
            return .equalizer(state)
        }
        if SonyCommands.isAudioParamReply(opcode: opcode) {
            if let (enabled, roomSize) = SonyCommands.decodeBGMMode(payload) {
                return .bgmMode(enabled: enabled, roomSize: roomSize)
            }
            if let enabled = SonyCommands.decodeUpmixCinema(payload) {
                return .upmixCinema(enabled)
            }
        }
        return nil
    }
}

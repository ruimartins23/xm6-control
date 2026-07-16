import Foundation

/// Builds request payloads and decodes reply/notify payloads for the six capabilities
/// Gadgetbridge's `SonyWH1000XM6Coordinator` declares as supported on this model:
/// battery (single), ambient sound control, speak-to-chat (enabled + config), automatic
/// power off, and pause-when-taken-off. Every byte layout below was read directly out of
/// Gadgetbridge's `SonyProtocolImplV2.java` / `SonyProtocolImplV1.java` source (not
/// reconstructed from documentation), specifically the codepaths reachable from the v2
/// RFCOMM UUID that XM6 uses.
///
/// Deliberately out of scope: equalizer, touch sensor, DSEE/voice notifications. XM6's own
/// coordinator marks these unimplemented/experimental ("probably not working"), so we don't
/// expose controls that would silently do nothing on real hardware.
public enum SonyCommands {

    // MARK: - Handshake

    public static func buildInit() -> [UInt8] {
        [Opcode.initRequest, 0x00]
    }

    /// The init reply's payload length is the only reliable v1/v2 discriminator
    /// (the version field itself isn't consistently meaningful across firmwares).
    public static func protocolVersion(fromInitReplyPayload payload: [UInt8]) -> ProtocolVersion {
        guard payload.first == Opcode.initReply else { return .unknown }
        switch payload.count {
        case 4: return .v1
        case 8: return .v2
        default: return .unknown
        }
    }

    // MARK: - Ambient Sound Control

    public static func buildAmbientSoundGet(subtype: UInt8 = 0x15) -> [UInt8] {
        [Opcode.ambientSoundControlGet, subtype]
    }

    public static func buildAmbientSoundSet(_ state: AmbientSoundState) -> [UInt8] {
        let onOff: UInt8 = state.mode == .off ? 0x00 : 0x01
        let ambientFlag: UInt8 = state.mode == .ambientSound ? 0x01 : 0x00
        var payload: [UInt8] = [
            Opcode.ambientSoundControlSet,
            state.subtype,
            0x01, // fixed; the real app sends 0x00 mid-drag, 0x01 on commit
            onOff,
            ambientFlag
        ]
        if state.hasWindNoiseByte {
            payload.append(0x02) // 0x02 = normal NC/ambient, 0x03 = wind-noise-reduction (not exposed in UI)
        }
        payload.append(state.focusOnVoice ? 0x01 : 0x00)
        payload.append(UInt8(clamping: state.level))
        return payload
    }

    /// Accepts all three subtypes the reference implementation accepts (0x15 standard,
    /// 0x17 ANC-2/wind-noise variant, 0x22 no-noise-cancelling variant) so we don't
    /// silently drop the reply if XM6 firmware speaks a different dialect than assumed.
    public static func decodeAmbientSound(_ payload: [UInt8]) -> AmbientSoundState? {
        guard payload.count >= 6, payload.count <= 8 else { return nil }
        let subtype = payload[1]
        guard subtype == 0x15 || subtype == 0x17 || subtype == 0x22 else { return nil }
        let hasWindNoiseByte = subtype == 0x17 && payload.count > 7

        let mode: AmbientSoundMode
        switch payload[3] {
        case 0x00:
            mode = .off
        case 0x01:
            if hasWindNoiseByte {
                if payload[5] == 0x03 || payload[5] == 0x05 {
                    // Wind-noise-reduction; closest of our three modes is NC.
                    mode = .noiseCancelling
                } else {
                    mode = payload[4] == 0x01 ? .ambientSound : .noiseCancelling
                }
            } else if subtype == 0x22 {
                mode = .ambientSound
            } else {
                mode = payload[4] == 0x01 ? .ambientSound : .noiseCancelling
            }
        default:
            return nil
        }

        let i = payload.count - 2
        guard let focusOnVoice = boolFromByte(payload[i]) else { return nil }
        let level = Int(payload[i + 1])
        guard (0...20).contains(level) else { return nil }

        return AmbientSoundState(
            mode: mode,
            focusOnVoice: focusOnVoice,
            level: level,
            subtype: subtype,
            hasWindNoiseByte: hasWindNoiseByte
        )
    }

    static func isAmbientSoundReply(opcode: UInt8) -> Bool {
        opcode == Opcode.ambientSoundControlRet || opcode == Opcode.ambientSoundControlNotify
    }

    // MARK: - Battery (single, over-ear headphones only report one battery)

    public static func buildBatteryGet() -> [UInt8] {
        [Opcode.batteryLevelRequest, 0x00] // 0x00 = SINGLE battery type
    }

    public static func decodeBattery(_ payload: [UInt8]) -> BatteryStatus? {
        guard payload.count >= 4, payload[1] == 0x00 else { return nil }
        return BatteryStatus(level: Int(payload[2]), isCharging: payload[3] == 1)
    }

    static func isBatteryReply(opcode: UInt8) -> Bool {
        opcode == Opcode.batteryLevelReply || opcode == Opcode.batteryLevelNotify
    }

    // MARK: - Equalizer (presets)
    //
    // The XM6 answers the EQEBB family only for inquired type 0x04
    // (PRESET_EQ_AND_ERRORCODE) -- its own status notify in a live capture used 0x04,
    // and the classic 0x00 query is silently ignored. Both are requested at connect;
    // whichever the device answers is echoed back on writes. Layout:
    // [opcode, type, presetId, bandCount, bands...]. Custom band writes are not
    // exposed (10-band layout, offset 6 -- readable below but risky to write blind).

    public static func buildEqualizerGet(subtype: UInt8 = 0x04) -> [UInt8] {
        [Opcode.equalizerGet, subtype]
    }

    public static func buildEqualizerPresetSet(code: UInt8, subtype: UInt8) -> [UInt8] {
        [Opcode.equalizerSet, subtype, code, 0x00]
    }

    public static func decodeEqualizer(_ payload: [UInt8]) -> EqualizerState? {
        guard payload.count >= 4 else { return nil }
        let subtype = payload[1]
        // PRESET_EQ (0x00), NONCUSTOMIZABLE (0x02), AND_ERRORCODE (0x04)
        guard subtype == 0x00 || subtype == 0x02 || subtype == 0x04 else { return nil }
        let presetCode = payload[2]
        let bandCount = Int(payload[3])
        var bands: [Int] = []
        if bandCount > 0, payload.count >= 4 + bandCount {
            // 6-band replies use offset 10 (classic ClearBass layout), 10-band use 6.
            let offset = bandCount == 6 ? 10 : 6
            bands = payload[4..<(4 + bandCount)].map { Int($0) - offset }
        }
        return EqualizerState(presetCode: presetCode, bands: bands, subtype: subtype)
    }

    static func isEqualizerReply(opcode: UInt8) -> Bool {
        opcode == Opcode.equalizerRet || opcode == Opcode.equalizerNotify
    }

    // MARK: - Listening Mode (Standard / Background Music / Cinema)
    //
    // AUDIO parameter family (0xe6...0xe9). Two independent on/off parameters:
    // BGM mode (inquired type 0x09 = "BGM mode and errorcode"; 0x03 on some firmware)
    // carrying a room-size byte, and Upmix Cinema (type 0x04). Enable/disable is
    // INVERTED on the wire: 0x00 = enabled, 0x01 = disabled.

    public static func buildBGMModeGet(subtype: UInt8 = 0x09) -> [UInt8] {
        [Opcode.audioGetParam, subtype]
    }

    public static func buildBGMModeSet(enabled: Bool, roomSize: BGMRoomSize, subtype: UInt8 = 0x09) -> [UInt8] {
        [Opcode.audioSetParam, subtype, enabled ? 0x00 : 0x01, roomSize.rawValue]
    }

    public static func buildUpmixCinemaGet() -> [UInt8] {
        [Opcode.audioGetParam, 0x04]
    }

    public static func buildUpmixCinemaSet(enabled: Bool) -> [UInt8] {
        [Opcode.audioSetParam, 0x04, enabled ? 0x00 : 0x01]
    }

    /// Returns (enabled, roomSize) for BGM replies (types 0x03/0x09).
    public static func decodeBGMMode(_ payload: [UInt8]) -> (Bool, BGMRoomSize)? {
        guard payload.count >= 4, payload[1] == 0x09 || payload[1] == 0x03 else { return nil }
        guard let roomSize = BGMRoomSize(rawValue: payload[3]) else { return nil }
        return (payload[2] == 0x00, roomSize)
    }

    /// Returns enabled for Upmix Cinema replies (type 0x04).
    public static func decodeUpmixCinema(_ payload: [UInt8]) -> Bool? {
        guard payload.count >= 3, payload[1] == 0x04 else { return nil }
        return payload[2] == 0x00
    }

    static func isAudioParamReply(opcode: UInt8) -> Bool {
        opcode == Opcode.audioRetParam || opcode == Opcode.audioNotifyParam
    }

    // MARK: - Multipoint device list + playback source switch (frame type 0x0e)
    //
    // PERIPHERAL family, which rides the second message table (frame type 0x0e).
    // The device list (inquired type 0x02 = pairing device management with Bluetooth
    // class-of-device) arrives as:
    //   [opcode, 0x02, count, entries..., playbackDeviceStatus]
    // where each entry is: MAC as 17 ASCII chars, connectedStatus (non-zero when
    // connected), 3-byte class-of-device, name length, name (UTF-8).
    // A device is the active playback source when its connectedStatus equals the
    // trailing playbackDeviceStatus byte. Confirmed against a live XM6 capture.

    public static func buildDeviceListGet() -> [UInt8] {
        [Opcode.periGetParam, 0x02]
    }

    /// Switch the active playback source to the device with the given MAC
    /// (SOURCE_SWITCH_CONTROL, inquired type 0x01).
    public static func buildSourceSwitchSet(macAddress: String) -> [UInt8]? {
        let macBytes = Array(macAddress.utf8)
        guard macBytes.count == 17 else { return nil }
        return [Opcode.periSetExtendedParam, 0x01] + macBytes
    }

    public static func decodeDeviceList(_ payload: [UInt8]) -> [MultipointDevice]? {
        guard payload.count >= 4, payload[1] == 0x02 || payload[1] == 0x00 else { return nil }
        let withClassOfDevice = payload[1] == 0x02
        let count = Int(payload[2])
        guard count > 0, count < 16 else { return [] }
        guard let playbackStatus = payload.last else { return nil }

        var devices: [MultipointDevice] = []
        var i = 3
        for _ in 0..<count {
            guard i + 17 <= payload.count else { return nil }
            guard let mac = String(bytes: payload[i..<(i + 17)], encoding: .utf8) else { return nil }
            i += 17
            guard i < payload.count else { return nil }
            let status = payload[i]
            i += 1
            if withClassOfDevice { i += 3 }
            guard i < payload.count else { return nil }
            let nameLen = Int(payload[i])
            i += 1
            guard i + nameLen <= payload.count else { return nil }
            let name = String(bytes: payload[i..<(i + nameLen)], encoding: .utf8) ?? "Unknown device"
            i += nameLen
            devices.append(MultipointDevice(
                macAddress: mac,
                name: name,
                connectedStatus: status,
                isPlayback: status != 0 && status == playbackStatus
            ))
        }
        return devices
    }

    static func isDeviceListReply(opcode: UInt8) -> Bool {
        opcode == Opcode.periRetParam || opcode == Opcode.periNotifyParam
    }

    // MARK: - Speak-to-Chat enabled

    public static func buildSpeakToChatEnabledGet() -> [UInt8] {
        [Opcode.buttonModeFamilyGet, Subtype.speakToChatEnabled]
    }

    public static func buildSpeakToChatEnabledSet(_ enabled: Bool) -> [UInt8] {
        // Confirmed inverted on v2: 0x00 = enabled, 0x01 = disabled.
        [Opcode.buttonModeFamilySet, Subtype.speakToChatEnabled, enabled ? 0x00 : 0x01, 0x01]
    }

    public static func decodeSpeakToChatEnabled(_ payload: [UInt8]) -> Bool? {
        guard payload.count == 4, payload[1] == Subtype.speakToChatEnabled else { return nil }
        guard let disabled = boolFromByte(payload[2]) else { return nil }
        return !disabled
    }

    static func isSpeakToChatEnabledReply(opcode: UInt8) -> Bool {
        opcode == Opcode.buttonModeFamilyRet || opcode == Opcode.buttonModeFamilyNotify
    }

    // MARK: - Speak-to-Chat config (sensitivity / timeout)

    public static func buildSpeakToChatConfigGet() -> [UInt8] {
        [Opcode.chatConfigFamilyGet, Subtype.speakToChatConfig]
    }

    public static func buildSpeakToChatConfigSet(_ config: SpeakToChatConfigState) -> [UInt8] {
        [Opcode.chatConfigFamilySet, Subtype.speakToChatConfig, config.sensitivity.rawValue, config.timeout.rawValue]
    }

    public static func decodeSpeakToChatConfig(_ payload: [UInt8]) -> SpeakToChatConfigState? {
        guard payload.count == 4, payload[1] == Subtype.speakToChatConfig else { return nil }
        guard let sensitivity = SpeakToChatSensitivity(rawValue: payload[2]) else { return nil }
        guard let timeout = SpeakToChatTimeout(rawValue: payload[3]) else { return nil }
        return SpeakToChatConfigState(sensitivity: sensitivity, timeout: timeout)
    }

    static func isSpeakToChatConfigReply(opcode: UInt8) -> Bool {
        opcode == Opcode.chatConfigFamilyRet || opcode == Opcode.chatConfigFamilyNotify
    }

    // MARK: - Automatic power off (duration-based, includes "when taken off")

    public static func buildAutomaticPowerOffGet() -> [UInt8] {
        [Opcode.autoPowerFamilyGet, Subtype.automaticPowerOffDuration]
    }

    /// POWER family SET, verified by probe on real hardware: [0x28, 0x05, element, 0x00]
    /// is accepted (device confirms via 0x29 notify and the readback changes).
    /// Note: some references route this write through the SYSTEM family (0xf8) instead;
    /// on XM6 that hits a different parameter entirely (SYSTEM type 0x05 is the voice
    /// assistant wake word) -- do not copy that.
    public static func buildAutomaticPowerOffSet(_ mode: AutomaticPowerOffMode) -> [UInt8] {
        [Opcode.autoPowerFamilySet, Subtype.automaticPowerOffDuration, mode.rawValue, 0x00]
    }

    public static func decodeAutomaticPowerOff(_ payload: [UInt8]) -> AutomaticPowerOffMode? {
        guard payload.count == 4, payload[1] == Subtype.automaticPowerOffDuration else { return nil }
        // payload[3] is "last selected element", not part of the current mode.
        return AutomaticPowerOffMode(rawValue: payload[2])
    }

    static func isAutomaticPowerOffReply(opcode: UInt8) -> Bool {
        opcode == Opcode.autoPowerFamilyRet || opcode == Opcode.autoPowerFamilyNotify
    }

    // MARK: - Pause when taken off
    //
    // GET rides the 0x26 family (subtype 0x01) but SET rides the *different* 0xf8
    // family (also subtype 0x01) -- confirmed asymmetric in the reference source.
    // We accept the reply on either opcode family defensively, since which one the
    // real reply comes back on for this specific model hasn't been confirmed against
    // real XM6 hardware.

    /// XM6 answers this from the SYSTEM family (0xf6, "playback control by wearing"),
    /// not the classic auto-power-off family -- a live capture showed [0x26, 0x01]
    /// being ACKed but never answered, while the reply arrives as [0xf7, 0x01, value].
    public static func buildPauseWhenTakenOffGet() -> [UInt8] {
        [Opcode.buttonModeFamilyGet, Subtype.pauseWhenTakenOff]
    }

    public static func buildPauseWhenTakenOffSet(_ enabled: Bool) -> [UInt8] {
        [Opcode.buttonModeFamilySet, Subtype.pauseWhenTakenOff, enabled ? 0x00 : 0x01]
    }

    public static func decodePauseWhenTakenOff(_ payload: [UInt8]) -> Bool? {
        guard payload.count == 3, payload[1] == Subtype.pauseWhenTakenOff else { return nil }
        guard let disabled = boolFromByte(payload[2]) else { return nil }
        return !disabled
    }

    static func isPauseWhenTakenOffReply(opcode: UInt8) -> Bool {
        opcode == Opcode.autoPowerFamilyRet || opcode == Opcode.autoPowerFamilyNotify
            || opcode == Opcode.buttonModeFamilyRet || opcode == Opcode.buttonModeFamilyNotify
    }
}

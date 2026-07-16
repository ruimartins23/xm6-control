import Foundation
import Combine

/// Orchestrates the connection lifecycle, the stop-and-wait sequence-number/ACK
/// handshake, and the outbound command queue for a single Sony headset, and exposes
/// the decoded device state as `@Published` properties for SwiftUI.
///
/// Sequence-number handling mirrors Gadgetbridge's `SonyHeadphonesProtocol.java`
/// exactly: a single shared alternating bit. We encode our own commands with the
/// current value; when the device ACKs, we adopt the ACK's sequence number as the new
/// current value. When the device sends us an unsolicited RET/NOTIFY, we reply with an
/// ACK carrying the complement of our current value.
@MainActor
public final class HeadphonesController: ObservableObject {
    @Published public private(set) var connectionState: ConnectionState = .disconnected
    @Published public private(set) var deviceName: String?
    @Published public private(set) var protocolVersion: ProtocolVersion = .unknown
    @Published public private(set) var pairedDevices: [PairedDeviceInfo] = []

    @Published public private(set) var ambientSound: AmbientSoundState?
    @Published public private(set) var battery: BatteryStatus?
    @Published public private(set) var speakToChatEnabled: Bool?
    @Published public private(set) var speakToChatConfig: SpeakToChatConfigState?
    @Published public private(set) var automaticPowerOff: AutomaticPowerOffMode?
    @Published public private(set) var pauseWhenTakenOff: Bool?
    @Published public private(set) var equalizer: EqualizerState?
    @Published public private(set) var listeningMode: ListeningMode?
    @Published public private(set) var bgmRoomSize: BGMRoomSize?
    @Published public private(set) var devices: [MultipointDevice]?

    /// Raw BGM/cinema flags as last reported; listeningMode is derived from them.
    private var bgmEnabled = false
    private var cinemaEnabled = false
    @Published public private(set) var lastError: String?
    /// Set when the headphones connected but didn't report some state within a few
    /// seconds. The UI uses this to stop showing spinners and offer optimistic
    /// controls instead (writes still work even when the initial read was ignored).
    @Published public private(set) var initialStateTimedOut = false

    /// Persists across launches; when off, the protocol log does zero disk I/O.
    @Published public var protocolLoggingEnabled: Bool {
        didSet {
            UserDefaults.standard.set(protocolLoggingEnabled, forKey: "protocolLoggingEnabled")
            protocolLog.isEnabled = protocolLoggingEnabled
        }
    }

    private let connection = RFCOMMConnection()
    private let frameParser = FrameParser()
    private let protocolLog = ProtocolLog()

    private var sequenceNumber: UInt8 = 0
    private var outgoingQueue: [(SonyMessageType, [UInt8])] = []
    private var awaitingAck = false
    private var ackTimeoutTask: Task<Void, Never>?
    private var initRetryTask: Task<Void, Never>?
    private var stateTimeoutTask: Task<Void, Never>?
    private var initRetryCount = 0
    private var didApplyConnectDefaults = false

    public init() {
        protocolLoggingEnabled = UserDefaults.standard.bool(forKey: "protocolLoggingEnabled")
        protocolLog.isEnabled = protocolLoggingEnabled
        connection.onEvent = { [weak self] event in
            guard let self else { return }
            Task { @MainActor in
                self.handle(event)
            }
        }
    }

    // MARK: - Public API

    public func refreshPairedDevices() {
        pairedDevices = RFCOMMConnection.pairedDevices()
    }

    /// Attempts to find and connect to a paired WH-1000XM6. If none is found by name,
    /// call `refreshPairedDevices()` and let the user pick manually via `connect(toAddress:)`.
    public func autoConnect() {
        refreshPairedDevices()
        if let match = RFCOMMConnection.findLikelyXM6() {
            connect(toAddress: match.id, name: match.name)
        } else {
            lastError = "Couldn't find a paired \u{201c}WH-1000XM6\u{201d}. Pair it in System Settings \u{2192} Bluetooth first, or pick it from the list below."
            connectionState = .failed(lastError ?? "")
        }
    }

    public func connect(toAddress address: String, name: String?) {
        // Tear down any live channel first; connecting on top of an open RFCOMM
        // channel leaks it and leaves two delegates fighting over one session.
        connection.disconnect()
        resetSessionState()
        deviceName = name
        connectionState = .connecting
        lastError = nil
        protocolLog.startSession(deviceName: name)
        connection.connect(toDeviceAddress: address)
    }

    public func disconnect() {
        ackTimeoutTask?.cancel()
        initRetryTask?.cancel()
        stateTimeoutTask?.cancel()
        connection.disconnect()
        connectionState = .disconnected
    }

    /// Re-requests all device state (e.g. after the initial read timed out).
    public func refreshState() {
        guard connectionState == .connected else { return }
        requestFullState()
    }

    // MARK: - Raw access (developer tooling)

    /// Called for every decoded inbound message; used by the XM6Probe tool.
    public var rawMessageHandler: ((SonyMessageType, [UInt8]) -> Void)?

    /// Queues a raw payload; used by the XM6Probe tool to verify command layouts.
    public func sendRaw(_ payload: [UInt8], type: SonyMessageType = .command1) {
        enqueue(payload, type: type)
    }

    public func setAmbientSound(_ state: AmbientSoundState) {
        ambientSound = state // optimistic; a NOTIFY will reconcile if the device disagrees
        enqueue(SonyCommands.buildAmbientSoundSet(state))
    }

    public func setSpeakToChatEnabled(_ enabled: Bool) {
        speakToChatEnabled = enabled
        enqueue(SonyCommands.buildSpeakToChatEnabledSet(enabled))
    }

    public func setSpeakToChatConfig(_ config: SpeakToChatConfigState) {
        speakToChatConfig = config
        enqueue(SonyCommands.buildSpeakToChatConfigSet(config))
    }

    public func setAutomaticPowerOff(_ mode: AutomaticPowerOffMode) {
        automaticPowerOff = mode
        enqueue(SonyCommands.buildAutomaticPowerOffSet(mode))
    }

    public func setPauseWhenTakenOff(_ enabled: Bool) {
        pauseWhenTakenOff = enabled
        enqueue(SonyCommands.buildPauseWhenTakenOffSet(enabled))
    }

    public func setEqualizerPreset(_ preset: EqualizerPreset) {
        let subtype = equalizer?.subtype ?? 0x04
        equalizer = EqualizerState(presetCode: preset.rawValue, bands: equalizer?.bands ?? [], subtype: subtype)
        enqueue(SonyCommands.buildEqualizerPresetSet(code: preset.rawValue, subtype: subtype))
    }

    public func setListeningMode(_ mode: ListeningMode) {
        listeningMode = mode
        let roomSize = bgmRoomSize ?? .middle
        enqueue(SonyCommands.buildBGMModeSet(enabled: mode == .backgroundMusic, roomSize: roomSize))
        enqueue(SonyCommands.buildUpmixCinemaSet(enabled: mode == .cinema))
    }

    public func setBGMRoomSize(_ roomSize: BGMRoomSize) {
        bgmRoomSize = roomSize
        enqueue(SonyCommands.buildBGMModeSet(enabled: listeningMode == .backgroundMusic, roomSize: roomSize))
    }

    /// Switch the active playback source to another connected device.
    public func switchPlayback(to device: MultipointDevice) {
        guard let payload = SonyCommands.buildSourceSwitchSet(macAddress: device.macAddress) else { return }
        devices = devices?.map { d in
            var d = d
            d.isPlayback = d.macAddress == device.macAddress
            return d
        }
        enqueue(payload, type: .command2)
        // The device pushes an updated list after a switch; ask anyway as a fallback.
        enqueue(SonyCommands.buildDeviceListGet(), type: .command2)
    }

    // MARK: - Connection events

    private func resetSessionState() {
        sequenceNumber = 0
        outgoingQueue.removeAll()
        awaitingAck = false
        ackTimeoutTask?.cancel()
        initRetryTask?.cancel()
        stateTimeoutTask?.cancel()
        initRetryCount = 0
        didApplyConnectDefaults = false
        initialStateTimedOut = false
        frameParser.reset()
        ambientSound = nil
        battery = nil
        speakToChatEnabled = nil
        speakToChatConfig = nil
        automaticPowerOff = nil
        pauseWhenTakenOff = nil
        equalizer = nil
        listeningMode = nil
        bgmRoomSize = nil
        devices = nil
        bgmEnabled = false
        cinemaEnabled = false
        protocolVersion = .unknown
    }

    private func handle(_ event: RFCOMMConnectionEvent) {
        switch event {
        case .opened:
            connectionState = .initializing
            beginHandshake()

        case .closed:
            connectionState = .disconnected

        case .dataReceived(let bytes):
            protocolLog.log("RX", bytes)
            for message in frameParser.feed(bytes) {
                handle(message: message)
            }

        case .failed(let message):
            lastError = message
            connectionState = .failed(message)
        }
    }

    private func beginHandshake() {
        initRetryCount = 0
        sendInitAttempt()
    }

    private func send(_ message: SonyMessage, note: String = "") {
        let bytes = message.encode()
        protocolLog.log("TX", bytes, note: note)
        connection.write(bytes)
    }

    private func sendInitAttempt() {
        awaitingAck = true
        send(SonyMessage(type: .command1, sequenceNumber: sequenceNumber, payload: SonyCommands.buildInit()), note: "init")

        initRetryTask?.cancel()
        initRetryTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_250_000_000)
            guard let self, !Task.isCancelled else { return }
            self.retryInitIfNeeded()
        }
    }

    private func retryInitIfNeeded() {
        guard protocolVersion == .unknown else { return } // already got a reply
        guard initRetryCount < 2 else {
            lastError = "The headphones didn't respond to the connection handshake."
            connectionState = .failed(lastError ?? "")
            return
        }
        initRetryCount += 1
        awaitingAck = false
        sendInitAttempt()
    }

    // MARK: - Message handling

    private func handle(message: SonyMessage) {
        if message.type == .ack {
            guard message.sequenceNumber != sequenceNumber else {
                return // duplicate/unexpected ACK, ignore
            }
            sequenceNumber = message.sequenceNumber
            awaitingAck = false
            ackTimeoutTask?.cancel()
            sendNextQueuedCommand()
            return
        }

        guard !message.payload.isEmpty else { return }

        // Acknowledge receipt of this command from the device. The ACK must carry the
        // complement of the *received message's* sequence number (Gadgetbridge:
        // `encodeAck` = `1 - seq` of the incoming message), NOT our own outgoing
        // sequence counter -- using the wrong one makes the headset consider its
        // replies unacknowledged and it stops responding to further requests.
        let ackSeq = message.sequenceNumber ^ 0x01
        send(SonyMessage(type: .ack, sequenceNumber: ackSeq, payload: []), note: "ack")

        rawMessageHandler?(message.type, message.payload)

        guard let event = SonyEventDecoder.decode(payload: message.payload, messageType: message.type) else { return }
        apply(event)
    }

    private func apply(_ event: HeadphonesEvent) {
        switch event {
        case .protocolInfo(let version):
            protocolVersion = version
            initRetryTask?.cancel()
            connectionState = .connected
            requestFullState()
            startStateTimeout()

        case .ambientSound(let state):
            // On the first report after connecting, apply the user's preferred startup
            // defaults: never sit in "Off" (use Noise Cancelling), and never keep an
            // ambient level of 0 (use 15). Later reports (e.g. changes made on the
            // headphones themselves) are mirrored untouched.
            if !didApplyConnectDefaults {
                didApplyConnectDefaults = true
                var desired = state
                if desired.mode == .off { desired.mode = .noiseCancelling }
                if desired.level == 0 { desired.level = 15 }
                if desired != state {
                    setAmbientSound(desired)
                    return
                }
            }
            ambientSound = state
        case .battery(let status):
            battery = status
        case .speakToChatEnabled(let enabled):
            speakToChatEnabled = enabled
        case .speakToChatConfig(let config):
            speakToChatConfig = config
        case .automaticPowerOff(let mode):
            automaticPowerOff = mode
        case .pauseWhenTakenOff(let enabled):
            pauseWhenTakenOff = enabled
        case .equalizer(let state):
            equalizer = state
        case .bgmMode(let enabled, let roomSize):
            bgmEnabled = enabled
            bgmRoomSize = roomSize
            updateListeningMode()
        case .upmixCinema(let enabled):
            cinemaEnabled = enabled
            updateListeningMode()
        case .deviceList(let list):
            devices = list
        }
    }

    private func updateListeningMode() {
        listeningMode = bgmEnabled ? .backgroundMusic : (cinemaEnabled ? .cinema : .standard)
    }

    private func startStateTimeout() {
        stateTimeoutTask?.cancel()
        stateTimeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            guard let self, !Task.isCancelled else { return }
            if self.ambientSound == nil || self.battery == nil || self.speakToChatEnabled == nil
                || self.automaticPowerOff == nil || self.pauseWhenTakenOff == nil {
                self.initialStateTimedOut = true
            }
        }
    }

    private func requestFullState() {
        // Ask for ambient sound in both known v2 dialects; the device answers whichever
        // it speaks and (per the reference implementation) ignores the other.
        enqueue(SonyCommands.buildAmbientSoundGet(subtype: 0x15))
        enqueue(SonyCommands.buildAmbientSoundGet(subtype: 0x17))
        enqueue(SonyCommands.buildBatteryGet())
        enqueue(SonyCommands.buildSpeakToChatEnabledGet())
        enqueue(SonyCommands.buildSpeakToChatConfigGet())
        enqueue(SonyCommands.buildAutomaticPowerOffGet())
        enqueue(SonyCommands.buildPauseWhenTakenOffGet())
        // XM6 answers EQ inquired type 0x04; 0x00 kept as a fallback for other firmware.
        enqueue(SonyCommands.buildEqualizerGet(subtype: 0x04))
        enqueue(SonyCommands.buildEqualizerGet(subtype: 0x00))
        enqueue(SonyCommands.buildBGMModeGet())
        enqueue(SonyCommands.buildUpmixCinemaGet())
        enqueue(SonyCommands.buildDeviceListGet(), type: .command2)
    }

    // MARK: - Outbound queue

    private func enqueue(_ payload: [UInt8], type: SonyMessageType = .command1) {
        outgoingQueue.append((type, payload))
        if !awaitingAck {
            sendNextQueuedCommand()
        }
    }

    private func sendNextQueuedCommand() {
        guard !outgoingQueue.isEmpty else { return }
        let (type, payload) = outgoingQueue.removeFirst()
        awaitingAck = true
        send(SonyMessage(type: type, sequenceNumber: sequenceNumber, payload: payload))

        ackTimeoutTask?.cancel()
        ackTimeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard let self, !Task.isCancelled else { return }
            self.handleAckTimeout()
        }
    }

    private func handleAckTimeout() {
        guard awaitingAck else { return }
        // Give up waiting and move on; a stale reply arriving late will just be ignored
        // since it won't match the (by-then-advanced) expected sequence number.
        awaitingAck = false
        sendNextQueuedCommand()
    }
}

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

    public var releaseWhenIdle: Bool {
        get { usage.releaseWhenIdle }
        set {
            guard newValue != usage.releaseWhenIdle else { return }
            usage.releaseWhenIdle = newValue
            usage.recordActivity()
            scheduleIdleDisconnect()
            if !newValue || usage.hasVisibleSurfaces { connectIfNeeded() }
        }
    }

    private var usage = ConnectionUsage()
    private var idleDisconnectTask: Task<Void, Never>?
    private var pendingCommands: [(SonyMessageType, [UInt8])] = []
    private var connectionGeneration = 0
    private let connection: HeadphonesConnection
    private let pairedDevicesProvider: () -> [PairedDeviceInfo]
    private let frameParser = FrameParser()
    private let protocolLog = ProtocolLog()

    private var sequenceNumber: UInt8 = 0
    private var outgoingQueue: [(SonyMessageType, [UInt8])] = []
    private var awaitingAck = false
    private var awaitingCommandAck = false
    private var ackTimeoutTask: Task<Void, Never>?
    private var initRetryTask: Task<Void, Never>?
    private var stateTimeoutTask: Task<Void, Never>?
    private var connectTimeoutTask: Task<Void, Never>?
    private var equalizerWriteTask: Task<Void, Never>?
    private var initRetryCount = 0
    private var connectRetryCount = 0
    private var connectTarget: (address: String, name: String?)?
    private var lastConnectTarget: (address: String, name: String?)?
    private var didApplyConnectDefaults = false

    public convenience init() {
        self.init(connection: RFCOMMConnection(), pairedDevices: RFCOMMConnection.pairedDevices)
    }

    init(connection: HeadphonesConnection, pairedDevices: @escaping () -> [PairedDeviceInfo]) {
        self.connection = connection
        self.pairedDevicesProvider = pairedDevices
        protocolLoggingEnabled = UserDefaults.standard.bool(forKey: "protocolLoggingEnabled")
        protocolLog.isEnabled = protocolLoggingEnabled
        connection.onEvent = { [weak self] event in
            guard let self else { return }
            let generation = self.connectionGeneration
            Task { @MainActor in
                guard generation == self.connectionGeneration, self.connectTarget != nil else { return }
                self.handle(event)
            }
        }
    }

    // MARK: - Public API

    public func refreshPairedDevices() {
        pairedDevices = pairedDevicesProvider()
    }

    /// Attempts to find and connect to a paired WH-1000XM6. If none is found by name,
    /// call `refreshPairedDevices()` and let the user pick manually via `connect(toAddress:)`.
    public func autoConnect() {
        refreshPairedDevices()
        if let match = pairedDevices.first(where: { $0.name.localizedCaseInsensitiveContains("WH-1000XM6") }) {
            connect(toAddress: match.id, name: match.name)
        } else {
            lastError = "Couldn't find a paired \u{201c}WH-1000XM6\u{201d}. Pair it in System Settings \u{2192} Bluetooth first, or pick it from the list below."
            pendingCommands.removeAll()
            connectionState = .failed(lastError ?? "")
        }
    }

    public func connect(toAddress address: String, name: String?) {
        usage.recordActivity()
        scheduleIdleDisconnect()
        connectRetryCount = 0
        connectTarget = (address, name)
        lastConnectTarget = connectTarget
        attemptConnect()
    }

    private func attemptConnect() {
        guard let target = connectTarget else { return }
        // Tear down any live channel first; connecting on top of an open RFCOMM
        // channel leaks it and leaves two delegates fighting over one session.
        connectionGeneration += 1
        connection.disconnect()
        resetSessionState()
        deviceName = target.name
        connectionState = .connecting
        lastError = nil
        protocolLog.startSession(deviceName: target.name)
        connection.connect(toDeviceAddress: target.address)
        startConnectTimeout()
    }

    /// Nothing in the connect path (ACL link-up, SDP query, RFCOMM channel open) is
    /// guaranteed to call back: if the headset is busy talking to a phone, or the link
    /// is half-torn-down from a previous session, IOBluetooth simply goes quiet. Without
    /// this the UI spins on "Connecting…" forever. One silent retry covers the common
    /// stale-link case; after that, say so instead of pretending we're still working.
    private func startConnectTimeout() {
        connectTimeoutTask?.cancel()
        connectTimeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 8_000_000_000)
            guard let self, !Task.isCancelled else { return }
            self.handleConnectTimeout()
        }
    }

    func handleConnectTimeout() {
        guard connectionState == .connecting || connectionState == .initializing else { return }
        guard connectRetryCount < 1 else {
            fail("The headphones didn\u{2019}t answer. Make sure they\u{2019}re on and connected as an audio device. If Sony Sound Connect is open on your phone, close it, then try again.")
            return
        }
        connectRetryCount += 1
        attemptConnect()
    }

    public func disconnect() {
        connectionGeneration += 1
        idleDisconnectTask?.cancel()
        pendingCommands.removeAll()
        equalizerWriteTask?.cancel()
        equalizerWriteTask = nil
        connectTarget = nil
        connection.disconnect()
        resetSessionState()
        connectionState = .disconnected
    }

    private func fail(_ message: String) {
        disconnect()
        lastError = message
        connectionState = .failed(message)
    }

    /// Each window or panel has its own identity; closing one must not release a
    /// channel still in use by another.
    public func setControlSurface(_ id: UUID, visible: Bool) {
        guard usage.setSurface(id, visible: visible) else { return }
        scheduleIdleDisconnect()
        if releaseWhenIdle && visible { connectIfNeeded() }
    }

    private func connectIfNeeded() {
        switch connectionState {
        case .disconnected, .failed:
            if let target = lastConnectTarget {
                connect(toAddress: target.address, name: target.name)
            } else {
                autoConnect()
            }
        default: break
        }
    }

    private func recordCommand() {
        usage.recordActivity()
        scheduleIdleDisconnect()
        if releaseWhenIdle { connectIfNeeded() }
    }

    private func scheduleIdleDisconnect() {
        idleDisconnectTask?.cancel()
        guard let deadline = usage.idleDeadline else { return }
        idleDisconnectTask = Task { [weak self] in
            try? await Task.sleep(until: deadline, clock: .continuous)
            guard let self, !Task.isCancelled else { return }
            self.disconnectIfIdle()
        }
    }

    func disconnectIfIdle(now: ContinuousClock.Instant = .now) {
        guard usage.shouldRelease(now: now) else { return }
        // Finish an accepted command before releasing; background state queries do
        // not extend the grace period.
        guard pendingCommands.isEmpty, !awaitingCommandAck, equalizerWriteTask == nil else { return }
        disconnect()
    }

    /// Re-requests all device state (e.g. after the initial read timed out).
    public func refreshState() {
        recordCommand()
        guard connectionState == .connected else { return }
        requestFullState()
    }

    // MARK: - Raw access (developer tooling)

    /// Called for every decoded inbound message; used by the XM6Probe tool.
    public var rawMessageHandler: ((SonyMessageType, [UInt8]) -> Void)?

    /// Queues a raw payload; used by the XM6Probe tool to verify command layouts.
    public func sendRaw(_ payload: [UInt8], type: SonyMessageType = .command1) {
        enqueueCommand(payload, type: type)
    }

    public func setAmbientSound(_ state: AmbientSoundState) {
        var state = state
        state.level = max(1, min(20, state.level))
        ambientSound = state // optimistic; a NOTIFY will reconcile if the device disagrees
        enqueueCommand(SonyCommands.buildAmbientSoundSet(state))
    }

    public func setSpeakToChatEnabled(_ enabled: Bool) {
        speakToChatEnabled = enabled
        enqueueCommand(SonyCommands.buildSpeakToChatEnabledSet(enabled))
    }

    public func setSpeakToChatConfig(_ config: SpeakToChatConfigState) {
        speakToChatConfig = config
        enqueueCommand(SonyCommands.buildSpeakToChatConfigSet(config))
    }

    public func setAutomaticPowerOff(_ mode: AutomaticPowerOffMode) {
        automaticPowerOff = mode
        enqueueCommand(SonyCommands.buildAutomaticPowerOffSet(mode))
    }

    public func setPauseWhenTakenOff(_ enabled: Bool) {
        pauseWhenTakenOff = enabled
        enqueueCommand(SonyCommands.buildPauseWhenTakenOffSet(enabled))
    }

    /// Writes a custom equalizer curve, coalescing rapid changes.
    ///
    /// Slider drags produce a continuous stream of values, and the protocol is
    /// stop-and-wait: one outstanding command at a time, each waiting for an ACK.
    /// Queueing every intermediate value would back the queue up for seconds after
    /// the user let go. Only the latest curve is ever in flight, so dragging stays
    /// responsive and the headphones follow within a moment of the slider settling.
    public func setEqualizerBands(_ bands: [Int]) {
        recordCommand()
        let subtype = equalizer?.subtype ?? 0x04
        // Optimistic, so the sliders track the drag rather than the device's replies.
        equalizer = EqualizerState(
            presetCode: EqualizerPreset.custom.rawValue,
            bands: bands,
            subtype: subtype
        )

        equalizerWriteTask?.cancel()
        equalizerWriteTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 120_000_000)
            guard let self, !Task.isCancelled else { return }
            self.equalizerWriteTask = nil
            self.enqueueCommand(SonyCommands.buildEqualizerBandsSet(bands: bands, subtype: subtype))
        }
    }

    public func setEqualizerPreset(_ preset: EqualizerPreset) {
        // A queued curve from a drag would otherwise land after this and drag the
        // device back to the custom preset.
        equalizerWriteTask?.cancel()
        equalizerWriteTask = nil
        let subtype = equalizer?.subtype ?? 0x04
        equalizer = EqualizerState(presetCode: preset.rawValue, bands: equalizer?.bands ?? [], subtype: subtype)
        enqueueCommand(SonyCommands.buildEqualizerPresetSet(code: preset.rawValue, subtype: subtype))
    }

    public func setListeningMode(_ mode: ListeningMode) {
        listeningMode = mode
        let roomSize = bgmRoomSize ?? .middle
        enqueueCommand(SonyCommands.buildBGMModeSet(enabled: mode == .backgroundMusic, roomSize: roomSize))
        enqueueCommand(SonyCommands.buildUpmixCinemaSet(enabled: mode == .cinema))
    }

    public func setBGMRoomSize(_ roomSize: BGMRoomSize) {
        bgmRoomSize = roomSize
        enqueueCommand(SonyCommands.buildBGMModeSet(enabled: listeningMode == .backgroundMusic, roomSize: roomSize))
    }

    /// Switch the active playback source to another connected device.
    public func switchPlayback(to device: MultipointDevice) {
        guard let payload = SonyCommands.buildSourceSwitchSet(macAddress: device.macAddress) else { return }
        devices = devices?.map { d in
            var d = d
            d.isPlayback = d.macAddress == device.macAddress
            return d
        }
        enqueueCommand(payload, type: .command2)
        // The device pushes an updated list after a switch; ask anyway as a fallback.
        enqueueCommand(SonyCommands.buildDeviceListGet(), type: .command2)
    }

    // MARK: - Connection events

    private func resetSessionState() {
        sequenceNumber = 0
        outgoingQueue.removeAll()
        awaitingAck = false
        awaitingCommandAck = false
        ackTimeoutTask?.cancel()
        initRetryTask?.cancel()
        stateTimeoutTask?.cancel()
        connectTimeoutTask?.cancel()
        if !releaseWhenIdle {
            equalizerWriteTask?.cancel()
            equalizerWriteTask = nil
        }
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
            let hasPendingWork = !pendingCommands.isEmpty || awaitingCommandAck || equalizerWriteTask != nil
            // Local teardown detaches the transport delegate and invalidates queued
            // events. An opened channel closing here is the headset yielding us out.
            if releaseWhenIdle && (connectionState == .connected || connectionState == .initializing)
                && !hasPendingWork {
                // Clear the active target and timers; only fresh user activity should
                // reacquire, not a surface that simply remained visible.
                disconnect()
                lastError = "Another device is using the headphones. Click Connect or Try Again, or change a setting here, to take them back."
                return
            }
            resetSessionState()
            connectionState = .disconnected
            if releaseWhenIdle && connectTarget != nil
                && (!usage.shouldRelease() || hasPendingWork) {
                attemptConnect()
            }

        case .dataReceived(let bytes):
            protocolLog.log("RX", bytes)
            for message in frameParser.feed(bytes) {
                handle(message: message)
            }

        case .failed(let message):
            fail(message)
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
            fail("The headphones didn't respond to the connection handshake. Close Sony Sound Connect on your phone, then try again.")
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
            awaitingCommandAck = false
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
            connectTimeoutTask?.cancel()
            connectRetryCount = 0
            connectionState = .connected
            // A protocol reply can arrive even if the separate init ACK was lost.
            // Accepted commands still need a bounded way out of that wait.
            if releaseWhenIdle && awaitingAck { startAckTimeout() }
            requestFullState()
            startStateTimeout()

        case .ambientSound(var state):
            // XM6 answers 0x17 reads with a zero-update placeholder. Keep loading
            // (or the last real state); legacy mode still applies its startup defaults.
            if releaseWhenIdle && state.subtype == 0x17 && !state.isUpdate { return }
            // On the first report after connecting, apply the user's preferred startup
            // defaults: never sit in "Off" (use Noise Cancelling), and never keep an
            // ambient level of 0 (use 15). Later reports (e.g. changes made on the
            // headphones themselves) are mirrored untouched.
            if !releaseWhenIdle && !didApplyConnectDefaults {
                didApplyConnectDefaults = true
                var desired = state
                if desired.mode == .off { desired.mode = .noiseCancelling }
                if desired.level == 0 { desired.level = 15 }
                if desired != state {
                    setAmbientSound(desired)
                    return
                }
            }
            if releaseWhenIdle { state.level = max(1, state.level) }
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
        // XM6 firmware 3.0.0 reports real state on 0x19; 0x17 can be a placeholder.
        // Keep the older queries for firmware using those layouts.
        enqueue(SonyCommands.buildAmbientSoundGet(subtype: 0x15))
        enqueue(SonyCommands.buildAmbientSoundGet(subtype: 0x17))
        enqueue(SonyCommands.buildAmbientSoundGet(subtype: 0x19))
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

    private func enqueueCommand(_ payload: [UInt8], type: SonyMessageType = .command1) {
        if releaseWhenIdle {
            pendingCommands.append((type, payload))
            recordCommand()
            if connectionState == .connected && !awaitingAck { sendNextQueuedCommand() }
        } else {
            recordCommand()
            enqueue(payload, type: type)
        }
    }

    private func enqueue(_ payload: [UInt8], type: SonyMessageType = .command1) {
        outgoingQueue.append((type, payload))
        if !awaitingAck {
            sendNextQueuedCommand()
        }
    }

    private func sendNextQueuedCommand() {
        disconnectIfIdle()
        let command: (SonyMessageType, [UInt8])
        if connectionState == .connected && !pendingCommands.isEmpty {
            command = pendingCommands.removeFirst()
            awaitingCommandAck = true
        } else {
            guard !outgoingQueue.isEmpty else { return }
            command = outgoingQueue.removeFirst()
            awaitingCommandAck = false
        }
        let (type, payload) = command
        awaitingAck = true
        send(SonyMessage(type: type, sequenceNumber: sequenceNumber, payload: payload))
        startAckTimeout()
    }

    private func startAckTimeout() {
        ackTimeoutTask?.cancel()
        ackTimeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard let self, !Task.isCancelled else { return }
            self.handleAckTimeout()
        }
    }

    func handleAckTimeout() {
        guard awaitingAck else { return }
        // Give up waiting and move on; a stale reply arriving late will just be ignored
        // since it won't match the (by-then-advanced) expected sequence number.
        awaitingAck = false
        awaitingCommandAck = false
        sendNextQueuedCommand()
    }
}

import XCTest
@testable import SonyHeadphonesKit

private final class TestConnection: HeadphonesConnection {
    var onEvent: ((RFCOMMConnectionEvent) -> Void)?
    var addresses: [String] = []
    var closeCount = 0
    var messages: [SonyMessage] = []

    func connect(toDeviceAddress address: String) { addresses.append(address) }
    func disconnect() { closeCount += 1 }
    func write(_ bytes: [UInt8]) {
        messages.append(contentsOf: FrameParser().feed(bytes))
    }

    func reply(_ payload: [UInt8]) {
        onEvent?(.dataReceived(SonyMessage(type: .command1, sequenceNumber: 0, payload: payload).encode()))
    }

    func ack() {
        guard let sent = messages.last(where: { $0.type != .ack }) else { return }
        onEvent?(.dataReceived(SonyMessage(type: .ack, sequenceNumber: sent.sequenceNumber ^ 1, payload: []).encode()))
    }

    var payloads: [[UInt8]] { messages.filter { $0.type != .ack }.map(\.payload) }
}

@MainActor
final class HeadphonesControllerTests: XCTestCase {
    private func makeController() -> (HeadphonesController, TestConnection) {
        let connection = TestConnection()
        let controller = HeadphonesController(connection: connection, pairedDevices: {
            [PairedDeviceInfo(id: "test-device", name: "WH-1000XM6")]
        })
        controller.releaseWhenIdle = true
        return (controller, connection)
    }

    private func settle() async {
        // Only the delegate's main-actor hop runs here; idle deadlines use a virtual instant.
        try? await Task.sleep(for: .milliseconds(10))
    }

    private func handshake(_ connection: TestConnection) async {
        connection.onEvent?(.opened)
        await settle()
        connection.ack()
        await settle()
        connection.reply([0x01, 0, 0, 0, 0, 0, 0, 0])
        await settle()
    }

    private func drain(_ connection: TestConnection) async {
        for _ in 0..<20 {
            connection.ack()
            await settle()
        }
    }

    func testStartsDisconnectedAndVisibleSurfacesAcquireOnce() {
        let (controller, connection) = makeController()
        defer { controller.disconnect() }
        XCTAssertTrue(connection.addresses.isEmpty)
        let main = UUID(), widget = UUID()
        controller.setControlSurface(main, visible: true)
        controller.setControlSurface(main, visible: true)
        controller.setControlSurface(widget, visible: true)
        XCTAssertEqual(connection.addresses, ["test-device"])
        controller.setControlSurface(main, visible: false)
        controller.disconnectIfIdle(now: .now.advanced(by: .seconds(100)))
        XCTAssertEqual(controller.connectionState, .connecting)
        controller.setControlSurface(widget, visible: false)
        controller.disconnectIfIdle(now: .now.advanced(by: .seconds(21)))
        XCTAssertEqual(controller.connectionState, .disconnected)
        XCTAssertEqual(connection.closeCount, 2)
    }

    func testDisconnectedCommandsWaitForHandshakeAndAreAppliedInOrder() async {
        let (controller, connection) = makeController()
        defer { controller.disconnect() }
        controller.setListeningMode(.cinema)
        controller.setEqualizerPreset(.off)
        XCTAssertEqual(connection.addresses.count, 1)
        XCTAssertTrue(connection.messages.isEmpty)
        await handshake(connection)
        XCTAssertEqual(controller.connectionState, .connected)
        await drain(connection)
        XCTAssertEqual(Array(connection.payloads.prefix(4)), [
            SonyCommands.buildInit(),
            SonyCommands.buildBGMModeSet(enabled: false, roomSize: .middle),
            SonyCommands.buildUpmixCinemaSet(enabled: true),
            SonyCommands.buildEqualizerPresetSet(code: EqualizerPreset.off.rawValue, subtype: 0x04)
        ])
        XCTAssertTrue(connection.payloads.contains(SonyCommands.buildBatteryGet()))
        XCTAssertTrue(connection.payloads.contains(SonyCommands.buildDeviceListGet()))
    }

    func testEqualizerDragConnectsAndKeepsLatestCurve() async {
        let (controller, connection) = makeController()
        defer { controller.disconnect() }
        controller.setEqualizerBands(Array(repeating: 1, count: 10))
        controller.setEqualizerBands(Array(repeating: 2, count: 10))
        try? await Task.sleep(for: .milliseconds(160))
        XCTAssertEqual(connection.addresses.count, 1)
        XCTAssertTrue(connection.messages.isEmpty)
        await handshake(connection)
        await drain(connection)
        XCTAssertTrue(connection.payloads.contains(SonyCommands.buildEqualizerBandsSet(bands: Array(repeating: 2, count: 10), subtype: 0x04)))
        XCTAssertFalse(connection.payloads.contains(SonyCommands.buildEqualizerBandsSet(bands: Array(repeating: 1, count: 10), subtype: 0x04)))
    }

    func testExplicitDisconnectCancelsCommandsAndLateCallbacks() async {
        let (controller, connection) = makeController()
        let surface = UUID()
        controller.setControlSurface(surface, visible: true)
        controller.setPauseWhenTakenOff(true)
        connection.onEvent?(.opened)
        controller.disconnect()
        await settle()
        controller.setControlSurface(surface, visible: true)
        XCTAssertEqual(controller.connectionState, .disconnected)
        XCTAssertEqual(connection.addresses.count, 1)
        XCTAssertTrue(connection.messages.isEmpty)
        controller.setControlSurface(surface, visible: false)
        controller.setControlSurface(surface, visible: true)
        await handshake(connection)
        await drain(connection)
        XCTAssertFalse(connection.payloads.contains(SonyCommands.buildPauseWhenTakenOffSet(true)))
        controller.disconnect()
    }

    func testFreshConnectionClearsCacheAndMirrorsOffWithoutStartupWrites() async {
        let (controller, connection) = makeController()
        defer { controller.disconnect() }
        controller.autoConnect()
        await handshake(connection)
        connection.reply([Opcode.ambientSoundControlRet, 0x15, 1, 1, 1, 0, 12])
        await settle()
        XCTAssertEqual(controller.ambientSound?.level, 12)
        await drain(connection)
        controller.disconnect()
        XCTAssertNil(controller.ambientSound)
        controller.autoConnect()
        await handshake(connection)
        XCTAssertNil(controller.ambientSound)
        let off = AmbientSoundState(mode: .off, level: 1)
        connection.reply([Opcode.ambientSoundControlRet, 0x15, 1, 0, 0, 0, 0])
        await settle()
        await drain(connection)
        XCTAssertEqual(controller.ambientSound, off)
        XCTAssertEqual(connection.payloads.filter { $0 == SonyCommands.buildBatteryGet() }.count, 2)
        XCTAssertFalse(connection.payloads.contains { $0.first == Opcode.ambientSoundControlSet })
    }

    func testConnectIgnoresZeroPlaceholderThenUsesXM6State() async {
        for opcode: UInt8 in [0x67, 0x69] {
            let (controller, connection) = makeController()
            defer { controller.disconnect() }
            controller.setControlSurface(UUID(), visible: true)
            await handshake(connection)
            connection.ack()
            await settle()
            XCTAssertEqual(connection.payloads.last, [0x66, 0x17])
            connection.reply([0x67, 0x17, 0, 0, 0, 0, 0])
            await settle()
            XCTAssertNil(controller.ambientSound)
            connection.ack()
            await settle()
            XCTAssertEqual(connection.payloads.last, [0x66, 0x19])
            connection.reply([opcode, 0x19, 1, 1, 0, 0, 9, 0, 0])
            await settle()
            XCTAssertEqual(controller.ambientSound?.mode, .noiseCancelling)
            XCTAssertEqual(controller.ambientSound?.level, 9)
            connection.reply([0x67, 0x17, 0, 0, 0, 0, 0])
            await settle()
            XCTAssertEqual(controller.ambientSound?.mode, .noiseCancelling)
            XCTAssertEqual(controller.ambientSound?.level, 9)
            await drain(connection)
            XCTAssertFalse(connection.payloads.contains { $0.first == 0x68 })
        }
    }

    func testZeroPlaceholderRemainsUnknownAfterInitialStateTimeout() async throws {
        let (controller, connection) = makeController()
        defer { controller.disconnect() }
        controller.setControlSurface(UUID(), visible: true)
        await handshake(connection)
        connection.reply([0x67, 0x17, 0, 0, 0, 0, 0])
        await drain(connection)
        try await Task.sleep(for: .seconds(6))
        XCTAssertTrue(controller.initialStateTimedOut)
        XCTAssertNil(controller.ambientSound)
        XCTAssertFalse(connection.payloads.contains { $0.first == 0x68 })
    }

    func testXM6AmbientStateAndUserLevelRemainInRange() async throws {
        let (controller, connection) = makeController()
        defer { controller.disconnect() }
        controller.setControlSurface(UUID(), visible: true)
        await handshake(connection)
        await drain(connection)
        connection.reply([0x69, 0x19, 1, 1, 1, 0, 10, 0, 0])
        await settle()
        XCTAssertEqual(controller.ambientSound?.mode, .ambientSound)
        XCTAssertEqual(controller.ambientSound?.level, 10)
        for (level, expected): (Int, UInt8) in [(0, 1), (21, 20)] {
            var state = try XCTUnwrap(controller.ambientSound)
            state.level = level
            controller.setAmbientSound(state)
            XCTAssertEqual(controller.ambientSound?.level, Int(expected))
            XCTAssertEqual(connection.payloads.last, [0x68, 0x17, 1, 1, 1, 0, expected])
            connection.ack()
            await settle()
        }
        connection.reply([0x69, 0x19, 1, 1, 1, 0, 1, 0, 0])
        await settle()
        XCTAssertEqual(controller.ambientSound?.level, 1)
    }

    func testLegacyZeroPlaceholderStillAppliesOriginalStartupDefaultsOnce() async {
        let (controller, connection) = makeController()
        defer { controller.disconnect() }
        controller.releaseWhenIdle = false
        await handshake(connection)
        connection.reply([0x67, 0x17, 0, 0, 0, 0, 0])
        await settle()
        await drain(connection)
        XCTAssertEqual(controller.ambientSound?.mode, .noiseCancelling)
        XCTAssertEqual(controller.ambientSound?.level, 15)
        XCTAssertEqual(connection.payloads.filter { $0.first == 0x68 }, [[0x68, 0x17, 1, 1, 0, 0, 15]])
        connection.reply([0x69, 0x17, 1, 0, 0, 0, 9])
        await settle()
        XCTAssertEqual(controller.ambientSound?.mode, .off)
        XCTAssertEqual(controller.ambientSound?.level, 9)
        XCTAssertEqual(connection.payloads.filter { $0.first == 0x68 }.count, 1)
    }

    func testLegacyStartupDefaultsPreserveAmbientModeAndNonzeroLevel() async {
        let fixtures: [([UInt8], AmbientSoundMode, Int, [[UInt8]])] = [
            ([0x67, 0x17, 1, 0, 0, 0, 9], .noiseCancelling, 9, [[0x68, 0x17, 1, 1, 0, 0, 9]]),
            ([0x67, 0x17, 1, 1, 1, 0, 0], .ambientSound, 15, [[0x68, 0x17, 1, 1, 1, 0, 15]]),
            ([0x67, 0x19, 1, 1, 1, 0, 10, 0, 0], .ambientSound, 10, []),
        ]
        for (report, mode, level, writes) in fixtures {
            let (controller, connection) = makeController()
            defer { controller.disconnect() }
            controller.releaseWhenIdle = false
            await handshake(connection)
            connection.reply(report)
            await settle()
            await drain(connection)
            XCTAssertEqual(controller.ambientSound?.mode, mode)
            XCTAssertEqual(controller.ambientSound?.level, level)
            XCTAssertEqual(connection.payloads.filter { $0.first == 0x68 }, writes)
        }
    }

    func testRemoteCloseYieldsDespiteVisibleSurfaceAndBackgroundQueries() async {
        let (controller, connection) = makeController()
        defer { controller.disconnect() }
        let surface = UUID()
        controller.setControlSurface(surface, visible: true)
        await handshake(connection)
        // The first state query is awaiting ACK; protocol traffic is not user work.
        connection.onEvent?(.closed)
        connection.reply([0x01, 0, 0, 0, 0, 0, 0, 0])
        await settle()
        XCTAssertEqual(connection.addresses.count, 1)
        XCTAssertEqual(controller.connectionState, .disconnected)
        let message = "Another device is using the headphones. Click Connect or Try Again, or change a setting here, to take them back."
        XCTAssertEqual(controller.lastError, message)
        controller.setControlSurface(surface, visible: true)
        controller.handleConnectTimeout()
        connection.onEvent?(.closed)
        connection.onEvent?(.opened)
        await settle()
        XCTAssertEqual(connection.addresses.count, 1)
        XCTAssertEqual(controller.connectionState, .disconnected)
        XCTAssertEqual(controller.lastError, message)
    }

    func testNewOrReopenedSurfaceReacquiresAfterYield() async {
        for reopen in [false, true] {
            let (controller, connection) = makeController()
            defer { controller.disconnect() }
            let surface = UUID()
            controller.connect(toAddress: "selected-headset", name: "My headphones")
            controller.setControlSurface(surface, visible: true)
            await handshake(connection)
            connection.onEvent?(.closed)
            await settle()
            XCTAssertEqual(controller.connectionState, .disconnected)
            if reopen {
                controller.setControlSurface(surface, visible: false)
                XCTAssertEqual(connection.addresses.count, 1)
            }
            controller.setControlSurface(reopen ? surface : UUID(), visible: true)
            XCTAssertEqual(connection.addresses, ["selected-headset", "selected-headset"])
            XCTAssertEqual(controller.connectionState, .connecting)
            XCTAssertNil(controller.lastError)
            await handshake(connection)
            XCTAssertEqual(controller.connectionState, .connected)
        }
    }

    func testCommandReacquiresAfterYield() async {
        let (controller, connection) = makeController()
        defer { controller.disconnect() }
        controller.setControlSurface(UUID(), visible: true)
        await handshake(connection)
        connection.onEvent?(.closed)
        await settle()
        XCTAssertEqual(controller.connectionState, .disconnected)
        controller.setPauseWhenTakenOff(true)
        XCTAssertEqual(connection.addresses.count, 2)
        XCTAssertEqual(controller.connectionState, .connecting)
        XCTAssertNil(controller.lastError)
        await handshake(connection)
        await drain(connection)
        XCTAssertEqual(connection.payloads.filter { $0 == SonyCommands.buildPauseWhenTakenOffSet(true) }.count, 1)
    }

    func testExplicitConnectReacquiresAfterYield() async {
        let (controller, connection) = makeController()
        defer { controller.disconnect() }
        controller.autoConnect()
        await handshake(connection)
        connection.onEvent?(.closed)
        await settle()
        XCTAssertEqual(controller.connectionState, .disconnected)
        controller.autoConnect()
        XCTAssertEqual(connection.addresses.count, 2)
        XCTAssertEqual(controller.connectionState, .connecting)
        XCTAssertNil(controller.lastError)
        await handshake(connection)
        XCTAssertEqual(controller.connectionState, .connected)
    }

    func testRemoteCloseWithPendingCommandReconnects() async {
        let (controller, connection) = makeController()
        defer { controller.disconnect() }
        controller.setControlSurface(UUID(), visible: true)
        await handshake(connection)
        controller.setPauseWhenTakenOff(true)
        XCTAssertFalse(connection.payloads.contains(SonyCommands.buildPauseWhenTakenOffSet(true)))
        connection.onEvent?(.closed)
        await settle()
        XCTAssertEqual(connection.addresses.count, 2)
        XCTAssertEqual(controller.connectionState, .connecting)
        XCTAssertNil(controller.lastError)
        await handshake(connection)
        await drain(connection)
        XCTAssertEqual(connection.payloads.filter { $0 == SonyCommands.buildPauseWhenTakenOffSet(true) }.count, 1)
    }

    func testRemoteCloseWithCommandAwaitingAckReconnects() async {
        let (controller, connection) = makeController()
        defer { controller.disconnect() }
        controller.setControlSurface(UUID(), visible: true)
        await handshake(connection)
        await drain(connection)
        controller.setPauseWhenTakenOff(true)
        XCTAssertEqual(connection.payloads.last, SonyCommands.buildPauseWhenTakenOffSet(true))
        connection.onEvent?(.closed)
        await settle()
        XCTAssertEqual(connection.addresses.count, 2)
        XCTAssertEqual(controller.connectionState, .connecting)
        XCTAssertNil(controller.lastError)
        await handshake(connection)
        await drain(connection)
        // Preserve existing semantics: an interrupted transmitted command is not replayed.
        XCTAssertEqual(connection.payloads.filter { $0 == SonyCommands.buildPauseWhenTakenOffSet(true) }.count, 1)
    }

    func testRemoteCloseWithEqualizerWriteReconnects() async {
        let (controller, connection) = makeController()
        defer { controller.disconnect() }
        controller.setControlSurface(UUID(), visible: true)
        await handshake(connection)
        let bands = Array(repeating: 3, count: 10)
        controller.setEqualizerBands(bands)
        connection.onEvent?(.closed)
        await settle()
        XCTAssertEqual(connection.addresses.count, 2)
        XCTAssertEqual(controller.connectionState, .connecting)
        XCTAssertNil(controller.lastError)
        try? await Task.sleep(for: .milliseconds(160))
        await handshake(connection)
        await drain(connection)
        XCTAssertEqual(connection.payloads.filter { $0 == SonyCommands.buildEqualizerBandsSet(bands: bands, subtype: 0x04) }.count, 1)
    }

    func testLocalDisconnectAndIdleReleaseDoNotYield() async {
        for idle in [false, true] {
            let (controller, connection) = makeController()
            defer { controller.disconnect() }
            let surface = UUID()
            controller.setControlSurface(surface, visible: true)
            await handshake(connection)
            // An event queued before our teardown must not be mistaken for takeover.
            connection.onEvent?(.closed)
            if idle {
                controller.setControlSurface(surface, visible: false)
                controller.disconnectIfIdle(now: .now.advanced(by: .seconds(21)))
            } else {
                controller.disconnect()
            }
            await settle()
            connection.onEvent?(.closed)
            await settle()
            XCTAssertEqual(connection.addresses.count, 1)
            XCTAssertEqual(controller.connectionState, .disconnected)
            XCTAssertNil(controller.lastError)
        }
    }

    func testRemoteCloseDuringHandshakeYields() async {
        let (controller, connection) = makeController()
        defer { controller.disconnect() }
        controller.setControlSurface(UUID(), visible: true)
        connection.onEvent?(.opened)
        await settle()
        XCTAssertEqual(controller.connectionState, .initializing)
        connection.onEvent?(.closed)
        await settle()
        XCTAssertEqual(connection.addresses.count, 1)
        XCTAssertEqual(controller.connectionState, .disconnected)
        XCTAssertNotNil(controller.lastError)
    }

    func testCloseBeforeOpenKeepsExistingRetryBehavior() async {
        let (controller, connection) = makeController()
        defer { controller.disconnect() }
        controller.setControlSurface(UUID(), visible: true)
        connection.onEvent?(.closed)
        await settle()
        XCTAssertEqual(connection.addresses.count, 2)
        XCTAssertEqual(controller.connectionState, .connecting)
        XCTAssertNil(controller.lastError)
    }

    func testRetryTeardownDiscardsQueuedCloseWithoutYielding() async {
        let (controller, connection) = makeController()
        defer { controller.disconnect() }
        controller.setControlSurface(UUID(), visible: true)
        connection.onEvent?(.opened)
        await settle()
        connection.onEvent?(.closed)
        controller.handleConnectTimeout()
        await settle()
        XCTAssertEqual(connection.addresses.count, 2)
        XCTAssertEqual(controller.connectionState, .connecting)
        XCTAssertNil(controller.lastError)
    }

    func testLegacyRemoteCloseDoesNotYieldOrReconnect() async {
        let (controller, connection) = makeController()
        defer { controller.disconnect() }
        controller.releaseWhenIdle = false
        controller.setControlSurface(UUID(), visible: true)
        await handshake(connection)
        connection.onEvent?(.closed)
        await settle()
        XCTAssertEqual(connection.addresses.count, 1)
        XCTAssertEqual(controller.connectionState, .disconnected)
        XCTAssertNil(controller.lastError)
    }

    func testFailureClearsDeferredCommandAndUsesExistingErrorSurface() async {
        let (controller, connection) = makeController()
        defer { controller.disconnect() }
        controller.setPauseWhenTakenOff(true)
        let message = RFCOMMConnection.channelOpenError(Int32(bitPattern: 0xe00002bc))
        connection.onEvent?(.failed(message))
        await settle()
        XCTAssertEqual(controller.lastError, message)
        XCTAssertTrue(message.contains("Sony Sound Connect"))
        XCTAssertEqual(controller.connectionState, .failed(message))
        controller.autoConnect()
        await handshake(connection)
        await drain(connection)
        XCTAssertFalse(connection.payloads.contains(SonyCommands.buildPauseWhenTakenOffSet(true)))
    }

    func testConnectionRetryPreservesQueuedCommands() async {
        let (controller, connection) = makeController()
        defer { controller.disconnect() }
        controller.setPauseWhenTakenOff(true)
        controller.handleConnectTimeout()
        XCTAssertEqual(connection.addresses.count, 2)
        await handshake(connection)
        await drain(connection)
        XCTAssertEqual(connection.payloads.filter { $0 == SonyCommands.buildPauseWhenTakenOffSet(true) }.count, 1)
    }

    func testUnsentCommandsSurviveDropAndReconnectGetsFreshRetry() async {
        let (controller, connection) = makeController()
        defer { controller.disconnect() }
        controller.setPauseWhenTakenOff(true)
        controller.setEqualizerPreset(.off)
        controller.handleConnectTimeout()
        await handshake(connection)
        connection.onEvent?(.closed)
        await settle()
        controller.handleConnectTimeout()
        XCTAssertEqual(connection.addresses.count, 4)
        XCTAssertEqual(controller.connectionState, .connecting)
        await handshake(connection)
        await drain(connection)
        XCTAssertTrue(connection.payloads.contains(SonyCommands.buildEqualizerPresetSet(code: EqualizerPreset.off.rawValue, subtype: 0x04)))
    }

    func testMissingInitAckDoesNotHoldCommandsForever() async {
        let (controller, connection) = makeController()
        defer { controller.disconnect() }
        controller.setPauseWhenTakenOff(true)
        connection.onEvent?(.opened)
        await settle()
        connection.reply([0x01, 0, 0, 0, 0, 0, 0, 0])
        await settle()
        XCTAssertEqual(controller.connectionState, .connected)
        XCTAssertFalse(connection.payloads.contains(SonyCommands.buildPauseWhenTakenOffSet(true)))
        // Exercise the real timeout callback without waiting for the transport timeout.
        controller.handleAckTimeout()
        XCTAssertTrue(connection.payloads.contains(SonyCommands.buildPauseWhenTakenOffSet(true)))
        connection.ack()
        await settle()
        controller.disconnectIfIdle(now: .now.advanced(by: .seconds(21)))
        XCTAssertEqual(controller.connectionState, .disconnected)
    }

    func testEqualizerDebounceSurvivesConnectionRetry() async {
        let (controller, connection) = makeController()
        defer { controller.disconnect() }
        controller.setEqualizerBands(Array(repeating: 3, count: 10))
        controller.handleConnectTimeout()
        try? await Task.sleep(for: .milliseconds(160))
        await handshake(connection)
        await drain(connection)
        XCTAssertTrue(connection.payloads.contains(SonyCommands.buildEqualizerBandsSet(bands: Array(repeating: 3, count: 10), subtype: 0x04)))
    }

    func testIdleExpiryFinishesCommandButDoesNotWaitForStateQueries() async {
        let (controller, connection) = makeController()
        defer { controller.disconnect() }
        controller.setPauseWhenTakenOff(true)
        controller.disconnectIfIdle(now: .now.advanced(by: .seconds(21)))
        XCTAssertEqual(controller.connectionState, .connecting)
        await handshake(connection)
        controller.disconnectIfIdle(now: .now.advanced(by: .seconds(21)))
        XCTAssertEqual(controller.connectionState, .connected)
        connection.ack()
        await settle()
        controller.disconnectIfIdle(now: .now.advanced(by: .seconds(21)))
        XCTAssertEqual(controller.connectionState, .disconnected)
        XCTAssertTrue(connection.payloads.contains(SonyCommands.buildPauseWhenTakenOffSet(true)))
        XCTAssertFalse(connection.payloads.contains(SonyCommands.buildDeviceListGet()))
    }

    func testTimerReleasesAfterPendingCommandsSurviveDropPastDeadline() async {
        let (controller, connection) = makeController()
        defer { controller.disconnect() }
        for index in 0..<10 { controller.setPauseWhenTakenOff(index.isMultiple(of: 2)) }
        await handshake(connection)
        let (idleController, idleConnection) = makeController()
        defer { idleController.disconnect() }
        let surface = UUID()
        idleController.setControlSurface(surface, visible: true)
        await handshake(idleConnection)
        await drain(idleConnection)
        idleController.setControlSurface(surface, visible: false)
        // Deliberately withhold ACKs. Ten user commands take longer than the grace
        // period at the normal three-second ACK timeout.
        try? await Task.sleep(for: ConnectionUsage.gracePeriod + .milliseconds(100))
        // With no queued work, the timer itself closes the other controller.
        XCTAssertEqual(idleController.connectionState, .disconnected)
        XCTAssertEqual(controller.connectionState, .connected)
        connection.onEvent?(.closed)
        await settle()
        XCTAssertEqual(controller.connectionState, .connecting)
        await handshake(connection)
        await drain(connection)
        // The ACK path must finish idle release itself, without another UI event.
        XCTAssertEqual(controller.connectionState, .disconnected)
        XCTAssertEqual(connection.payloads.filter { $0 == SonyCommands.buildPauseWhenTakenOffSet(true) }.count
            + connection.payloads.filter { $0 == SonyCommands.buildPauseWhenTakenOffSet(false) }.count, 10)
    }

    func testIdleReleaseRemembersManuallySelectedHeadset() {
        let connection = TestConnection()
        let controller = HeadphonesController(connection: connection, pairedDevices: { [] })
        defer { controller.disconnect() }
        controller.releaseWhenIdle = true
        controller.connect(toAddress: "renamed-headset", name: "My headphones")
        controller.disconnectIfIdle(now: .now.advanced(by: .seconds(21)))
        XCTAssertEqual(controller.connectionState, .disconnected)
        controller.setControlSurface(UUID(), visible: true)
        XCTAssertEqual(connection.addresses, ["renamed-headset", "renamed-headset"])
    }

    func testEnablingReleaseAcquiresForAlreadyVisibleSurface() {
        let connection = TestConnection()
        let controller = HeadphonesController(connection: connection, pairedDevices: {
            [PairedDeviceInfo(id: "test-device", name: "WH-1000XM6")]
        })
        defer { controller.disconnect() }
        controller.setControlSurface(UUID(), visible: true)
        XCTAssertTrue(connection.addresses.isEmpty)
        controller.releaseWhenIdle = true
        XCTAssertEqual(connection.addresses, ["test-device"])
    }

    func testDisablingReleaseConnectsAndPreservesStartupDefaults() async {
        let (controller, connection) = makeController()
        defer { controller.disconnect() }
        controller.releaseWhenIdle = false
        XCTAssertEqual(connection.addresses.count, 1)
        await handshake(connection)
        connection.reply([Opcode.ambientSoundControlRet, 0x15, 1, 0, 0, 0, 0])
        await settle()
        XCTAssertEqual(controller.ambientSound?.mode, .noiseCancelling)
        XCTAssertEqual(controller.ambientSound?.level, 15)
        controller.disconnectIfIdle(now: .now.advanced(by: .seconds(100)))
        XCTAssertEqual(controller.connectionState, .connected)
    }
}

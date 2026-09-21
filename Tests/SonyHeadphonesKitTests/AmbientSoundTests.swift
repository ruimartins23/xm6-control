import XCTest
@testable import SonyHeadphonesKit

final class AmbientSoundTests: XCTestCase {
    func testXM6ReportsDecodeObservedModesAndRememberedLevels() throws {
        let fixtures: [([UInt8], AmbientSoundMode, Int)] = [
            ([0x69, 0x19, 0x01, 0x01, 0x00, 0x00, 0x09, 0x00, 0x00], .noiseCancelling, 9),
            ([0x69, 0x19, 0x01, 0x00, 0x00, 0x00, 0x09, 0x00, 0x00], .off, 9),
            ([0x69, 0x19, 0x01, 0x01, 0x01, 0x00, 0x01, 0x00, 0x00], .ambientSound, 1),
            ([0x69, 0x19, 0x01, 0x01, 0x01, 0x00, 0x0a, 0x00, 0x00], .ambientSound, 10),
        ]
        for (payload, mode, level) in fixtures {
            for opcode: UInt8 in [0x67, 0x69] {
                var report = payload
                report[0] = opcode
                let state = try XCTUnwrap(SonyCommands.decodeAmbientSound(report))
                XCTAssertEqual(state.mode, mode)
                XCTAssertEqual(state.level, level)
                XCTAssertFalse(state.focusOnVoice)
                XCTAssertEqual(state.subtype, 0x19)
                XCTAssertFalse(state.hasWindNoiseByte)
                XCTAssertTrue(state.isUpdate)
                XCTAssertEqual(state.trailingBytes, [0, 0])
                guard case .ambientSound(let eventState) = SonyEventDecoder.decode(payload: report, messageType: .command1) else {
                    return XCTFail("Expected ambient event for \(report)")
                }
                XCTAssertEqual(eventState, state)
            }
        }
    }

    func testXM6RejectsTruncatedExtendedAndInvalidReports() {
        let report: [UInt8] = [0x69, 0x19, 1, 1, 1, 0, 10, 0, 0]
        for count in 0..<report.count {
            XCTAssertNil(SonyCommands.decodeAmbientSound(Array(report.prefix(count))))
        }
        XCTAssertNil(SonyCommands.decodeAmbientSound(report + [0]))
        for (index, value): (Int, UInt8) in [(3, 2), (5, 2), (6, 21)] {
            var invalid = report
            invalid[index] = value
            XCTAssertNil(SonyCommands.decodeAmbientSound(invalid))
        }
    }

    func testXM6WritesUseProvenSubtypeAndExcludeTrailer() {
        let state = AmbientSoundState(mode: .ambientSound, focusOnVoice: true, level: 10, subtype: 0x19, trailingBytes: [0xa5, 0x5a])
        XCTAssertEqual(SonyCommands.buildAmbientSoundSet(state), [0x68, 0x17, 1, 1, 1, 1, 10])
    }

    func testZeroPlaceholderRetainsUpdateFlagAndRawLevelForLegacyMode() throws {
        let state = try XCTUnwrap(SonyCommands.decodeAmbientSound([0x67, 0x17, 0, 0, 0, 0, 0]))
        XCTAssertFalse(state.isUpdate)
        XCTAssertEqual(state.mode, .off)
        XCTAssertEqual(state.level, 0)
        XCTAssertTrue(state.trailingBytes.isEmpty)
    }

    func testXM6PreservesUnknownTrailerWithoutUsingItAsVoiceOrLevel() throws {
        // Synthetic bytes test preservation, not the unknown flags' meaning.
        let state = try XCTUnwrap(SonyCommands.decodeAmbientSound([0x69, 0x19, 1, 1, 1, 1, 10, 0xa5, 0x5a]))
        XCTAssertTrue(state.focusOnVoice)
        XCTAssertEqual(state.level, 10)
        XCTAssertEqual(state.trailingBytes, [0xa5, 0x5a])
        XCTAssertEqual(SonyCommands.buildAmbientSoundSet(state), [0x68, 0x17, 1, 1, 1, 1, 10])
    }

    func testAmbientWritesClampLevelsIncludingMutatedState() {
        for (level, expected): (Int, UInt8) in [(Int.min, 1), (0, 1), (1, 1), (20, 20), (21, 20), (Int.max, 20)] {
            var state = AmbientSoundState(mode: .ambientSound, subtype: 0x17)
            state.level = level
            XCTAssertEqual(SonyCommands.buildAmbientSoundSet(state), [0x68, 0x17, 1, 1, 1, 0, expected])
        }
    }

    func testOlderAmbientLayoutsKeepVoiceLevelAndWriteDialect() throws {
        let fixtures: [[UInt8]] = [
            [0x67, 0x15, 1, 1, 1, 1, 12],
            [0x67, 0x17, 1, 1, 1, 1, 12],
            [0x67, 0x17, 1, 1, 1, 2, 1, 12],
            [0x67, 0x22, 1, 1, 1, 12],
        ]
        for report in fixtures {
            let state = try XCTUnwrap(SonyCommands.decodeAmbientSound(report))
            XCTAssertEqual(state.mode, .ambientSound)
            XCTAssertTrue(state.focusOnVoice)
            XCTAssertEqual(state.level, 12)
            XCTAssertEqual(state.hasWindNoiseByte, report.count == 8)
            XCTAssertEqual(SonyCommands.buildAmbientSoundSet(state)[1], report[1])
        }
    }
}

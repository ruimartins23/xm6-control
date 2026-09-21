import XCTest
@testable import SonyHeadphonesKit

final class ConnectionUsageTests: XCTestCase {
    func testClosingLastSurfaceStartsGracePeriod() {
        var usage = ConnectionUsage(releaseWhenIdle: true)
        let main = UUID(), panel = UUID(), widget = UUID()
        let now = ContinuousClock.now
        for id in [main, panel, widget] {
            XCTAssertTrue(usage.setSurface(id, visible: true, now: now))
        }
        XCTAssertNil(usage.idleDeadline)
        _ = usage.setSurface(main, visible: false, now: now)
        _ = usage.setSurface(panel, visible: false, now: now)
        XCTAssertFalse(usage.shouldRelease(now: now.advanced(by: .seconds(100))))
        _ = usage.setSurface(widget, visible: false, now: now)
        XCTAssertFalse(usage.shouldRelease(now: now.advanced(by: .seconds(19))))
        XCTAssertTrue(usage.shouldRelease(now: now.advanced(by: .seconds(20))))
    }

    func testCommandRestartsGraceAndOpeningCancelsIt() {
        var usage = ConnectionUsage(releaseWhenIdle: true)
        let now = ContinuousClock.now
        usage.recordActivity(now: now)
        usage.recordActivity(now: now.advanced(by: .seconds(19)))
        XCTAssertFalse(usage.shouldRelease(now: now.advanced(by: .seconds(20))))
        XCTAssertTrue(usage.shouldRelease(now: now.advanced(by: .seconds(39))))
        _ = usage.setSurface(UUID(), visible: true, now: now.advanced(by: .seconds(38)))
        XCTAssertNil(usage.idleDeadline)
        XCTAssertFalse(usage.shouldRelease(now: now.advanced(by: .seconds(100))))
    }

    func testRepeatedCloseDoesNotExtendDeadline() {
        var usage = ConnectionUsage(releaseWhenIdle: true)
        let id = UUID(), now = ContinuousClock.now
        _ = usage.setSurface(id, visible: true, now: now)
        _ = usage.setSurface(id, visible: false, now: now)
        XCTAssertFalse(usage.setSurface(id, visible: false, now: now.advanced(by: .seconds(10))))
        XCTAssertTrue(usage.shouldRelease(now: now.advanced(by: .seconds(20))))
    }

    func testDisabledPolicyNeverReleases() {
        var usage = ConnectionUsage()
        usage.recordActivity()
        XCTAssertNil(usage.idleDeadline)
        XCTAssertFalse(usage.shouldRelease(now: .now.advanced(by: .seconds(100))))
        usage.releaseWhenIdle = true
        usage.recordActivity()
        usage.releaseWhenIdle = false
        usage.recordActivity()
        XCTAssertNil(usage.idleDeadline)
        XCTAssertFalse(usage.shouldRelease(now: .now.advanced(by: .seconds(100))))
    }
}

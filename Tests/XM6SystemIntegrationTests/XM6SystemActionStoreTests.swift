import XCTest
@testable import XM6SystemIntegration

final class XM6SystemActionStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "XM6SystemActionStoreTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testSubmittedActionIsConsumedOnlyOnce() {
        let store = XM6SystemActionStore(defaults: defaults)

        store.submit(.ambientSound)

        XCTAssertEqual(store.consume(), .ambientSound)
        XCTAssertNil(store.consume())
    }

    func testNewActionSupersedesUnconsumedAction() {
        let store = XM6SystemActionStore(defaults: defaults)

        store.submit(.openControls)
        store.submit(.openWidget)

        XCTAssertEqual(store.consume(), .openWidget)
    }

    func testInvalidPersistedActionIsDiscarded() {
        let store = XM6SystemActionStore(defaults: defaults)
        defaults.set("not-an-action", forKey: XM6SystemActionStore.defaultKey)

        XCTAssertNil(store.consume())
        XCTAssertNil(defaults.object(forKey: XM6SystemActionStore.defaultKey))
    }
}

@testable import Noma
import XCTest

final class EmptyAccountDataTests: XCTestCase {
    @MainActor
    func testStoreStartsEmptyWithoutPersistedData() async {
        let suiteName = "EmptyAccountDataTests-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Could not create isolated user defaults")
            return
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = DailyTaskGroupStore(
            userDefaults: defaults,
            storageKey: DailyTaskGroupStorage.storageKey(forUserID: "new-user")
        )

        XCTAssertTrue(store.groups.isEmpty)
        XCTAssertNil(store.persistenceError)
    }
}

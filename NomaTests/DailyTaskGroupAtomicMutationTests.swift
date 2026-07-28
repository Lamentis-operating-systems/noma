@testable import Noma
import XCTest

@MainActor
final class DailyTaskGroupAtomicMutationTests: XCTestCase {
    func testCarryForwardMovesTaskWithOneAtomicSave() {
        let source = CreateReminder(
            id: UUID(),
            text: "Carry me",
            createdAt: Date(timeIntervalSinceReferenceDate: 100),
            carryForwardCount: 2
        )
        let state = DailyTaskGroupState(
            groups: [
                DailyTaskGroup(id: "2026-05-16", date: Date(), reminders: [source])
            ],
            projects: [],
            selectedProjectID: nil
        )
        let persistence = AtomicPersistence(state: state)
        let store = DailyTaskGroupStore(persistenceFactory: { _ in persistence })
        RetainedDailyTaskGroupStores.retain(store)

        XCTAssertTrue(store.carryForwardReminders(
            [source],
            fromDayID: "2026-05-16",
            toDayID: "2026-05-17"
        ))
        XCTAssertEqual(persistence.saveCallCount, 1)
        XCTAssertTrue(store.reminders(forDayID: "2026-05-16").isEmpty)
        let carried = store.reminders(forDayID: "2026-05-17").first
        XCTAssertEqual(carried?.text, source.text)
        XCTAssertEqual(carried?.createdAt, source.createdAt)
        XCTAssertEqual(carried?.carryForwardCount, 3)
        XCTAssertNil(carried?.projectID)
    }

    func testFailedCaptureLeavesStoreUnchanged() {
        let persistence = AtomicPersistence(state: .empty, failsSaves: true)
        let store = DailyTaskGroupStore(persistenceFactory: { _ in persistence })
        RetainedDailyTaskGroupStores.retain(store)

        XCTAssertFalse(store.setReminders([CreateReminder(text: "Unsaved")], forDayID: "2026-05-17"))
        XCTAssertTrue(store.groups.isEmpty)
        XCTAssertEqual(persistence.saveCallCount, 1)
        XCTAssertEqual(store.persistenceError, .writeFailed)
    }

    func testFailedCarryForwardLeavesSourceAndTargetUnchanged() {
        let source = CreateReminder(text: "Stay put")
        let state = DailyTaskGroupState(
            groups: [DailyTaskGroup(id: "2026-05-16", date: Date(), reminders: [source])],
            projects: [],
            selectedProjectID: nil
        )
        let persistence = AtomicPersistence(state: state, failsSaves: true)
        let store = DailyTaskGroupStore(persistenceFactory: { _ in persistence })
        RetainedDailyTaskGroupStores.retain(store)

        XCTAssertFalse(store.carryForwardReminders(
            [source],
            fromDayID: "2026-05-16",
            toDayID: "2026-05-17"
        ))
        XCTAssertEqual(store.reminders(forDayID: "2026-05-16").map(\.id), [source.id])
        XCTAssertTrue(store.reminders(forDayID: "2026-05-17").isEmpty)
    }
}

@MainActor
enum RetainedDailyTaskGroupStores {
    private static var stores: [DailyTaskGroupStore] = []

    static func retain(_ store: DailyTaskGroupStore) {
        stores.append(store)
    }
}

@MainActor
private final class AtomicPersistence: DailyTaskGroupPersisting {
    var state: DailyTaskGroupState
    var saveCallCount = 0
    let failsSaves: Bool

    init(state: DailyTaskGroupState, failsSaves: Bool = false) {
        self.state = state
        self.failsSaves = failsSaves
    }

    func load() -> DailyTaskGroupLoadResult {
        .loaded(state, source: .current(version: DailyTaskGroupPersistenceEnvelope.currentSchemaVersion))
    }

    func save(_ state: DailyTaskGroupState) -> Result<Void, DailyTaskGroupPersistenceError> {
        saveCallCount += 1
        guard !failsSaves else { return .failure(.writeFailed) }
        self.state = state
        return .success(())
    }

    func delete() -> Result<Void, DailyTaskGroupPersistenceError> {
        state = .empty
        return .success(())
    }
}

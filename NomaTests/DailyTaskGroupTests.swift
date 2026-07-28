@testable import Noma
import XCTest

@MainActor
final class DailyTaskGroupTests: XCTestCase {
    func testQuickCaptureAlwaysPersistsWithoutProjectAssociation() {
        let persistence = LifecyclePersistence(state: .empty)
        let store = DailyTaskGroupStore(persistenceFactory: { _ in persistence })
        RetainedDailyTaskGroupStores.retain(store)
        let dayID = "2026-05-17"

        XCTAssertTrue(store.setReminders(
            [CreateReminder(text: "Captured", projectID: UUID())],
            forDayID: dayID
        ))
        XCTAssertEqual(store.reminders(forDayID: dayID).map(\.text), ["Captured"])
        XCTAssertNil(store.reminders(forDayID: dayID).first?.projectID)
    }

    func testCompletionPersistsForToday() {
        let reminder = CreateReminder(text: "Complete me")
        let state = DailyTaskGroupState(
            groups: [DailyTaskGroup(id: "2026-05-17", date: Date(), reminders: [reminder])],
            projects: [],
            selectedProjectID: nil
        )
        let persistence = LifecyclePersistence(state: state)
        let store = DailyTaskGroupStore(persistenceFactory: { _ in persistence })
        RetainedDailyTaskGroupStores.retain(store)

        XCTAssertTrue(store.setReminders([reminder.togglingCompletion()], forDayID: "2026-05-17"))
        XCTAssertEqual(store.reminders(forDayID: "2026-05-17").first?.isCompleted, true)
    }

    func testOpenRemindersFromPreviousDayExcludesCompletedTasks() throws {
        let calendar = Calendar(identifier: .gregorian)
        let previousDate = try XCTUnwrap(
            DateComponents(calendar: calendar, year: 2026, month: 5, day: 16).date
        )
        let state = DailyTaskGroupState(
            groups: [
                DailyTaskGroup(
                    id: "2026-05-16",
                    date: previousDate,
                    reminders: [
                        CreateReminder(text: "Carry"),
                        CreateReminder(text: "Done", isCompleted: true)
                    ]
                )
            ],
            projects: [],
            selectedProjectID: nil
        )
        let store = DailyTaskGroupStore(
            calendar: calendar,
            persistenceFactory: { _ in LifecyclePersistence(state: state) }
        )
        RetainedDailyTaskGroupStores.retain(store)

        XCTAssertEqual(
            store.openRemindersFromPreviousDay(beforeDayID: "2026-05-17").map(\.text),
            ["Carry"]
        )
    }
}

@MainActor
private final class LifecyclePersistence: DailyTaskGroupPersisting {
    var state: DailyTaskGroupState

    init(state: DailyTaskGroupState) {
        self.state = state
    }

    func load() -> DailyTaskGroupLoadResult {
        .loaded(state, source: .current(version: DailyTaskGroupPersistenceEnvelope.currentSchemaVersion))
    }

    func save(_ state: DailyTaskGroupState) -> Result<Void, DailyTaskGroupPersistenceError> {
        self.state = state
        return .success(())
    }

    func delete() -> Result<Void, DailyTaskGroupPersistenceError> {
        state = .empty
        return .success(())
    }
}

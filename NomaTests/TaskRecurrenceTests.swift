@testable import Noma
import XCTest

@MainActor
final class TaskRecurrenceTests: XCTestCase {
    func testCustomMenuDefaultsToTheMondayThroughFridayWorkweek() {
        XCTAssertEqual(Set(TaskRecurrenceMenu.customWeekdays), Set(2...6))
    }

    func testValidationRejectsBlankTextEmptyAndInvalidWeekdays() {
        XCTAssertFalse(TaskRecurrence(sourceText: " ", activeWeekdays: [2], startDate: .now).isValid)
        XCTAssertFalse(TaskRecurrence(sourceText: "Read", activeWeekdays: [], startDate: .now).isValid)
        XCTAssertFalse(TaskRecurrence(sourceText: "Read", activeWeekdays: [0, 8], startDate: .now).isValid)
        XCTAssertTrue(TaskRecurrence(sourceText: "Read", activeWeekdays: Set(1...7), startDate: .now).isValid)
    }

    func testDailyMaterializationIsOneOrdinaryTaskAndIdempotent() async {
        let calendar = berlinCalendar()
        let date = localDate(2026, 3, 29, 10, calendar: calendar)
        let store = makeStore(calendar: calendar, now: date)
        let source = CreateReminder(text: "Water plants", createdAt: date)
        let dayID = DailyTaskGroupStore.dayID(for: date, calendar: calendar)
        XCTAssertTrue(store.setReminders([source], forDayID: dayID))
        XCTAssertTrue(store.createRecurrence(from: source, onDayID: dayID, schedule: .daily))

        let nextDay = calendar.date(byAdding: .day, value: 1, to: date)!
        XCTAssertTrue(store.materializeRecurrences(asOf: nextDay))
        XCTAssertTrue(store.materializeRecurrences(asOf: nextDay))

        let generated = store.reminders(forDayID: DailyTaskGroupStore.dayID(for: nextDay, calendar: calendar))
        XCTAssertEqual(generated.count, 1)
        XCTAssertEqual(generated.first?.text, source.text)
        XCTAssertFalse(generated.first!.isCompleted)
    }

    func testSelectedWeekdaysOnlyMaterializeMatchingLocalWeekday() async {
        let calendar = berlinCalendar()
        let monday = localDate(2026, 3, 30, 9, calendar: calendar)
        let store = makeStore(calendar: calendar, now: monday)
        let source = CreateReminder(text: "Monday review", createdAt: monday)
        let mondayID = DailyTaskGroupStore.dayID(for: monday, calendar: calendar)
        XCTAssertTrue(store.setReminders([source], forDayID: mondayID))
        XCTAssertTrue(store.createRecurrence(from: source, onDayID: mondayID, schedule: .selectedWeekdays([2])))

        let tuesday = calendar.date(byAdding: .day, value: 1, to: monday)!
        XCTAssertTrue(store.materializeRecurrences(asOf: tuesday))
        XCTAssertTrue(store.reminders(forDayID: DailyTaskGroupStore.dayID(for: tuesday, calendar: calendar)).isEmpty)
    }

    func testStopLeavesTodaysInstanceAndPreventsFutureInstances() async {
        let calendar = berlinCalendar()
        let today = localDate(2026, 5, 4, 9, calendar: calendar)
        let store = makeStore(calendar: calendar, now: today)
        let source = CreateReminder(text: "Stand up", createdAt: today)
        let todayID = DailyTaskGroupStore.dayID(for: today, calendar: calendar)
        XCTAssertTrue(store.setReminders([source], forDayID: todayID))
        XCTAssertTrue(store.createRecurrence(from: source, onDayID: todayID, schedule: .daily))
        let recurrenceID = store.recurrences.first!.id

        XCTAssertTrue(store.stopRecurrence(withID: recurrenceID))
        XCTAssertEqual(store.reminders(forDayID: todayID), [source])
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        XCTAssertTrue(store.materializeRecurrences(asOf: tomorrow))
        XCTAssertTrue(store.reminders(forDayID: DailyTaskGroupStore.dayID(for: tomorrow, calendar: calendar)).isEmpty)
    }

    func testDeletingTodaysInstanceDoesNotStopRecurrence() async {
        let calendar = berlinCalendar()
        let today = localDate(2026, 5, 4, 9, calendar: calendar)
        let store = makeStore(calendar: calendar, now: today)
        let source = CreateReminder(text: "Independent delete", createdAt: today)
        let todayID = DailyTaskGroupStore.dayID(for: today, calendar: calendar)
        XCTAssertTrue(store.setReminders([source], forDayID: todayID))
        XCTAssertTrue(store.createRecurrence(from: source, onDayID: todayID, schedule: .daily))

        XCTAssertTrue(store.setReminders([], forDayID: todayID))
        XCTAssertEqual(store.recurrences.count, 1)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        XCTAssertTrue(store.materializeRecurrences(asOf: tomorrow))
        XCTAssertEqual(store.reminders(forDayID: DailyTaskGroupStore.dayID(for: tomorrow, calendar: calendar)).count, 1)
    }

    func testFailedAtomicWriteCanRetryWithoutPhantomOrDuplicate() async {
        let calendar = berlinCalendar()
        let start = localDate(2026, 1, 1, 9, calendar: calendar)
        let persistence = RecurrenceTestPersistence()
        let store = DailyTaskGroupStore(
            calendar: calendar,
            now: { start },
            persistenceFactory: { _ in persistence }
        )
        let source = CreateReminder(text: "Retry", createdAt: start)
        let startID = DailyTaskGroupStore.dayID(for: start, calendar: calendar)
        XCTAssertTrue(store.setReminders([source], forDayID: startID))
        XCTAssertTrue(store.createRecurrence(from: source, onDayID: startID, schedule: .daily))
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: start)!

        persistence.failsWrites = true
        XCTAssertFalse(store.materializeRecurrences(asOf: tomorrow))
        XCTAssertTrue(store.reminders(forDayID: DailyTaskGroupStore.dayID(for: tomorrow, calendar: calendar)).isEmpty)
        persistence.failsWrites = false
        XCTAssertTrue(store.materializeRecurrences(asOf: tomorrow))
        XCTAssertTrue(store.materializeRecurrences(asOf: tomorrow))
        XCTAssertEqual(store.reminders(forDayID: DailyTaskGroupStore.dayID(for: tomorrow, calendar: calendar)).count, 1)
    }

    func testDSTTimezoneChangeAndMissedDaysUseCurrentLocalDayWithoutBackfill() async {
        let berlin = berlinCalendar()
        let start = localDate(2026, 3, 28, 23, calendar: berlin)
        let store = makeStore(calendar: berlin, now: start)
        let source = CreateReminder(text: "Local day", createdAt: start)
        let startID = DailyTaskGroupStore.dayID(for: start, calendar: berlin)
        XCTAssertTrue(store.setReminders([source], forDayID: startID))
        XCTAssertTrue(store.createRecurrence(from: source, onDayID: startID, schedule: .daily))

        let afterDST = localDate(2026, 3, 30, 8, calendar: berlin)
        XCTAssertTrue(store.materializeRecurrences(asOf: afterDST))
        XCTAssertTrue(store.reminders(forDayID: "2026-03-29").isEmpty)
        XCTAssertEqual(store.reminders(forDayID: "2026-03-30").count, 1)

        var losAngeles = Calendar(identifier: .gregorian)
        losAngeles.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        XCTAssertNotEqual(
            DailyTaskGroupStore.dayID(for: afterDST, calendar: berlin),
            DailyTaskGroupStore.dayID(for: afterDST, calendar: losAngeles)
        )
    }

    func testAccountSwitchKeepsDefinitionsAndInstancesIsolated() async {
        let calendar = berlinCalendar()
        let today = localDate(2026, 6, 1, 9, calendar: calendar)
        let first = RecurrenceTestPersistence()
        let second = RecurrenceTestPersistence()
        let store = DailyTaskGroupStore(
            calendar: calendar,
            now: { today },
            userID: "first",
            persistenceFactory: { $0 == "first" ? first : second }
        )
        let source = CreateReminder(text: "First only", createdAt: today)
        let dayID = DailyTaskGroupStore.dayID(for: today, calendar: calendar)
        XCTAssertTrue(store.setReminders([source], forDayID: dayID))
        XCTAssertTrue(store.createRecurrence(from: source, onDayID: dayID, schedule: .daily))

        store.switchUserID("second")
        XCTAssertTrue(store.recurrences.isEmpty)
        XCTAssertTrue(store.reminders(forDayID: dayID).isEmpty)
        store.switchUserID("first")
        XCTAssertEqual(store.recurrences.count, 1)
        XCTAssertEqual(store.reminders(forDayID: dayID), [source])
    }

    private func makeStore(calendar: Calendar, now: Date) -> DailyTaskGroupStore {
        DailyTaskGroupStore(
            calendar: calendar,
            now: { now },
            persistenceFactory: { _ in RecurrenceTestPersistence() }
        )
    }

    private func berlinCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return calendar
    }

    private func localDate(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        _ hour: Int,
        calendar: Calendar
    ) -> Date {
        DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour
        ).date!
    }
}

@MainActor
private final class RecurrenceTestPersistence: DailyTaskGroupPersisting {
    var state: DailyTaskGroupState?
    var failsWrites = false

    func load() -> DailyTaskGroupLoadResult {
        state.map { .loaded($0, source: .current(version: DailyTaskGroupPersistenceEnvelope.currentSchemaVersion)) }
            ?? .empty
    }

    func save(_ state: DailyTaskGroupState) -> Result<Void, DailyTaskGroupPersistenceError> {
        guard !failsWrites else { return .failure(.writeFailed) }
        self.state = state
        return .success(())
    }

    func delete() -> Result<Void, DailyTaskGroupPersistenceError> {
        state = nil
        return .success(())
    }
}

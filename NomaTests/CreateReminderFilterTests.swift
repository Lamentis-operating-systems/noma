@testable import Noma
import XCTest

final class CreateReminderFilterTests: XCTestCase {
    func testCreateReminderFilterShowsOnlyUnsolvedTasksWhenEnabled() throws {
        let completedReminder = CreateReminder(text: "Done", isCompleted: true)
        let unsolvedReminder = CreateReminder(text: "Open")
        let reminders = [completedReminder, unsolvedReminder]

        XCTAssertEqual(
            CreateReminderListFilter.visibleReminders(reminders, showsOnlyUnsolved: false),
            reminders
        )
        XCTAssertEqual(
            CreateReminderListFilter.visibleReminders(reminders, showsOnlyUnsolved: true),
            [unsolvedReminder]
        )
    }

    func testCreateReminderFilterTemporarilyKeepsJustCompletedTasksVisible() throws {
        let completedReminder = CreateReminder(text: "Done", isCompleted: true)
        let unsolvedReminder = CreateReminder(text: "Open")
        let reminders = [completedReminder, unsolvedReminder]

        XCTAssertEqual(
            CreateReminderListFilter.visibleReminders(
                reminders,
                showsOnlyUnsolved: true,
                temporarilyVisibleCompletedReminderIDs: [completedReminder.id]
            ),
            reminders
        )
    }

    func testCreateReminderFilterPreferencePersistsUnsolvedMode() throws {
        let suiteName = "NomaTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        XCTAssertFalse(CreateReminderFilterPreference.isEnabled(in: defaults))

        CreateReminderFilterPreference.setIsEnabled(true, in: defaults)
        XCTAssertTrue(CreateReminderFilterPreference.isEnabled(in: defaults))

        CreateReminderFilterPreference.setIsEnabled(false, in: defaults)
        XCTAssertFalse(CreateReminderFilterPreference.isEnabled(in: defaults))
    }

    func testCreateReminderBatchCompletionCompletesEveryTaskWithoutChangingIdentity() throws {
        let projectID = UUID(uuidString: "00000000-0000-0000-0000-000000000031")!
        let firstID = UUID(uuidString: "00000000-0000-0000-0000-000000000032")!
        let secondID = UUID(uuidString: "00000000-0000-0000-0000-000000000033")!
        let reminders = [
            CreateReminder(id: firstID, text: "Open", projectID: projectID),
            CreateReminder(id: secondID, text: "Already done", isCompleted: true)
        ]

        let completedReminders = CreateReminderBatchCompletion.completingAll(reminders)

        XCTAssertTrue(completedReminders.allSatisfy(\.isCompleted))
        XCTAssertEqual(completedReminders.map(\.id), [firstID, secondID])
        XCTAssertEqual(completedReminders.map(\.projectID), [projectID, nil])
        XCTAssertEqual(completedReminders.map(\.text), ["Open", "Already done"])
    }
}

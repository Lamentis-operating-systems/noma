@testable import Noma
import Foundation
import XCTest

final class CreateReminderSubmissionTests: XCTestCase {
    func testCreateReminderSubmissionTrimsSubmittedText() {
        let reminder = CreateReminderSubmission.reminder(from: "  Call Mika  ")

        XCTAssertEqual(reminder?.text, "Call Mika")
    }

    func testCreateReminderSubmissionRemovesWhitespaceOnlyLines() {
        let reminder = CreateReminderSubmission.reminder(from: "  Call Mika  \n   \n\n  Bring notes  \n  ")

        XCTAssertEqual(reminder?.text, "Call Mika\nBring notes")
    }

    func testCreateReminderSubmissionRejectsTextOverCharacterLimit() {
        let overLimitText = String(repeating: "a", count: CreateReminderSubmission.characterLimit + 1)

        XCTAssertNil(CreateReminderSubmission.reminder(from: overLimitText))
    }

    func testCreateReminderSubmissionRejectsEmptyText() {
        XCTAssertNil(CreateReminderSubmission.reminder(from: "   \n  "))
    }

    func testCreateReminderSubmissionClearsInputAfterSuccessfulSubmit() {
        let result = CreateReminderSubmission.submit(
            text: "  Call Mika  ",
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        )

        XCTAssertEqual(result?.reminder.text, "Call Mika")
        XCTAssertEqual(result?.remainingText, "")
    }

    func testCreateReminderSubmissionTreatsFormerProjectSyntaxAsPlainText() {
        let work = TaskProject(id: UUID(uuidString: "00000000-0000-0000-0000-000000000063")!, title: "Work")
        let home = TaskProject(id: UUID(uuidString: "00000000-0000-0000-0000-000000000064")!, title: "Home")
        let result = CreateReminderSubmission.submit(
            text: "Work: Send launch update",
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000065")!,
            projects: [work, home],
            selectedProjectID: home.id
        )

        XCTAssertEqual(result?.reminder.text, "Work: Send launch update")
        XCTAssertNil(result?.reminder.projectID)
        XCTAssertEqual(result?.remainingText, "")
    }

    @MainActor
    func testSubmittedReminderPersistenceAppendsToOriginatingStoreDayAfterActiveDayChanges() throws {
        let suiteName = "CreateReminderSubmissionTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = DailyTaskGroupStore(userDefaults: defaults, storageKey: suiteName)
        RetainedDailyTaskGroupStores.retain(store)
        let originatingDayID = "2026-05-16"
        let nextDayID = "2026-05-17"
        let existingReminder = CreateReminder(text: "Existing source task")
        let nextDayReminder = CreateReminder(text: "Existing next-day task")
        let submittedReminder = CreateReminder(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000069")!,
            text: "Submitted while switching days"
        )
        let submission = CreateReminderSubmissionResult(reminder: submittedReminder, remainingText: "")
        XCTAssertTrue(store.setReminders([existingReminder], forDayID: originatingDayID))
        XCTAssertTrue(store.setReminders([nextDayReminder], forDayID: nextDayID))

        let route = CreateReminderSubmissionRoute(originatingDayID: originatingDayID)
        let activeDayID = nextDayID
        XCTAssertFalse(route.isOriginatingDayStillActive(activeDayID))

        var reminders = store.reminders(forDayID: route.originatingDayID)

        let appendedReminder = CreateReminderSubmissionPersistence.append(
            submission,
            to: &reminders,
            projects: [],
            selectedProjectID: nil
        )
        XCTAssertTrue(store.replaceRemindersAtomically(reminders, forDayID: route.originatingDayID))

        XCTAssertEqual(appendedReminder.id, submittedReminder.id)
        XCTAssertEqual(
            store.reminders(forDayID: originatingDayID).map(\.id),
            [existingReminder.id, submittedReminder.id]
        )
        XCTAssertEqual(store.reminders(forDayID: nextDayID).map(\.id), [nextDayReminder.id])
    }
}

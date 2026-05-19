@testable import Noma
import XCTest

final class CreateReminderEditingTests: XCTestCase {
    func testEditingReminderUpdatesExistingTaskTextAndProjectWithoutAppending() {
        let reminderID = UUID(uuidString: "00000000-0000-0000-0000-000000000072")!
        let originalProjectID = UUID(uuidString: "00000000-0000-0000-0000-000000000073")!
        let updatedProject = TaskProject(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000074")!,
            title: "Work"
        )
        let existingReminder = CreateReminder(
            id: reminderID,
            text: "Old copy",
            isCompleted: true,
            projectID: originalProjectID
        )

        let updatedReminders = CreateReminderSubmissionPersistence.updatedRemindersAfterEditing(
            sourceReminders: [existingReminder],
            editingReminderID: reminderID,
            submittedText: "  New copy  ",
            projects: [updatedProject],
            selectedProjectID: updatedProject.id
        )

        XCTAssertEqual(updatedReminders?.count, 1)
        XCTAssertEqual(updatedReminders?.first?.id, reminderID)
        XCTAssertEqual(updatedReminders?.first?.text, "New copy")
        XCTAssertEqual(updatedReminders?.first?.isCompleted, true)
        XCTAssertEqual(updatedReminders?.first?.projectID, updatedProject.id)
    }

    func testEditingReminderRejectsInvalidSubmittedText() {
        let reminderID = UUID(uuidString: "00000000-0000-0000-0000-000000000075")!
        let existingReminder = CreateReminder(id: reminderID, text: "Old copy")

        XCTAssertNil(
            CreateReminderSubmissionPersistence.updatedRemindersAfterEditing(
                sourceReminders: [existingReminder],
                editingReminderID: reminderID,
                submittedText: "   \n",
                projects: [],
                selectedProjectID: nil
            )
        )
    }

    func testClearingEditedDraftResetsEditingStateBeforeNewTextIsEntered() {
        let reminderID = UUID(uuidString: "00000000-0000-0000-0000-000000000076")!

        XCTAssertTrue(
            CreateReminderEditingDraftReset.shouldResetEditingDraft(
                text: "   \n",
                editingReminderID: reminderID
            )
        )
        XCTAssertFalse(
            CreateReminderEditingDraftReset.shouldResetEditingDraft(
                text: "New task",
                editingReminderID: reminderID
            )
        )
        XCTAssertFalse(
            CreateReminderEditingDraftReset.shouldResetEditingDraft(
                text: "",
                editingReminderID: nil
            )
        )
    }

    func testTaskContextMenuPreviewUsesRoundedPrimaryBackgroundCardTokens() {
        XCTAssertEqual(CreateReminderContextMenuPreviewLayout.cornerRadius, NomaRadius.taskPreview)
        XCTAssertEqual(CreateReminderContextMenuPreviewLayout.contentPadding, NomaSpacing.md)
        XCTAssertEqual(CreateReminderContextMenuPreviewLayout.outerPadding, NomaSpacing.md)
        XCTAssertEqual(CreateReminderContextMenuPreviewLayout.cardWidth, NomaSize.taskPreview)
    }
}

@testable import Noma
import Foundation
import XCTest

final class CreateReminderCarryForwardTests: XCTestCase {
    @MainActor
    func testCreateReminderDecodesLegacyPayloadWithoutProjectID() throws {
        let legacyJSON = """
        {
          "id": "00000000-0000-0000-0000-000000000031",
          "text": "Legacy reminder",
          "isCompleted": false
        }
        """
        let data = try XCTUnwrap(legacyJSON.data(using: .utf8))

        let reminder = try JSONDecoder().decode(CreateReminder.self, from: data)

        XCTAssertEqual(reminder.id, UUID(uuidString: "00000000-0000-0000-0000-000000000031"))
        XCTAssertEqual(reminder.text, "Legacy reminder")
        XCTAssertFalse(reminder.isCompleted)
        XCTAssertNil(reminder.projectID)
    }

    func testCarryForwardPreviewExcludesTasksAlreadyAddedToday() {
        let projectID = UUID(uuidString: "00000000-0000-0000-0000-000000000051")!
        let previousOpenReminders = [
            CreateReminder(text: "Move invoice", projectID: projectID),
            CreateReminder(text: "Send update")
        ]
        let currentReminders = [
            CreateReminder(text: "Move invoice", projectID: projectID)
        ]

        XCTAssertEqual(
            CreateReminderCarryForwardPreview.visibleReminders(
                currentReminders: currentReminders,
                previousOpenReminders: previousOpenReminders
            )
            .map(\.text),
            ["Send update"]
        )
    }

    func testCarryForwardPreviewSortsOldestRemindersFirst() {
        let oldestDate = Date(timeIntervalSince1970: 100)
        let middleDate = Date(timeIntervalSince1970: 200)
        let newestDate = Date(timeIntervalSince1970: 300)
        let previousOpenReminders = [
            CreateReminder(text: "Newest", createdAt: newestDate),
            CreateReminder(text: "Oldest", createdAt: oldestDate),
            CreateReminder(text: "Middle", createdAt: middleDate)
        ]

        XCTAssertEqual(
            CreateReminderCarryForwardPreview.visibleReminders(
                currentReminders: [],
                previousOpenReminders: previousOpenReminders
            )
            .map(\.text),
            ["Oldest", "Middle", "Newest"]
        )
    }

    func testCarryForwardPreviewKeepsOriginalOrderWhenCreatedAtMatches() {
        let createdAt = Date(timeIntervalSince1970: 100)
        let previousOpenReminders = [
            CreateReminder(text: "First", createdAt: createdAt),
            CreateReminder(text: "Second", createdAt: createdAt),
            CreateReminder(text: "Third", createdAt: createdAt)
        ]

        XCTAssertEqual(
            CreateReminderCarryForwardPreview.visibleReminders(
                currentReminders: [],
                previousOpenReminders: previousOpenReminders
            )
            .map(\.text),
            ["First", "Second", "Third"]
        )
    }

    func testCarriedForwardReminderPreservesCreatedAtAndIncrementsCarryCount() {
        let createdAt = Date(timeIntervalSince1970: 100)
        let sourceReminder = CreateReminder(
            text: "Move invoice",
            createdAt: createdAt,
            carryForwardCount: 1
        )

        let carriedReminder = CreateReminderCarryForwardTransfer.carriedReminder(from: sourceReminder)

        XCTAssertEqual(carriedReminder.text, sourceReminder.text)
        XCTAssertEqual(carriedReminder.createdAt, createdAt)
        XCTAssertEqual(carriedReminder.carryForwardCount, 2)
        XCTAssertTrue(carriedReminder.wasCarriedForward)
    }

    @MainActor
    func testLegacyReminderDecodingBackfillsCarryForwardMetadata() throws {
        let json = """
        {
          "id": "00000000-0000-0000-0000-000000000072",
          "text": "Legacy task",
          "isCompleted": false
        }
        """.data(using: .utf8)!

        let reminder = try JSONDecoder().decode(CreateReminder.self, from: json)

        XCTAssertEqual(reminder.text, "Legacy task")
        XCTAssertEqual(reminder.createdAt, .distantPast)
        XCTAssertEqual(reminder.carryForwardCount, 0)
        XCTAssertFalse(reminder.wasCarriedForward)
    }

    func testCarryForwardPreviewCompletionMarksOriginalReminderDone() {
        let reminderID = UUID(uuidString: "00000000-0000-0000-0000-000000000052")!
        let targetReminder = CreateReminder(id: reminderID, text: "Send update")
        let reminders = [
            CreateReminder(text: "Keep open"),
            targetReminder
        ]

        let updatedReminders = CreateReminderCarryForwardCompletion.completing(
            targetReminder,
            in: reminders
        )

        XCTAssertFalse(updatedReminders[0].isCompleted)
        XCTAssertTrue(updatedReminders[1].isCompleted)
    }

    func testCarryForwardTransferRemovesTransferredTasksFromSourceDay() {
        let transferredReminder = CreateReminder(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000070")!,
            text: "Move invoice"
        )
        let remainingReminder = CreateReminder(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000071")!,
            text: "Keep yesterday"
        )

        XCTAssertEqual(
            CreateReminderCarryForwardTransfer.sourceRemindersAfterTransfer(
                sourceReminders: [transferredReminder, remainingReminder],
                transferredReminders: [transferredReminder]
            ),
            [remainingReminder]
        )
    }
}

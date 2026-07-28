@testable import Noma
import Foundation
import XCTest

final class CreateReminderAutoScrollTests: XCTestCase {
    func testCreateReminderAutoScrollTargetsSubmittedReminderAfterSubmission() {
        let reminder = CreateReminder(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
            text: "Last task"
        )

        XCTAssertEqual(
            CreateReminderAutoScroll.targetAfterAppending(reminder),
            CreateReminderAutoScroll.targetID(for: reminder)
        )
    }

    func testCreateReminderAutoScrollTargetsLastVisibleTaskAfterKeyboardFocus() {
        let firstReminder = CreateReminder(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!,
            text: "First task"
        )
        let lastReminder = CreateReminder(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000005")!,
            text: "Last task"
        )

        XCTAssertEqual(
            CreateReminderAutoScroll.targetAfterKeyboardFocus(visibleReminders: [firstReminder, lastReminder]),
            CreateReminderAutoScroll.targetID(for: lastReminder)
        )
    }

    func testCreateReminderAutoScrollIgnoresKeyboardFocusWithoutTasks() {
        XCTAssertNil(CreateReminderAutoScroll.targetAfterKeyboardFocus(visibleReminders: []))
    }
}

import XCTest
@testable import Noma

final class CreateTaskEmptyHintTests: XCTestCase {
    func testCreateTaskFilteredEmptyStateUsesCompletedHintCopy() {
        let emptyState = CreateTaskEmptyState.filtered

        XCTAssertEqual(emptyState.systemImage, "checkmark.circle")
        XCTAssertEqual(emptyState.titleKey, "create.tasks.empty.filtered.title")
        XCTAssertEqual(emptyState.subtitleKey, "create.tasks.empty.filtered.subtitle")
        XCTAssertFalse(emptyState.mirrorsImageForRightToLeftLayoutDirection)
        XCTAssertNil(emptyState.cta)
    }

    func testCreateReminderListShowsFilteredEmptyStateOnlyWhenFilterHidesExistingTasks() {
        XCTAssertTrue(
            CreateReminderListSection.showsFilteredEmptyState(
                visibleReminderCount: 0,
                reminderCount: 2
            )
        )
        XCTAssertFalse(
            CreateReminderListSection.showsFilteredEmptyState(
                visibleReminderCount: 1,
                reminderCount: 2
            )
        )
        XCTAssertFalse(
            CreateReminderListSection.showsFilteredEmptyState(
                visibleReminderCount: 0,
                reminderCount: 0
            )
        )
    }
}

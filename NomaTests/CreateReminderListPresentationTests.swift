@testable import Noma
import Foundation
import XCTest

final class CreateReminderListPresentationTests: XCTestCase {
    func testCreateReminderListShowsEmptyStateOnlyWithoutTasks() {
        XCTAssertTrue(CreateReminderListSection.showsEmptyState(reminderCount: 0))
        XCTAssertFalse(CreateReminderListSection.showsEmptyState(reminderCount: 1))
        XCTAssertFalse(
            CreateReminderListSection.showsEmptyState(
                reminderCount: 0,
                carryForwardPreviewCount: 1
            )
        )
    }

    func testCreateViewOnlyUsesScrollViewAfterTasksWereAdded() {
        XCTAssertFalse(CreateViewContentMode.usesScrollView(reminderCount: 0))
        XCTAssertTrue(CreateViewContentMode.usesScrollView(reminderCount: 1))
    }

    func testCreateViewUsesScrollViewForCarryForwardPreview() {
        XCTAssertTrue(CreateViewContentMode.usesScrollView(reminderCount: 0, carryForwardPreviewCount: 1))
    }

    func testSectionHeaderTextFormattingUsesTitleCase() {
        XCTAssertEqual(
            SectionHeaderTextFormatting.titleCased("tasks for today"),
            "Tasks For Today"
        )
    }

    func testCreateReminderListSectionFormatsHeaderAndTracksVisibility() {
        let date = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 5, day: 18))!
        let headerTitle = CreateReminderListSection.headerTitle(for: date)
        let dateText = date.formatted(date: .abbreviated, time: .omitted)

        XCTAssertTrue(headerTitle.contains(dateText))
        XCTAssertFalse(CreateReminderListSection.showsHeader(reminderCount: 0))
        XCTAssertFalse(
            CreateReminderListSection.showsHeader(
                reminderCount: 0,
                carryForwardPreviewCount: 1
            )
        )
        XCTAssertTrue(CreateReminderListSection.showsHeader(reminderCount: 1))
    }
}

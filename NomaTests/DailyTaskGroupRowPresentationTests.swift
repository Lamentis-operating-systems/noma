@testable import Noma
import XCTest

final class DailyTaskGroupRowPresentationTests: XCTestCase {
    func testDailyTaskGroupRowsUseScaleFeedbackAndCompletionCopy() {
        XCTAssertEqual(DailyTaskGroupRowLayout.statusIconWidth, NomaSize.taskMetadataIconColumn)
        XCTAssertEqual(DailyTaskGroupRowLayout.statusIconHeight, NomaSize.radioCheckboxOuter)
        XCTAssertEqual(DailyTaskGroupsProgressCopy.completedKey, "home.daily-groups.progress.completed")
    }

    @MainActor
    func testDailyTaskGroupSummaryUsesDailyGroupsProgressCopyAndCompletionState() throws {
        let calendar = Calendar(identifier: .gregorian)
        let date = try XCTUnwrap(DateComponents(calendar: calendar, year: 2026, month: 5, day: 16).date)
        let summary = DailyTaskGroupSummary(
            group: DailyTaskGroup(
                id: "2026-05-16",
                date: date,
                reminders: [
                    CreateReminder(text: "One"),
                    CreateReminder(text: "Two")
                ]
            )
        )
        let completedSummary = DailyTaskGroupSummary(
            group: DailyTaskGroup(
                id: "2026-05-17",
                date: date,
                reminders: [
                    CreateReminder(text: "One", isCompleted: true)
                ]
            )
        )

        XCTAssertEqual(DailyTaskGroupsSection.headerTitleKey, "home.daily-groups.section-header")
        XCTAssertEqual(summary.taskCount, 2)
        XCTAssertEqual(summary.completedTaskCount, 0)
        XCTAssertEqual(summary.taskCountUnitKey, "home.daily-groups.task-count.plural")
        XCTAssertFalse(summary.isCompleted)
        XCTAssertTrue(completedSummary.isCompleted)
        XCTAssertEqual(completedSummary.completedTaskCount, 1)
        XCTAssertEqual(completedSummary.taskCountUnitKey, "home.daily-groups.task-count.singular")
        XCTAssertEqual(DailyTaskGroupsProgressCopy.ofKey, "home.daily-groups.progress.of")
        XCTAssertEqual(DailyTaskGroupsProgressCopy.completedKey, "home.daily-groups.progress.completed")
    }

    func testDailyTaskGroupRowUsesStatusIconsForOpenAndCompletedGroups() throws {
        let calendar = Calendar(identifier: .gregorian)
        let date = try XCTUnwrap(DateComponents(calendar: calendar, year: 2026, month: 5, day: 16).date)
        let incompleteSummary = DailyTaskGroupSummary(
            group: DailyTaskGroup(
                id: "2026-05-16",
                date: date,
                reminders: [
                    CreateReminder(text: "One", isCompleted: true),
                    CreateReminder(text: "Two")
                ]
            )
        )
        let completedSummary = DailyTaskGroupSummary(
            group: DailyTaskGroup(
                id: "2026-05-17",
                date: date,
                reminders: [
                    CreateReminder(text: "One", isCompleted: true)
                ]
            )
        )

        XCTAssertEqual(
            DailyTaskGroupRowStatus.status(for: incompleteSummary).systemImage,
            DailyTaskGroupRowStatus.openSystemImage
        )
        XCTAssertEqual(
            DailyTaskGroupRowStatus.status(for: completedSummary).systemImage,
            DailyTaskGroupRowStatus.completedSystemImage
        )
    }
}

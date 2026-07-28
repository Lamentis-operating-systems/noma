@testable import Noma
import CoreGraphics
import Foundation
import SwiftUI
import XCTest

final class CreateReminderInteractionTests: XCTestCase {
    func testCreateReminderStartsIncompleteAndCanToggleCompletion() {
        let reminder = CreateReminder(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, text: "Call Mika")

        XCTAssertFalse(reminder.isCompleted)
        XCTAssertTrue(reminder.togglingCompletion().isCompleted)
        XCTAssertFalse(reminder.togglingCompletion().togglingCompletion().isCompleted)
    }

    func testRadioCheckboxStateOnlyShowsInnerCircleWhenOn() {
        XCTAssertFalse(RadioCheckboxState(isOn: false).showsInnerCircle)
        XCTAssertTrue(RadioCheckboxState(isOn: true).showsInnerCircle)
    }

    func testReminderCompletionHapticOnlyPlaysWhenToggledOn() {
        XCTAssertEqual(CreateReminderCompletionFeedback.feedback(isCompleted: true), .createTaskSubmit)
        XCTAssertNil(CreateReminderCompletionFeedback.feedback(isCompleted: false))
    }

    @MainActor
    func testFailedTogglePersistenceRollsBackVisibilityAndSkipsHaptic() {
        let reminder = CreateReminder(text: "Keep open")
        var reminders = [reminder]
        var visibleIDs = Set<CreateReminder.ID>()
        var playedFeedback: [HapticFeedbackClass] = []
        let visibleIDsBinding = Binding(
            get: { visibleIDs },
            set: { visibleIDs = $0 }
        )

        let didToggle = CreateReminderCompletionVisibility.toggleReminderWithCompletionFeedback(
            reminder,
            in: &reminders,
            showsOnlyUnsolved: true,
            visibleIDs: visibleIDsBinding,
            hapticFeedback: HapticFeedbackService { playedFeedback.append($0) },
            persist: { _ in false }
        )

        XCTAssertFalse(didToggle)
        XCTAssertEqual(reminders, [reminder])
        XCTAssertTrue(visibleIDs.isEmpty)
        XCTAssertTrue(playedFeedback.isEmpty)
    }

    func testReminderSwipeOnlyTracksLeftDragAndDeletesAfterThreshold() {
        XCTAssertEqual(CreateReminderSwipeAction.minimumDistance, 0)
        XCTAssertTrue(CreateReminderSwipeAction.shouldTrackSwipe(translation: CGSize(width: -24, height: 4)))
        XCTAssertFalse(CreateReminderSwipeAction.shouldTrackSwipe(translation: CGSize(width: -4, height: 24)))
        XCTAssertFalse(CreateReminderSwipeAction.shouldTrackSwipe(translation: CGSize(width: 24, height: 4)))
        XCTAssertEqual(CreateReminderSwipeAction.offset(for: 24), 0)
        XCTAssertEqual(CreateReminderSwipeAction.offset(for: -24), -24 * NomaScale.taskDeleteSwipeDamping)
        XCTAssertFalse(CreateReminderSwipeAction.shouldDelete(offset: -24))
        XCTAssertFalse(CreateReminderSwipeAction.shouldDelete(offset: CreateReminderSwipeAction.offset(for: -24)))
        XCTAssertTrue(CreateReminderSwipeAction.shouldDelete(offset: -CreateReminderSwipeAction.deleteThreshold))
    }

    func testReminderSwipeProgressTracksDeleteThreshold() {
        XCTAssertEqual(CreateReminderSwipeAction.progress(for: 0), 0)
        XCTAssertEqual(CreateReminderSwipeAction.remainingProgress(for: 0), 1)
        XCTAssertEqual(
            CreateReminderSwipeAction.progress(for: -CreateReminderSwipeAction.deleteThreshold),
            1
        )
        XCTAssertEqual(
            CreateReminderSwipeAction.remainingProgress(for: -CreateReminderSwipeAction.deleteThreshold),
            0
        )
    }

    func testReminderSwipeFeedbackOnlyPlaysWhenCrossingDeleteThreshold() {
        XCTAssertEqual(
            CreateReminderSwipeAction.feedback(previousOffset: -24, currentOffset: -CreateReminderSwipeAction.deleteThreshold),
            .taskSwipeDeleteThreshold
        )
        XCTAssertNil(
            CreateReminderSwipeAction.feedback(
                previousOffset: -CreateReminderSwipeAction.deleteThreshold,
                currentOffset: -CreateReminderSwipeAction.deleteThreshold - 1
            )
        )
        XCTAssertNil(CreateReminderSwipeAction.feedback(previousOffset: 0, currentOffset: -24))
    }
}

@testable import Noma
import CoreGraphics
import XCTest

final class UICleanupTests: XCTestCase {
    func testSwipeDeleteThresholdPlaysCanonicalFeedbackOnlyWhenCrossingThreshold() {
        var playedFeedback: [HapticFeedbackClass] = []
        let haptics = HapticFeedbackService { playedFeedback.append($0) }

        CreateReminderSwipeAction.playFeedbackIfNeeded(
            previousOffset: 0,
            currentOffset: -CreateReminderSwipeAction.deleteThreshold,
            using: haptics
        )
        CreateReminderSwipeAction.playFeedbackIfNeeded(
            previousOffset: -CreateReminderSwipeAction.deleteThreshold,
            currentOffset: -CreateReminderSwipeAction.deleteThreshold - 1,
            using: haptics
        )
        CreateReminderSwipeAction.playFeedbackIfNeeded(
            previousOffset: 0,
            currentOffset: -1,
            using: haptics
        )

        XCTAssertEqual(playedFeedback, [.taskSwipeDeleteThreshold])
    }

    func testPrimaryGlassButtonStateCoversDisabledAndLoadingInteraction() {
        XCTAssertTrue(
            PrimaryGlassButtonState(isDisabled: false, isLoading: false).allowsInteraction
        )
        XCTAssertFalse(
            PrimaryGlassButtonState(isDisabled: true, isLoading: false).allowsInteraction
        )

        let loadingState = PrimaryGlassButtonState(isDisabled: false, isLoading: true)
        XCTAssertFalse(loadingState.allowsInteraction)
        XCTAssertTrue(loadingState.showsProgress)
    }

    func testHomeScrollPositionNormalizesTheTopInset() {
        XCTAssertEqual(
            HomeScrollPosition.normalizedOffsetY(contentOffsetY: -59, topContentInset: 59),
            0
        )
        XCTAssertEqual(
            HomeScrollPosition.normalizedOffsetY(contentOffsetY: -9, topContentInset: 59),
            50
        )
        XCTAssertEqual(
            HomeScrollPosition.normalizedOffsetY(contentOffsetY: .nan, topContentInset: 59),
            NomaSpacing.none
        )
    }

}

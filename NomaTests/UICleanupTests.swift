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

    func testProjectIconOptionsHaveUniqueSymbolsAndLocalizedLabelKeys() {
        let icons = ProjectIconPickerOption.icons

        XCTAssertFalse(icons.isEmpty)
        XCTAssertEqual(Set(icons.map(\.symbolName)).count, icons.count)
        XCTAssertEqual(Set(icons.map(\.accessibilityLabelKey)).count, icons.count)
        XCTAssertTrue(icons.allSatisfy { !$0.accessibilityLabelKey.isEmpty })
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

    func testHomeCreateButtonOffsetCompensatesForTheBottomSafeArea() {
        XCTAssertEqual(
            HomeViewLayout.createButtonVerticalOffset(bottomSafeAreaInset: 34),
            2
        )
        XCTAssertEqual(
            HomeViewLayout.createButtonVerticalOffset(bottomSafeAreaInset: 0),
            -32
        )
    }
}

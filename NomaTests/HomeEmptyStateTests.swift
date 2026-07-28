@testable import Noma
import XCTest

final class HomeEmptyStateTests: XCTestCase {
    func testHomeEmptyStateUsesHintCopyAndIcon() {
        let emptyState = HomeEmptyState.placeholder

        XCTAssertEqual(emptyState.systemImage, "plus.circle")
        XCTAssertEqual(emptyState.titleKey, "home.empty.title")
        XCTAssertEqual(emptyState.subtitleKey, "home.empty.subtitle")
    }

    func testHomeContentShowsEmptyStateOnlyWhenAllSectionsAreEmpty() {
        XCTAssertTrue(
            HomeContentVisibility.showsEmptyState(
                showsTodaySection: false,
                showsProjectSection: false,
                showsDailyGroupsSection: false
            )
        )
        XCTAssertFalse(
            HomeContentVisibility.showsEmptyState(
                showsTodaySection: true,
                showsProjectSection: false,
                showsDailyGroupsSection: false
            )
        )
    }
}

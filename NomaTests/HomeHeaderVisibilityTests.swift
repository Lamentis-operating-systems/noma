import XCTest
@testable import Noma

final class HomeHeaderVisibilityTests: XCTestCase {
    func testHomeHeaderVisibilityHidesAfterScrollingDownAndShowsAtTop() {
        XCTAssertTrue(HomeHeaderVisibility.isVisible(contentOffsetY: NomaSpacing.none))
        XCTAssertFalse(HomeHeaderVisibility.isVisible(contentOffsetY: NomaSize.scrollDismissSentinel))
        XCTAssertTrue(HomeHeaderVisibility.isVisible(contentOffsetY: -NomaSize.scrollDismissSentinel))
    }
}

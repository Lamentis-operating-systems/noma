@testable import Noma
import XCTest

final class HomeEmptyStateTests: XCTestCase {
    func testHomeEmptyStateKeepsCopyWithoutDecorativeIcon() {
        let emptyState = HomeEmptyState.placeholder

        XCTAssertEqual(emptyState.titleKey, "home.empty.title")
        XCTAssertEqual(emptyState.subtitleKey, "home.empty.subtitle")
    }
}

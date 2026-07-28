@testable import Noma
import XCTest

final class HintPresentationTests: XCTestCase {
    func testHintViewAddsDefaultHorizontalPadding() {
        XCTAssertEqual(HintViewLayout.horizontalPadding, NomaSpacing.xl)
    }

    func testCreateTaskEmptyStateUsesHintCopyAndNoIcon() {
        let emptyState = CreateTaskEmptyState.placeholder

        XCTAssertNil(emptyState.systemImage)
        XCTAssertEqual(emptyState.titleKey, "create.tasks.empty.today.title")
        XCTAssertEqual(emptyState.subtitleKey, "create.tasks.empty.today.subtitle")
    }
}

@testable import Noma
import XCTest

final class DesignSystemTokenTests: XCTestCase {
    func testSpacingContractExposesXsToken() {
        XCTAssertEqual(NomaSpacing.none, 0)
        XCTAssertEqual(NomaSpacing.xs, 4)
        XCTAssertEqual(NomaSpacing.xl, 24)
        XCTAssertEqual(NomaSpacing.xxl, 32)
    }
}

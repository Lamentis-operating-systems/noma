@testable import Noma
import XCTest

final class HapticFeedbackServiceTests: XCTestCase {
    func testHapticFeedbackServiceRoutesSubmitFeedback() {
        var playedFeedback: [HapticFeedbackClass] = []
        let haptics = HapticFeedbackService { feedback in
            playedFeedback.append(feedback)
        }

        haptics.play(.createTaskSubmit)

        XCTAssertEqual(playedFeedback, [.createTaskSubmit])
    }
}

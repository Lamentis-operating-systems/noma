@testable import Noma
import XCTest

final class SignupPresentationTests: XCTestCase {
    func testSignInWithAppleStateBlocksRepeatedTapsAndRecoveryUnavailability() {
        let ready = SignInWithAppleGlassButtonState(isLoading: false)
        let loading = SignInWithAppleGlassButtonState(isLoading: true)
        let recoveryBlocked = SignInWithAppleGlassButtonState(
            isLoading: false,
            isAvailable: false
        )

        XCTAssertFalse(ready.showsProgressSpinner)
        XCTAssertTrue(ready.allowsInteraction)
        XCTAssertTrue(loading.showsProgressSpinner)
        XCTAssertFalse(loading.allowsInteraction)
        XCTAssertFalse(recoveryBlocked.allowsInteraction)
    }
}

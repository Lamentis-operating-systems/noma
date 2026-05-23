@testable import Noma
import XCTest

final class SignupConsentTests: XCTestCase {
    func testSignInWithAppleRequiresPrivacyAcceptanceBeforeInteraction() {
        XCTAssertFalse(
            SignInWithAppleGlassButtonState(isLoading: false, hasAcceptedPrivacyPolicy: false).allowsInteraction
        )
        XCTAssertTrue(
            SignInWithAppleGlassButtonState(isLoading: false, hasAcceptedPrivacyPolicy: true).allowsInteraction
        )
    }

    func testSignupConsentLinksExternalPrivacyPolicy() {
        XCTAssertEqual(
            SignupConsent.privacyPolicyURL.absoluteString,
            "https://lamentis.de/naome/privacy"
        )
    }
}

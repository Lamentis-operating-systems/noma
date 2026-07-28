@testable import Noma
import XCTest

final class SignupConsentTests: XCTestCase {
    func testAppleSignInIsAvailableWithoutASeparateConsentToggle() {
        XCTAssertTrue(SignInWithAppleGlassButtonState(isLoading: false).allowsInteraction)
    }

    func testSignupConsentLinksExternalPrivacyPolicy() {
        XCTAssertEqual(
            SignupConsent.privacyPolicyURL(forLanguageCode: "en").absoluteString,
            "https://lamentis.de/en/noma/privacy"
        )
        XCTAssertEqual(
            SignupConsent.privacyPolicyURL(forLanguageCode: "de").absoluteString,
            "https://lamentis.de/de/noma/privacy"
        )
        XCTAssertEqual(
            SignupConsent.privacyPolicyURL(forLanguageCode: "fr").absoluteString,
            "https://lamentis.de/en/noma/privacy"
        )
    }
}

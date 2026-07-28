@testable import Noma
import XCTest

final class SupabaseConfigurationTests: XCTestCase {
    func testSupabaseConfigurationTargetsNomaProject() {
        XCTAssertEqual(
            SupabaseClientProvider.projectURL.absoluteString,
            "https://ogajkrmbznzpwjxhaxev.supabase.co"
        )
    }

    func testSupabaseConfigurationRequiresPublishableKey() {
        let configuration = SupabaseConfiguration(
            projectURL: SupabaseClientProvider.projectURL,
            publishableKey: ""
        )

        XCTAssertFalse(configuration.isConfigured)
    }

    @MainActor
    func testSupabaseCurrentConfigurationIncludesPublishableKey() {
        XCTAssertEqual(
            SupabaseClientProvider.currentConfiguration,
            SupabaseConfiguration(
                projectURL: SupabaseClientProvider.projectURL,
                publishableKey: SupabaseClientProvider.publishableKey
            )
        )
        XCTAssertTrue(SupabaseClientProvider.currentConfiguration.isConfigured)
    }

    func testSupabaseClientOptionsOptIntoLocalInitialSessionEmission() {
        XCTAssertTrue(SupabaseClientProvider.emitsLocalSessionAsInitialSession)
    }
}

#if DEBUG
@testable import Noma
import SwiftUI
import XCTest

final class NomaUITestLaunchConfigurationTests: XCTestCase {
    func testStrictParserAcceptsCompleteKnownConfiguration() throws {
        let runIdentifier = UUID(uuidString: "00000000-0000-0000-0000-00000000B001")!
        let configuration = try XCTUnwrap(NomaUITestLaunchConfiguration.parse(arguments: [
            "Noma",
            "--noma-ui-test-scenario", "signup",
            "--noma-ui-test-locale", "de",
            "--noma-ui-test-dynamic-type", "AX5",
            "--noma-ui-test-run-id", runIdentifier.uuidString
        ]))

        XCTAssertEqual(configuration.scenario, .signup)
        XCTAssertEqual(configuration.localeIdentifier, "de")
        XCTAssertEqual(configuration.dynamicTypeSize, .accessibility5)
        XCTAssertEqual(configuration.runIdentifier, runIdentifier)
    }

    func testStrictParserRejectsUnknownOrIncompleteConfiguration() {
        let validArguments = [
            "Noma",
            "--noma-ui-test-scenario", "workspace",
            "--noma-ui-test-locale", "en",
            "--noma-ui-test-dynamic-type", "default",
            "--noma-ui-test-run-id", "00000000-0000-0000-0000-00000000B002"
        ]

        XCTAssertNil(NomaUITestLaunchConfiguration.parse(arguments: replacing("en", with: "fr", in: validArguments)))
        XCTAssertNil(NomaUITestLaunchConfiguration.parse(arguments: replacing("default", with: "AX6", in: validArguments)))
        XCTAssertNil(
            NomaUITestLaunchConfiguration.parse(
                arguments: replacing("00000000-0000-0000-0000-00000000B002", with: "not-a-uuid", in: validArguments)
            )
        )
        XCTAssertNil(NomaUITestLaunchConfiguration.parse(arguments: Array(validArguments.dropLast(2))))
    }

    private func replacing(_ value: String, with replacement: String, in arguments: [String]) -> [String] {
        arguments.map { $0 == value ? replacement : $0 }
    }
}
#endif

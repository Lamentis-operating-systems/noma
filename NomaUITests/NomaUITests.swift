import XCTest

@MainActor
final class NomaUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    func testSignupKeepsPrivacyAndAppleSignInAccessible() {
        let app = launch(.signup, language: "en")

        XCTAssertTrue(app.buttons["signup-privacy-link"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["signup-apple-button"].isHittable)
        XCTAssertEqual(app.switches.matching(identifier: "signup-consent-toggle").count, 0)
    }

    func testEmptyHomeKeepsCopyAndCaptureWithoutCircularPlusIcon() {
        let app = launch(.empty, language: "en")
        let capture = app.buttons["home-create-button"]

        XCTAssertTrue(app.staticTexts["Nothing planned yet"].waitForExistence(timeout: 8))
        XCTAssertTrue(capture.waitForExistence(timeout: 3))
        XCTAssertTrue(capture.isEnabled)
        XCTAssertTrue(capture.isHittable)
        XCTAssertEqual(app.images.matching(identifier: "plus.circle").count, 0)
    }

    func testTodayCaptureCompleteAndSimplifiedSurfaces() {
        let app = launch(.workspace, language: "en")
        XCTAssertTrue(app.buttons["home-create-button"].waitForExistence(timeout: 8))

        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'home-project-'")).count, 0)
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'home-daily-group-'")).count, 0)
        app.buttons["home-create-button"].tap()

        let input = app.textFields["create-reminder-input"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons.matching(identifier: "create-reminder-tray-button").count, 0)
        XCTAssertEqual(app.buttons.matching(identifier: "project-sheet-create-button").count, 0)

        input.tap()
        input.typeText("Captured today")
        app.buttons["Send"].tap()
        XCTAssertTrue(app.staticTexts["Captured today"].waitForExistence(timeout: 5))

        let done = app.buttons["task-workspace-done-button"]
        XCTAssertTrue(done.isEnabled)
        done.tap()
        XCTAssertFalse(done.isEnabled)
    }

    private enum Scenario: String {
        case signup
        case empty
        case workspace
    }

    private func launch(_ scenario: Scenario, language: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "--noma-ui-test-scenario", scenario.rawValue,
            "--noma-ui-test-locale", language,
            "--noma-ui-test-dynamic-type", "default",
            "--noma-ui-test-run-id", UUID().uuidString,
            "-AppleLanguages", "(\(language))",
            "-AppleLocale", language == "de" ? "de_DE" : "en_US"
        ]
        app.launch()
        return app
    }
}
